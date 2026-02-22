# Contributing to WhisperNotes

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. **Requirements:** macOS 14+, Xcode 15+ (or Swift 5.9+ toolchain), Apple Silicon Mac
2. **Clone the repo:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/whisper-notes.git
   cd whisper-notes
   ```
3. **Build:**
   ```bash
   swift build
   ```
4. **Run the app bundle:**
   ```bash
   ./build.sh
   open WhisperNotes.app
   ```

## Code Style

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

## Reporting Issues

When filing an issue, include:
- macOS version and Mac model (Intel or Apple Silicon)
- Steps to reproduce
- Expected vs actual behavior
- Console output if relevant (`Console.app` > filter by "WhisperNotes")

## Areas for Contribution

Here are some areas where help is welcome:

- **Intel Mac support** — currently builds for arm64 only
- **Localization** — the app defaults to Italian for transcription language; making this configurable in the UI
- **Tests** — unit tests for `Database`, `MarkdownSync`, and `WhisperService`
- **Accessibility** — VoiceOver support and accessibility labels
- **Audio playback** — playing back recorded audio from the detail view
- **Import** — importing existing audio files for transcription

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
