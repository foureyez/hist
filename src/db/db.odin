package db

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:sys/info"
import "core:time"


DB :: struct {
	log:  ^os.File,
	idx:  ^os.File,
	cmds: [dynamic]string,
}

Error :: enum {
	DBOpenFailed          = 1,
	PrepareStmtFailed     = 2,
	PrepareStmtExecFailed = 3,
	BindPrepareStmtFailed = 4,
	AddCmdFailed          = 5,
}

Filter :: struct {
	query: string,
}

open :: proc(path: string) -> (^DB, Error) {
	log_path, lperr := filepath.join([]string{path, "histdb.log"}, context.temp_allocator)
	if lperr != nil {
		return nil, .DBOpenFailed
	}

	idx_path, iperr := filepath.join([]string{path, "histdb.idx"}, context.temp_allocator)
	if iperr != nil {
		return nil, .DBOpenFailed
	}


	log_file, lerr := os.open(log_path, {.Read, .Write, .Append, .Create})
	if lerr != nil {
		log.error(lerr)
		return nil, .DBOpenFailed
	}

	idx_file, ierr := os.open(idx_path, {.Read, .Write, .Append, .Create})
	if ierr != nil {
		log.error(ierr)
		return nil, .DBOpenFailed
	}

	db := new(DB)
	db.log = log_file
	db.idx = idx_file
	free_all(context.temp_allocator)
	return db, nil
}

add_cmd :: proc(db: ^DB, cmd: Command) -> Error {
	// TODO: acquire lock before calcuating offset and writing
	offset, oerr := os.file_size(db.log)
	if oerr != nil {
		log.error(oerr)
		return .AddCmdFailed
	}

	_, err := os.write_at(db.log, transmute([]u8)cmd, offset)
	if err != nil {
		log.error(err)
		return .AddCmdFailed
	}

	index := Command_Index {
		offset       = u64(offset),
		length       = u32(len(cmd)),
		timestamp_ms = time.time_to_unix(time.now()),
		duration_ms  = 0,
	}
	raw_idx := serialize(index)
	n, ierr := os.write(db.idx, raw_idx)
	if ierr != nil || n < len(raw_idx) {
		log.error(ierr)
		return .AddCmdFailed
	}

	return nil
}

load_cmds :: proc(db: ^DB, start_idx, limit: int) {
	if start_idx < 0 || limit <= 0 {
		return
	}

	idx_size, serr := os.file_size(db.idx)
	if serr != nil {
		log.error(serr)
		return
	}

	if idx_size == 0 {
		return
	}

	record_size := i64(size_of(Command_Index))
	if idx_size % record_size != 0 {
		log.error("corrupted index file: unexpected size")
		return
	}

	total_records := idx_size / record_size
	if i64(start_idx) >= total_records {
		return
	}

	remaining := total_records - i64(start_idx)
	count := i64(limit)
	if count > remaining {
		count = remaining
	}

	read_offset := i64(start_idx) * record_size
	read_len := count * record_size
	raw := make([]byte, read_len, context.allocator)
	n, rerr := os.read_at(db.idx, raw, read_offset)
	if rerr != nil || n < len(raw) {
		log.error(rerr)
		return
	}

	records, ok := deserialize_many(raw)
	if !ok {
		log.error("failed to deserialize index records")
		return
	}

	for record, i in records {
		cmd_raw := make([]byte, int(record.length), context.allocator)
		read_n, read_err := os.read_at(db.log, cmd_raw, i64(record.offset))
		if read_err != nil || read_n < len(cmd_raw) {
			log.error(read_err)
			continue
		}

		append(&db.cmds, string(cmd_raw))
		// fmt.println(start_idx + i, record, string(cmd_raw))
	}
}

search_cmd :: proc(db: ^DB, query: string = {}) -> []string {
	filtered_cmds := make([dynamic]string)

	mask := prepare_mask(query)
	for cmd in db.cmds {
		if fuzzy_search(cmd, query, mask) {
			append(&filtered_cmds, cmd)
		}
	}
	return filtered_cmds[:]
}

update_cmd :: proc(db: ^DB, id: u64, duration_ms: u32, exit_code: i32) -> Error {
	size := size_of(Command_Index)
	out := make([]byte, size)

	offset := i64(u64(size) * id)
	os.read_at(db.idx, out, offset)

	idx: Command_Index
	deserialize(out, &idx)

	idx.duration_ms = duration_ms
	idx.exit_code = exit_code

	out = serialize(idx)
	os.write_at(db.idx, out, offset)

	return nil
}

close :: proc(db: ^DB) {
	if db == nil {
		return
	}
	os.close(db.log)
	os.close(db.idx)
	free(db)
}

Command :: string
Command_Index :: struct #packed {
	offset:       u64,
	length:       u32,
	timestamp_ms: i64,
	duration_ms:  u32,
	exit_code:    i32,
}

serialize :: proc(record: Command_Index) -> []byte {
	record := record
	data := make([]byte, size_of(Command_Index), context.allocator)
	copy(data, slice.bytes_from_ptr(&record, size_of(Command_Index)))
	return data
}

deserialize :: proc(payload: []byte, record: ^Command_Index) -> bool {
	// TODO: convert bigendian to little endian
	if len(payload) != size_of(Command_Index) {
		return false
	}

	raw := slice.bytes_from_ptr(record, size_of(Command_Index))
	copy(raw, payload)
	return true
}

deserialize_many :: proc(payload: []byte) -> ([]Command_Index, bool) {
	record_size := size_of(Command_Index)
	if len(payload) % record_size != 0 {
		return nil, false
	}

	count := len(payload) / record_size
	records := make([]Command_Index, count)

	for i in 0 ..< count {
		start := i * record_size
		if !deserialize(payload[start:start + record_size], &records[i]) {
			return nil, false
		}
	}

	return records, true
}

