package main

import "core:fmt"
import "core:log"
import "core:mem"
import sql "deps:sqlite3"

db: ^sql.DB
DB_PATH :: "./test.db"

main :: proc() {

	when ODIN_DEBUG {
		cl := log.create_console_logger(.Debug)
		context.logger = cl

		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer reset_tracking_allocator()

	} else {
		cl := log.create_console_logger(.Error)
		context.logger = cl
	}


	err: sql.Error
	db, err = sql.db_open(DB_PATH)
	if err != nil {
		log.fatalf("Unable to open db: %s", err)
	}
	defer sql.db_close(db)

	cli := cli_create(context.allocator)
	defer cli_destroy(cli)

	cli_add_command(cli, "add", "stores the cli command", add_cmd)
	cli_add_command(cli, "list", "lists the stored cli commands", list_cmd)
	cli_add_command(cli, "version", "prints the cmdh version", version_cmd)

	cli_run(cli)
}


reset_tracking_allocator :: proc() -> bool {
	a := cast(^mem.Tracking_Allocator)context.allocator.data
	err := false
	if len(a.allocation_map) > 0 {
		log.warnf("Leaked allocation count: %v", len(a.allocation_map))
	}
	for _, v in a.allocation_map {
		log.warnf("%v: Leaked %v bytes", v.location, v.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}
