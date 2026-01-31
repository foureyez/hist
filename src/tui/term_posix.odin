#+build linux, darwin
package tui

import "core:os"
import "core:sys/darwin"
import "core:sys/linux"
import "core:sys/posix"
import "core:sys/unix"

// Store the original settings to restore them when the app exits
@(private)
orig_termios: posix.termios

TermSize :: struct {
	rows: int,
	cols: int,
}

enable_raw_mode :: proc() {
	posix.tcgetattr(posix.STDIN_FILENO, &orig_termios)

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
	posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw)
}

disable_raw_mode :: proc() {
	// Restore original settings
	posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &orig_termios)
}


get_term_size :: proc(fd: i32) -> (TermSize, bool) {
	winsize :: struct {
		row, col, xpixel, ypixel: u16,
	}

	ws := winsize{}

	when ODIN_OS == .Darwin {
		res := darwin.syscall_ioctl(fd, darwin.TIOCGWINSZ, &ws)
	} else {
		// TIOCGWINSZ is the magic number to request Window Size
		// 1 is usually stdout (or os.stdout.handle)
		res := linux.ioctl(fd, linux.TIOCGWINSZ, &ws)
	}


	if res != 0 {
		return TermSize{0, 0}, false
	}

	return TermSize{rows = int(ws.row), cols = int(ws.col)}, true
}

has_input :: proc(fd: os.Handle) -> bool {
	pfd: posix.pollfd
	pfd.fd = posix.FD(fd)
	pfd.events = {.IN}

	// Timeout 0 means return immediately (don't block)
	ret := posix.poll(&pfd, 1, 0)
	return ret > 0
}
