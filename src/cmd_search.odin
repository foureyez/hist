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
	log.infof("Query filter: %s", query)

	cmd_infos, err := db_list_cmd(query)
	if err != nil {
		return cli.error("unable to list cmd history")
	}

	selected_cmd := get_selected_cmd(cmd_infos)
	fmt.print(selected_cmd)
	return nil
}

get_selected_cmd :: proc(cmd_infos: []Command_Info) -> string {
	ui, err := tui.new_tui({.FULLSCREEN})
	if err != nil {
		return ""
	}

	defer tui.cleanup(ui)
	query: strings.Builder
	ui_model := UI_Model {
		cmds = cmd_infos,
	}

	for {
		event := tui.poll_event(ui)

		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
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

		for c, i in ui_model.cmds {
			if i == ui_model.selected {
				tui.write_string(
					ui,
					fmt.tprintf("%s:%d:%s:%s", c.cmd, c.exit_code, c.executed_at, c.duration),
					tui.Grey,
				)
			} else {
				tui.write_string(
					ui,
					fmt.tprintf("%s:%d:%s:%s", c.cmd, c.exit_code, c.executed_at, c.duration),
				)

			}
		}
		tui.render_frame(ui)
	}
}
