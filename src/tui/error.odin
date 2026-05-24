package tui

Error :: union {
	TTYError,
}

TTYError :: enum {
	TermSizeFailed,
	InvalidInput,
}

