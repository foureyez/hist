package main

import "cli"
import "core:strconv"
import "core:time"


add_start_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 1 {
		return cli.error("'cmd' required")
	}

	cmd := args[0]
	cmd_info := Command_Info {
		cmd         = cmd,
		executed_at = time.now(),
	}

	// Ignore error, nothing to do here
	_ = db_save_cmd(cmd_info)
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
