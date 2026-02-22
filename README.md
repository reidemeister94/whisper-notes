# WhisperNotes

[![CI](https://github.com/silviopavanetto/whisper-notes/actions/workflows/ci.yml/badge.svg)](https://github.com/silviopavanetto/whisper-notes/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen.svg)](https://www.apple.com/macos/sonoma/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

A native macOS app for recording audio and transcribing it to text using [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Organize your transcriptions into folders, tag them, search across everything, and export to Markdown.

> Built with Swift and SwiftUI. No Electron, no web views — just a fast, native Mac experience.

## Features

- **Record & Transcribe** — One-click audio recording with real-time waveform visualization, powered by whisper.cpp for local, private transcription
- **Organize** — Create custom folders, color-coded tags, and mark favorites
- **Smart Folders** — Built-in views for All, Favorites, Recent (last 7 days), and Uncategorized notes
- **Search** — Full-text search across all your transcriptions
- **Markdown Export** — Export individual notes or auto-sync all notes as Markdown files with YAML frontmatter
- **Obsidian Compatible** — Synced Markdown files work directly as an Obsidian vault
- **Edit Anywhere** — Edit titles and transcription content directly in the app
- **Keyboard Shortcuts** — `Cmd+N` new recording, `Cmd+Shift+N` new folder, `Cmd+S` save
- **Privacy First** — Everything runs locally. Audio and transcriptions never leave your machine

## Prerequisites

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** Mac (M1/M2/M3/M4)
- **Swift 5.9+** toolchain (included with Xcode 15+)
- **whisper.cpp** — the CLI transcription engine

### Installing whisper.cpp

```bash
# Clone and build whisper.cpp
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
cmake -B build
cmake --build build --config Release

# Download a model (large-v3-turbo recommended for quality + speed)
./models/download-ggml-model.sh large-v3-turbo
```

After building, note the paths to:
- `whisper.cpp/build/bin/whisper-cli` — the CLI binary
- `whisper.cpp/models/ggml-large-v3-turbo.bin` — the model file

You'll configure these in WhisperNotes settings.

## Build & Run

```bash
# Clone the repo
git clone https://github.com/silviopavanetto/whisper-notes.git
cd whisper-notes

# Build the app bundle
./build.sh

# Install (optional)
cp -r WhisperNotes.app /Applications/
```

The `build.sh` script compiles a release build, creates a proper `.app` bundle with icon and Info.plist, and ad-hoc signs it.

**First launch:** Right-click the app > Open (to bypass Gatekeeper for unsigned apps).

### Development build

```bash
swift build          # Debug build
swift build -c release   # Release build
```

## Configuration

On first launch, open **WhisperNotes > Settings** (`Cmd+,`) and configure:

| Setting | Description | Default |
|---------|-------------|---------|
| **whisper-cli path** | Path to the `whisper-cli` binary | `~/Documents/whisper.cpp/build/bin/whisper-cli` |
| **Model path** | Path to the GGML model file | `~/Documents/whisper.cpp/models/ggml-large-v3-turbo.bin` |
| **Notes folder** | Where Markdown files are saved | `~/Documents/Whisper Notes/` |

The settings view shows green/red indicators for whether each file is found.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and component descriptions.

**Key design decisions:**
- **No external dependencies** — uses only system frameworks (SwiftUI, AVFoundation, SQLite3)
- **Centralized state** — single `AppState` ObservableObject manages all app data
- **SQLite with WAL** — fast concurrent reads, reliable persistence
- **Batch tag queries** — avoids N+1 query problem when loading transcriptions
- **Markdown sync** — every save writes a `.md` file with YAML frontmatter

## Data Storage

| What | Where |
|------|-------|
| SQLite database | `~/Library/Application Support/WhisperNotes/whisper-notes.db` |
| Audio recordings | `~/Library/Application Support/WhisperNotes/` |
| Markdown exports | Configurable (default: `~/Documents/Whisper Notes/`) |

## Markdown Format

Exported files use YAML frontmatter compatible with Obsidian:

```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
date: 2024-12-15T10:30:00Z
tags: ["meeting", "project"]
favorite: true
duration: 180
---

# Meeting Notes

Transcribed content goes here...
```

## Permissions

WhisperNotes requires **microphone access** to record audio. macOS will prompt you on first recording. You can manage this in System Settings > Privacy & Security > Microphone.

## Troubleshooting

**"whisper-cli not found"** — Check Settings and verify the path to the whisper-cli binary. Make sure whisper.cpp is built.

**"Model not found"** — Check Settings and verify the model path. Make sure you've downloaded a GGML model.

**Transcription fails or times out** — The default timeout is 300 seconds. Large audio files with the `large-v3-turbo` model may need more time. Check that the model file isn't corrupted.

**No audio input** — Grant microphone permission in System Settings > Privacy & Security > Microphone.

**App won't open** — Right-click > Open on first launch to bypass Gatekeeper for ad-hoc signed apps.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov — the engine that makes local transcription possible
- [OpenAI Whisper](https://github.com/openai/whisper) — the original speech recognition model
