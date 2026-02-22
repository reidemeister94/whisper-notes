# Contributing to WhisperNotes

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. **Requirements:** macOS 14+, Xcode 15+ (or Swift 5.9+ toolchain), Apple Silicon Mac, Homebrew
2. **Clone the repo:**
   ```bash
   git clone https://github.com/silviopavanetto/whisper-notes.git
   cd whisper-notes
   ```
3. **Set up dev environment** (installs SwiftLint, SwiftFormat, pre-commit hooks):
   ```bash
   make setup-dev-env
   ```
4. **Build:**
   ```bash
   make build
   ```
5. **Run tests:**
   ```bash
   make test
   ```
6. **Run the app bundle:**
   ```bash
   make app-bundle
   open WhisperNotes.app
   ```

## Code Style

- **Linting**: SwiftLint checks are enforced via pre-commit hooks. Run manually with `make lint`.
- **Formatting**: SwiftFormat runs automatically on commit. Run manually with `make format`.
- **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/) format (enforced by commitizen).
- Follow standard Swift conventions and the existing code patterns
- Use SwiftUI for all UI work
- Keep `AppState` as the single source of truth — don't create additional ObservableObjects
- Use raw SQLite3 API (no ORM) — match the existing `Database.swift` patterns
- No external dependencies unless absolutely necessary

## Making Changes

1. **Fork** the repo and create a feature branch from `main`
2. **Keep changes focused** — one feature or fix per PR
3. **Test manually** — build the app and verify your changes work end-to-end
4. **Update docs** if your change affects build steps, configuration, or architecture

## Pull Request Process

1. Describe what your PR does and why
2. Include steps to test the change manually
3. Keep the diff small and reviewable
4. Make sure `swift build` succeeds with no warnings
5. Make sure `swift test` passes — CI runs automatically on every PR
6. Make sure `make lint` passes (no SwiftLint violations)

## Reporting Issues

When filing an issue, include:
- macOS version and Mac model (Intel or Apple Silicon)
- Steps to reproduce
- Expected vs actual behavior
- Console output if relevant (`Console.app` > filter by "WhisperNotes")

## Areas for Contribution

Here are some areas where help is welcome:

- **Intel Mac support** — currently builds for arm64 only
- **Localization** — UI strings for additional languages beyond English
- **Tests** — unit tests for `Database`, `MarkdownSync`, and `WhisperService`
- **Audio playback** — playing back recorded audio from the detail view
- **Import** — importing existing audio files for transcription

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
