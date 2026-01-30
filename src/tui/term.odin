package tui

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:unicode/utf8"


TermSize :: struct {
	rows: int,
	cols: int,
}

// Simple non-blocking key reader
read_key :: proc() -> rune {
	if !has_input() {
		return utf8.RUNE_ERROR
	}

	// Buffer for a single max-length UTF-8 sequence (4 bytes)
	buf: [4]byte

	// 1. Read the first byte
	n, err := os.read(os.stdin, buf[:1])
	if n == 0 || err != 0 {
		return 0
	}

	// 2. Check how many total bytes this rune SHOULD have
	// utf8.rune_size returns 1, 2, 3, or 4 based on the header byte
	// It returns -1 if the byte is invalid
	total_width := get_utf8_width(buf[0])

	if total_width > 1 {
		current_index := 1
		for current_index < total_width {
			n, r_err := os.read(os.stdin, buf[current_index:total_width])
			if r_err != nil || n == 0 {
				break
			}
			current_index += n
		}
	}

	r, size := utf8.decode_rune(buf[:total_width])
	return r
}

get_utf8_width :: proc(b: u8) -> int {
	if b < 0x80 do return 1 // 0xxxxxxx (ASCII)
	if (b & 0xE0) == 0xC0 do return 2 // 110xxxxx
	if (b & 0xF0) == 0xE0 do return 3 // 1110xxxx
	if (b & 0xF8) == 0xF0 do return 4 // 11110xxx
	return 1 // Invalid start byte, treat as 1 so we consume it and move on
}
