package main

import "base:runtime"
import "cli"
import "core:c"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:strings"
import "core:time"
import sql "deps:sqlite3"


add_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 2 {
		return cli.error("'cmd' and 'exit code' required")
	}

	cmd := args[0]
	exit_code_str := args[1]

	// Parse exit_code string to int
	exit_code, ok := strconv.parse_int(exit_code_str)
	if !ok {
		return cli.error("exit_code must be a valid integer")
	}

	// Validate exit code range (Unix convention: 0-255)
	if exit_code < 0 || exit_code > 255 {
		return cli.error("exit_code must be between 0 and 255")
	}

	query := "insert into cmd_history(cmd, exit_code, executed_at) values(?, ?, ?)"
	stmt, err := sql.stmt_prepare(db, query)
	if err != nil {
		log.errorf("unable to prepare stmt: %s", err)
		return nil
	}
	defer sql.stmt_close(stmt)

	affected, eerr := sql.stmt_exec(stmt, cmd, exit_code, time.now())
	if eerr != nil {
		log.errorf("unable to exec stmt: %s", eerr)
		return nil
	}

	return nil
}
