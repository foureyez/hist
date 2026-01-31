package main

import "./cli"
import "core:fmt"
import "core:log"
import "core:mem"
import os "core:os/os2"
import "core:path/filepath"
import sql "deps:sqlite3"

db: ^sql.DB
APP_HOME :: ".config/cmdh"
DB_NAME :: "sqlite.db"

main :: proc() {

	when ODIN_DEBUG {
		cl := log.create_console_logger(.Debug)
		context.logger = cl

		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer reset_tracking_allocator()

	} else {
		//TODO: Create file logger instead
		cl := log.create_console_logger(.Error)
		context.logger = cl
	}

	home_dir_path, err := os.user_home_dir(context.temp_allocator)
	if err != nil {
		log.fatalf("Unable to get home dir: %s", err)
	}

	app_path := filepath.join([]string{home_dir_path, APP_HOME}, context.temp_allocator)
	os.mkdir_all(app_path)
	db_path := filepath.join([]string{app_path, DB_NAME}, context.temp_allocator)


	derr: sql.Error
	db, derr = sql.db_open(db_path)
	if err != nil {
		log.fatalf("Unable to open db: %s", err)
	}
	defer sql.db_close(db)

	app_cli := cli.create(context.allocator)
	defer cli.destroy(app_cli)

	cli.add_command(app_cli, "add", "stores the cli command", add_cmd)
	cli.add_command(app_cli, "list", "lists the stored cli commands", list_cmd)
	cli.add_command(app_cli, "version", "prints the cmdh version", version_cmd)

	free_all(context.temp_allocator)
	cli.cli_run(app_cli)
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
