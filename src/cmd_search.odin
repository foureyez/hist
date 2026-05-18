package main

import "base:runtime"
import "cli"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"
import "db"
import "tui"

UI_Model :: struct {
	cmds:     [dynamic]db.Command_Entry,
	selected: int,
}

DEFAULT_LIMIT :: 10000

search_cmd :: proc(args: []string) -> ^cli.Error {
	// defer free_all(context.temp_allocator)
	low_ts, high_ts := db.load_cmds(dbh, 0, DEFAULT_LIMIT)

	query := os.get_env_alloc("HISTR_QUERY", context.temp_allocator)
	result, err := search_ui(query, low_ts, high_ts)
	if err != nil {
		// How to return cli error
	}
	if len(result) > 0 {
		os.write_string(os.stdout, result)
	}
	return nil
}

search_ui :: proc(start_query: string, low_ts, high_ts: time.Time) -> (string, Error) {
	tty, tferr := os.open("/dev/tty", os.O_RDWR)
	assert(tferr == nil, "unable to open tty")

	ui, terr := tui.new_tui(
		{.FULLSCREEN},
		tty,
		padding = tui.Padding{top = 1, right = 2, bottom = 1, left = 2},
	)
	if terr != nil {
		return "", terr
	}
	defer tui.cleanup(ui)

	query: strings.Builder
	defer strings.builder_destroy(&query)
	strings.write_string(&query, start_query)

	ui_model := UI_Model{}
	defer delete(ui_model.cmds)
	db.search_cmd(dbh, &ui_model.cmds, start_query, ui.size.y - 5)

	// limit := 50
	refresh_rate := 1000 / 60 // 60FPS
	curr_load_idx := 0
	low_ts, high_ts := low_ts, high_ts

	ui_query: strings.Builder
	defer strings.builder_destroy(&ui_query)
	line_buf: strings.Builder
	defer strings.builder_destroy(&line_buf)

	for {
		event := tui.poll_event(ui, refresh_rate)

		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
				strings.write_rune(&query, e.key.char)
				db.search_cmd(dbh, &ui_model.cmds, strings.to_string(query), ui.size.y - 5)
			case .Backspace:
				strings.pop_rune(&query)
				db.search_cmd(dbh, &ui_model.cmds, strings.to_string(query), ui.size.y - 5)
			case .Up:
				ui_model.selected = max(ui_model.selected - 1, 0)
			case .Down:
				ui_model.selected = min(ui_model.selected + 1, len(ui_model.cmds) - 1)
			case .Enter:
				if ui_model.selected < len(ui_model.cmds) {
					return ui_model.cmds[ui_model.selected].cmd, nil
				}
				return "", nil
			case .Ctrl:
				switch e.key.char {
				case 'c':
					return "", nil
				case 'r':
					// Load next page records in db
					curr_load_idx += DEFAULT_LIMIT
					low_ts, high_ts = db.load_cmds(dbh, curr_load_idx, DEFAULT_LIMIT)
					// and filter the new cmds
					db.search_cmd(dbh, &ui_model.cmds, strings.to_string(query), ui.size.y - 5)
				case 'g':
					// Load prev page records in db
					curr_load_idx -= DEFAULT_LIMIT
					low_ts, high_ts = db.load_cmds(
						dbh,
						curr_load_idx - DEFAULT_LIMIT,
						DEFAULT_LIMIT,
					)
					// and filter the new cmds
					db.search_cmd(dbh, &ui_model.cmds, strings.to_string(query), ui.size.y - 5)
				}
			case .Esc:
				return "", nil
			}
		}

		strings.builder_reset(&ui_query)
		strings.write_string(&ui_query, "> ")
		strings.write_string(&ui_query, strings.to_string(query))

		tui.write_string(ui, strings.to_string(ui_query))
		for entry, i in ui_model.cmds {
			fg := i == ui_model.selected ? tui.Grey : entry.exit_code > 0 ? tui.Red : tui.White

			// Left-aligned: command text
			tui.write_string(ui, entry.cmd, fg)

			// Right-aligned: metadata
			strings.builder_reset(&line_buf)
			humanize_time_sb(&line_buf, entry.timestamp_sec)
			fmt.sbprintf(&line_buf, "  %dms", entry.duration_sec)
			meta := strings.to_string(line_buf)
			meta_x := ui.size.x - len(meta)
			row := ui.curr_line - 1 // write_string already incremented
			if meta_x > 0 {
				tui.raw_draw(ui, meta_x, row, meta, fg)
			}
		}
		// Status line on last row: time range of loaded commands
		strings.builder_reset(&line_buf)
		ly, lm, ld := time.date(low_ts)
		lh, lmin, ls := time.clock_from_time(low_ts)
		hy, hm, hd := time.date(high_ts)
		hh, hmin, hs := time.clock_from_time(high_ts)
		fmt.sbprintf(
			&line_buf,
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

		tui.raw_draw(ui, 0, ui.size.y - 1, strings.to_string(line_buf), tui.White, tui.DarkGreen)

		version_str := "hist:version: " + VERSION
		meta_x := ui.size.x - len(version_str)
		if meta_x > 0 {
			tui.raw_draw(ui, meta_x, ui.size.y - 1, version_str, tui.White, tui.DarkGreen)
		}

		tui.render_frame(ui)
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

