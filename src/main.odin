package main

import "./cli"
import "core:fmt"
import "core:log"
import "core:mem"
import oso "core:os"
import os "core:os/os2"
import "core:path/filepath"
import sql "deps:sqlite3"

db: ^sql.DB
APP_PATH :: ".config/cmdh"
LOG_FILE_PATH :: APP_PATH + "/cmdh.log"
DB_FILE_PATH :: APP_PATH + "/sqlite.db"

main :: proc() {

	level: log.Level
	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer reset_tracking_allocator()
		level = .Debug
	} else {
		level = .Error
	}


	home_dir_path, err := os.user_home_dir(context.temp_allocator)
	if err != nil {
		panic("Unable to get home dir")
	}

	app_path := filepath.join([]string{home_dir_path, APP_PATH}, context.temp_allocator)
	os.mkdir_all(app_path)

	log_path := filepath.join([]string{home_dir_path, LOG_FILE_PATH}, context.temp_allocator)
	mode := oso.O_WRONLY | oso.O_CREATE | oso.O_APPEND
	log_file, lerr := oso.open(log_path, mode)
	if lerr != nil {
		panic("Unable to open log file")
	}


	cl := log.create_file_logger(log_file, level)
	context.logger = cl

	db_path := filepath.join([]string{home_dir_path, DB_FILE_PATH}, context.temp_allocator)


	derr: sql.Error
	db, derr = sql.db_open(db_path)
	if derr != nil {
		log.fatalf("Unable to open db: %s", derr)
	}
	defer sql.db_close(db)

	// Initialize database schema
	if schema_err := ensure_schema(db); schema_err != nil {
		log.fatalf("Unable to initialize database schema: %s", schema_err)
	}

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
