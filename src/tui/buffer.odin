package tui

import "core:fmt"
import "core:os"
import "core:strings"

Cell :: struct {
	char:  rune,
	color: Color,
}

Buffer :: struct {
	width, height: int,
	cells:         []Cell,
}

init_buffer :: proc(w, h: int) -> Buffer {
	b := Buffer {
		width  = w,
		height = h,
	}
	b.cells = make([]Cell, w * h)
	clear_buffer(&b)
	return b
}

destroy_buffer :: proc(b: ^Buffer) {
	delete(b.cells)
}

clear_buffer :: proc(b: ^Buffer) {
	for i in 0 ..< len(b.cells) {
		b.cells[i] = Cell {
			char  = ' ',
			color = .Reset,
		}
	}
}

draw_text :: proc(b: ^Buffer, x, y: int, text: string, color: Color) {
	row := y
	col := x
	for r in text {
		if col >= 0 && col < b.width && row >= 0 && row < b.height {
			idx := (row * b.width) + col
			b.cells[idx] = Cell {
				char  = r,
				color = color,
			}
		}
		col += 1
	}
}

// The "Render" pass
render_buffer :: proc(ctx: ^Context) {
	// Reset cursor to top-left
	move_cursor(ctx.output, 1, 1)

	last_color := Color.Reset

	for i in 0 ..< len(ctx.buffer.cells) {
		cell := ctx.buffer.cells[i]

		// Optimization: Only print color code if it changes
		if cell.color != last_color {
			set_color(ctx.output, cell.color)
			last_color = cell.color
		}

		os.write_rune(ctx.output, cell.char)

		// Handle wrapping manually if needed, or rely on terminal width
		if (i + 1) % ctx.buffer.width == 0 {
			// In raw mode, we might need explicit newlines depending on setup
			// But usually, we just fill the screen.
		}
	}
	// Flush stdout to ensure it draws immediately
	// Odin's fmt usually buffers, so explicit flush is good practice in loops
}
