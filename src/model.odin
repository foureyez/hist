package main

import "core:time"

Command_Info :: struct {
	cmd:         string,
	exit_code:   int,
	duration:    time.Duration,
	executed_at: time.Time,
}
