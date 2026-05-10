# hist

`hist` is a command history tool written in Odin.

It tracks executed shell commands, stores them in a local SQLite-backed database, and provides an interactive terminal UI to search commands quickly.

## Features

- Interactive search UI (`hist search`)
- Zsh integration with a `Ctrl+R` widget
- Local persistence under your home directory (`~/.config/hist`)
- Works on macOS and Linux

## Requirements

- [Odin](https://odin-lang.org/) toolchain
- `make`

## Build

Build with the project Makefile (recommended):

```bash
make build
```

Useful targets:

- `make build` - debug-style build (`./hist`)
- `make debug` - alias around debug build flow
- `make release` - optimized release binary
- `make release-all` - build dependencies + release binary
- `make run` - run directly with sanitizer flags

## Installation

After building, place `hist` somewhere in your `PATH`, for example:

```bash
cp ./hist /usr/local/bin/hist
```

Or add the repository path to `PATH`.

## Shell Integration (Zsh)

Initialize Zsh integration in your `~/.zshrc`:

```bash
eval "$(hist init zsh)"
```

This wires:

- `preexec` hook to capture command start
- `precmd` hook to capture exit code + duration
- `hist-search` ZLE widget
- key binding for `Ctrl+R` in emacs keymap

Reload shell config:

```bash
source ~/.zshrc
```

## CLI Commands

### `hist init zsh`

Prints shell initialization script for Zsh integration.

### `hist add start <cmd>`

Creates a history record and prints a record ID.

### `hist add end <id> <exit_code> <duration_ns>`

Completes an existing history record.

### `hist search`

Launches the interactive TUI search.

- Type to filter commands
- `Up` / `Down` to navigate
- `Enter` to select and print the command
- `Esc` / `Ctrl+C` to exit

### `hist version`

Prints the application version.

## Data & Logs

`hist` stores files under:

- `~/.config/hist/hist.db` - command history database
- `~/.config/hist/hist.log` - log output

