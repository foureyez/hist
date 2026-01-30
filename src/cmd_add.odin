package main

import "base:runtime"
import "cli"
import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import sql "deps:sqlite3"


add_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 2 {
		return cli.error("'cmd' and 'exit code' required")
	}

	cmd := args[0]
	exit_code := args[1]

	query := "insert into cmd_history(cmd, exit_code, executed_at) values(?, ?, ?)"
	stmt, err := sql.stmt_prepare(db, query)
	if err != nil {
		log.errorf("unable to prepare stmt: %s", err)
		return nil
	}
	defer sql.stmt_close(stmt)

	affected, eerr := sql.stmt_exec(stmt, cmd, exit_code, time.time_to_unix_nano(time.now()))
	if err != nil {
		log.errorf("unable to exec stmt: %s", err)
		return nil
	}

	return nil
}
