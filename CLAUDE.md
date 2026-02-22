# WhisperNotes — Development Guide

## Project Overview

Native macOS app (Swift/SwiftUI) for audio recording and transcription via whisper.cpp. SQLite storage with Markdown filesystem sync for Obsidian compatibility.

## Build Commands

```bash
swift build              # Debug build
swift build -c release   # Release build
./build.sh               # Build .app bundle (release + codesign)
```

## Project Structure

- `Sources/WhisperNotes/` — all application source code
- `Resources/` — Info.plist, AppIcon.icns
- `Package.swift` — SPM manifest (Swift 5.9, macOS 14+)
- `build.sh` — creates signed .app bundle

### Key Files

| File | Role |
|------|------|
| `AppState.swift` | Centralized state management (single ObservableObject) |
| `Database.swift` | SQLite3 layer — WAL mode, foreign keys, batch tag queries |
| `WhisperService.swift` | Runs whisper-cli as subprocess, parses output |
| `MarkdownSync.swift` | Writes/reads .md files with YAML frontmatter |
| `Models.swift` | Data models: Transcription, Folder, Tag, SidebarSelection |
| `ContentView.swift` | Root 3-column NavigationSplitView |
| `RecordingView.swift` | Recording modal with waveform animation |

## Architecture & Conventions

- **No external dependencies** — only system frameworks (SwiftUI, AVFoundation, SQLite3)
- **State pattern** — single `AppState` ObservableObject, views use `@EnvironmentObject`
- **Database** — raw SQLite3 C API, no ORM. WAL journal mode. Foreign keys enabled
- **Markdown sync** — every transcription save also writes a `.md` file for Obsidian
- **UI** — 3-column NavigationSplitView (sidebar | list | detail)
- **Process execution** — whisper-cli runs via Foundation `Process` with timeout
- **Default language** — Italian (`"it"`) in WhisperService — configurable

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
A skill swift-dev is also available in this project following the same patterns as the other skills inside development-skills plugin, use it.
