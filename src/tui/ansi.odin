package tui

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// Define colors
Color :: struct {
	r, g, b: int,
}

None :: Color{}

Black :: Color {
	r = 0,
	g = 0,
	b = 0,
}

Grey :: Color {
	r = 128,
	g = 128,
	b = 128,
}

White :: Color {
	r = 255,
	g = 255,
	b = 255,
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

save_cursor :: proc(fd: os.Handle) {
	fmt.fprint(fd, "\x1b[s")
}

restore_cursor :: proc(fd: os.Handle) {
	fmt.fprint(fd, "\x1b[u")
}

// Set text color
set_color :: proc(fd: os.Handle, c: Color) {
	fmt.fprintf(fd, "\x1b[%dm", int(0))
}

// Hide/Show Cursor (Important for clean UI)
hide_cursor :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?25l")}
show_cursor :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?25h")}
reset_cursor :: proc(fd: os.Handle, line_count: int) {
	// \x1b[0m    = Reset all colors/styles
	// \x1b[2K    = Clear the entire current line
	// \r         = Move to start of line
	fmt.fprintf(fd, "\033[1G\033[%dA\033[J", line_count)
}

move_cursor_up :: proc(fd: os.Handle, lines: int) {
	fmt.fprintf(fd, "\x1b[%dA", lines)
}


enable_alt_buffer :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?1049h")}
disable_alt_buffer :: proc(fd: os.Handle) {fmt.fprint(fd, "\x1b[?1049l")}

get_cursor_pos :: proc(fd: os.Handle) -> (x, y: int) {
	// 1. Request cursor position: ESC [ 6 n
	os.write_string(fd, "\x1b[6n")

	// 2. Read the response: ESC [ rows ; cols R
	// We read byte by byte to ensure we stop exactly at 'R'
	buf: [32]byte
	idx := 0

	for idx < len(buf) {
		b: [1]byte
		n, err := os.read(fd, b[:])
		if n == 0 || err != 0 {return 0, 0}

		// Store byte
		buf[idx] = b[0]

		// If we hit 'R', we are done
		if b[0] == 'R' {
			break
		}
		idx += 1
	}

	// 3. Parse the buffer
	// Example buffer: \x1b [ 2 4 ; 8 0 R

	// Check for valid prefix (ESC [)
	if buf[0] != 0x1b || buf[1] != '[' {
		return 0, 0
	}

	// Convert buffer up to 'R' into a string for parsing
	// We skip the first 2 bytes (ESC [) and exclude the last byte (R)
	response_str := string(buf[2:idx])

	// Split by ';'
	parts := strings.split(response_str, ";", context.temp_allocator)
	if len(parts) != 2 {
		return 0, 0
	}

	row, _ := strconv.parse_int(parts[0])
	col, _ := strconv.parse_int(parts[1])
	return col, row
}
