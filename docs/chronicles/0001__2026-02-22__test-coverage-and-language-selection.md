# Test Coverage & Language Selection Feature

> Chronicle: 0001__2026-02-22__test-coverage-and-language-selection.md
> Status: Completed

## Context

WhisperNotes is a native macOS app (Swift/SwiftUI) for audio recording and transcription via whisper.cpp. The project had zero test infrastructure — no test target in Package.swift, no test files. The transcription language was hardcoded to Italian ("it") in WhisperService and not wired through AppState or exposed in any UI. The user wanted:

1. Comprehensive test coverage across all business logic
2. Language selection at first app launch, in Settings, and as an option when starting a new recording

## Objective (The WHY)

**Testing:** The project had zero tests, making it fragile for future changes. Adding `init(path:)` to Database and `init(db:mdSync:)` to AppState enabled dependency injection for test isolation. 95 tests across 7 test files cover all core business logic (CRUD operations, filtering, markdown sync, whisper service validation, models, color parsing, language support).

**Language Selection:** The app only transcribed Italian audio. Users needed to select their language at first launch (onboarding), change it globally in Settings, and optionally override it per-recording. This makes the app usable for any of the 30 most common languages whisper.cpp supports.

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| Build config | `Package.swift` | Split into WhisperNotesLib + WhisperNotes + WhisperNotesTests |
| Models | `Models.swift` | Added `SupportedLanguage` struct with 30 languages |
| State | `AppState.swift` | Added `language`, `hasCompletedSetup`, `completeSetup()`, language override in `recordAndTranscribe` |
| Transcription | `WhisperService.swift` | Default language changed from "it" to "auto" |
| Settings UI | `SettingsView.swift` | Added language picker section |
| Recording UI | `RecordingView.swift` | Added per-recording language override picker |
| App entry | `Sources/WhisperNotesApp/WhisperNotesApp.swift` | New thin wrapper with first-launch sheet |
| First launch | `LanguageSetupView.swift` | New searchable language selection view |
| Database | `Database.swift` | Added `init(path:)` and `openAndConfigure()` extraction |
| Content | `ContentView.swift` | Made public for cross-module access |
| Tests | `Tests/WhisperNotesTests/` | 7 new test files, 95 tests total |

## Discoveries & Insights

- **2026-02-22**: WhisperService already accepted `language` as a property but AppState ignored it — minimal wiring needed
- **2026-02-22**: SPM executable targets with `@main` conflict with test runners — solved by library/executable split with `exclude:` directive
- **2026-02-22**: Database `init(path:)` with temp SQLite files provides complete test isolation per test case
- **2026-02-22**: The `-l` flag in whisper-cli accepts ISO 639-1 codes ("en", "it", "de") or "auto" for auto-detection
- **2026-02-22**: `SupportedLanguage` Hashable should use `code` only for identity (matches `Identifiable.id`)
- **2026-02-22**: `isTranscribing` must be reset on all exit paths in `recordAndTranscribe` to avoid UI hang
- **2026-02-22**: Sheet binding `set:` that calls `completeSetup()` duplicates the button action — simplified to `{ _ in }`

---

## CLAUDE.md Updates

- [x] `CLAUDE.md` - Add test commands, test structure, language configuration details
