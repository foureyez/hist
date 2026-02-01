# cmdh - Command History Manager

A lightweight command-line tool for storing and managing your shell command history with exit codes. Built with [Odin](https://odin-lang.org/).

## Features

- **Store Commands**: Save commands with their exit codes and execution timestamps
- **Interactive List**: Browse your command history with an interactive TUI
- **SQLite Storage**: Reliable local storage using SQLite
- **Cross-platform**: Works on Linux and macOS

## Installation

### Prerequisites

- [Odin compiler](https://odin-lang.org/docs/install/) (dev-2024-12 or later)
- SQLite3 (usually pre-installed on most systems)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/foureyez/cmdh.git
cd cmdh

# Build the project
make build

# Or build an optimized release version
make build-release

# Install to /usr/local/bin (optional)
sudo make install
```

## Usage

### Add a Command

Store a command with its exit code:

```bash
cmdh add "git commit -m 'Update README'" 0
```

The exit code is typically `0` for success, or any other number for failure.

### List Commands

Browse your command history interactively:

```bash
cmdh list
```

Use arrow keys to navigate, Enter to select, and Esc or Ctrl+C to exit.

### Check Version

```bash
cmdh version
```

## Development

### Project Structure

```
cmdh/
├── src/
│   ├── main.odin          # Main entry point
│   ├── db.odin            # Database schema initialization
│   ├── cmd_add.odin       # Add command implementation
│   ├── cmd_list.odin      # List command with TUI
│   ├── cmd_version.odin   # Version command
│   └── cli/               # CLI framework
├── tests/
│   └── smoke_test.sh      # Smoke tests
├── deps/                  # External dependencies (sqlite3)
└── Makefile              # Build targets
```

### Building

```bash
# Debug build with bounds checking
make build

# Release build (optimized)
make build-release

# Run directly with address sanitizer
make run
```

### Running Tests

```bash
# Run smoke tests
make test
```

The smoke test creates a temporary config directory, builds the binary, runs basic commands, and verifies database operations.

### Cleaning

```bash
# Remove build artifacts
make clean
```

## Configuration

cmdh stores its data in your home directory:

- **Config Path**: `~/.config/cmdh/`
- **Database**: `~/.config/cmdh/sqlite.db`
- **Logs**: `~/.config/cmdh/cmdh.log`

## Platform Support

- **Linux**: Fully supported (tested on Ubuntu)
- **macOS**: Fully supported
- **Windows**: Not currently supported

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Created by [foureyez](https://github.com/foureyez)
