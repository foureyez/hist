package main

import "core:fmt"

VERSION :: "0.0.2"

version_cmd :: proc(args: []string) {
	fmt.printfln("Version: %s", VERSION)
}

