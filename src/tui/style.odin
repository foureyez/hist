package tui

Style :: struct {
	fg: Color,
	bg: Color,
}

Color :: struct {
	r, g, b: u8,
	none:    bool,
}

NoColor :: Color {
	none = true,
}

DefaultStyle :: Style {
	fg = White,
	bg = NoColor,
}

NoStyle :: Style {
	fg = NoColor,
	bg = NoColor,
}

fg_style :: proc(fg: Color) -> Style {
	return Style{fg = fg, bg = NoColor}
}

