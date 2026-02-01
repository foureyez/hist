package tui

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:os"
import "core:strings"

alpha := []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"}
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
			b.cells[idx].char = r
			b.cells[idx].fg = fg
			b.cells[idx].bg = bg
		}
		col += 1
	}
}

// The "Render" pass
render_buffer :: proc(ctx: ^Context) {
	strings.builder_reset(&ctx.buffer_string)
	cursor_x, cursor_y := -1, -1

	x, y := 0, 0
	width := ctx.buffer.width

	for i in 0 ..< len(ctx.buffer.cells) {
		prev_cell := ctx.back_buffer.cells[i]
		cell := ctx.buffer.cells[i]


		if cell != prev_cell {
			if cursor_y != y || cursor_x != x {
				// fmt.sbprintf(&ctx.buffer_string, "\x1b[%d;%dH", y + 1, x + 1)
				move_cursor_sb(&ctx.buffer_string, x + 1, y + 1)
				cursor_y = y
				cursor_x = x
			}

			render_cell(&ctx.buffer_string, cell)
			cursor_x += 1
			ctx.back_buffer.cells[i] = ctx.buffer.cells[i]
		}

		// More optimized than calculating x and y at the start of the loop 
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
	// fmt.sbprintf(
	// 	sb,
	// 	"\x1b[38;2;%d;%d;%d;48;2;%d;%d;%dm%r\x1b[0m",
	// 	cell.fg.r,
	// 	cell.fg.g,
	// 	cell.fg.b,
	// 	cell.bg.r,
	// 	cell.bg.g,
	// 	cell.bg.b,
	// 	cell.char,
	// )
	strings.write_string(sb, "\x1b[;38;2;")
	strings.write_int(sb, cell.fg.r)
	strings.write_rune(sb, ';')
	strings.write_int(sb, cell.fg.g)
	strings.write_rune(sb, ';')
	strings.write_int(sb, cell.fg.b)
	strings.write_rune(sb, ';')

	strings.write_string(sb, "48;2;")

	strings.write_int(sb, cell.bg.r)
	strings.write_rune(sb, ';')
	strings.write_int(sb, cell.bg.g)
	strings.write_rune(sb, ';')
	strings.write_int(sb, cell.bg.b)
	strings.write_rune(sb, 'm')

	strings.write_rune(sb, cell.char)
	strings.write_string(sb, "\x1b[0m")
}
