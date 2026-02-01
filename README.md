# histr

Command history tool written in Odin.

Overview
- Simple TUI to list command history.

Build
- Build (debug):
  make build
- Build (release):
  make build-release

Development
- Run smoke tests:
  make test
- CI: A GitHub Actions workflow is included in `.github/workflows/ci.yml` which builds debug & release and runs the smoke test.

Notes
- Supports Linux and Mac
