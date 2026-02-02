package main

import "base:runtime"
import "cli"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"
import "tui"

Command_Info :: struct {
	cmd:         string,
	exit_code:   int,
	duration:    time.Duration,
	executed_at: time.Time,
}

UI_Model :: struct {
	cmds:     []Command_Info,
	selected: int,
}

search_cmd :: proc(args: []string) -> ^cli.Error {
	defer free_all(context.temp_allocator)

	query := os.get_env("HISTR_QUERY")
	selected_cmd := get_selected_cmd(query)
	fmt.print(selected_cmd)
	return nil
}

get_selected_cmd :: proc(start_query: string) -> string {
	ui, terr := tui.new_tui({.FULLSCREEN})
	if terr != nil {
		return ""
	}
	defer tui.cleanup(ui)

	query: strings.Builder
	strings.write_string(&query, start_query)

	limit := 50
	ui_model := UI_Model{}
	query_stmt, err := db_prepare_list_stmt()
	if err != nil {
		log.errorf("Unable to prepare stmt for list cmd: %s", err)
		return ""
	}
	defer db_close_list_stmt(query_stmt)

	ui_model.cmds, err = db_list_cmd(query_stmt, strings.to_string(query), limit)
	if err != nil {
		log.errorf("Unable to list cmd: %s", err)
		return ""
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
				return ui_model.cmds[ui_model.selected].cmd
			case .Ctrl:
				if e.key.char == 'c' {
					return ""
				}
			case .Esc:
				return ""
			}
		}


		tui.write_string(ui, fmt.tprintf("> %s", strings.to_string(query)))
		for c, i in ui_model.cmds {
			if i == ui_model.selected {
				tui.write_string(ui, fmt.tprintf("%s", c.cmd), tui.Grey)
			} else {
				tui.write_string(ui, fmt.tprintf("%s", c.cmd))

			}
		}
		tui.render_frame(ui)
	}
}
