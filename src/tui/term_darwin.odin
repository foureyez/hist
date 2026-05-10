#+build  darwin
package tui

import "core:c"
import "core:os"
import "core:sys/darwin"
import "core:sys/posix"

// Store the original settings to restore them when the app exits
@(private)
orig_termios: posix.termios

TermSize :: struct {
	rows: int,
	cols: int,
}

enable_raw_mode :: proc(file: ^os.File) {
	// Need to open /dev/tty explicitly since the cli can be invoked as a zsh plugin.
	// This guarantees you are configuring the actual physical terminal the user is typing into, regardless of how Zsh pipes the input/output.
	fd := posix.open("/dev/tty", {})
	posix.tcgetattr(fd, &orig_termios)

	raw := orig_termios

	// ICRNL: Fix CTRL+M handling
	// IXON: Disable CTRL+S/CTRL+Q flow control
	raw.c_iflag -= {.ICRNL, .IXON}

	// OPOST: Turn off output processing (newline translation)
	raw.c_oflag -= {.OPOST}

	// ECHO: Turn off echoing typed keys
	// ICANON: Turn off canonical mode (read byte-by-byte)
	// ISIG: Turn off CTRL+C/CTRL+Z signals (optional, be careful!)
	raw.c_lflag -= {.ECHO, .ICANON, .ISIG} // Remove ISIG if you want CTRL+C to kill app

	// 3. Apply new attributes
	posix.tcsetattr(fd, .TCSAFLUSH, &raw)
}

disable_raw_mode :: proc(file: ^os.File) {
	posix_fd := posix.FD(os.fd(file))
	posix.tcsetattr(posix_fd, .TCSAFLUSH, &orig_termios)
}


get_term_size :: proc(fd: i32) -> (TermSize, bool) {
	winsize :: struct {
		row, col, xpixel, ypixel: u16,
	}

	ws := winsize{}
	res := darwin.syscall_ioctl(fd, darwin.TIOCGWINSZ, &ws)
	if res != 0 {
		return TermSize{0, 0}, false
	}

	return TermSize{rows = int(ws.row), cols = int(ws.col)}, true
}

has_input :: proc(file: ^os.File, timeout_msec: int) -> bool {
	fd := posix.FD(os.fd(file))
	if fd < 0 {
		return false
	}

	readfds := posix.fd_set{}
	posix.FD_ZERO(&readfds)
	posix.FD_SET(fd, &readfds)

	timeout_ptr: ^posix.timeval
	if timeout_msec >= 0 {
		tv := posix.timeval {
			tv_sec  = cast(posix.time_t)(timeout_msec / 1000),
			tv_usec = cast(posix.suseconds_t)((timeout_msec % 1000) * 1000),
		}
		timeout_ptr = &tv
	} else {
		timeout_ptr = nil
	}

	// posix.poll() was returning NVAL for tty fd
	// got the suggestion to use select instead for darwin since poll
	// has issues with tty device.
	ret := posix.select(c.int(fd + 1), &readfds, nil, nil, timeout_ptr)
	if ret <= 0 {
		return false
	}

	return posix.FD_ISSET(fd, &readfds)
}

