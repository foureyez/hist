package tui

import "base:runtime"
import "core:os"
import "core:strings"

Context :: struct {
	config_flags:  Config_Flags,
	buffer:        Buffer,
	back_buffer:   Buffer,
	curr_line:     int,
	cursor_pos:    [2]int,
	output:        os.Handle,
	clear_init:    bool,
	buffer_string: strings.Builder,
	is_dirty:      bool,
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

Error :: union {
	TTYError,
}

TTYError :: enum {
	TermSizeFailed,
}

new_tui :: proc(
	config_flags: Config_Flags = nil,
	output: os.Handle = os.stderr,
	allocator: runtime.Allocator = context.allocator,
) -> (
	^Context,
	Error,
) {
	enable_raw_mode()
	curx, cury := get_cursor_pos(output)
	hide_cursor(output)

	term_size, ok := get_term_size(i32(output))
	if !ok {
		return nil, .TermSizeFailed
	}


	buf: Buffer
	back_buf: Buffer
	if .FULLSCREEN in config_flags {
		enable_alt_buffer(output)
		buf = init_buffer(term_size.cols, term_size.rows)
		back_buf = init_buffer(term_size.cols, term_size.rows)
	} else {
		buf = init_buffer(term_size.cols, term_size.rows - cury)
		back_buf = init_buffer(term_size.cols, term_size.rows - cury)

		// This is for starting drawing from the cursor position
		// Start from top and put empty lines until the cursor y pos
		move_cursor(output, 0, 0)
		for i in 1 ..< cury {
			os.write_rune(output, '\n')
		}
		// Move the cursor back to the cursor pos
		move_cursor(output, 0, cury)
	}

	buffer_string: strings.Builder
	strings.builder_init(&buffer_string)

	ctx := new(Context, allocator)
	ctx.buffer = buf
	ctx.back_buffer = back_buf
	ctx.config_flags = config_flags
	ctx.output = output
	ctx.cursor_pos = {curx, cury}
	ctx.buffer_string = buffer_string
	ctx.is_dirty = true

	return ctx, nil
}

cleanup :: proc(ctx: ^Context) {
	// reset_cursor(ctx.output, ctx.buffer.height)
	move_cursor(ctx.output, ctx.cursor_pos.x, ctx.cursor_pos.y - 1)
	show_cursor(ctx.output)
	destroy_buffer(&ctx.buffer)
	disable_raw_mode()

	strings.builder_destroy(&ctx.buffer_string)

	if .FULLSCREEN in ctx.config_flags {
		disable_alt_buffer(ctx.output)
	}
	free(ctx)
}

poll_event :: proc(ctx: ^Context) -> Event {
	clear_buffer(&ctx.buffer)
	timeout := -1
	if ctx.is_dirty == true {
		timeout = 16
	}

	key := read_key(ctx.output, timeout)
	if key.type != .None {
		ctx.is_dirty = true
		return TypeEvent{key = key}
	}

	return NoneEvent{}
}

raw_draw :: proc(ctx: ^Context, x, y: int, text: string, fg: Color, bg: Color) {
	draw_text(&ctx.buffer, x, y, text, fg, bg)
}

write_string :: proc(ctx: ^Context, text: string, fg: Color = White, bg: Color = NoColor) {
	draw_text(&ctx.buffer, 0, ctx.curr_line, text, fg, bg)
	ctx.curr_line += 1
}

render_frame :: proc(ctx: ^Context) {
	if ctx.is_dirty {
		render_buffer(ctx)
		ctx.is_dirty = false
	}
	ctx.curr_line = 0
}

request_refresh :: proc(ctx: ^Context) {
	ctx.is_dirty = true
}
