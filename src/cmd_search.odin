package main

import "base:runtime"
import "cli"
import "core:log"
import "core:os"
import "core:strings"
import "db"
import "tui"

UI_Model :: struct {
	cmds:     []string,
	selected: int,
}

search_cmd :: proc(args: []string) -> ^cli.Error {
	defer free_all(context.temp_allocator)
	db.load_cmds(dbh, 0, 100)

	query := os.get_env_alloc("HISTR_QUERY", context.temp_allocator)
	if err := search_ui(query); err != nil {
		// How to return cli error
	}
	return nil
}

search_ui :: proc(start_query: string) -> Error {
	tty, tferr := os.open("/dev/tty", os.O_RDWR)
	assert(tferr == nil, "unable to open tty")

	ui, terr := tui.new_tui({.FULLSCREEN}, tty)
	if terr != nil {
		return terr
	}
	defer tui.cleanup(ui)

	query: strings.Builder
	strings.write_string(&query, start_query)

	ui_model := UI_Model{}
	ui_model.cmds = db.search_cmd(dbh)

	// limit := 50
	refresh_rate := 1000 / 60 // 60FPS

	for {
		event := tui.poll_event(ui, refresh_rate)

		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
				strings.write_rune(&query, e.key.char)
				ui_model.cmds = db.search_cmd(dbh, strings.to_string(query))
			case .Backspace:
				strings.pop_rune(&query)
				ui_model.cmds = db.search_cmd(dbh, strings.to_string(query))
			case .Up:
				ui_model.selected = max(ui_model.selected - 1, 0)
			case .Down:
				ui_model.selected = min(ui_model.selected + 1, len(ui_model.cmds) - 1)
			case .Enter:
				os.write_string(os.stdout, ui_model.cmds[ui_model.selected])
				return nil
			case .Ctrl:
				switch e.key.char {
				case 'c':
					return nil
				case 'r':
					// Load more records in db
					db.load_cmds(dbh, 100, 1000)
					// and filter the new cmds
					ui_model.cmds = db.search_cmd(dbh, strings.to_string(query))
				}
			case .Esc:
				return nil
			}
		}


		ui_query: strings.Builder
		strings.write_string(&ui_query, "> ")
		strings.write_string(&ui_query, strings.to_string(query))

		tui.write_string(ui, strings.to_string(ui_query))
		for c, i in ui_model.cmds {
			if i == ui_model.selected {
				tui.write_string(ui, c, tui.Grey)
			} else {
				tui.write_string(ui, c)

			}
		}
		tui.render_frame(ui)
	}
}

