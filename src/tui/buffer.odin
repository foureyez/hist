package tui

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

Cell :: struct {
	char: rune,
	fg:   Color,
	bg:   Color,
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
			char = ' ',
			fg   = None,
		}
	}
}

draw_text :: proc(b: ^Buffer, x, y: int, text: string, fg: Color, bg: Color) {
	row := y
	col := x
	for r in text {
		if col >= 0 && col < b.width && row >= 0 && row < b.height {
			idx := (row * b.width) + col
			b.cells[idx] = Cell {
				char = r,
				fg   = fg,
				bg   = bg,
			}
		}
		col += 1
	}
}

// The "Render" pass
render_buffer :: proc(ctx: ^Context) {

	save_cursor(ctx.output)
	for i in 0 ..< len(ctx.buffer.cells) {
		cell := ctx.buffer.cells[i]


		render_cell(ctx.output, cell)

		// Handle wrapping manually if needed, or rely on terminal width
		if (i + 1) % ctx.buffer.width == 0 {
			// In raw mode, we might need explicit newlines depending on setup
			// But usually, we just fill the screen.
		}
	}
	restore_cursor(ctx.output)
}

render_cell :: proc(fd: os.Handle, cell: Cell) {
	if cell.char == ' ' {
		fmt.fprintf(fd, "%r", cell.char)
	} else {
		fmt.fprintf(
			fd,
			"\x1b[38;2;%d;%d;%d;48;2;%d;%d;%dm%r\x1b[0m",
			cell.fg.r,
			cell.fg.g,
			cell.fg.b,
			cell.bg.r,
			cell.bg.g,
			cell.bg.b,
			cell.char,
		)
	}
}
