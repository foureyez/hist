package tui

import "core:unicode/utf8"

Context :: struct {
	buffer: Buffer,
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

new :: proc() -> Context {
	enable_raw_mode()
	hide_cursor()

	term_size, ok := get_term_size()
	if !ok {
		panic("unable to get termsize")
	}

	buf := init_buffer(term_size.cols, term_size.rows)
	ctx := Context {
		buffer = buf,
	}
	return ctx
}

cleanup :: proc(ctx: ^Context) {
	destroy_buffer(&ctx.buffer)
	disable_raw_mode()
	show_cursor()
}

poll_event :: proc(ctx: ^Context) -> Event {
	clear_buffer(&ctx.buffer)
	key := read_key()

	if utf8.valid_rune(key) {
		return TypeEvent{key = key}
	}

	return NoneEvent{}
}

draw :: proc(ctx: ^Context, x, y: int, text: string, color: Color) {
	draw_text(&ctx.buffer, x, y, text, color)
}

render_frame :: proc(ctx: ^Context) {
	render_buffer(&ctx.buffer)
}
