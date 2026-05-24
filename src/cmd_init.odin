package main

import "cli"
import "core:os"

zsh_init := #load("../shell/hist.zsh")

init_cmd :: proc(args: []string) -> ^cli.Error {
	if len(args) == 0 {
		return cli.error("'shell' required")
	}

	// enable_db_flags(dbh)
	// schema_err := ensure_schema(dbh)
	// if schema_err != nil {
	// log.fatalf("Failed to initialize database schema: %s", schema_err)
	// }

	shell := args[0]
	switch shell {
	case "zsh":
		os.write(os.stdout, zsh_init)
		os.write_string(os.stdout, "bindkey -M emacs '^r' hist-search")
	case:
		return cli.error("shell not supported")
	}
	return nil
}

