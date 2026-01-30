package tui

import "core:unicode/utf8"

Context :: struct {
	config_flags: Config_Flags,
	buffer:       Buffer,
	curr_line:    int,
}

Event :: union {
	TypeEvent,
	NoneEvent,
}

TypeEvent :: struct {
	key: rune,
}

NoneEvent :: struct {
}

Config_Flags :: bit_set[Config_Flag]
Config_Flag :: enum {
	FULLSCREEN,
}

new :: proc(config_flags: Config_Flags) -> Context {
	if .FULLSCREEN in config_flags {
		enable_alt_buffer()
	}

	enable_raw_mode()
	hide_cursor()

	term_size, ok := get_term_size()
	if !ok {
		panic("unable to get termsize")
	}

	buf := init_buffer(term_size.cols, term_size.rows)
	ctx := Context {
		buffer       = buf,
		config_flags = config_flags,
	}
	return ctx
}

cleanup :: proc(ctx: ^Context) {
	destroy_buffer(&ctx.buffer)
	disable_raw_mode()
	show_cursor()
	reset_cursor()
	if .FULLSCREEN in ctx.config_flags {
		disable_alt_buffer()
	}
}

poll_event :: proc(ctx: ^Context) -> Event {
	clear_buffer(&ctx.buffer)
	key := read_key()

	if utf8.valid_rune(key) {
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
	render_buffer(&ctx.buffer)
	ctx.curr_line = 0
}
