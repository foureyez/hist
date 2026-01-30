package main

import "base:runtime"
import "cli"
import "core:c"
import "core:fmt"
import "core:math/rand"
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

alpha := []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"}
list_cmd :: proc(args: []string) -> ^cli.Error {
	filter := ""
	if len(args) > 0 {
		filter = args[0]
	}

	cmd_infos := fetch_cmd_info(filter)
	defer delete(cmd_infos)

	ui := tui.new({.FULLSCREEN})
	defer tui.cleanup(&ui)
	query: strings.Builder

	printKey: rune
	for {
		event := tui.poll_event(&ui)

		#partial switch e in event {
		case tui.TypeEvent:
			if e.key == 'q' {
				return nil
			}
		}


		for x in 0 ..< ui.buffer.width {
			for y in 0 ..< ui.buffer.height {
				tui.raw_draw(&ui, x, y, alpha[rand.int_max(12)], .White)
			}
		}

		tui.render_frame(&ui)
		// time.sleep(16 * time.Millisecond)
	}
	return nil
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

	command_infos := make([dynamic]Command_Info)

	for {
		if !sql.row_next(stmt) {
			break
		}
		cmd_info := Command_Info{}
		sql.row_scan(stmt, &cmd_info.cmd, &cmd_info.exit_code, &cmd_info.executed_at)
		append_elems(&command_infos, cmd_info)
	}

	return command_infos[:]
}
