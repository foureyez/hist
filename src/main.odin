package main

import "./cli"
import "core:log"
import "core:mem"
import os "core:os"
import "core:path/filepath"
import "db"

dbh: ^db.DB
APP_PATH :: ".config/hist"
LOG_FILE_PATH :: APP_PATH + "/hist.log"

main :: proc() {
	level: log.Level
	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		level = .Debug
	} else {
		level = .Info
	}

	home_dir_path, err := os.user_home_dir(context.temp_allocator)
	if err != nil {
		panic("Unable to get home dir")
	}

	app_path, path_err := filepath.join([]string{home_dir_path, APP_PATH}, context.temp_allocator)
	if path_err != nil {
		panic("Unable to build app path")
	}
	os.mkdir(app_path)

	log_path, log_path_err := filepath.join(
		[]string{home_dir_path, LOG_FILE_PATH},
		context.temp_allocator,
	)
	if log_path_err != nil {
		panic("Unable to build log path")
	}
	mode := os.O_WRONLY | os.O_CREATE | os.O_APPEND
	perm := os.perm(0o700)
	log_file, lerr := os.open(log_path, mode, perm)
	if lerr != nil {
		panic("Unable to open log file")
	}
	defer os.close(log_file)


	cl := log.create_file_logger(log_file, level)
	context.logger = cl
	when ODIN_DEBUG {
		defer reset_tracking_allocator()
	}
	defer log.destroy_file_logger(cl)


	derr: db.Error
	dbh, derr = db.open(app_path)
	if derr != nil {
		log.fatalf("Unable to open db: %s", derr)
	}
	defer db.close(dbh)

	app_cli := cli.create(context.allocator)
	defer cli.destroy(app_cli)

	cli.add_command(app_cli, "init", "prints the shell script to initialize cmdd", init_cmd)
	cli.add_command(app_cli, "add", "add a cli command to history", nil)
	cli.add_subcommand(
		app_cli,
		"add",
		"start",
		"start add a cli command to history",
		add_start_cmd,
	)

	cli.add_subcommand(app_cli, "add", "end", "end add a cli command to history", add_end_cmd)
	cli.add_command(app_cli, "search", "search the stored cli commands", search_cmd)
	cli.add_command(app_cli, "version", "prints the hist version", version_cmd)

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

