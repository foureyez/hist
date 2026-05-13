package main

import "tui"

Error :: union {
	DBError,
	tui.Error,
}

DBError :: enum {
	PrepareStmtFailed,
	ExecStmtFailed,
	UnableToAddCmd,
}

