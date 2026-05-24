package tui

import "base:runtime"
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

Program :: struct {
	init:   Init_Proc,
	update: Update_Proc,
	view:   View_Proc,
	model:  rawptr,
}

Run_Opts :: struct {
	flags:  Config_Flags,
	input:  ^os.File,
	output: ^os.File,
	fps:    int,
}

default_run_opts :: proc() -> Run_Opts {
	return Run_Opts{flags = nil, input = os.stdin, output = os.stderr, padding = {}, fps = 60}
}

run :: proc(p: Program, flags: Config_Flags = {}) -> Error {
	o := opts
	if o.input == nil {o.input = os.stdin}
	if o.output == nil {o.output = os.stderr}
	if o.fps <= 0 {o.fps = 60}

	ctx, err := new_tui(o.flags, o.input, o.output, o.padding)
	if err != nil {
		return err
	}
	defer cleanup(ctx)

	refresh_rate := 1000 / o.fps

	// Init phase
	if p.init != nil {
		cmd := p.init(ctx, model)
		if cmd == .Quit {
			return nil
		}
	}

	// Main loop: poll → update → view → render
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

		if p.update != nil {
			cmd := p.update(ctx, model, msg)
			if cmd == .Quit {
				return nil
			}
		}

		if p.view != nil {
			p.view(ctx, model)
		}

		render_frame(ctx)
	}
}

