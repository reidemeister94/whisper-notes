---
paths:
  - "Sources/**"
  - "Tests/**"
---

# Architecture & conventions

State: a single `AppState` `ObservableObject` is the sole source of truth; views read it via `@EnvironmentObject`. No other ViewModels or observable objects.

Database (`Database.swift`): raw SQLite3 C API, no ORM. WAL journal mode, foreign keys ON. Tag sync wrapped in a `BEGIN`/`COMMIT` transaction. Pre-flight check validates directory access at launch. Batch tag query (`fetchAllTranscriptionTags`) avoids N+1. Cascades: delete folder → `folder_id = NULL` (SET NULL); delete transcription or tag → cascade `transcription_tags`.

Markdown sync (`MarkdownSync.swift`): one-way (app → filesystem). SQLite is the sole source of truth; every save also writes a `.md` with YAML frontmatter. Finder-side changes (deleting `.md`) are NOT synced back. Non-critical — sync failure is logged, never blocks a save.

Transcription (`WhisperService.swift`): runs `whisper-cli` as a Foundation `Process` subprocess with timeout; parses/cleans stdout (strips timestamps, joins lines). `WhisperError` enum: `.cliNotFound`, `.modelNotFound`, `.processFailed`.

Language: default `"auto"` (auto-detect). 30 languages via `SupportedLanguage.all`; persisted in UserDefaults; selectable at first launch, in Settings, and per-recording (`-l` flag).

Autosave: detail view debounces 3s after last edit; the timer resets on each keystroke, so no writes happen during active typing.

Key files:
| File | Role |
|------|------|
| `AppState.swift` | Centralized state (single ObservableObject); `handleDrop`, `recordAndTranscribe` |
| `Database.swift` | SQLite3 layer — WAL, FK, batch tag queries, preflight |
| `WhisperService.swift` | whisper-cli subprocess + output parse |
| `MarkdownSync.swift` | `.md` writer with YAML frontmatter |
| `Models.swift` | Transcription, Folder, Tag, SidebarSelection, SupportedLanguage |
| `ContentView.swift` | Root 3-column NavigationSplitView |
| `TranscriptionDetailView.swift` | Editor with debounced autosave |
| `RecordingView.swift` | Recording modal + waveform + language override |
| `SettingsView.swift` | Settings incl. language, whisper-cli/model paths |
| `WelcomeView.swift` / `LanguageSetupView.swift` | First-launch onboarding |

Targets: `WhisperNotes/` = library (`WhisperNotesLib`), `WhisperNotesApp/` = thin `@main` executable, `Tests/WhisperNotesTests/`. See `ARCHITECTURE.md` for diagrams, DB schema, and the full component map.
