package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import sql "deps:sqlite3"

ctx: runtime.Context
add_cmd :: proc() {
	ctx = context

	db := &sql.sqlite3{}
	if res := sql.open("./test.db", &db); res != .OK {
		errMsg := sql.errmsg(db)
		fmt.printfln("failed to load db: %s", errMsg)
		return
	}


	fmt.println("db opened successfully")
	defer sql.close(db)

	query: cstring = "SELECT * from COMPANY WHERE NAME = ?;"
	stmt := &sql.sqlite3_stmt{}
	rc := sql.prepare_v3(db, query, -1, 0, &stmt, nil)
	if rc != .OK {
		fmt.printfln("Error while preparing stmt: %s", sql.errmsg(db))
		return
	}

	name: cstring = "Paul"
	rc = sql.bind_text(stmt, 1, name, -1, sql.STATIC)
	if rc != .OK {
		fmt.printfln("Error while binding: %s", sql.errmsg(db))
		return
	}
	fmt.println("query parameter bound")

	for {
		rc = sql.step(stmt)
		if rc != .ROW {
			break
		}

		id := sql.column_int(stmt, 0)
		name := sql.column_text(stmt, 1)
		fmt.printfln("%d: %s", id, name)
	}

	if rc != .DONE {
		fmt.println(rc)
		fmt.printfln("Stmt execution failed: %s", sql.errmsg(db))
	}

	if rc := sql.finalize(stmt); rc != .OK {
		fmt.printfln("unable to finalize sql stmt: %s", sql.errmsg(db))
	}
}
