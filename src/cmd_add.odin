package main

import "cli"
import "core:strconv"
import "core:time"


add_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) < 2 {
		return cli.error("'cmd' and 'exit code' required")
	}

	cmd := args[0]
	exit_code_str := args[1]

	exit_code, ok := strconv.parse_int(exit_code_str, 10)
	if !ok {
		return cli.error("exit code must be an integer")
	}

	cmd_info := Command_Info {
		cmd         = cmd,
		exit_code   = exit_code,
		executed_at = time.now(),
	}

	// Ignore error, nothing to do here
	_ = db_save_cmd(cmd_info)

	return nil
}
