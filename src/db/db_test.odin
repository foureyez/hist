package db

import "core:fmt"
import "core:testing"


@(test)
test_generate_cmds :: proc(t: ^testing.T) {
	dbh, err := open("test_hist")
	assert(err == nil, "Unable to open db")

	for i in 0 ..< 100 {
		add_cmd(dbh, fmt.tprintf("randomcommand%d", i))
	}
}

