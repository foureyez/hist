package main

import "core:log"
import sql "deps:sqlite3"

// ensure_schema creates the cmd_history table if it doesn't exist
ensure_schema :: proc(db: ^sql.DB) -> sql.Error {
	query := `CREATE TABLE IF NOT EXISTS cmd_history(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		cmd TEXT NOT NULL,
		exit_code INTEGER,
		executed_at TEXT
	);`

	stmt, err := sql.stmt_prepare(db, query)
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

	log.debug("Database schema initialized successfully")
	return nil
}
