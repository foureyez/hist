package sqlite3

import "core:c"

when ODIN_OS == .Darwin && ODIN_ARCH == .arm64 {
	foreign import lib "lib/macos-arm64/libsqlite3.a"
}

sqlite3 :: struct {
}

sqlite3_stmt :: struct {
}


@(default_calling_convention = "c", link_prefix = "sqlite3_")
foreign lib {
	config :: proc(flag: ..c.int) -> ResultCode ---
	open :: proc(path: cstring, db: ^^sqlite3) -> ResultCode ---
	close :: proc(db: ^sqlite3) -> ResultCode ---
	errmsg :: proc(db: ^sqlite3) -> cstring ---
	prepare_v3 :: proc(db: ^sqlite3, stmt: cstring, nByte: c.int, prepFlags: c.uint, ppStmt: ^^sqlite3_stmt, pzTail: ^cstring) -> ResultCode ---
	bind_text :: proc(stmt: ^sqlite3_stmt, _: c.int, _: cstring, _: c.int, lifetime: uintptr) -> ResultCode ---
	step :: proc(stmt: ^sqlite3_stmt) -> ResultCode ---

	column_int :: proc(stmt: ^sqlite3_stmt, i_col: c.int) -> c.int ---
	column_text :: proc(stmt: ^sqlite3_stmt, i_col: c.int) -> cstring ---
	column_double :: proc(stmt: ^sqlite3_stmt, i_col: c.int) -> c.double ---

	finalize :: proc(stmt: ^sqlite3_stmt) -> ResultCode ---
	free :: proc(val: rawptr) ---
}

STATIC :: uintptr(0)
TRANSIENT :: ~uintptr(0)


ResultCode :: enum {
	OK   = 0,
	ROW  = 100,
	DONE = 101,
}

ConfigFlags :: enum {
	SQLITE_CONFIG_STMTSTATUS = 1018,
}
