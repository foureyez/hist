# hist

`hist` is a fast shell history manager written in [Odin](https://odin-lang.org/).

It captures shell commands with metadata (exit code, duration, timestamp), stores them in a compact local file-based database, and provides an interactive TUI to fuzzy-search through your history.

## Features

- **Interactive TUI search** — fuzzy matching, table display with columns for command, timestamp, and duration
- **Configurable table widget** — customizable borders (`DEFAULT_BORDERS`, `ROUNDED_BORDERS`, `ASCII_BORDERS`), optional headers, scrollable rows, flexible/fixed column widths
- **Zsh integration** — `preexec`/`precmd` hooks + `Ctrl+R` ZLE widget
- **Paginated history loading** — navigate large histories with `Ctrl+R` (next page) / `Ctrl+G` (previous page)
- **Fuzzy search** — type to filter; results update instantly
- **Local persistence** — data stored under `~/.config/hist`

## Requirements

- [Odin](https://odin-lang.org/) toolchain
- `make`

## Build

```bash
make build
```

Targets:

- `make build` — debug build (`./hist`)
- `make debug` — alias for debug build
- `make release` — optimized release binary
- `make release-all` — build dependencies (SQLite) + release binary
- `make build-deps` — download and compile SQLite dependency
- `make test` — run tests
- `make run` — run with address sanitizer

## Installation

Place the built `hist` binary somewhere in your `PATH`:

```bash
cp ./hist /usr/local/bin/hist
```

## Shell Integration (Zsh)

Add to your `~/.zshrc`:

```bash
eval "$(hist init zsh)"
```

This sets up:

- **`preexec`** hook — captures command text and start time
- **`precmd`** hook — records exit code and duration
- **`hist-search`** ZLE widget bound to `Ctrl+R`

Then reload:

```bash
source ~/.zshrc
```

## CLI Commands

```hist init zsh```

Prints the Zsh shell integration script.

```hist add start <cmd>```

Creates a history record and prints a record ID.

```hist add end <id> <exit_code> <duration_ms>```

Completes an existing history record with exit code and duration.

```hist search```

Launches the interactive TUI search.

| Key | Action |
|---|---|
| Type | Filter commands (fuzzy match) |
| `Up` / `Down` | Navigate results |
| `Enter` | Select and print command |
| `Esc` / `Ctrl+C` | Exit |
| `Ctrl+R` | Load next page of history |
| `Ctrl+G` | Load previous page of history |

```hist version```

Prints the application version (currently `0.0.2`).

## Data & Logs

Stored under `~/.config/hist/`:

- `histdb.log` — append-only command log
- `histdb.idx` — binary index for fast lookups
- `hist.log` — application log

