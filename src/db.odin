package main

import "core:log"
import sql "deps:sqlite3"

// ensure_schema creates the cmd_history table if it doesn't exist
ensure_schema :: proc(db: ^sql.DB) -> sql.Error {
	schema := `
CREATE TABLE IF NOT EXISTS cmd_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cmd TEXT NOT NULL,
    exit_code INTEGER NOT NULL,
    executed_at DATETIME NOT NULL
);
`
	stmt, err := sql.stmt_prepare(db, schema)
	if err != nil {
		log.errorf("unable to prepare schema statement: %s", err)
		return err
	}
	defer sql.stmt_close(stmt)

	_, exec_err := sql.stmt_exec(stmt)
	if exec_err != nil {
		log.errorf("unable to execute schema statement: %s", exec_err)
		return exec_err
	}

	return nil
}
