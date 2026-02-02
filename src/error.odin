package main

Error :: union {
	DBError,
}

DBError :: enum {
	PrepareStmtFailed,
	ExecStmtFailed,
	UnableToAddCmd,
}
