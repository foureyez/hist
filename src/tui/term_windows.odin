#+build windows
package otui

import "core:os"
import "core:sys/windows"

enable_raw_mode :: proc() {
	panic("not implemented")
}

disable_raw_mode :: proc() {
	panic("not implemented")
}

get_term_size :: proc() -> (TermSize, bool) {
	handle := windows.GetStdHandle(windows.STD_OUTPUT_HANDLE)
	if handle == windows.INVALID_HANDLE_VALUE {
		return TermSize{0, 0}, false
	}

	csbi: windows.CONSOLE_SCREEN_BUFFER_INFO
	success := windows.GetConsoleScreenBufferInfo(handle, &csbi)

	if !bool(success) {
		return TermSize{0, 0}, false
	}

	// Windows coordinates are inclusive (Right - Left + 1)
	cols := int(csbi.srWindow.Right - csbi.srWindow.Left + 1)
	rows := int(csbi.srWindow.Bottom - csbi.srWindow.Top + 1)

	return TermSize{rows, cols}, true
}

has_input :: proc() -> bool {
	handle := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
	count: windows.DWORD

	// Check how many events are pending
	if !windows.GetNumberOfConsoleInputEvents(handle, &count) {
		return false
	}
	return count > 0
}
