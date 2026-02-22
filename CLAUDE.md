# WhisperNotes — Development Guide

## Project Overview

Native macOS app (Swift/SwiftUI) for audio recording and transcription via whisper.cpp. SQLite storage with Markdown filesystem sync.

## Build Commands

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run all 96 tests
./build.sh               # Build .app bundle (release + codesign)
```

## Developer Tooling

```bash
make setup-dev-env   # Install SwiftLint, SwiftFormat, pre-commit hooks
make lint            # Run SwiftLint
make lint-fix        # Run SwiftLint with auto-fix
make format          # Run SwiftFormat (auto-fix)
make help            # Show all targets
```

- **Pre-commit** runs trailing-whitespace, end-of-file-fixer, SwiftLint, SwiftFormat on every commit
- **Commitizen** enforces conventional commit messages (commit-msg hook)
- **SwiftLint** config: `.swiftlint.yml` (line_length 140, includes Sources/ and Tests/)
- **SwiftFormat** config: `.swiftformat` (4-space indent, maxwidth 140, trailing commas)

## Project Structure

- `Sources/WhisperNotes/` — library target (WhisperNotesLib) — all application source code
- `Sources/WhisperNotesApp/` — executable target — thin `@main` wrapper
- `Tests/WhisperNotesTests/` — test target (96 tests across 7 files)
- `Resources/` — Info.plist, AppIcon.icns
- `Package.swift` — SPM manifest (Swift 5.9, macOS 14+)
- `build.sh` — creates signed .app bundle

### Key Files

| File | Role |
|------|------|
| `AppState.swift` | Centralized state management (single ObservableObject) |
| `Database.swift` | SQLite3 layer — WAL mode, foreign keys, batch tag queries, preflight check |
| `WhisperService.swift` | Runs whisper-cli as subprocess, parses output |
| `MarkdownSync.swift` | Writes/reads .md files with YAML frontmatter (with error logging) |
| `Models.swift` | Data models: Transcription, Folder, Tag, SidebarSelection, SupportedLanguage |
| `ContentView.swift` | Root 3-column NavigationSplitView |
| `TranscriptionDetailView.swift` | Transcription editor with debounced autosave |
| `TagPickerView.swift` | Tag assignment popover (SnippetsLab style) |
| `ToolbarIconButton.swift` | Reusable icon button with accessibility |
| `FlowLayout.swift` | Flow layout for tag pill wrapping |
| `RecordingView.swift` | Recording modal with waveform animation + language override |
| `SettingsView.swift` | App settings including language selection |
| `LanguageSetupView.swift` | First-launch language selection onboarding |

## Architecture & Conventions

- **No external dependencies** — only system frameworks (SwiftUI, AVFoundation, SQLite3)
- **State pattern** — single `AppState` ObservableObject, views use `@EnvironmentObject`
- **Database** — raw SQLite3 C API, no ORM. WAL journal mode. Foreign keys enabled. Tag sync wrapped in BEGIN/COMMIT transaction. Pre-flight check validates directory access at launch.
- **Markdown sync** — every transcription save also writes a `.md` file. One-way sync (app → filesystem); SQLite is the sole source of truth. Filesystem changes (deleting .md files in Finder) are NOT reflected back to the app.
- **UI** — 3-column NavigationSplitView (sidebar | list | detail). Sidebar `Section` views use `isExpanded:` bindings for reliable rendering when data changes dynamically.
- **Process execution** — whisper-cli runs via Foundation `Process` with timeout
- **Language** — Default "auto" (auto-detect). Selectable at first launch, in Settings, and per-recording. 30 languages supported via `SupportedLanguage` model. Persisted in UserDefaults.
- **Autosave** — Detail view uses debounced dirty-flag autosave (3 seconds after last edit). Timer resets on each keystroke, preventing writes during active typing.
- **Testability** — Library/executable split enables `@testable import WhisperNotesLib`. Database accepts `init(path:)` for temp DBs. AppState accepts `init(db:mdSync:)` for dependency injection.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New Recording |
| Cmd+Shift+N | New Folder |
| Cmd+S | Save transcription edits |
| Cmd+Delete | Delete selected item (with confirmation) |
| Cmd+F | Focus search field |
| Cmd+D | Toggle favorite on selected transcription |

Shortcuts are defined as `CommandGroup` in `WhisperNotesApp.swift`. Actions that modify `@FocusState` use a counter trigger pattern (`searchFocusTrigger += 1`) to avoid race conditions.

## SwiftUI Pitfalls

- **TextField `.onSubmit`** only fires on Enter key press, NOT on focus loss. Always commit pending state (e.g. new folder name) before actions the user can trigger by clicking buttons (e.g. Start Recording).
- **Sidebar `Section`** must use `isExpanded:` binding for reliable rendering when data changes dynamically (e.g. first folder creation transitioning from empty to non-empty).

## Drag-and-Drop

- `Transcription` conforms to `Transferable` via `ProxyRepresentation(exporting: \.id.uuidString)`
- Transcription rows in `TranscriptionListView` use `.draggable(transcription)`
- Folder rows and "Uncategorized" in `SidebarView` use `.dropDestination(for: String.self)`
- Drop handling centralized in `AppState.handleDrop(uuidStrings:targetFolderId:)`
- The "Uncategorized" sentinel UUID is `SidebarSelection.uncategorizedFolderID` — use this constant, never the raw UUID string

## Data Locations

- DB: `~/Library/Application Support/WhisperNotes/whisper-notes.db`
- Audio: `~/Library/Application Support/WhisperNotes/`
- Markdown: `~/Documents/Whisper Notes/` (configurable in Settings)

## Platform

- macOS 14.0+ (Sonoma)
- Apple Silicon (arm64)
- Swift 5.9+

## Development Skills

CRITICAL: USE ALWAYS THE PLUGIN "development-skills" FOR EVERY TASK ON THIS PROJECT (BRAINSTORMING, DEVELOPMENT, BUG FIXING, NEW FEATURE, ...) IF THE PLUGIN IS NOT AVAILABLE ON THE USER SYSTEM, NOTICE IT
