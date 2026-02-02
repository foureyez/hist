package main

import "cli"
import "core:fmt"
import "core:log"

zsh_init := #load("./shell/cmdd.zsh")

init_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) == 0 {
		return cli.error("'shell' required")
	}

	os.mkdir_all(app_path)

	// Ensure DB schema exists (creates cmd_history table if missing)
	schema_err := ensure_schema(dbh)
	if schema_err != nil {
		log.fatalf("Failed to initialize database schema: %s", schema_err)
	}

	shell := args[0]
	switch shell {
	case "zsh":
		fmt.println(string(zsh_init))
		fmt.println("bindkey -M emacs '^r' histr-search")
	case:
		return cli.error("shell not supported")
	}
	return nil
}
