package main

import "cli"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"
import "db"
import "tui"

style_cmd_highlighted := tui.Style {
	fg = tui.White,
	bg = tui.DarkGreen,
}

style_cmd_default := tui.Style {
	fg = tui.White,
	bg = tui.NoColor,
}

style_cmd_err := tui.Style {
	fg = tui.Red,
	bg = tui.NoColor,
}

DEFAULT_LOAD_LIMIT :: 100000

search_table_cols := [?]tui.Column {
	{name = "Command", align = .Left},
	{name = "When", align = .Right, width = 12},
	{name = "Duration", align = .Right, width = 10},
}

Search_Model :: struct {
	cmds:          [dynamic]db.Command_Entry,
	query:         strings.Builder,
	ui_query:      strings.Builder,
	line_buf:      strings.Builder,
	table:         tui.Table,
	curr_load_idx: int,
	low_ts:        time.Time,
	high_ts:       time.Time,
}


search_cmd :: proc(args: []string) -> ^cli.Error {
	start_query := os.get_env_alloc("HISTR_QUERY", context.temp_allocator)
	tty, tferr := os.open("/dev/tty", os.O_RDWR)
	if tferr != nil {
		log.error(tferr)
		return nil
	}

	ctx, err := tui.new_tui({.FULLSCREEN}, input = tty)
	if err != nil {
		log.error(err)
		return nil
	}
	defer tui.cleanup(ctx)

	model := Search_Model{}
	search_init(ctx, &model, start_query)

	result := search_update(ctx, &model)
	if len(result) > 0 {
		os.write_string(os.stdout, result)
	}
	return nil
}

search_model_destroy :: proc(m: ^Search_Model) {
	delete(m.cmds)
	strings.builder_destroy(&m.query)
	strings.builder_destroy(&m.ui_query)
	strings.builder_destroy(&m.line_buf)
	tui.table_destroy(&m.table)
}

search_init :: proc(ctx: ^tui.Context, m: ^Search_Model, start_query: string) {
	strings.write_string(&m.query, start_query)
	m.low_ts, m.high_ts = db.load_cmds(dbh, 0, DEFAULT_LOAD_LIMIT)
	m.table = tui.table_new(
		search_table_cols[:],
		style_cmd_highlighted,
		border_set = tui.ASCII_BORDERS,
		flags = {.SHOW_HEADERS, .SHOW_BORDERS},
		height = ctx.size.y - 2,
	)
	db.search_cmd(dbh, &m.cmds, strings.to_string(m.query))
	rebuild_table(ctx, m)
}

search_update :: proc(ctx: ^tui.Context, m: ^Search_Model) -> string {
	for {
		event := tui.poll_event(ctx)
		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
				strings.write_rune(&m.query, e.key.char)
				db.search_cmd(dbh, &m.cmds, strings.to_string(m.query))
				rebuild_table(ctx, m)
			case .Backspace:
				strings.pop_rune(&m.query)
				db.search_cmd(dbh, &m.cmds, strings.to_string(m.query))
				rebuild_table(ctx, m)
			case .Up:
				tui.table_select_up(&m.table)
			case .Down:
				tui.table_select_down(&m.table)
			case .Enter:
				sel := m.table.selected
				if sel >= 0 && sel < len(m.cmds) {
					return m.cmds[sel].cmd
				}
			case .Ctrl:
				switch e.key.char {
				case 'c':
					return ""
				case 'r':
					// Load next page records in db
					m.curr_load_idx += DEFAULT_LOAD_LIMIT
					m.low_ts, m.high_ts = db.load_cmds(dbh, m.curr_load_idx, DEFAULT_LOAD_LIMIT)
					// and filter the new cmds
					db.search_cmd(dbh, &m.cmds, strings.to_string(m.query))
					rebuild_table(ctx, m)
				case 'g':
					// Load prev page records in db
					m.curr_load_idx -= DEFAULT_LOAD_LIMIT
					m.low_ts, m.high_ts = db.load_cmds(
						dbh,
						m.curr_load_idx - DEFAULT_LOAD_LIMIT,
						DEFAULT_LOAD_LIMIT,
					)
					// and filter the new cmds
					db.search_cmd(dbh, &m.cmds, strings.to_string(m.query))
					rebuild_table(ctx, m)
				}
			case .Esc:
				return ""
			}
		}

		search_view(ctx, m)
	}
}

search_view :: proc(ctx: ^tui.Context, m: ^Search_Model) {
	draw_query(ctx, m)
	draw_cmds(ctx, m)
	draw_footer(ctx, m)
	tui.render_frame(ctx)
}

