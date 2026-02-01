package main

import "core:log"
import "core:strings"
import sql "deps:sqlite3"

DB_Error :: union {
	SDB_Error,
}

SDB_Error :: enum {
	PrepareStmtFailed,
	ExecStmtFailed,
}

// ensure_schema makes sure the cmd_history table exists.
// Returns an sql.Error if something goes wrong.
ensure_schema :: proc(db: ^sql.DB) -> sql.Error {
	// Use a CREATE TABLE IF NOT EXISTS to be idempotent and safe on first-run.
	create_table_sql :=
		"CREATE TABLE IF NOT EXISTS cmd_history(" +
		"id INTEGER PRIMARY KEY AUTOINCREMENT, " +
		"cmd TEXT NOT NULL, " +
		"exit_code INTEGER, " +
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

db_save_cmd :: proc(cmd_info: Command_Info) -> DB_Error {
	query := "insert into cmd_history(cmd, exit_code, executed_at) values(?, ?, ?)"
	stmt, err := sql.stmt_prepare(db, query)
	if err != nil {
		return .PrepareStmtFailed
	}
	defer sql.stmt_close(stmt)

	affected, eerr := sql.stmt_exec(stmt, cmd_info.cmd, cmd_info.exit_code, cmd_info.executed_at)
	if eerr != nil {
		log.errorf("unable to exec stmt: %s", err)
		return .ExecStmtFailed
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
