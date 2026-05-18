package db

import "base:runtime"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:time"

DB :: struct {
	log:      ^os.File,
	idx:      ^os.File,
	cmds:     [dynamic]Command_Entry,
	cmd_bulk: []byte,
}

Command_Entry :: struct {
	cmd:           string,
	timestamp_sec: u32,
	duration_sec:  u16,
	exit_code:     i8,
}

Command :: string
Command_Index :: struct #packed {
	offset:        u32,
	length:        u16,
	timestamp_sec: u32,
	duration_sec:  u16,
	exit_code:     i8,
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

add_cmd :: proc(db: ^DB, cmd: Command) -> (i64, Error) {
	// TODO: acquire lock before calcuating offset and writing
	log_offset, oerr := os.file_size(db.log)
	if oerr != nil {
		log.error(oerr)
		return 0, .AddCmdFailed
	}

	_, err := os.write_at(db.log, transmute([]u8)cmd, log_offset)
	if err != nil {
		log.error(err)
		return 0, .AddCmdFailed
	}

	idx := Command_Index {
		offset        = u32(log_offset),
		length        = u16(len(cmd)),
		timestamp_sec = u32(time.time_to_unix(time.now())),
		duration_sec  = 0,
	}
	idx_bytes := serialize(idx)
	idx_file_size, _ := os.file_size(db.idx)
	idx_offset := idx_file_size / size_of(Command_Index)


	n, ierr := os.write(db.idx, idx_bytes)
	if ierr != nil || n < len(idx_bytes) {
		log.error(ierr)
		return 0, .AddCmdFailed
	}


	return idx_offset, nil
}

update_cmd :: proc(db: ^DB, id: u64, duration_sec: u16, exit_code: i8) -> Error {
	size := size_of(Command_Index)
	out := make([]byte, size)

	offset := i64(u64(size) * id)
	os.read_at(db.idx, out, offset)

	idx: Command_Index
	deserialize(out, &idx)

	idx.duration_sec = duration_sec
	idx.exit_code = exit_code

	out = serialize(idx)
	os.write_at(db.idx, out, offset)

	return nil
}

load_cmds :: proc(db: ^DB, start_idx, limit: int) -> (low_ts, high_ts: time.Time) {
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

	defer free_all(context.temp_allocator)
	if db.cmd_bulk != nil {
		delete(db.cmd_bulk)
		clear(&db.cmds)
	}

	remaining := total_records - i64(start_idx)
	count := i64(limit)
	if count > remaining {
		count = remaining
	}

	read_offset := i64(start_idx) * record_size
	read_len := count * record_size
	raw := make([]byte, read_len, context.temp_allocator)
	n, rerr := os.read_at(db.idx, raw, read_offset)
	if rerr != nil || n < len(raw) {
		log.error(rerr)
		return
	}

	records, ok := deserialize_many(raw, context.temp_allocator)
	if !ok {
		log.error("failed to deserialize index records")
		return
	}

	first := records[0]
	last := records[len(records) - 1]

	low_ts = time.unix(i64(first.timestamp_sec), 0)
	high_ts = time.unix(i64(last.timestamp_sec), 0)
	log.infof("loaded %d commands: %v — %v", len(records), low_ts, high_ts)

	// Single bulk read: compute the byte span covering all commands
	span_start := i64(first.offset)
	span_end := i64(last.offset) + i64(last.length)
	span_len := span_end - span_start

	bulk := make([]byte, span_len, context.allocator)
	db.cmd_bulk = bulk
	bulk_n, bulk_err := os.read_at(db.log, bulk, span_start)
	if bulk_err != nil || bulk_n < len(bulk) {
		log.error(bulk_err)
		return
	}

	// Slice into the bulk buffer per record
	for record in records {
		lo := i64(record.offset) - span_start
		hi := lo + i64(record.length)
		append(
			&db.cmds,
			Command_Entry {
				cmd = string(bulk[lo:hi]),
				timestamp_sec = record.timestamp_sec,
				duration_sec = record.duration_sec,
				exit_code = record.exit_code,
			},
		)
	}
	return low_ts, high_ts
}

search_cmd :: proc(db: ^DB, result: ^[dynamic]Command_Entry, query: string = {}, limit := 100) {
	clear(result)

	mask := prepare_mask(query)
	for entry in db.cmds {
		if fuzzy_search(entry.cmd, query, mask) {
			append(result, entry)
			if len(result) > limit {
				return
			}
		}
	}
}


close :: proc(db: ^DB) {
	if db == nil {
		return
	}
	if db.cmd_bulk != nil {
		delete(db.cmd_bulk)
	}
	delete(db.cmds)

	if db.log != nil {
		os.close(db.log)
	}

	if db.idx != nil {
		os.close(db.idx)
	}
	free(db)
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

deserialize_many :: proc(
	payload: []byte,
	allocator := context.allocator,
) -> (
	[]Command_Index,
	bool,
) {
	record_size := size_of(Command_Index)
	if len(payload) % record_size != 0 {
		return nil, false
	}

	count := len(payload) / record_size
	records := make([]Command_Index, count, allocator)

	for i in 0 ..< count {
		start := i * record_size
		if !deserialize(payload[start:start + record_size], &records[i]) {
			return nil, false
		}
	}

	return records, true
}

