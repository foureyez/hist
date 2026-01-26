package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import sql "deps:sqlite3"

list_cmd :: proc(args: []string) -> ^Cmd_Error {
	name: string = "Paul"
	stmt, err := sql.stmt_prepare(db, "SELECT * from COMPANY WHERE NAME = ?;", name)
	if err != nil {
		fmt.println(err)
		return nil
	}
	defer sql.stmt_close(stmt)

	for {
		if !sql.row_next(stmt) {
			break
		}

		id: int
		name: string
		sql.row_scan(stmt, &id, &name)
		fmt.printfln("%d: %s", id, name)
	}
	return nil
}
