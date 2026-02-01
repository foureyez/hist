# cmdh - Command History Manager

A command-line tool for storing and managing your command history with exit codes, built with Odin.

## Features

- **Store commands**: Save commands with their exit codes and execution timestamps
- **List and search**: Interactive TUI for browsing command history
- **SQLite backend**: Persistent storage using SQLite database
- **Cross-platform**: Supports Linux and macOS

## Building

### Prerequisites

- [Odin compiler](https://odin-lang.org/) (dev-2024-08 or later)
- SQLite3 development libraries

### Build Commands

```bash
# Build debug version
make build

# Build optimized release version
make build-release

# Clean build artifacts
make clean
```

## Installation

```bash
# Build and install to /usr/local/bin
make install
```

## Usage

### Add a command to history

```bash
cmdh add "echo hello world" 0
```

The first argument is the command string, and the second is the exit code (integer).

### List command history

```bash
cmdh list
```

Launches an interactive TUI where you can:
- Use arrow keys (↑/↓) to navigate
- Press Enter to select a command
- Press Esc or Ctrl+C to exit

### Search command history

```bash
cmdh list "search term"
```

Filters the command history to show only commands matching the search term.

### Check version

```bash
cmdh version
```

## Database Location

Command history is stored in:
- Linux/macOS: `~/.config/cmdh/sqlite.db`

Logs are written to:
- Linux/macOS: `~/.config/cmdh/cmdh.log`

## Development

### Running Tests

```bash
# Run smoke tests
make test
```

The smoke test script validates:
- Database initialization
- Command insertion
- Exit code validation
- Basic CLI functionality

### Code Formatting

```bash
# Format code (requires odinfmt)
make fmt
```

### Project Structure

```
cmdh/
├── src/
│   ├── main.odin          # Main entry point
│   ├── db.odin            # Database schema initialization
│   ├── cmd_add.odin       # Add command implementation
│   ├── cmd_list.odin      # List command implementation
│   ├── cmd_version.odin   # Version command
│   ├── cli/               # CLI framework
│   └── tui/               # Terminal UI components
├── deps/
│   └── sqlite3/           # SQLite bindings
├── tests/
│   └── smoke_test.sh      # Integration test script
└── Makefile
```

## Platform Support

- ✅ Linux (Ubuntu, Debian, Arch, etc.)
- ✅ macOS
- ⚠️  Windows (not yet tested)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

foureyez
