package tui

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:unicode/utf8"

Key :: struct {
	type: Key_Type,
	char: rune,
}

Key_Type :: enum {
	None,
	Char,
	Ctrl,
	Enter,
	Backspace,
	Tab,
	Esc,
	Arrow_Up,
	Arrow_Down,
	Arrow_Left,
	Arrow_Right,
}

// Simple non-blocking key reader
read_key :: proc(fd: os.Handle) -> Key {
	if !has_input(fd) {
		return Key{.None, 0}
	}

	// Buffer for a single max-length UTF-8 sequence (4 bytes)
	buf: [4]byte

	// 1. Read the first byte
	n, err := os.read(fd, buf[:1])
	if n == 0 || err != 0 {
		return Key{.None, 0}
	}

	b := buf[0]

	switch b {
	case 1 ..= 26:
		// If the byte is 13 (CR) or 10 (LF), it's Enter.
		// If the byte is 9, it's Tab.
		if b == 13 || b == 10 {return Key{.Enter, '\n'}}
		if b == 9 {return Key{.Tab, '\t'}}

		// Byte 1 is Ctrl+A, 2 is Ctrl+B, etc.
		// Map 1->'a', 3->'c', etc. (ASCII 'a' starts at 97)
		return Key{.Ctrl, rune('a' + (b - 1))}

	case 127, 8:
		return Key{.Backspace, 0}

	case:
		// Handle Regular utf8 input
		// Check how many total bytes this rune SHOULD have
		// utf8.rune_size returns 1, 2, 3, or 4 based on the header byte
		// It returns -1 if the byte is invalid
		total_width := get_utf8_width(b)

		if total_width > 1 {
			current_index := 1
			for current_index < total_width {
				n, r_err := os.read(fd, buf[current_index:total_width])
				if r_err != nil || n == 0 {
					break
				}
				current_index += n
			}
		}
		r, _ := utf8.decode_rune(buf[:total_width])
		return Key{type = .Char, char = r}
	}
}

get_utf8_width :: proc(b: u8) -> int {
	if b < 0x80 do return 1 // 0xxxxxxx (ASCII)
	if (b & 0xE0) == 0xC0 do return 2 // 110xxxxx
	if (b & 0xF0) == 0xE0 do return 3 // 1110xxxx
	if (b & 0xF8) == 0xF0 do return 4 // 11110xxx
	return 1 // Invalid start byte, treat as 1 so we consume it and move on
}
