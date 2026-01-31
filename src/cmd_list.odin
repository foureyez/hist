package main

import "base:runtime"
import "cli"
import "core:c"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import "core:thread"
import "core:time"
import "core:unicode/utf8"
import sql "deps:sqlite3"
import "tui"

Command_Info :: struct {
	cmd:         string,
	exit_code:   int,
	executed_at: time.Time,
}

UI_Model :: struct {
	cmds:     []Command_Info,
	selected: int,
}

alpha := []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"}
list_cmd :: proc(args: []string) -> ^cli.Error {
	filter := ""
	if len(args) > 0 {
		filter = args[0]
	}

	cmd_infos := fetch_cmd_info(filter)
	selected_cmd := get_selected_cmd(cmd_infos)
	fmt.println(selected_cmd)
	defer free_all(context.temp_allocator)
	return nil
}

get_selected_cmd :: proc(cmd_infos: []Command_Info) -> string {
	ui := tui.new()
	defer tui.cleanup(&ui)
	query: strings.Builder
	ui_model := UI_Model {
		cmds = cmd_infos,
	}

	printKey: rune
	for {
		event := tui.poll_event(&ui)

		#partial switch e in event {
		case tui.TypeEvent:
			#partial switch e.key.type {
			case .Char:
			case .Arrow_Up:
				ui_model.selected = (ui_model.selected + 1) % ui_model.selected
			case .Arrow_Down:
				ui_model.selected = min(ui_model.selected - 1, 0)
			case .Enter:
				return ui_model.cmds[ui_model.selected].cmd
			case .Ctrl:
				if e.key.char == 'c' {
					return ""
				}
			}
		}

		for c, i in ui_model.cmds {
			if i == ui_model.selected {
				tui.write_string(&ui, c.cmd, .Cyan)
			} else {
				tui.write_string(&ui, c.cmd)
			}
		}

		tui.render_frame(&ui)
		time.sleep(16 * time.Millisecond)
	}

}

fetch_cmd_info :: proc(search_filter: string) -> []Command_Info {
	search_term := "%"
	max_limit := 20
	if len(search_filter) > 0 {
		search_term = strings.join([]string{"%", search_filter, "%"}, "")
	}
	query := "select cmd, exit_code, executed_at from cmd_history where cmd like ? order by executed_at desc limit ?"
	stmt, err := sql.stmt_prepare(db, query, search_term, max_limit)
	if err != nil {
		return nil
	}
	defer sql.stmt_close(stmt)

	command_infos := make([dynamic]Command_Info, context.temp_allocator)

	for {
		if !sql.row_next(stmt) {
			break
		}
		cmd_info := Command_Info{}
		sql.row_scan(
			stmt,
			context.temp_allocator,
			&cmd_info.cmd,
			&cmd_info.exit_code,
			&cmd_info.executed_at,
		)
		append(&command_infos, cmd_info)
	}

	return command_infos[:]
}
