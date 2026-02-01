# cmdh - Command History Manager

A terminal command history manager built with Odin that stores and retrieves command history with exit codes and execution timestamps.

## Features

- Store commands with their exit codes and execution timestamps
- List and search through command history with an interactive TUI
- Persistent storage using SQLite
- Fast and lightweight

## Building

### Prerequisites

- [Odin compiler](https://odin-lang.org/) (dev-2024-01 or later)
- SQLite3 dependencies (usually pre-installed on most systems)

### Build Commands

```bash
# Build debug version
make build

# Build optimized release version
make build-release

# Run with address sanitizer (for development)
make run
```

## Installation

```bash
# Build and install to /usr/local/bin
make install

# Install to custom location
PREFIX=/custom/path make install
```

## Usage

### Add a command to history

```bash
cmdh add "echo hello world" 0
```

The first argument is the command string, and the second is the exit code.

### List command history

```bash
cmdh list
```

This launches an interactive TUI where you can:
- Navigate with arrow keys (Up/Down)
- Press Enter to select a command
- Press Esc or Ctrl+C to exit

### Optional: Filter history

```bash
cmdh list "search term"
```

### Check version

```bash
cmdh version
```

## Configuration

cmdh stores its data in:
- **Database**: `~/.config/cmdh/sqlite.db`
- **Logs**: `~/.config/cmdh/cmdh.log`

The database is automatically initialized on first run.

## Development

### Running Tests

```bash
# Run smoke tests
make test
```

### Clean Build Artifacts

```bash
make clean
```

### Project Structure

```
.
├── src/
│   ├── main.odin           # Application entry point
│   ├── db.odin             # Database schema management
│   ├── cmd_add.odin        # Add command implementation
│   ├── cmd_list.odin       # List command with TUI
│   ├── cmd_version.odin    # Version command
│   ├── cli/                # CLI framework
│   └── tui/                # Terminal UI framework
├── tests/
│   └── smoke_test.sh       # Basic integration tests
└── Makefile
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.
