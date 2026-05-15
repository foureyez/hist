package db

import "base:runtime"
import "core:os"

DB :: struct {
	file:   ^os.File,
	offset: i64,
}

Error :: enum {
	DBOpenFailed          = 1,
	PrepareStmtFailed     = 2,
	PrepareStmtExecFailed = 3,
	BindPrepareStmtFailed = 4,
	AddCmdFailed          = 5,
}

open :: proc(path: string) -> (^DB, Error) {
	file, err := os.open(path, {.Read, .Write, .Append})
	if err != nil {
		return nil, .DBOpenFailed
	}

	db := new(DB)
	db.file = file
	return db, nil
}

add_cmd :: proc(db: ^DB, cmd: string) -> Error {
	n, err := os.write_at(db.file, transmute([]u8)cmd, db.offset)
	if err != nil {
		return .AddCmdFailed
	}
	return nil
}

close :: proc(db: ^DB) {
	if db == nil {
		return
	}
	os.close(db.file)
	free(db)
}

