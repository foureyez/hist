# hist

Command history tool written in Odin.

Overview
- Simple TUI to list command history.

Installation
- Build from source: 
```
  make release-all
```
- Copy the binary (hist) to /usr/bin/ or just add the binary to PATH
- Add this line to .zshrc 
```
  eval "$(hist init zsh)"
```

Notes
- Supports only Linux and Mac
