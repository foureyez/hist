# Contributing to cmdh

Thank you for your interest in contributing to cmdh! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/cmdh.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- Odin compiler (dev-2024-12 or later)
- SQLite3
- Basic understanding of Odin programming language

### Building

```bash
make build        # Debug build
make build-release  # Release build
```

### Running Tests

Before submitting a PR, make sure all tests pass:

```bash
make test
```

## Code Style

- Follow standard Odin naming conventions
- Use snake_case for procedures and variables
- Use PascalCase for types and structs
- Keep procedures small and focused
- Add comments for complex logic
- Use meaningful variable names

## Pull Request Guidelines

1. **Keep PRs focused**: One feature or bug fix per PR
2. **Write clear commit messages**: Describe what and why, not how
3. **Update documentation**: If you change functionality, update README.md
4. **Add tests**: For new features, add appropriate test coverage
5. **Check CI**: Ensure all CI checks pass before requesting review
6. **Small changes**: Keep changes minimal and self-contained

## Commit Messages

Use clear, descriptive commit messages:

```
Fix error handling in cmd_add.odin

- Parse exit code as integer instead of string
- Check correct error variable (eerr instead of err)
- Add validation for invalid exit codes
```

## Testing

- Run `make test` to execute the smoke test suite
- Manually test your changes with the built binary
- Test on both debug and release builds
- If possible, test on multiple platforms (Linux/macOS)

## Bug Reports

When filing a bug report, please include:

- Odin version (`odin version`)
- Operating system and version
- Steps to reproduce
- Expected vs actual behavior
- Any relevant log output

## Feature Requests

When suggesting a feature:

- Explain the use case
- Describe the expected behavior
- Consider backwards compatibility
- Keep it aligned with the project's goals

## Questions?

If you have questions about contributing, feel free to open an issue with the `question` label.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

Thank you for contributing to cmdh!
