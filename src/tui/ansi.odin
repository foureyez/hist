package tui

import "core:fmt"
import "core:os"

// Define colors
Color :: enum {
	Black   = 30,
	Red     = 31,
	Green   = 32,
	Yellow  = 33,
	Blue    = 34,
	Magenta = 35,
	Cyan    = 36,
	White   = 37,
	Reset   = 0,
}

// Clear the entire screen
clear_screen :: proc(fd: os.Handle) {
	fmt.fprint(fd, "\x1b[2J") // Clear
	fmt.fprint(fd, "\x1b[H") // Move cursor to 0,0
}

// Move cursor to specific X, Y coordinates (1-based)
move_cursor :: proc(fd: os.Handle, x, y: int) {
	fmt.fprintf(fd, "\x1b[%d;%dH", y, x)
}

// Set text color
set_color :: proc(fd: os.Handle, c: Color) {
	fmt.fprintf(fd, "\x1b[%dm", int(c))
}

// Hide/Show Cursor (Important for clean UI)
hide_cursor :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?25l")}
show_cursor :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?25h")}
reset_cursor :: proc(fd: os.Handle) {
	// \x1b[0m    = Reset all colors/styles
	// \x1b[2K    = Clear the entire current line
	// \r         = Move to start of line
	fmt.fprint(fd, "\x1b[0m\x1b[2K\r")
}


enable_alt_buffer :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?1049h")}
disable_alt_buffer :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?1049l")}
