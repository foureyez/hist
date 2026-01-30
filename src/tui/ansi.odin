package tui

import "core:fmt"

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
clear_screen :: proc() {
	fmt.print("\x1b[2J") // Clear
	fmt.print("\x1b[H") // Move cursor to 0,0
}

// Move cursor to specific X, Y coordinates (1-based)
move_cursor :: proc(x, y: int) {
	fmt.printf("\x1b[%d;%dH", y, x)
}

// Set text color
set_color :: proc(c: Color) {
	fmt.printf("\x1b[%dm", int(c))
}

// Hide/Show Cursor (Important for clean UI)
hide_cursor :: proc() {fmt.print("\x1b[?25l")}
show_cursor :: proc() {fmt.print("\x1b[?25h")}
