package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:sys/darwin"
import "core:sys/posix"

@(private)
orig_termios: posix.termios

main :: proc() {
	file, err := os.open("/dev/tty", {.Read, .Write})
	if err != nil {
		fmt.println("Unable to open tty:", err)
		return
	}
	defer os.close(file)

	fd := posix.FD(os.fd(file))

	enable_raw_mode(fd)
	defer disable_raw_mode(fd)


	readfds := posix.fd_set{}
	posix.FD_ZERO(&readfds)
	posix.FD_SET(fd, &readfds)

	fmt.println("waiting")
	ret := posix.select(c.int(fd + 1), &readfds, nil, nil, nil)
	if ret <= 0 {
		fmt.printfln("Erro Ret: %s, errno: %s", ret, posix.errno())
		return
	}

	fmt.println(readfds)
}


enable_raw_mode :: proc(fd: posix.FD) {
	posix.tcgetattr(fd, &orig_termios)
	raw := orig_termios
	raw.c_iflag -= {.ICRNL, .IXON}
	raw.c_oflag -= {.OPOST}
	raw.c_lflag -= {.ECHO, .ICANON}
	posix.tcsetattr(fd, .TCSAFLUSH, &raw)
}

disable_raw_mode :: proc(fd: posix.FD) {
	posix.tcsetattr(fd, .TCSAFLUSH, &orig_termios)
}

