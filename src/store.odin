package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import "db"


ensure_schema :: proc(dbh: ^db.DB) -> db.Error {
	create_table_query := `
  CREATE TABLE IF NOT EXISTS cmd_history (
		id INTEGER PRIMARY KEY AUTOINCREMENT, 
		cmd TEXT NOT NULL, 
		exit_code INTEGER,
		duration INTEGER, 
		executed_at INTEGER
		);
  `


	stmt, err := db.stmt_prepare(dbh, create_table_query)
	if err != nil {
		log.errorf("schema: prepare failed: %s", err)
		return err
	}
	defer db.stmt_close(stmt)

	_, exec_err := db.stmt_exec(stmt)
	if exec_err != nil {
		log.errorf("schema: exec failed: %s", exec_err)
		return exec_err
	}

	log.info("Database schema ensured")
	return nil
}

enable_db_flags :: proc(dbh: ^db.DB) {
	query := "PRAGMA journal_mode = WAL;"

	stmt, err := db.stmt_prepare(dbh, query)
	if err != nil {
		log.errorf("schema: prepare failed: %s", err)
		return
	}
	defer db.stmt_close(stmt)

	_, exec_err := db.stmt_exec(stmt)
	if exec_err != nil {
		log.errorf("schema: exec failed: %s", exec_err)
	}
}

db_add_cmd :: proc(cmd: string, executed_at: time.Time) -> (i64, Error) {
	query := "insert into cmd_history(cmd, executed_at) values(?, ?) RETURNING id"
	stmt, err := db.stmt_prepare(dbh, query, cmd, executed_at)
	if err != nil {
		return 0, .PrepareStmtFailed
	}
	defer db.stmt_close(stmt)

	id: i64
	db.row_next(stmt)
	db.row_scan(stmt, context.temp_allocator, &id)
	return id, nil
}

db_update_cmd :: proc(id: i64, exit_code: int, duration_ns: i64) -> Error {
	query := "update cmd_history set exit_code = ?, duration = ? where id = ?;"
	stmt, err := db.stmt_prepare(dbh, query, exit_code, duration_ns, id)
	if err != nil {
		return .PrepareStmtFailed
	}
	defer db.stmt_close(stmt)

	for {
		if !db.row_next(stmt) {
			break
		}
		id: i64
		db.row_scan(stmt, context.temp_allocator, &id)
	}

	return nil
}

db_prepare_list_stmt :: proc() -> (^db.Stmt, Error) {
	query := "select cmd, exit_code, duration, executed_at from cmd_history where cmd like ? order by executed_at desc limit ?"

	stmt, err := db.stmt_prepare(dbh, query)
	if err != nil {
		return nil, .PrepareStmtFailed
	}
	return stmt, nil
}

db_list_cmd :: proc {
	db_list_cmd_stmt,
	db_list_cmd_base,
}

db_close_list_stmt :: proc(stmt: ^db.Stmt) {
	db.stmt_close(stmt)
}

db_list_cmd_stmt :: proc(stmt: ^db.Stmt, query: string, limit: int) -> ([]Command_Info, Error) {
	defer db.stmt_reset(stmt)

	query := query
	if len(query) > 0 {
		query = strings.join([]string{"%", query, "%"}, "")
	} else {
		query = "%"
	}

	if err := db.stmt_bind(stmt, query, limit); err != nil {
		log.errorf("Error while binding list stmt: %s", err)
		return nil, .PrepareStmtFailed
	}

	command_infos := make([dynamic]Command_Info, context.temp_allocator)

	for {
		if !db.row_next(stmt) {
			break
		}
		cmd_info := Command_Info{}
		db.row_scan(
			stmt,
			context.temp_allocator,
			&cmd_info.cmd,
			&cmd_info.exit_code,
			&cmd_info.duration,
			&cmd_info.executed_at,
		)
		append(&command_infos, cmd_info)
	}
	return command_infos[:], nil
}

db_list_cmd_base :: proc(query: string, limit: int) -> ([]Command_Info, Error) {
	search_term := "%"
	if len(query) > 0 {
		search_term = strings.join([]string{"%", query, "%"}, "")
	}

	sql_query := "select cmd, exit_code, duration, executed_at from cmd_history where cmd like ? order by executed_at desc limit ?"
	stmt, err := db.stmt_prepare(dbh, sql_query, search_term, limit)
	if err != nil {
		return nil, .PrepareStmtFailed
	}
	defer db.stmt_close(stmt)

	command_infos := make([dynamic]Command_Info, context.temp_allocator)

	for {
		if !db.row_next(stmt) {
			break
		}
		cmd_info := Command_Info{}
		db.row_scan(
			stmt,
			context.temp_allocator,
			&cmd_info.cmd,
			&cmd_info.exit_code,
			&cmd_info.duration,
			&cmd_info.executed_at,
		)
		append(&command_infos, cmd_info)
	}

	return command_infos[:], nil
}
