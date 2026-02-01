# Contributing to cmdh

Thank you for your interest in contributing to cmdh! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/cmdh.git
   cd cmdh
   ```
3. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Building

```bash
make build        # Debug build
make build-release # Release build
```

### Testing

Before submitting a PR, ensure all tests pass:

```bash
make test
```

The smoke test validates core functionality including:
- Database initialization
- Command addition with exit codes
- Exit code validation
- List command execution

### Code Style

- Follow the existing code style in the project
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and concise
- Run `make fmt` if you have `odinfmt` installed

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb in imperative mood (e.g., "Add", "Fix", "Update")
- Keep the first line under 72 characters
- Add details in the commit body if needed

Example:
```
Fix error handling in cmd_add when parsing exit codes

- Parse exit_code string to integer using strconv
- Return error if parsing fails
- Check correct error variable (eerr) after stmt_exec
```

## Submitting Changes

1. Ensure your code builds without errors
2. Run the test suite and verify all tests pass
3. Commit your changes with clear commit messages
4. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
5. Open a Pull Request (PR) on GitHub
6. Provide a clear description of the changes
7. Reference any related issues

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Update documentation if needed
- Add tests for new functionality
- Ensure CI passes on all platforms (Linux, macOS)
- Respond to review feedback promptly

## Reporting Issues

When reporting issues, please include:
- Operating system and version
- Odin compiler version
- Steps to reproduce the issue
- Expected vs actual behavior
- Error messages or logs if applicable

## Areas for Contribution

- Bug fixes
- New features
- Documentation improvements
- Test coverage
- Performance optimizations
- Platform support (e.g., Windows)
- UI/UX improvements

## Questions?

If you have questions about contributing, feel free to:
- Open an issue for discussion
- Reach out to the maintainers

Thank you for contributing to cmdh!
