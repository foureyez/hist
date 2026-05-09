package main

import "cli"
import "core:fmt"
import "tui"


test_cmd :: proc(args: []string) -> ^cli.Error {
	fmt.println("here")


	// tui.enable_raw_mode()
	// defer tui.disable_raw_mode()
	tui.poll_event(nil)
	return nil
}

