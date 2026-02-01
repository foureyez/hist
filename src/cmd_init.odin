package main

import "cli"
import "core:fmt"

zsh_init := #load("./shell/cmdd.zsh")

init_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) == 0 {
		return cli.error("'shell' required")
	}

	shell := args[0]
	switch shell {
	case "zsh":
		fmt.println(string(zsh_init))
	case:
		return cli.error("shell not supported")
	}
	return nil
}
