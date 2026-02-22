# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Accessibility labels for all icon-only buttons (VoiceOver support)
- Accessibility hints for recording and list interactions
- Input validation for folder and tag names (trim, length limits)
- Error alerts for critical failures (recording, transcription)
- Debug logging for markdown sync operations
- `ARCHITECTURE.md` with Mermaid diagrams for contributors
- GitHub Actions CI pipeline (build + test on push/PR)
- Issue templates (bug report, feature request)
- Pull request template with checklist
- `CHANGELOG.md`
- New tests for input validation, drag-drop, edge cases

### Changed
- `createTag()` now returns the created `Tag` (fixes race condition in tag assignment)
- `build.sh` now verifies binary and bundle files exist before signing
- Updated `README.md` with CI badge, license badge, and architecture link
- Updated `CONTRIBUTING.md` with CI and lint requirements

### Fixed
- Tag creation race condition where newly created tag couldn't be found for assignment
- Silent failures when audio directory creation or file copy failed during recording
- `renameFolder` now rejects empty names instead of creating nameless folders

### Removed
- Duplicate `WhisperNotesApp.swift` from library target (was dead code, excluded by Package.swift)

## [1.0.0] - 2024-12-15

### Added
- Audio recording with waveform visualization
- Local transcription via whisper.cpp
- 3-column layout (sidebar, list, detail)
- Folder organization with drag-and-drop
- Color-coded tags with flow layout
- Smart folders: All, Favorites, Recent, Uncategorized
- Full-text search across titles and content
- Markdown export with YAML frontmatter (Obsidian compatible)
- Keyboard shortcuts (Cmd+N, Cmd+Shift+N, Cmd+S, Cmd+F, Cmd+D, Cmd+Delete)
- Language selection (30 languages) with per-recording override
- First-launch language setup onboarding
- Settings for whisper-cli path, model path, notes folder
- SQLite database with WAL mode
- 96 unit tests