draw_query :: proc(ctx: ^tui.Context, m: ^Search_Model) {
	strings.builder_reset(&m.line_buf)
	strings.write_string(&m.line_buf, "> ")
	strings.write_string(&m.line_buf, strings.to_string(m.query))
	tui.draw_line(ctx, strings.to_string(m.line_buf))
}

draw_cmds :: proc(ctx: ^tui.Context, m: ^Search_Model) {
	tui.table_draw(ctx, &m.table)
}

rebuild_table :: proc(ctx: ^tui.Context, m: ^Search_Model) {
	tui.table_clear(&m.table)
	for entry in m.cmds {
		strings.builder_reset(&m.line_buf)
		cmd := get_cmd_string(&m.line_buf, entry.cmd, ctx.size.x)
		cmd_str := strings.clone(cmd, context.temp_allocator)

		strings.builder_reset(&m.line_buf)
		humanize_time_sb(&m.line_buf, entry.timestamp_sec)
		time_str := strings.clone(strings.to_string(m.line_buf), context.temp_allocator)

		strings.builder_reset(&m.line_buf)
		humanize_duration_sb(&m.line_buf, entry.duration_ms)
		dur_str := strings.clone(strings.to_string(m.line_buf), context.temp_allocator)

		style := entry.exit_code > 0 ? style_cmd_err : style_cmd_default
		tui.table_add_row(&m.table, style, cmd_str, time_str, dur_str)
	}
}

draw_footer :: proc(ctx: ^tui.Context, m: ^Search_Model) {
	strings.builder_reset(&m.line_buf)
	strings.write_byte(&m.line_buf, '[')
	write_datetime_sb(&m.line_buf, m.low_ts)
	strings.write_string(&m.line_buf, " — ")
	write_datetime_sb(&m.line_buf, m.high_ts)
	strings.write_byte(&m.line_buf, ']')
	tui.draw_raw(ctx, 0, ctx.size.y - 1, strings.to_string(m.line_buf), style_cmd_highlighted)

	version_str := "hist:version: " + VERSION
	meta_x := ctx.size.x - len(version_str)
	if meta_x > 0 {
		tui.draw_raw(ctx, meta_x, ctx.size.y - 1, version_str, style_cmd_highlighted)
	}
}


write_datetime_sb :: proc(sb: ^strings.Builder, t: time.Time) {
	y, m, d := time.date(t)
	h, min, s := time.clock_from_time(t)
	fmt.sbprintf(sb, "%4d-%02d-%02d %02d:%02d:%02d", y, int(m), d, h, min, s)
}

humanize_time_sb :: proc(sb: ^strings.Builder, ts_sec: u32) {
	now := time.now()
	ts := time.unix(i64(ts_sec), 0)
	diff := time.diff(ts, now)

	secs := i64(time.duration_seconds(diff))
	if secs < 0 {
		secs = -secs
	}

	mins := secs / 60
	hours := mins / 60
	days := hours / 24

	if secs < 60 {
		fmt.sbprintf(sb, "%ds ago", secs)
	} else if mins < 60 {
		fmt.sbprintf(sb, "%dm ago", mins)
	} else if hours < 24 {
		fmt.sbprintf(sb, "%dh ago", hours)
	} else if days < 7 {
		fmt.sbprintf(sb, "%dd ago", days)
	} else if days < 30 {
		fmt.sbprintf(sb, "%dw ago", days / 7)
	} else if days < 365 {
		fmt.sbprintf(sb, "%dmo ago", days / 30)
	} else {
		fmt.sbprintf(sb, "%dy ago", days / 365)
	}
}


humanize_duration_sb :: proc(sb: ^strings.Builder, duration_ms: u32) {
	if duration_ms >= 1000 {
		fmt.sbprintf(sb, "%fs", f32(duration_ms) / 1000)
	} else {
		fmt.sbprintf(sb, "%dms", duration_ms)

	}
}

get_cmd_string :: proc(sb: ^strings.Builder, cmd: string, max_size: int) -> string {
	cmd := cmd
	suffix := ""
	if len(cmd) > max_size { 	// Avg size for timestamp and duration
		cmd, _ = strings.substring_to(cmd, max_size)
		suffix = "..."
	}

	for r in strings.trim_right_space(cmd) {
		if r == '\n' {
			strings.write_string(sb, " ⏎ ")
		} else if r == '\t' {
			strings.write_byte(sb, ' ')
		} else {
			strings.write_rune(sb, r)
		}
	}
	strings.write_string(sb, suffix)
	return strings.to_string(sb^)
}

