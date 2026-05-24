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

Search_Model :: struct {
	cmds:          [dynamic]db.Command_Entry,
	selected:      int,
	result:        string,
	query:         strings.Builder,
	ui_query:      strings.Builder,
	line_buf:      strings.Builder,
	curr_load_idx: int,
	low_ts:        time.Time,
	high_ts:       time.Time,
}

DEFAULT_LIMIT :: 100000

search_cmd :: proc(args: []string) -> ^cli.Error {
	low_ts, high_ts := db.load_cmds(dbh, 0, DEFAULT_LIMIT)

	start_query := os.get_env_alloc("HISTR_QUERY", context.temp_allocator)

	model := Search_Model {
		low_ts  = low_ts,
		high_ts = high_ts,
	}
	defer search_model_destroy(&model)
	strings.write_string(&model.query, start_query)

	tty, tferr := os.open("/dev/tty", os.O_RDWR)
	assert(tferr == nil, "unable to open tty")

	err := tui.run(
		tui.App{init = search_init, update = search_update, view = search_view, model = &model},
		tui.Opts{flags = {.FULLSCREEN}, input = tty},
	)
	if err != nil {
		log.error(err)
		return nil
	}

	if len(model.result) > 0 {
		os.write_string(os.stdout, model.result)
	}
	return nil
}

search_model_destroy :: proc(m: ^Search_Model) {
	delete(m.cmds)
	strings.builder_destroy(&m.query)
	strings.builder_destroy(&m.ui_query)
	strings.builder_destroy(&m.line_buf)
}

search_init :: proc(ctx: ^tui.Context, ptr: rawptr) -> tui.Cmd {
	m := cast(^Search_Model)ptr
	db.search_cmd(dbh, &m.cmds, strings.to_string(m.query), ctx.size.y - 5)
	return .None
}

search_update :: proc(ctx: ^tui.Context, ptr: rawptr, msg: tui.Msg) -> tui.Cmd {
	m := cast(^Search_Model)ptr

	key_msg, is_key := msg.(tui.Key_Msg)
	if !is_key {
		return .None
	}

	#partial switch key_msg.key.type {
	case .Char:
		strings.write_rune(&m.query, key_msg.key.char)
		db.search_cmd(dbh, &m.cmds, strings.to_string(m.query), ctx.size.y - 5)
		if len(m.cmds) < m.selected {
			m.selected = 0
		}
	case .Backspace:
		strings.pop_rune(&m.query)
		db.search_cmd(dbh, &m.cmds, strings.to_string(m.query), ctx.size.y - 5)
	case .Up:
		m.selected = max(m.selected - 1, 0)
	case .Down:
		m.selected = min(m.selected + 1, len(m.cmds) - 1)
	case .Enter:
		if m.selected < len(m.cmds) {
			m.result = m.cmds[m.selected].cmd
		}
		return .Quit
	case .Ctrl:
		switch key_msg.key.char {
		case 'c':
			return .Quit
		case 'r':
			m.curr_load_idx += DEFAULT_LIMIT
			m.low_ts, m.high_ts = db.load_cmds(dbh, m.curr_load_idx, DEFAULT_LIMIT)
			db.search_cmd(dbh, &m.cmds, strings.to_string(m.query), ctx.size.y - 5)
		case 'g':
			m.curr_load_idx -= DEFAULT_LIMIT
			m.low_ts, m.high_ts = db.load_cmds(dbh, m.curr_load_idx - DEFAULT_LIMIT, DEFAULT_LIMIT)
			db.search_cmd(dbh, &m.cmds, strings.to_string(m.query), ctx.size.y - 5)
		}
	case .Esc:
		return .Quit
	}

	return .None
}

search_view :: proc(ctx: ^tui.Context, ptr: rawptr) {
	m := cast(^Search_Model)ptr

	// Query line
	strings.builder_reset(&m.ui_query)
	strings.write_string(&m.ui_query, "> ")
	strings.write_string(&m.ui_query, strings.to_string(m.query))
	tui.draw_line(ctx, strings.to_string(m.ui_query))

	// Command list
	for entry, i in m.cmds {

		style :=
			i == m.selected ? style_cmd_highlighted : entry.exit_code > 0 ? style_cmd_err : style_cmd_default

		max_size := ctx.size.x - 100
		cmd := get_cmd_string(entry.cmd, max_size)
		tui.draw_line(ctx, cmd, style)

		// Right-aligned metadata
		strings.builder_reset(&m.line_buf)
		humanize_time_sb(&m.line_buf, entry.timestamp_sec)
		strings.write_string(&m.line_buf, " ")
		humanize_duration_sb(&m.line_buf, entry.duration_ms)
		meta := strings.to_string(m.line_buf)
		meta_x := ctx.size.x - len(meta)
		row := ctx.curr_line - 1
		if meta_x > 0 {
			tui.draw_raw(ctx, meta_x, row, meta, style)
		}
	}

	// Status bar
	strings.builder_reset(&m.line_buf)
	ly, lm, ld := time.date(m.low_ts)
	lh, lmin, ls := time.clock_from_time(m.low_ts)
	hy, hm, hd := time.date(m.high_ts)
	hh, hmin, hs := time.clock_from_time(m.high_ts)
	fmt.sbprintf(
		&m.line_buf,
		"[%4d-%02d-%02d %02d:%02d:%02d — %4d-%02d-%02d %02d:%02d:%02d]",
		ly,
		int(lm),
		ld,
		lh,
		lmin,
		ls,
		hy,
		int(hm),
		hd,
		hh,
		hmin,
		hs,
	)
	tui.draw_raw(
		ctx,
		0,
		ctx.size.y - 1,
		strings.to_string(m.line_buf),
		tui.Style{fg = tui.White, bg = tui.DarkGreen},
	)

	version_str := "hist:version: " + VERSION
	meta_x := ctx.size.x - len(version_str)
	if meta_x > 0 {
		tui.draw_raw(
			ctx,
			meta_x,
			ctx.size.y - 1,
			version_str,
			tui.Style{fg = tui.White, bg = tui.DarkGreen},
		)
	}
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

get_cmd_string :: proc(cmd: string, max_size: int) -> string {
	sb: strings.Builder
	cmd := cmd
	suffix := ""
	if len(cmd) > max_size { 	// Avg size for timestamp and duration
		cmd, _ = strings.substring_to(cmd, max_size)
		suffix = "..."
	}

	for r in strings.trim_right_space(cmd) {
		if r == '\n' {
			strings.write_string(&sb, " ⏎ ")
		} else if r == '\t' {
			strings.write_byte(&sb, ' ')
		} else {
			strings.write_rune(&sb, r)
		}
	}
	strings.write_string(&sb, suffix)
	return strings.to_string(sb)
}

