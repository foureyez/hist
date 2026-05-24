package tui

import "core:strings"

Align :: enum {
	Left,
	Right,
}

Column :: struct {
	name:  string,
	width: int, // 0 = flex (takes remaining space after fixed columns)
	align: Align,
}

MAX_TABLE_COLS :: 8

Table_Row :: struct {
	cells: [MAX_TABLE_COLS]string,
	style: Style,
}

Table_Flag :: enum {
	SHOW_HEADERS,
	SHOW_BORDERS,
}

Table_Flags :: bit_set[Table_Flag]

Border_Set :: struct {
	h:            rune,
	v:            string,
	top_left:     string,
	top_right:    string,
	bottom_left:  string,
	bottom_right: string,
	top_tee:      string,
	bottom_tee:   string,
	left_tee:     string,
	right_tee:    string,
	cross:        string,
}

DEFAULT_BORDERS :: Border_Set {
	h            = '─',
	v            = "│",
	top_left     = "┌",
	top_right    = "┐",
	bottom_left  = "└",
	bottom_right = "┘",
	top_tee      = "┬",
	bottom_tee   = "┴",
	left_tee     = "├",
	right_tee    = "┤",
	cross        = "┼",
}

ROUNDED_BORDERS :: Border_Set {
	h            = '─',
	v            = "│",
	top_left     = "╭",
	top_right    = "╮",
	bottom_left  = "╰",
	bottom_right = "╯",
	top_tee      = "┬",
	bottom_tee   = "┴",
	left_tee     = "├",
	right_tee    = "┤",
	cross        = "┼",
}

ASCII_BORDERS :: Border_Set {
	h            = '-',
	v            = "|",
	top_left     = "+",
	top_right    = "+",
	bottom_left  = "+",
	bottom_right = "+",
	top_tee      = "+",
	bottom_tee   = "+",
	left_tee     = "+",
	right_tee    = "+",
	cross        = "+",
}

Table :: struct {
	columns:        []Column,
	rows:           [dynamic]Table_Row,
	selected:       int,
	selected_style: Style,
	header_style:   Style,
	border_style:   Style,
	border_set:     Border_Set,
	flags:          Table_Flags,
	width:          int, // 0 = use ctx.size.x
	height:         int, // 0 = show all rows
	_scroll:        int,
	_line_buf:      strings.Builder,
}

table_new :: proc(
	columns: []Column,
	selected_style: Style,
	header_style: Style = DefaultStyle,
	border_style: Style = DefaultStyle,
	border_set: Border_Set = DEFAULT_BORDERS,
	flags: Table_Flags = nil,
	width: int = 0,
	height: int = 0,
) -> Table {
	return Table {
		columns = columns,
		selected_style = selected_style,
		header_style = header_style,
		border_style = border_style,
		border_set = border_set,
		flags = flags,
		width = width,
		height = height,
	}
}

table_destroy :: proc(t: ^Table) {
	delete(t.rows)
	strings.builder_destroy(&t._line_buf)
}

table_clear :: proc(t: ^Table) {
	clear(&t.rows)
	t._scroll = 0
}

table_add_row :: proc(t: ^Table, style: Style, cells: ..string) {
	row := Table_Row {
		style = style,
	}
	for cell, i in cells {
		if i >= MAX_TABLE_COLS do break
		row.cells[i] = cell
	}
	append(&t.rows, row)
}

table_select_up :: proc(t: ^Table) {
	row_count := len(t.rows)
	if row_count == 0 do return
	t.selected = (t.selected + row_count - 1) % row_count
}

table_select_down :: proc(t: ^Table) {
	row_count := len(t.rows)
	if row_count == 0 do return
	t.selected = (t.selected + 1) % row_count
}

