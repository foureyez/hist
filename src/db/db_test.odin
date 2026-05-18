package db

import "core:fmt"
import "core:testing"


@(test)
test_generate_cmds :: proc(t: ^testing.T) {
	dbh, err := open("/Users/arawat/.config/hist")
	assert(err == nil, "Unable to open db")

	for i in 0 ..< 10000000 {
		add_cmd(dbh, fmt.tprintf("randomcommand%d", i))
	}
}

