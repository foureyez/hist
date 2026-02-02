package main

import "core:log"
import "core:strings"
import "core:time"
import "db"


ensure_schema :: proc(dbh: ^db.DB) -> db.Error {
	create_table_query :=
		"CREATE TABLE IF NOT EXISTS cmd_history(" +
		"id INTEGER PRIMARY KEY AUTOINCREMENT, " +
		"cmd TEXT NOT NULL, " +
		"exit_code INTEGER, " +
		"duration INTEGER, " +
		"executed_at INTEGER" +
		");"

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

db_list_cmd :: proc(cmd_filter: string) -> ([]Command_Info, Error) {
	search_term := "%"
	max_limit := 50
	if len(cmd_filter) > 0 {
		search_term = strings.join([]string{"%", cmd_filter, "%"}, "")
	}

	query := "select cmd, exit_code, duration, executed_at from cmd_history where cmd like ? order by executed_at desc limit ?"
	stmt, err := db.stmt_prepare(dbh, query, search_term, max_limit)
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
