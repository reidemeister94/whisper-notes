# Developer Tooling Setup — Pre-commit, Makefile, SwiftLint, SwiftFormat

> Chronicle: 0002__2026-02-22__developer-tooling-setup.md
> Status: Completed

## Context

The user maintains a Python project (dtp-order-extraction-api) with a mature developer tooling setup: pre-commit hooks (trailing-whitespace, end-of-file-fixer, check-yaml/toml, check-merge-conflict, commitizen for commit messages, ruff for linting + formatting), a Makefile for common tasks, and ruff config in pyproject.toml (line-length=100). The whisper-notes Swift project had zero developer tooling. The goal was to translate the Python tooling patterns into Swift equivalents.

**Key references:**
- `.pre-commit-config.yaml` - pre-commit hooks (trailing-whitespace, end-of-file-fixer, check-yaml, check-merge-conflict, commitizen, SwiftLint, SwiftFormat)
- `Makefile` - all dev targets (clean, setup-dev-env, build, test, lint, format, bump, etc.)
- `.swiftlint.yml` - SwiftLint config calibrated to existing codebase
- `.swiftformat` - SwiftFormat config consistent with SwiftLint
- `.cz.toml` - commitizen config for version management
- `VERSION` - version tracking file

## Objective (The WHY)

Standardize developer experience across projects. Same workflow muscle memory across Python and Swift projects: `make setup-dev-env` to bootstrap, pre-commit hooks for quality gates, commitizen for conventional commits.

## Tool Mapping (Python -> Swift)

| Python Tool | Swift Equivalent | Purpose |
|-------------|-----------------|---------|
| ruff (lint) | SwiftLint 0.63.2 | Code linting with auto-fix |
| ruff (format) | SwiftFormat 0.59.1 | Code formatting |
| pre-commit | pre-commit (same) | Git hook framework |
| commitizen | commitizen (same) | Conventional commit enforcement |
| pyproject.toml | .swiftlint.yml + .swiftformat | Tool configuration |
| Makefile | Makefile | Task automation |
| uv/pip | Homebrew | Package management for tools |

## Discoveries & Insights

- **2026-02-22**: Use `language: system` for pre-commit Swift hooks (fast, uses Homebrew binaries) instead of `language: swift` which compiles from source (~2-5 min per run)
- **2026-02-22**: The `multiline_arguments` SwiftLint opt-in rule was too aggressive for the existing codebase — removed to avoid excessive churn
- **2026-02-22**: SwiftFormat auto-applied many idiomatic Swift improvements: keypath syntax (`.filter(\.isFavorite)`), shorthand unwrapping (`guard let id`), removed redundant `self.`, replaced `try!` with `try` in tests
- **2026-02-22**: The `identifier_name` rule's `excluded` list is redundant when `min_length.warning: 1` is set
- **2026-02-22**: Pre-commit `exclude` regex should escape dots (`.build` matches any char + build, `\.build` matches literal dot)
- **2026-02-22**: Use `brew install commitizen` instead of `pip install` for consistency — avoids system Python conflicts

## Files Created/Modified

| File | Action |
|------|--------|
| `.pre-commit-config.yaml` | Created |
| `.swiftlint.yml` | Created |
| `.swiftformat` | Created |
| `.cz.toml` | Created |
| `VERSION` | Created |
| `Makefile` | Created |
| `.gitignore` | Modified (added .swiftlint/) |
| `CLAUDE.md` | Modified (added Developer Tooling section) |
| `CONTRIBUTING.md` | Modified (updated setup + code style) |
| `Tests/.../AppStateTests.swift` | Modified (renamed final_ -> result) |

---

## CLAUDE.md Updates

### Updates applied:

- [x] `CLAUDE.md` - Added Developer Tooling section with make targets and tool configs
