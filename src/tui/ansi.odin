package tui

import os "core:os"
import "core:strconv"
import "core:strings"

// Define colors
Color :: struct {
	r, g, b: i16,
}

NoColor :: Color {
	r = -1,
	g = -1,
	b = -1,
}

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
clear_screen :: proc(f: ^os.File) {
	os.write_string(f, "\x1b[2J") // Clear
	os.write_string(f, "\x1b[H") // Move cursor to 0,0
}

// Move cursor to specific X, Y coordinates (1-based)
move_cursor :: proc(f: ^os.File, x, y: int) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	move_cursor_sb(&sb, x, y)
	os.write_string(f, strings.to_string(sb))
}

move_cursor_sb :: proc(sb: ^strings.Builder, x, y: int) {
	strings.write_string(sb, "\x1b[")
	strings.write_int(sb, y)
	strings.write_string(sb, ";")
	strings.write_int(sb, x)
	strings.write_byte(sb, 'H')
}

save_cursor :: proc(f: ^os.File) {
	os.write_string(f, "\x1b[s")
}

restore_cursor :: proc(f: ^os.File) {
	os.write_string(f, "\x1b[u")
}

// Set text color
set_color :: proc(f: ^os.File, c: Color) {
	if c.r < 0 || c.g < 0 || c.b < 0 {
		os.write_string(f, "\x1b[0m")
		return
	}

	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "\x1b[38;2;")
	strings.write_int(&sb, int(c.r))
	strings.write_byte(&sb, ';')
	strings.write_int(&sb, int(c.g))
	strings.write_byte(&sb, ';')
	strings.write_int(&sb, int(c.b))
	strings.write_byte(&sb, 'm')

	os.write_string(f, strings.to_string(sb))
}

// Hide/Show Cursor (Important for clean UI)
hide_cursor :: proc(f: ^os.File) {os.write_string(f, "\x1b[?25l")}
show_cursor :: proc(f: ^os.File) {os.write_string(f, "\x1b[?25h")}
reset_cursor :: proc(f: ^os.File, line_count: int) {
	// \x1b[0m    = Reset all colors/styles
	// \x1b[2K    = Clear the entire current line
	// \r         = Move to start of line
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "\x1b[1G\x1b[")
	strings.write_int(&sb, line_count)
	strings.write_string(&sb, "A\x1b[J")

	os.write_string(f, strings.to_string(sb))
}

move_cursor_up :: proc(f: ^os.File, lines: int) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "\x1b[")
	strings.write_int(&sb, lines)
	strings.write_byte(&sb, 'A')

	os.write_string(f, strings.to_string(sb))
}


enable_alt_buffer :: proc(f: ^os.File) {os.write_string(f, "\x1b[?1049h")}
disable_alt_buffer :: proc(f: ^os.File) {os.write_string(f, "\x1b[?1049l")}

get_cursor_pos :: proc(fd: ^os.File) -> (x, y: int) {
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

