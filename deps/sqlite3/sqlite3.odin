package sqlite3

import "base:runtime"
import "core:c"
import "core:log"
import "core:strings"
import "core:time"

DB :: struct {
	handle: ^sqlite3,
}

Stmt :: struct {
	handle: ^sqlite3_stmt,
}

db_open :: proc(path: string) -> (^DB, Error) {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	sql_db: ^sqlite3
	if rc := open(cpath, &sql_db); rc != .OK {
		if sql_db != nil {
			close(sql_db)
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
	close(db.handle)
	free(db)
}


stmt_prepare :: proc(db: ^DB, query: string, args: ..any) -> (^Stmt, Error) {
	cquery := strings.clone_to_cstring(query)
	defer delete(cquery)
	sql_stmt: ^sqlite3_stmt
	if rc := prepare_v3(db.handle, cquery, -1, 0, &sql_stmt, nil); rc != .OK {
		log.errorf("unable to prepare stmt: %s", errmsg(db.handle))
		return nil, .PrepareStmtFailed
	}

	if err := stmt_bind(sql_stmt, ..args); err != nil {
		return nil, err
	}

	stmt := new(Stmt)
	stmt.handle = sql_stmt
	return stmt, nil
}

@(private = "file")
stmt_bind :: proc(stmt: ^sqlite3_stmt, args: ..any) -> Error {
	for arg, i in args {
		rc: ResultCode
		switch value in arg {
		case string:
			cval := strings.clone_to_cstring(value)
			rc = bind_text(stmt, i32(i) + 1, cval, -1, TRANSIENT)
			delete(cval)
		case int:
			rc = bind_int(stmt, i32(i) + 1, c.int(value))
		case time.Time:
			rc = bind_int64(stmt, i32(i) + 1, c.int64_t(time.to_unix_nanoseconds(value)))
		}

		if rc != .OK {
			log.errorf("unable to prepare stmt: %s", errmsg(db_handle(stmt)))
			return .BindPrepareStmtFailed
		}
	}

	return nil
}


stmt_exec :: proc(stmt: ^Stmt, args: ..any) -> (i64, Error) {
	if err := stmt_bind(stmt.handle, ..args); err != nil {
		return 0, err
	}

	if rc := step(stmt.handle); rc == .DONE {
		rows_modified := changes64(db_handle(stmt.handle))
		reset(stmt.handle)
		return rows_modified, nil
	}
	log.errorf("unable to exec stmt: %s", errmsg(db_handle(stmt.handle)))
	return 0, .PrepareStmtExecFailed
}

stmt_close :: proc(stmt: ^Stmt) {
	finalize(stmt.handle)
	free(stmt)
}

row_next :: proc(stmt: ^Stmt) -> bool {
	rc := step(stmt.handle)
	return rc == .ROW
}

row_scan :: proc(stmt: ^Stmt, allocator: runtime.Allocator = context.allocator, dest: ..any) {
	for d, i in dest {
		switch &val in d {
		case ^string:
			c_str := column_text(stmt.handle, i32(i))
			val^ = strings.clone_from_cstring(c_str, allocator)
		case ^int:
			v := int(column_int(stmt.handle, i32(i)))
			val^ = v
		case ^time.Time:
			v := i64(column_int64(stmt.handle, i32(i)))
			val^ = time.from_nanoseconds(v)
		}
	}
}

Error :: enum {
	DBOpenFailed          = 1,
	PrepareStmtFailed     = 2,
	PrepareStmtExecFailed = 3,
	BindPrepareStmtFailed = 4,
}
