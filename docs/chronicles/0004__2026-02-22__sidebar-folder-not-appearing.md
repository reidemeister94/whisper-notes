# Sidebar Folder Not Appearing After Creation

> Chronicle: 0004__2026-02-22__sidebar-folder-not-appearing.md
> Status: Completed

## Context

User reports that after creating a new note with a new folder (via RecordingView),
the folder does not appear in the left sidebar AND does not appear in Finder.

**Key references:**
- `Sources/WhisperNotes/AppState.swift` - `createFolder()` creates folder, calls `reload()`
- `Sources/WhisperNotes/SidebarView.swift` - `Section` for folders uses `ForEach(state.folders)`
- `Sources/WhisperNotes/RecordingView.swift` - Folder creation during recording setup

## Objective (The WHY)

The sidebar is the primary navigation element. If a newly created folder doesn't
appear, users lose trust in the app and can't organize their transcriptions.
The fix must ensure reliable rendering of folder changes in all scenarios:
first folder creation (empty → non-empty), folder creation while a sheet is
presented, and folder creation from the sidebar itself.

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| Recording flow | `RecordingView.swift` | **ROOT CAUSE**: Commit pending folder creation before recording/transcription |
| State management | `AppState.swift` | `createFolder` returns created Folder for direct ID usage |
| Sidebar UI | `SidebarView.swift` | Add `isExpanded` binding to Folders section |
| Root view | `ContentView.swift` | Add `onDismiss: { state.reload() }` to sheet |
| Tests | `AppStateTests.swift` | Add test for `createFolder` return value |

## Discoveries & Insights

- **2026-02-22 (initial)**: SwiftUI `Section` in macOS sidebar `List` without an `isExpanded:` binding
  delegates disclosure state management to the framework. When section content transitions
  from empty to non-empty (first folder) or when `@Published` data changes while a sheet
  is presented, SwiftUI may fail to re-render the section content. Adding
  `Section(isExpanded:)` (available macOS 14+) gives programmatic control over the
  expanded state, ensuring new folders are always visible.

- **2026-02-22 (initial)**: `RecordingView` looked up the newly created folder by name
  (`state.folders.first { $0.name == newFolderName }?.id`) which is fragile.
  Returning the `Folder` directly from `createFolder` eliminates the lookup entirely.

- **2026-02-22 (ROOT CAUSE)**: The folder name TextField's `.onSubmit` is the **only**
  place `state.createFolder()` was called. If the user types a folder name and clicks
  the record button (without pressing Enter), `.onSubmit` never fires. Result:
  - `createFolder()` never called → folder never inserted in DB
  - `createFolderDir()` never called → folder never created in Finder
  - `selectedFolderId` remains `nil` → transcription created without folder association

  **Fix**: Extract `commitPendingFolderCreation()` and call it when the user clicks
  Start Recording and again as a safety net in `stopAndTranscribe()`. This ensures
  the folder is always created before the transcription, regardless of whether the
  user pressed Enter or just clicked the record button.

- **2026-02-22 (data consistency analysis)**: MarkdownSync is one-way (app → filesystem).
  All filesystem operations use `try?`, silently swallowing errors. Deleting .md files
  or folders in Finder does NOT reflect in the app because there is no filesystem → DB
  sync. This is a known limitation, not a bug — the .md files are an export/backup
  mechanism, not the source of truth. SQLite is the sole source of truth.

---

## CLAUDE.md Updates

### Updates to apply:

- [x] `CLAUDE.md` - Add note: "SwiftUI sidebar `Section` must use `isExpanded:` binding for reliable rendering when data changes dynamically"
- [x] `CLAUDE.md` - Add note: "SwiftUI TextField `.onSubmit` only fires on Enter key press — always commit pending state before actions the user can trigger by clicking buttons"