table_draw :: proc(ctx: ^Context, t: ^Table) {
	n_cols := len(t.columns)
	if n_cols > MAX_TABLE_COLS do n_cols = MAX_TABLE_COLS
	if n_cols == 0 do return

	// Clamp selected to valid range
	if len(t.rows) > 0 {
		t.selected = clamp(t.selected, 0, len(t.rows) - 1)
	}

	has_borders := .SHOW_BORDERS in t.flags
	bs := t.border_set
	total_width := t.width > 0 ? t.width : ctx.size.x

	// Calculate column widths
	col_widths: [MAX_TABLE_COLS]int
	outer_width := has_borders ? 4 : 0 // "v " + " v"
	gap_width := has_borders ? 3 : 1 // " v " or " "
	total_gaps := n_cols > 1 ? (n_cols - 1) * gap_width : 0
	available := total_width - total_gaps - outer_width

	fixed_total := 0
	flex_count := 0
	for ci in 0 ..< n_cols {
		if t.columns[ci].width > 0 {
			col_widths[ci] = t.columns[ci].width
			fixed_total += t.columns[ci].width
		} else {
			flex_count += 1
		}
	}

	flex_width := flex_count > 0 ? max((available - fixed_total) / flex_count, 1) : 0
	for ci in 0 ..< n_cols {
		if t.columns[ci].width == 0 {
			col_widths[ci] = flex_width
		}
	}

	// Visible row range (scrolling when height is set)
	// height includes borders and headers, subtract overhead to get data rows
	overhead := 0
	if has_borders do overhead += 2 // top + bottom border
	if .SHOW_HEADERS in t.flags {
		overhead += 1 // header row
		if has_borders do overhead += 1 // header separator
	}
	row_count := len(t.rows)
	max_data_rows := t.height > 0 ? max(t.height - overhead, 1) : row_count
	visible := min(max_data_rows, row_count)
	if visible < row_count {
		if t.selected < t._scroll {
			t._scroll = t.selected
		}
		if t.selected >= t._scroll + visible {
			t._scroll = t.selected - visible + 1
		}
		t._scroll = clamp(t._scroll, 0, row_count - visible)
	} else {
		t._scroll = 0
	}
	row_start := t._scroll
	row_end := min(row_start + visible, row_count)

	// Top border
	if has_borders {
		strings.builder_reset(&t._line_buf)
		write_hline(&t._line_buf, col_widths, n_cols, bs.top_left, bs.top_tee, bs.top_right, bs.h)
		draw_line(ctx, strings.to_string(t._line_buf), t.border_style)
	}

	// Draw headers
	if .SHOW_HEADERS in t.flags {
		strings.builder_reset(&t._line_buf)
		if has_borders {
			strings.write_string(&t._line_buf, bs.v)
			strings.write_byte(&t._line_buf, ' ')
		}
		for ci in 0 ..< n_cols {
			if ci > 0 {
				if has_borders {
					strings.write_byte(&t._line_buf, ' ')
					strings.write_string(&t._line_buf, bs.v)
					strings.write_byte(&t._line_buf, ' ')
				} else {
					strings.write_byte(&t._line_buf, ' ')
				}
			}
			write_cell(&t._line_buf, t.columns[ci].name, col_widths[ci], t.columns[ci].align)
		}
		if has_borders {
			strings.write_byte(&t._line_buf, ' ')
			strings.write_string(&t._line_buf, bs.v)
		}
		draw_line(ctx, strings.to_string(t._line_buf), t.header_style)

		// Header separator
		if has_borders {
			strings.builder_reset(&t._line_buf)
			write_hline(
				&t._line_buf,
				col_widths,
				n_cols,
				bs.left_tee,
				bs.cross,
				bs.right_tee,
				bs.h,
			)
			draw_line(ctx, strings.to_string(t._line_buf), t.border_style)
		}
	}

	// Draw rows
	for i in row_start ..< row_end {
		row := t.rows[i]
		style := i == t.selected ? t.selected_style : row.style

		strings.builder_reset(&t._line_buf)
		if has_borders {
			strings.write_string(&t._line_buf, bs.v)
			strings.write_byte(&t._line_buf, ' ')
		}
		for ci in 0 ..< n_cols {
			if ci > 0 {
				if has_borders {
					strings.write_byte(&t._line_buf, ' ')
					strings.write_string(&t._line_buf, bs.v)
					strings.write_byte(&t._line_buf, ' ')
				} else {
					strings.write_byte(&t._line_buf, ' ')
				}
			}
			write_cell(&t._line_buf, row.cells[ci], col_widths[ci], t.columns[ci].align)
		}
		if has_borders {
			strings.write_byte(&t._line_buf, ' ')
			strings.write_string(&t._line_buf, bs.v)
		}
		draw_line(ctx, strings.to_string(t._line_buf), style)
	}

	// Bottom border
	if has_borders {
		strings.builder_reset(&t._line_buf)
		write_hline(
			&t._line_buf,
			col_widths,
			n_cols,
			bs.bottom_left,
			bs.bottom_tee,
			bs.bottom_right,
			bs.h,
		)
		draw_line(ctx, strings.to_string(t._line_buf), t.border_style)
	}
}

@(private = "file")
write_hline :: proc(
	sb: ^strings.Builder,
	col_widths: [MAX_TABLE_COLS]int,
	n_cols: int,
	left: string,
	mid: string,
	right: string,
	h: rune,
) {
	strings.write_string(sb, left)
	strings.write_rune(sb, h)
	for ci in 0 ..< n_cols {
		for _ in 0 ..< col_widths[ci] {
			strings.write_rune(sb, h)
		}
		if ci < n_cols - 1 {
			strings.write_rune(sb, h)
			strings.write_string(sb, mid)
			strings.write_rune(sb, h)
		}
	}
	strings.write_rune(sb, h)
	strings.write_string(sb, right)
}

@(private = "file")
write_cell :: proc(sb: ^strings.Builder, text: string, width: int, align: Align) {
	rune_cnt := 0
	trunc_byte := len(text)
	truncated := false

	for _, i in text {
		if rune_cnt == width {
			trunc_byte = i
			truncated = true
			break
		}
		rune_cnt += 1
	}

	display := text[:trunc_byte]
	display_len := truncated ? width : rune_cnt

	if display_len >= width {
		strings.write_string(sb, display)
		return
	}

	pad := width - display_len
	switch align {
	case .Right:
		for _ in 0 ..< pad {
			strings.write_byte(sb, ' ')
		}
		strings.write_string(sb, display)
	case .Left:
		strings.write_string(sb, display)
		for _ in 0 ..< pad {
			strings.write_byte(sb, ' ')
		}
	}
}

