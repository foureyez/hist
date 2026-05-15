package main

import "cli"
import "core:fmt"
import "core:strconv"
import "db"


add_start_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 1 {
		return cli.error("'cmd' required")
	}

	cmd := args[0]
	err := db.add_cmd(dbh, cmd)
	fmt.println("")
	return nil
}

add_end_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 3 {
		return cli.error("'id', 'exit_code', 'duration' required")
	}

	id_str := args[0]
	exit_code_str := args[1]
	duration_str := args[2]

	id, _ := strconv.parse_i64_of_base(id_str, 10)
	exit_code, _ := strconv.parse_int(exit_code_str, 10)
	duration_ns, _ := strconv.parse_i64_of_base(duration_str, 10)
	// db_update_cmd(id, exit_code, duration_ns)
	return nil
}

