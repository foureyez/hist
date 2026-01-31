package tui

import "core:log"
import "core:os"
import "core:unicode/utf8"

Context :: struct {
	config_flags: Config_Flags,
	buffer:       Buffer,
	curr_line:    int,
	cursor_pos:   [2]int,
	output:       os.Handle,
	clear_init:   bool,
}

Event :: union {
	TypeEvent,
	NoneEvent,
}

TypeEvent :: struct {
	key: Key,
}

NoneEvent :: struct {
}

Config_Flags :: bit_set[Config_Flag]
Config_Flag :: enum {
	FULLSCREEN,
	CLEAR_ON_EXIT,
}

new :: proc(config_flags: Config_Flags = nil, output: os.Handle = os.stderr) -> Context {
	enable_raw_mode()
	curx, cury := get_cursor_pos(output)
	log.info(curx, cury)


	hide_cursor(output)

	term_size, ok := get_term_size(i32(output))
	if !ok {
		panic("unable to get termsize")
	}


	buf: Buffer
	if .FULLSCREEN in config_flags {
		enable_alt_buffer(output)
		buf = init_buffer(term_size.cols, term_size.rows)
	} else {
		// This is for starting drawing from the cursor position 
		buf = init_buffer(term_size.cols, term_size.rows - cury)
		// Start from top and put empty lines until the cursor y pos
		move_cursor(output, 0, 0)
		for i in 1 ..< cury {
			os.write_rune(output, '\n')
		}
		// Move the cursor back to the cursor pos
		move_cursor(output, 0, cury)
	}

	ctx := Context {
		buffer       = buf,
		config_flags = config_flags,
		output       = output,
		cursor_pos   = {curx, cury},
	}

	return ctx
}

cleanup :: proc(ctx: ^Context) {
	// reset_cursor(ctx.output, ctx.buffer.height)
	move_cursor(ctx.output, ctx.cursor_pos.x, ctx.cursor_pos.y - 1)
	log.info("moved to: %v", ctx.cursor_pos)
	show_cursor(ctx.output)
	destroy_buffer(&ctx.buffer)
	disable_raw_mode()

	if .FULLSCREEN in ctx.config_flags {
		disable_alt_buffer(ctx.output)
	}
}

poll_event :: proc(ctx: ^Context) -> Event {
	clear_buffer(&ctx.buffer)
	key := read_key(ctx.output)

	if key.type != .None {
		return TypeEvent{key = key}
	}

	return NoneEvent{}
}

raw_draw :: proc(ctx: ^Context, x, y: int, text: string, fg: Color, bg: Color) {
	draw_text(&ctx.buffer, x, y, text, fg, bg)
}

write_string :: proc(ctx: ^Context, text: string, fg: Color = White, bg: Color = Black) {
	draw_text(&ctx.buffer, 0, ctx.curr_line, text, fg, bg)
	ctx.curr_line += 1
}

render_frame :: proc(ctx: ^Context) {
	render_buffer(ctx)
	ctx.curr_line = 0
}
