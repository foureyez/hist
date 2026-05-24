package tui

import "core:os"

// Messages — events delivered to the update procedure
Msg :: union {
	Key_Msg,
	Window_Size_Msg,
	Tick_Msg,
}

Key_Msg :: struct {
	key: Key,
}

Window_Size_Msg :: struct {
	width, height: int,
}

Tick_Msg :: struct {}

// Commands — returned from update to signal the runtime
Cmd :: enum {
	None,
	Quit,
}

Init_Proc :: #type proc(ctx: ^Context, model: rawptr) -> Cmd
Update_Proc :: #type proc(ctx: ^Context, model: rawptr, msg: Msg) -> Cmd
View_Proc :: #type proc(ctx: ^Context, model: rawptr)

App :: struct {
	init:   Init_Proc,
	update: Update_Proc,
	view:   View_Proc,
	model:  rawptr,
}

Opts :: struct {
	flags:  Config_Flags,
	input:  ^os.File,
	output: ^os.File,
	fps:    int,
}

default_run_opts :: proc() -> Opts {
	return Opts{flags = nil, input = os.stdin, output = os.stderr, fps = 60}
}

run :: proc(p: App, opts: Opts = {}) -> Error {
	o := opts
	if o.input == nil {o.input = os.stdin}
	if o.output == nil {o.output = os.stderr}
	if o.fps <= 0 {o.fps = 60}

	if p.init == nil || p.update == nil || p.view == nil {
		return .InvalidInput
	}

	ctx, err := new_tui(o.flags, o.input, o.output)
	if err != nil {
		return err
	}
	defer cleanup(ctx)
	refresh_rate := 1000 / o.fps

	cmd := p.init(ctx, p.model)
	if cmd == .Quit {
		return nil
	}

	for {
		event := poll_event(ctx, refresh_rate)

		msg: Msg
		#partial switch e in event {
		case TypeEvent:
			msg = Key_Msg {
				key = e.key,
			}
		case NoneEvent:
			msg = Tick_Msg{}
		}

		cmd := p.update(ctx, p.model, msg)
		if cmd == .Quit {
			return nil
		}

		p.view(ctx, p.model)
		render_frame(ctx)
	}
}

