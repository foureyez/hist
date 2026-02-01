package tui

import "core:os"
import "core:unicode/utf8"

Key :: struct {
	type: Key_Type,
	char: rune,
}

Key_Type :: enum {
	None,
	Char,
	Ctrl,
	Alt,
	Enter,
	End,
	Del,
	PgUp,
	PgDown,
	Home,
	Backspace,
	Tab,
	Esc,
	Up,
	Down,
	Left,
	Right,
}

// Blocks until timeout has reached
read_key :: proc(fd: os.Handle, timeout_ms: int) -> Key {
	if !has_input(fd, timeout_ms) {
		return Key{.None, 0}
	}

	buf: [1]byte

	// 1. Read the first byte
	n, err := os.read(fd, buf[:])
	if n == 0 || err != 0 {
		return Key{.None, 0}
	}

	b := buf[0]
	switch b {
	case 127, 8:
		return Key{.Backspace, 0}
	case 13, 10:
		return Key{.Enter, '\n'}
	case 9:
		return Key{.Tab, '\t'}
	case 1 ..= 26:
		// Byte 1 is Ctrl+A, 2 is Ctrl+B, etc.
		// Map 1->'a', 3->'c', etc. (ASCII 'a' starts at 97)
		return Key{.Ctrl, rune('a' + (b - 1))}
	case 27:
		return parse_escape_sequence(fd, b)
	case:
		return parse_utf8_sequence(fd, b)
	}
}

parse_escape_sequence :: proc(fd: os.Handle, b: byte) -> Key {
	// We already read the ESC (0x1B).
	// We must check if more data is waiting IMMEDIATELY.
	// If we wait 5ms and nothing arrives, it's just the ESC key.

	// Tiny sleep to allow sequence bytes to arrive in buffer
	// TODO:: Need to see what to do here to remove.
	// Second thread?
	if !has_input(fd, 1) {
		return Key{type = .Esc}
	}

	// Read next byte
	buf: [1]u8
	os.read(fd, buf[:])
	b := buf[0]

	// Handle Alt + Key (ESC followed by a letter)
	if (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') {
		return Key{type = .Alt, char = rune(b)}
	}

	// Handle CSI sequences (starts with '[')
	if b == '[' {
		os.read(fd, buf[:]) // Read command byte
		c := buf[0]

		switch c {
		case 'A':
			return Key{type = .Up}
		case 'B':
			return Key{type = .Down}
		case 'C':
			return Key{type = .Right}
		case 'D':
			return Key{type = .Left}
		case 'H':
			return Key{type = .Home}
		case 'F':
			return Key{type = .End}
		// Tilde sequences (Delete, PageUp/Down) often look like ESC[3~
		case '1' ..< '6':
			// Read the tilde '~'
			tilde: [1]u8
			os.read(fd, tilde[:])
			switch c {
			case '3':
				return Key{type = .Del}
			case '5':
				return Key{type = .PgUp}
			case '6':
				return Key{type = .PgDown}
			}
		}
	}

	// Handle SS3 sequences (starts with 'O', usually F-keys or nav)
	// Zsh and some other shells use this for arrows (Application Mode)
	if b == 'O' {
		os.read(fd, buf[:])
		switch buf[0] {
		case 'A':
			return Key{type = .Up}
		case 'B':
			return Key{type = .Down}
		case 'C':
			return Key{type = .Right}
		case 'D':
			return Key{type = .Left}
		case 'H':
			return Key{type = .Home}
		case 'F':
			return Key{type = .End}
		}
	}

	return Key{type = .None}
}

parse_utf8_sequence :: proc(fd: os.Handle, b: byte) -> Key {
	buf: [4]byte
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

get_utf8_width :: proc(b: u8) -> int {
	if b < 0x80 do return 1 // 0xxxxxxx (ASCII)
	if (b & 0xE0) == 0xC0 do return 2 // 110xxxxx
	if (b & 0xF0) == 0xE0 do return 3 // 1110xxxx
	if (b & 0xF8) == 0xF0 do return 4 // 11110xxx
	return 1 // Invalid start byte, treat as 1 so we consume it and move on
}
