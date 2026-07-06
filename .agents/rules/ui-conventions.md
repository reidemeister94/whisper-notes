---
paths:
  - "Sources/**"
---

# SwiftUI / macOS UI conventions

TextField `.onSubmit` fires only on Enter, NOT on focus loss. Commit pending state (e.g. a new folder name) before any action the user can trigger by clicking a button (e.g. Start Recording), or the pending value is lost.

Sidebar `Section` must use an `isExpanded:` binding — required for reliable rendering when data changes dynamically (e.g. first folder creation transitions empty → non-empty).

Keyboard shortcuts (defined as `CommandGroup` in `WhisperNotesApp.swift`):
| Shortcut | Action |
|----------|--------|
| Cmd+N | New Recording |
| Cmd+Shift+N | New Folder |
| Cmd+S | Save transcription edits |
| Cmd+Delete | Delete selected item (with confirmation) |
| Cmd+F | Focus search field |
| Cmd+D | Toggle favorite on selected transcription |

Actions that modify `@FocusState` from menu commands use a counter-trigger (`searchFocusTrigger += 1`), never a boolean — avoids `@FocusState` race conditions.

Drag-and-drop:
- `Transcription` conforms to `Transferable` via `ProxyRepresentation(exporting: \.id.uuidString)`.
- Transcription rows use `.draggable(transcription)`; folder rows and "Uncategorized" use `.dropDestination(for: String.self)`.
- Drop handling is centralized in `AppState.handleDrop(uuidStrings:targetFolderId:)`.
- The "Uncategorized" sentinel is `SidebarSelection.uncategorizedFolderID` — use this constant, never the raw UUID string.

Recording UI:
- The main record control uses a stable `ZStack` with tap handling on the whole control; keep the large hit target when changing styling.
- Before starting/stopping, commit pending new-folder text so clicking the record button does not lose folder creation.
- Voxtral streaming text appears while recording; Cohere/Whisper transcribe after stop.

Settings UI:
- Engine names come from `TranscriptionEngine.displayName`; descriptions come from `settingsDescription`.
- Adding an engine requires updating `TranscriptionEngine`, `SupportedLanguage.all(for:)`, the Settings section, and the `recordAndTranscribe` switch.
