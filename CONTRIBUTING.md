# Contributing to cmdh

Thank you for your interest in contributing to cmdh! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourname/cmdh.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Odin compiler (dev-2024-01 or later)
- SQLite3 development libraries
- Git

### Building

```bash
make build        # Debug build
make build-release # Release build
```

## Running Tests

Before submitting a PR, make sure all tests pass:

```bash
make test
```

The test suite includes:
- Smoke tests that verify basic functionality
- Database initialization tests
- Error handling validation

## Code Style

- Follow the existing code style in the repository
- Use tabs for indentation (Odin convention)
- Keep functions focused and single-purpose
- Add comments for complex logic
- Use meaningful variable and function names

### Odin-Specific Guidelines

- Use `::` for constants and procedures
- Use `:` for variables
- Prefer explicit types over inference when it improves readability
- Use defer for cleanup (file handles, database connections, etc.)
- Always check error returns from procedures that can fail

## Making Changes

1. **Small, focused commits**: Each commit should represent a logical unit of work
2. **Descriptive commit messages**: Start with a verb in present tense (e.g., "Add feature", "Fix bug")
3. **Test your changes**: Ensure `make test` passes
4. **Update documentation**: If you change functionality, update README.md

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Ensure all tests pass locally
3. Update the version number if applicable
4. Create a pull request with a clear description of changes
5. Link any related issues

### PR Title Format

- `Fix: Description of bug fix`
- `Feature: Description of new feature`
- `Docs: Description of documentation changes`
- `Refactor: Description of refactoring`

### PR Description Should Include

- Summary of changes
- Motivation for changes
- Any breaking changes
- Screenshots (if UI changes)
- Testing performed

## Reporting Bugs

When filing a bug report, please include:

1. **Description**: Clear description of the bug
2. **Steps to reproduce**: Step-by-step instructions
3. **Expected behavior**: What you expected to happen
4. **Actual behavior**: What actually happened
5. **Environment**: OS, Odin version, cmdh version
6. **Logs**: Relevant log output from `~/.config/cmdh/cmdh.log`

## Feature Requests

Feature requests are welcome! Please:

1. Check if the feature has already been requested
2. Clearly describe the feature and use case
3. Explain why it would be useful to other users
4. Consider if it fits the project's scope and philosophy

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Welcome newcomers and help them get started
- Assume good intentions

## Questions?

If you have questions about contributing, feel free to:
- Open an issue with the "question" label
- Check existing issues and discussions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
