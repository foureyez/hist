package cli

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"

Flag_Type :: enum {
	Bool,
	String,
	Int,
}

Error :: struct {
	message: string,
}

Flag :: struct {
	name:        string,
	short_name:  string,
	description: string,
	type:        Flag_Type,
	value:       any,
}

Action_Err :: proc(args: []string) -> ^Error
Action_Void :: proc(args: []string)

Command_Proc :: union {
	Action_Err,
	Action_Void,
}

Command :: struct {
	name:        string,
	description: string,
	action:      Command_Proc,
	subcommands: map[string]Command,
	flags:       map[string]Flag,
}

Cli :: struct {
	app_name:  string,
	commands:  map[string]Command,
	allocator: runtime.Allocator,
}

create :: proc(allocator: runtime.Allocator) -> ^Cli {
	cli := new(Cli, allocator)
	cli.allocator = allocator
	cli.commands = make(map[string]Command, allocator)
	return cli
}

destroy :: proc(cli: ^Cli) {
	for _, cmd in cli.commands {
		delete(cmd.flags)
	}
	delete(cli.commands)
	free(cli, cli.allocator)
}


add_subcommand :: proc(cli: ^Cli, parent_name, name, description: string, action: Command_Proc) {
	cmd := Command {
		name        = name,
		description = description,
		action      = action,
		flags       = make(map[string]Flag, cli.allocator),
	}
	parent, ok := &cli.commands[parent_name]
	if !ok {
		log.fatalf("Unknown parent command '%s' for subcommand '%s'", parent_name, name)
	}
	parent.subcommands[name] = cmd
}

add_command :: proc(cli: ^Cli, name, description: string, action: Command_Proc) {
	cmd := Command {
		name        = name,
		description = description,
		action      = action,
		subcommands = make(map[string]Command, cli.allocator),
		flags       = make(map[string]Flag, cli.allocator),
	}
	cli.commands[name] = cmd
}

cli_add_flag :: proc(
	cmd: ^Command,
	name: string,
	short_name: string,
	description: string,
	value: any,
) {
	flag: Flag
	flag.name = name
	flag.short_name = short_name
	flag.description = description
	flag.value = value

	switch v in value {
	case bool:
		flag.type = .Bool
	case string:
		flag.type = .String
	case int:
		flag.type = .Int
	case:
		panic("invalid flag type")
	}
	cmd.flags[name] = flag
}


cli_print_help :: proc(cli: ^Cli) {
	fmt.printf("Usage: %s <command> [flags]\n\n", cli.app_name)
	fmt.println("Available commands:")
	for name, cmd in cli.commands {
		fmt.printf("  %-15s %s\n", name, cmd.description)
	}
	fmt.println("\nRun '<command> --help' for more information on a specific command.")
}

cli_print_command_help :: proc(cli: ^Cli, cmd: Command) {
	fmt.printf("Usage: %s %s [flags]\n\n", cli.app_name, cmd.name)
	fmt.printf("%s\n\n", cmd.description)
	if len(cmd.flags) > 0 {
		fmt.println("Flags:")
		for _, flag in cmd.flags {
			short_str := ""
			if flag.short_name != "" {
				short_str = fmt.tprintf("-%c, ", flag.short_name)
			}
			fmt.printf("  %s--%-15s %s\n", short_str, flag.name, flag.description)
		}
	}
}

cli_run :: proc(cli: ^Cli) -> (err: os.Error) {
	args := os.args

	if len(args) < 2 {
		cli_print_help(cli)
		return nil
	}

	cli.app_name = args[0]
	command_name := args[1]

	if command_name == "help" {
		cli_print_help(cli)
		return .Permission_Denied
	}

	command, ok := &cli.commands[command_name]
	if !ok {
		fmt.eprintf("Error: Unknown command '%s'\n\n", command_name)
		cli_print_help(cli)
		return .Permission_Denied
	}

	final_command := command^
	arg_index := 2
	for arg_index < len(args) {
		curr_arg := args[arg_index]
		subcommand, ok := &final_command.subcommands[curr_arg]
		if !ok {
			break
		}
		final_command = subcommand^
		arg_index += 1
	}

	if final_command.action != nil {
		switch execute in final_command.action {
		case Action_Void:
			execute(args[arg_index:])
		case Action_Err:
			if err := execute(args[arg_index:]); err != nil {
				fmt.printfln("Error: %s", err.message)
				cli_print_help(cli)
				free(err)
				return .Permission_Denied
			}
		}
	}
	return nil
}

error :: proc(msg: string) -> ^Error {
	err := new(Error)
	err.message = msg
	return err
}

