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
			b.cells[idx].char = r
			b.cells[idx].fg = fg
			b.cells[idx].bg = bg
		}
		col += 1
	}
}

// The "Render" pass
render_buffer :: proc(ctx: ^Context) {
	sb: strings.Builder
	strings.builder_init(&sb)
	defer strings.builder_destroy(&sb)

	cursor_x, cursor_y := -1, -1

	for i in 0 ..< len(ctx.buffer.cells) {
		prev_cell := ctx.prev_buffer.cells[i]
		cell := ctx.buffer.cells[i]
		x := i % ctx.buffer.width
		y := i / ctx.buffer.width


		if cell == prev_cell {
			// strings.write_rune(&sb, '.')
			continue
		}

		if cursor_y != y || cursor_x != x {
			fmt.sbprintf(&sb, "\x1b[%d;%dH", y + 1, x + 1)
			cursor_y = y
			cursor_x = x
		}

		render_cell(&sb, cell)
		cursor_x += 1
		ctx.prev_buffer.cells[i] = ctx.buffer.cells[i]
	}

	fmt.fprintf(ctx.output, strings.to_string(sb))
}

render_cell :: proc(sb: ^strings.Builder, cell: Cell) {
	fmt.sbprintf(
		sb,
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
