package main

import "core:log"
import "core:strings"
import "core:time"
import sql "deps:sqlite3"

DB_Error :: union {
	SDB_Error,
}

SDB_Error :: enum {
	PrepareStmtFailed,
	ExecStmtFailed,
	UnableToAddCmd,
}

ensure_schema :: proc(db: ^sql.DB) -> sql.Error {
	create_table_sql :=
		"CREATE TABLE IF NOT EXISTS cmd_history(" +
		"id INTEGER PRIMARY KEY AUTOINCREMENT, " +
		"cmd TEXT NOT NULL, " +
		"exit_code INTEGER, " +
		"duration INTEGER, " +
		"executed_at TEXT" +
		");"

	stmt, err := sql.stmt_prepare(db, create_table_sql)
	if err != nil {
		log.errorf("schema: prepare failed: %s", err)
		return err
	}
	defer sql.stmt_close(stmt)

	_, exec_err := sql.stmt_exec(stmt)
	if exec_err != nil {
		log.errorf("schema: exec failed: %s", exec_err)
		return exec_err
	}

	log.info("Database schema ensured")
	return nil
}

db_add_cmd :: proc(cmd: string, executed_at: time.Time) -> (i64, DB_Error) {
	query := "insert into cmd_history(cmd, executed_at) values(?, ?) RETURNING id;"
	stmt, err := sql.stmt_prepare(db, query, cmd, executed_at)
	if err != nil {
		return 0, .PrepareStmtFailed
	}
	defer sql.stmt_close(stmt)

	if !sql.row_next(stmt) {
		return 0, .UnableToAddCmd
	}
	id: i64
	sql.row_scan(stmt, context.temp_allocator, &id)
	return id, nil
}

db_update_cmd :: proc(id: i64) -> DB_Error {
	query := "insert into cmd_history(cmd, exit_code, executed_at) values(?, ?, ?) RETURNING id;"
	stmt, err := sql.stmt_prepare(
		db,
		query,
		cmd_info.cmd,
		cmd_info.exit_code,
		cmd_info.executed_at,
	)
	if err != nil {
		return .PrepareStmtFailed
	}
	defer sql.stmt_close(stmt)

	for {
		if !sql.row_next(stmt) {
			break
		}
		id: i64
		sql.row_scan(stmt, context.temp_allocator, &id)
	}

	return nil
}

db_list_cmd :: proc(cmd_filter: string) -> ([]Command_Info, DB_Error) {
	search_term := "%"
	max_limit := 50
	if len(cmd_filter) > 0 {
		search_term = strings.join([]string{"%", cmd_filter, "%"}, "")
	}

	query := "select cmd, exit_code, executed_at from cmd_history where cmd like ? order by executed_at desc limit ?"
	stmt, err := sql.stmt_prepare(db, query, search_term, max_limit)
	if err != nil {
		return nil, .PrepareStmtFailed
	}
	defer sql.stmt_close(stmt)

	command_infos := make([dynamic]Command_Info, context.temp_allocator)

	for {
		if !sql.row_next(stmt) {
			break
		}
		cmd_info := Command_Info{}
		sql.row_scan(
			stmt,
			context.temp_allocator,
			&cmd_info.cmd,
			&cmd_info.exit_code,
			&cmd_info.executed_at,
		)
		append(&command_infos, cmd_info)
	}

	return command_infos[:], nil
}
