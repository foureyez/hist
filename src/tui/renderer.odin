#+private
package tui

import "core:mem"
import "core:os"
import "core:strings"


Cell :: struct {
	char:  rune,
	style: Style,
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
			style = NoStyle,
		}
	}
}

set_cell :: proc(b: ^Buffer, x, y: int, text: string, style: Style) -> int {
	row := y
	col := x
	for r in text {
		if col >= 0 && col < b.width && row >= 0 && row < b.height {
			idx := (row * b.width) + col
			b.cells[idx].char = r
			b.cells[idx].style = style
		}
		col += 1
	}
	return col - x
}

render_buffer :: proc(ctx: ^Context) {
	strings.builder_reset(&ctx.buffer_string)
	cursor_x, cursor_y := -1, -1
	last_style := NoStyle

	width := ctx.buffer.width
	total := len(ctx.buffer.cells)
	cell_size := size_of(Cell)

	i := 0
	for i < total {
		// OptimizationPass: Batch-skip 4 unchanged cells at a time
		if i + 4 <= total {
			front := ([^]byte)(&ctx.buffer.cells[i])
			back := ([^]byte)(&ctx.back_buffer.cells[i])
			span := cell_size * 4
			if mem.compare(front[:span], back[:span]) == 0 {
				i += 4
				continue
			}
		}

		cell := ctx.buffer.cells[i]
		back_cell := ctx.back_buffer.cells[i]

		if cell != back_cell {
			x := i % width
			y := i / width

			if cursor_y != y || cursor_x != x {
				move_cursor_sb(&ctx.buffer_string, x + 1, y + 1)
				cursor_x, cursor_y = x, y
			}

			is_style_changed := last_style != cell.style
			last_style = render_cell(&ctx.buffer_string, cell, is_style_changed)

			ctx.back_buffer.cells[i] = cell
			cursor_x = x + 1
			cursor_y = y
		}
		i += 1
	}

	os.write(ctx.output, ctx.buffer_string.buf[:])
}

is_cell_changed :: proc(curr: Cell, last: Cell) -> bool {
	return curr != last
}

// Optimization: fast color value write using ascii table
@(private = "file")
write_color_val :: #force_inline proc(sb: ^strings.Builder, v: u8) {
	if v >= 0 && v <= 255 {
		strings.write_byte(sb, ';')
		val := int(v)
		// 3 digit write
		if val >= 100 {
			strings.write_byte(sb, u8('0') + u8(val / 100))
			strings.write_byte(sb, u8('0') + u8((val / 10) % 10))
			strings.write_byte(sb, u8('0') + u8(val % 10))

			// 2 digit write
		} else if val >= 10 {
			strings.write_byte(sb, u8('0') + u8(val / 10))
			strings.write_byte(sb, u8('0') + u8(val % 10))
			// 1 digit write
		} else {
			strings.write_byte(sb, u8('0') + u8(val))
		}
	}
}

render_cell :: proc(sb: ^strings.Builder, cell: Cell, is_style_changed: bool) -> Style {
	if is_style_changed {
		strings.write_string(sb, "\x1b[")

		if cell.style.fg == NoColor {
			strings.write_string(sb, "39")
		} else {
			strings.write_string(sb, "38;2")
			write_color_val(sb, cell.style.fg.r)
			write_color_val(sb, cell.style.fg.g)
			write_color_val(sb, cell.style.fg.b)
		}

		if cell.style.bg == NoColor {
			strings.write_string(sb, ";49")
		} else {
			strings.write_string(sb, ";48;2")
			write_color_val(sb, cell.style.bg.r)
			write_color_val(sb, cell.style.bg.g)
			write_color_val(sb, cell.style.bg.b)
		}
		strings.write_byte(sb, 'm')
	}

	// Write_byte for ASCII, write_rune only for non-ASCII
	if cell.char < 128 {
		strings.write_byte(sb, u8(cell.char))
	} else {
		strings.write_rune(sb, cell.char)
	}
	return cell.style
}
