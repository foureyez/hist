package main

import "cli"
import "core:fmt"
import "core:strconv"
import "core:time"


add_start_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 1 {
		return cli.error("'cmd' required")
	}

	cmd := args[0]
	id, _ := db_add_cmd(cmd, time.now())
	fmt.println(id)
	return nil
}

add_end_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 1 {
		return cli.error("'exit_code' required")
	}

	exit_code_str := args[0]
	exit_code, ok := strconv.parse_int(exit_code_str, 10)
	if !ok {
		return cli.error("exit code must be an integer")
	}

	return nil
}
