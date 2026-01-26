package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import sql "deps:sqlite3"

list_cmd :: proc(args: []string) -> ^Cmd_Error {
	search_term: string
	if len(args) > 0 {
		search_term = args[0]
	}
	query := "select cmd, exit_code, executed_at from cmd_history where cmd like ? order by executed_at desc limit 50"
	stmt, err := sql.stmt_prepare(db, query, search_term)
	if err != nil {
		return cli_error("unable to list")
	}
	defer sql.stmt_close(stmt)

	for {
		if !sql.row_next(stmt) {
			break
		}

		cmd: string
		exit_code: int
		executed_at: i64
		sql.row_scan(stmt, &cmd, &exit_code, &executed_at)
		fmt.printfln("%s: %d: %d", cmd, exit_code, executed_at)
	}
	return nil
}
