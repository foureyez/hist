package db

import "core:fmt"
import "core:os"
import "core:testing"


@(test)
test_generate_cmds :: proc(t: ^testing.T) {
	mkdir_err := os.mkdir_all("test_hist")
	assert(mkdir_err == nil, "Unable to create test db directory")

	dbh, err := open("test_hist")
	assert(err == nil, "Unable to open db")
	defer close(dbh)

	for i in 0 ..< 100 {
		add_cmd(dbh, fmt.tprintf("randomcommand%d", i))
	}
}

