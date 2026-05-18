package main

import "cli"
import "core:log"
import "core:strconv"
import "db"


add_start_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 1 {
		return cli.error("'cmd' required")
	}

	cmd := args[0]
	err := db.add_cmd(dbh, cmd)
	if err != nil {
		log.error(err)
	}
	return nil
}

add_end_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 3 {
		return cli.error("'id', 'exit_code', 'duration' required")
	}

	id_str := args[0]
	exit_code_str := args[1]
	duration_str := args[2]

	offset, _ := strconv.parse_u64_of_base(id_str, 10)
	duration_ns, _ := strconv.parse_u64(duration_str, 10)
	exit_code, _ := strconv.parse_int(exit_code_str, 10)
	db.update_cmd(dbh, offset, u16(duration_ns), i8(exit_code))
	return nil
}

