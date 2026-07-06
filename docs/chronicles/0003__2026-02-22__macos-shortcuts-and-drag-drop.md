# macOS Keyboard Shortcuts & Drag-and-Drop

> Chronicle: 0003__2026-02-22__macos-shortcuts-and-drag-drop.md
> Status: Completed

## Context

WhisperNotes is a macOS 14+ SwiftUI app with a 3-column NavigationSplitView (sidebar | list | detail). Previously it only had 3 keyboard shortcuts: Cmd+N (new recording), Cmd+Shift+N (new folder), Cmd+S (save). No drag-and-drop support and no standard macOS keyboard shortcuts for common operations like delete, find, or copy.

Users expect standard macOS behavior: Cmd+Delete to delete items, Cmd+F to search, drag-and-drop to organize notes into folders.

**Key references:**
- `Sources/WhisperNotesApp/WhisperNotesApp.swift` - App entry point with `.commands` modifier (menu bar)
- `Sources/WhisperNotes/ContentView.swift` - Root NavigationSplitView + confirmation alerts
- `Sources/WhisperNotes/SidebarView.swift` - Sidebar with folders (drop destinations)
- `Sources/WhisperNotes/TranscriptionListView.swift` - Middle column (draggable rows, search focus)
- `Sources/WhisperNotes/TranscriptionDetailView.swift` - Detail view (consistent delete/move)
- `Sources/WhisperNotes/AppState.swift` - Centralized state with CRUD + confirmation + drag-drop helpers
- `Sources/WhisperNotes/Models.swift` - Transcription (Transferable), Folder, Tag, SidebarSelection

## Objective (The WHY)

macOS users have deeply ingrained muscle memory for standard keyboard shortcuts. Without them, the app feels foreign and requires mouse-driven workflows for common operations. Drag-and-drop is the natural macOS metaphor for organizing items into folders.

This change makes WhisperNotes feel like a native, polished macOS citizen.

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| Menu bar | `WhisperNotesApp.swift` | Added CommandGroup for Delete, Find, Toggle Favorite |
| Transcription list | `TranscriptionListView.swift` | Draggable rows, search focus via @FocusState |
| Sidebar | `SidebarView.swift` | Drop destinations on folders + Uncategorized |
| Detail view | `TranscriptionDetailView.swift` | Consistent confirm-before-delete, moveToFolder |
| App state | `AppState.swift` | Confirmation state, handleDrop, moveToFolder, deleteSelectedItem |
| Models | `Models.swift` | Transferable conformance, public access, uncategorizedFolderID constant |
| Content view | `ContentView.swift` | Confirmation alert modifiers |
| Tests | `AppStateTests.swift` | Updated to use uncategorizedFolderID constant |

## Discoveries & Insights

- **2026-02-22**: macOS 14+ supports `.draggable()` / `.dropDestination()` — modern SwiftUI APIs, no NSItemProvider needed
- **2026-02-22**: `.onDeleteCommand` handles Fn+Delete (forward delete), not Cmd+Delete. For Cmd+Delete we need `.keyboardShortcut(.delete, modifiers: .command)` in menu commands
- **2026-02-22**: Transferable protocol — `ProxyRepresentation(exporting: \.id.uuidString)` is the simplest approach for intra-app drag. Transfers UUID string, no Codable needed
- **2026-02-22**: For search focus trigger, use an incrementing counter (`searchFocusTrigger += 1`) instead of a boolean that must be reset. Avoids race conditions with SwiftUI's observation system
- **2026-02-22**: SwiftUI `.alert(isPresented:presenting:)` can be driven by a computed `Binding` on an optional (`get: { item != nil }, set: { if !$0 { item = nil } }`), eliminating redundant boolean state
- **2026-02-22**: Magic UUID for "Uncategorized" (`00000000-...`) appeared 5 times across 4 files. Extracted to `SidebarSelection.uncategorizedFolderID` constant
- **2026-02-22**: Making model types `public` (Transcription, Folder, Tag, SidebarSelection) was required because the executable target (`WhisperNotesApp`) imports `WhisperNotesLib` and the menu commands need access to `selectedTranscription`, `sidebarSelection`, `folders`

---

## CLAUDE.md Updates

- [x] `CLAUDE.md` - Add keyboard shortcuts reference table
- [x] `CLAUDE.md` - Document drag-and-drop pattern and uncategorizedFolderID constant
