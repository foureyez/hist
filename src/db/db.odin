package db

import "base:runtime"
import "core:c"
import "core:log"
import "core:strings"
import "core:time"
import sqlite "deps:sqlite3"

DB :: struct {
	handle: ^sqlite.sqlite3,
}

Stmt :: struct {
	handle: ^sqlite.sqlite3_stmt,
}

Error :: enum {
	DBOpenFailed          = 1,
	PrepareStmtFailed     = 2,
	PrepareStmtExecFailed = 3,
	BindPrepareStmtFailed = 4,
}

db_open :: proc(path: string) -> (^DB, Error) {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	sql_db: ^sqlite.sqlite3
	if rc := sqlite.open(cpath, &sql_db); rc != .OK {
		if sql_db != nil {
			sqlite.close(sql_db)
		}
		return nil, .DBOpenFailed
	}

	db := new(DB)
	db.handle = sql_db
	return db, nil
}

db_close :: proc(db: ^DB) {
	if db == nil {
		return
	}
	sqlite.close(db.handle)
	free(db)
}


stmt_prepare :: proc(db: ^DB, query: string, args: ..any) -> (^Stmt, Error) {
	cquery := strings.clone_to_cstring(query)
	defer delete(cquery)
	sql_stmt: ^sqlite.sqlite3_stmt
	if rc := sqlite.prepare_v3(db.handle, cquery, -1, 0, &sql_stmt, nil); rc != .OK {
		log.errorf("unable to prepare stmt: %s", sqlite.errmsg(db.handle))
		return nil, .PrepareStmtFailed
	}

	stmt := new(Stmt)
	stmt.handle = sql_stmt

	if err := stmt_bind(stmt, ..args); err != nil {
		return nil, err
	}

	// raw_query := sqlite.expanded_sql(sql_stmt)
	// defer sqlite.free(&raw_query)
	// log.debugf("Prepared sql query: %s", raw_query)
	return stmt, nil
}

stmt_bind :: proc(stmt: ^Stmt, args: ..any) -> Error {
	for arg, i in args {
		rc: sqlite.ResultCode
		switch value in arg {
		case string:
			cval := strings.clone_to_cstring(value)
			rc = sqlite.bind_text(stmt.handle, i32(i) + 1, cval, -1, sqlite.TRANSIENT)
			delete(cval)
		case int:
			rc = sqlite.bind_int(stmt.handle, i32(i) + 1, c.int(value))
		case i64:
			rc = sqlite.bind_int64(stmt.handle, i32(i) + 1, i64(value))
		case time.Time:
			rc = sqlite.bind_int64(
				stmt.handle,
				i32(i) + 1,
				c.int64_t(time.to_unix_nanoseconds(value)),
			)
		}

		if rc != .OK {
			log.errorf("unable to prepare stmt: %s", sqlite.errmsg(sqlite.db_handle(stmt.handle)))
			return .BindPrepareStmtFailed
		}
	}

	return nil
}


stmt_exec :: proc(stmt: ^Stmt, args: ..any) -> (i64, Error) {
	if err := stmt_bind(stmt, ..args); err != nil {
		return 0, err
	}

	if rc := sqlite.step(stmt.handle); rc == .DONE {
		rows_modified := sqlite.changes64(sqlite.db_handle(stmt.handle))
		sqlite.reset(stmt.handle)
		return rows_modified, nil
	}
	log.errorf("unable to exec stmt: %s", sqlite.errmsg(sqlite.db_handle(stmt.handle)))
	return 0, .PrepareStmtExecFailed
}

stmt_reset :: proc(stmt: ^Stmt) {
	sqlite.reset(stmt.handle)
}

stmt_close :: proc(stmt: ^Stmt) {
	sqlite.finalize(stmt.handle)
	free(stmt)
}

row_next :: proc(stmt: ^Stmt) -> bool {
	rc := sqlite.step(stmt.handle)
	return rc == .ROW
}

row_scan :: proc(stmt: ^Stmt, allocator: runtime.Allocator = context.allocator, dest: ..any) {
	for d, i in dest {
		switch &val in d {
		case ^string:
			c_str := sqlite.column_text(stmt.handle, i32(i))
			val^ = strings.clone_from_cstring(c_str, allocator)
		case ^int:
			v := int(sqlite.column_int(stmt.handle, i32(i)))
			val^ = v
		case ^i64:
			v := i64(sqlite.column_int64(stmt.handle, i32(i)))
			val^ = v
		case ^time.Duration:
			v := i64(sqlite.column_int64(stmt.handle, i32(i)))
			val^ = time.Duration(v)
		case ^time.Time:
			v := i64(sqlite.column_int64(stmt.handle, i32(i)))
			val^ = time.from_nanoseconds(v)
		}
	}
}
