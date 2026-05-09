#+build  darwin
package tui

import "core:log"
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
	posix_fd := posix.FD(os.fd(file))
	posix.tcgetattr(posix_fd, &orig_termios)

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
	posix.tcsetattr(posix_fd, .TCSAFLUSH, &raw)
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
	pfd := posix.pollfd{}
	pfd.fd = posix.FD(os.fd(file))
	pfd.events = {.IN}
	pfd.revents = {.IN}

	ret := posix.poll(&pfd, 1, i32(timeout_msec))
	return ret > 0
}

