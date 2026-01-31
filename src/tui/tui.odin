package tui

import "core:os"
import "core:unicode/utf8"

Context :: struct {
	config_flags: Config_Flags,
	buffer:       Buffer,
	curr_line:    int,
	output:       os.Handle,
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
}

new :: proc(config_flags: Config_Flags = nil, output: os.Handle = os.stderr) -> Context {
	if .FULLSCREEN in config_flags {
		enable_alt_buffer(output)
	}

	enable_raw_mode()
	hide_cursor(output)

	term_size, ok := get_term_size(i32(output))
	if !ok {
		panic("unable to get termsize")
	}

	buf := init_buffer(term_size.cols, term_size.rows)
	ctx := Context {
		buffer       = buf,
		config_flags = config_flags,
		output       = output,
	}
	return ctx
}

cleanup :: proc(ctx: ^Context) {
	destroy_buffer(&ctx.buffer)
	disable_raw_mode()
	show_cursor(ctx.output)
	reset_cursor(ctx.output)
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

raw_draw :: proc(ctx: ^Context, x, y: int, text: string, color: Color) {
	draw_text(&ctx.buffer, x, y, text, color)
}

write_string :: proc(ctx: ^Context, text: string, color: Color = .White) {
	draw_text(&ctx.buffer, 0, ctx.curr_line, text, color)
	ctx.curr_line += 1
}

render_frame :: proc(ctx: ^Context) {
	render_buffer(ctx)
	ctx.curr_line = 0
}
