package main

import "base:runtime"
import "cli"
import "core:log"
import "core:os"
import "core:strings"
import "tui"

UI_Model :: struct {
	cmds:     []Command_Info,
	selected: int,
}

search_cmd :: proc(args: []string) -> ^cli.Error {
	defer free_all(context.temp_allocator)

	query := os.get_env_alloc("HISTR_QUERY", context.temp_allocator)
	search_ui(query)
	return nil
}

search_ui :: proc(start_query: string) {
	tty, tferr := os.open("/dev/tty", os.O_RDWR)
	assert(tferr == nil, "unable to open tty")

	ui, terr := tui.new_tui({.FULLSCREEN}, tty)
	if terr != nil {
		return
	}
	defer tui.cleanup(ui)

	query: strings.Builder
	strings.write_string(&query, start_query)

	ui_model := UI_Model{}
	query_stmt, err := db_prepare_list_stmt()
	if err != nil {
		log.errorf("Unable to prepare stmt for list cmd: %s", err)
		return
	}
	defer db_close_list_stmt(query_stmt)

	limit := 50
	ui_model.cmds, err = db_list_cmd(query_stmt, strings.to_string(query), limit)
	if err != nil {
		log.errorf("Unable to list cmd: %s", err)
		return
	}

	// ui_model.cmds, _ = db_list_cmd(strings.to_string(query), limit)

	for {
		event := tui.poll_event(ui)

		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
				strings.write_rune(&query, e.key.char)
				ui_model.cmds, _ = db_list_cmd(query_stmt, strings.to_string(query), limit)
			case .Backspace:
				strings.pop_rune(&query)
				ui_model.cmds, _ = db_list_cmd(query_stmt, strings.to_string(query), limit)
			case .Up:
				ui_model.selected = max(ui_model.selected - 1, 0)
			case .Down:
				ui_model.selected = min(ui_model.selected + 1, len(ui_model.cmds) - 1)
			case .Enter:
				os.write_string(os.stdout, ui_model.cmds[ui_model.selected].cmd)
				return
			case .Ctrl:
				log.info(e)
				if e.key.char == 'c' {
					return
				}
			case .Esc:
				log.info(e)
				return
			}
		}


		ui_query: strings.Builder
		strings.write_string(&ui_query, "> ")
		strings.write_string(&ui_query, strings.to_string(query))

		tui.write_string(ui, strings.to_string(ui_query))
		for c, i in ui_model.cmds {
			if i == ui_model.selected {
				tui.write_string(ui, c.cmd, tui.Grey)
			} else {
				tui.write_string(ui, c.cmd)

			}
		}
		tui.render_frame(ui)
	}
}

