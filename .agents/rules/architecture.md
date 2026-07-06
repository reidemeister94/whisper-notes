---
paths:
  - "Sources/**"
  - "Tests/**"
---

# Architecture & conventions

State: one `AppState` `ObservableObject` is the source of truth; views read it via `@EnvironmentObject`. Do not add parallel ViewModels for app state.

Database (`Database.swift`): raw SQLite3 C API, no ORM. WAL journal mode, foreign keys ON. Tag sync is transactional. Batch tag query (`fetchAllTranscriptionTags`) avoids N+1. Cascades: delete folder -> `folder_id = NULL`; delete transcription/tag -> cascade `transcription_tags`.

Markdown sync (`MarkdownSync.swift`): one-way app -> filesystem. SQLite is authoritative; every save writes a `.md` with YAML frontmatter. Finder-side edits/deletes do not sync back. Sync failure is logged and must not block DB saves.

Transcription engines:
| Engine | File | Pattern |
|--------|------|---------|
| Whisper | `WhisperService.swift` | `whisper-cli` subprocess, timeout, stdout cleanup |
| Cohere | `CohereService.swift` + `Resources/CohereBackend/` | bundled Python backend, local venv under App Support |
| Voxtral | `VoxtralService.swift` + `Sources/Cvoxtral/` | vendored C target, preloaded model, streaming tokens |

Cohere app integration is self-contained: the bundled backend script and setup script ship as `WhisperNotesLib` resources. Do not reference the separate `italian-transcriber` project.

`AudioRecorder.swift` uses `AVAudioEngine` input tap + `AVAudioConverter` to 16kHz mono Float32 and writes a 16-bit WAV. Keep the direct input tap; mixer-based capture produced silent recordings.

Language: `SupportedLanguage.all(for:)` is engine-specific. Persisted default is `"auto"`; Cohere maps `"auto"` to Italian in `CohereService`.

Autosave: detail view debounces 3s after the last edit; the timer resets on each keystroke.

Key files:
| File | Role |
|------|------|
| `AppState.swift` | Centralized state, engine selection, recording/transcription flow |
| `AudioRecorder.swift` | 16kHz mono capture, WAV persistence, streaming buffer callback |
| `CohereService.swift` | bundled backend subprocess and setup paths |
| `VoxtralService.swift` | `Cvoxtral` streaming/batch wrapper |
| `WhisperService.swift` | whisper.cpp subprocess wrapper |
| `Database.swift` | SQLite3 layer: WAL, FK, batch tag queries, preflight |
| `MarkdownSync.swift` | `.md` writer with YAML frontmatter |
| `Models.swift` | Transcription, Folder, Tag, SidebarSelection, per-engine languages |
| `RecordingView.swift` | recording modal, folder commit, language override, streaming text |
| `SettingsView.swift` | engine selector and engine-specific setup |

Targets: `Cvoxtral` = vendored C sources, `WhisperNotesLib` = library + Cohere resources, `WhisperNotes` = thin `@main`, `WhisperNotesTests` = tests. `build.sh` must copy `WhisperNotes_WhisperNotesLib.bundle` into the `.app`.
