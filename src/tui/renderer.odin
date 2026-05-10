package tui

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
			fg   = NoColor,
		}
	}
}

draw_text :: proc(b: ^Buffer, x, y: int, text: string, fg: Color, bg: Color) {
	row := y
	col := x
	for r in text {
		if col >= 0 && col < b.width && row >= 0 && row < b.height {
			idx := (row * b.width) + col
			b.cells[idx].char = r
			b.cells[idx].fg = fg
			b.cells[idx].bg = bg
		}
		col += 1
	}
}

render_buffer :: proc(ctx: ^Context) {
	strings.builder_reset(&ctx.buffer_string)
	cursor_x, cursor_y := -1, -1

	x, y := 0, 0
	width := ctx.buffer.width

	for i in 0 ..< len(ctx.buffer.cells) {
		back_cell := ctx.back_buffer.cells[i]
		cell := ctx.buffer.cells[i]


		if cell != back_cell {
			if cursor_y != y || cursor_x != x {
				move_cursor_sb(&ctx.buffer_string, x + 1, y + 1)
				cursor_x, cursor_y = x, y
			}

			render_cell(&ctx.buffer_string, cell)
			ctx.back_buffer.cells[i] = cell
		}

		// Faster than calculating x and y at the start of the loop
		// x = i % ctx.buffer.width
		// y = i / ctx.buffer.width
		x += 1
		if x >= width {
			x = 0
			y += 1
		}
	}

	os.write(ctx.output, ctx.buffer_string.buf[:])
}

render_cell :: proc(sb: ^strings.Builder, cell: Cell) {
	// Faster than fmt.sbprintf(sb,	"\x1b[38;2;%d;%d;%d;48;2;%d;%d;%dm%r\x1b[0m",...)
	strings.write_string(sb, "\x1b[38;2;")

	strings.write_int(sb, int(cell.fg.r))
	strings.write_rune(sb, ';')
	strings.write_int(sb, int(cell.fg.g))
	strings.write_rune(sb, ';')
	strings.write_int(sb, int(cell.fg.b))
	strings.write_rune(sb, ';')


	if cell.bg != NoColor {
		strings.write_string(sb, ";48;2;") // Leading semicolon joins FG and BG
		strings.write_int(sb, int(cell.bg.r))
		strings.write_byte(sb, ';')
		strings.write_int(sb, int(cell.bg.g))
		strings.write_byte(sb, ';')
		strings.write_int(sb, int(cell.bg.b))
	}
	strings.write_byte(sb, 'm')
	strings.write_rune(sb, cell.char)
}

