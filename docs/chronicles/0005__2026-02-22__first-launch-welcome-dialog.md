# First-Launch Welcome Dialog (Apple-Style)

> Chronicle: 0005__2026-02-22__first-launch-welcome-dialog.md
> Status: Completed

## Context

The app currently shows a `LanguageSetupView` sheet on first launch (gated by `hasCompletedSetup` in UserDefaults). This view has a "Welcome to WhisperNotes" header but immediately asks the user to pick a transcription language — no introduction to what the app does or how to use it.

The user wants an Apple-style welcome dialog (like Freeform, Keynote, Pages on first launch) that introduces the app's key features before proceeding to language selection.

**Key references:**
- `Sources/WhisperNotes/LanguageSetupView.swift` - Current first-launch sheet, will embed welcome as page 1
- `Sources/WhisperNotesApp/WhisperNotesApp.swift` - Shows the sheet when `!hasCompletedSetup`
- `Sources/WhisperNotes/AppState.swift` - `hasCompletedSetup` flag and `completeSetup()` method

## Objective (The WHY)

First impressions matter. When a user opens WhisperNotes for the first time, they should immediately understand what the app does and its key capabilities — record & transcribe, organize with folders/tags, auto-sync to Markdown, keyboard shortcuts. This matches the polished onboarding experience Apple provides in its own apps and sets user expectations before diving into configuration (language selection).

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| New view | `Sources/WhisperNotes/WelcomeView.swift` | New file — Apple-style welcome dialog with feature rows |
| Onboarding flow | `Sources/WhisperNotes/LanguageSetupView.swift` | Modified to embed WelcomeView as first page before language selection |

## Discoveries & Insights

- **2026-02-22**: The existing `LanguageSetupView` already contains the "Welcome to WhisperNotes" header and is the sole onboarding entry point. Embedding the welcome page inside it (as a two-step flow) avoids any changes to `WhisperNotesApp.swift` or `AppState.swift`, and prevents sheet-swapping jankiness.
- **2026-02-22**: Apple's native welcome dialogs use a consistent pattern: large icon, title, 3-4 feature rows (SF Symbol + title + description), and a single CTA button. No external dependencies needed — achievable with pure SwiftUI.
- **2026-02-22**: Staff review identified that SwiftUI transitions inside a bare `if/else` at the body root need a `ZStack` + `.clipped()` container to prevent visual artifacts during the slide animation. Also added accessibility annotations (`.accessibilityHidden(true)` on decorative icons, `.accessibilityHint` on Continue button) and `.keyboardShortcut(.defaultAction)` on both primary buttons for standard macOS Return-to-proceed behavior.

---

## CLAUDE.md Updates

### Updates to apply:

- [x] `CLAUDE.md` - Add `WelcomeView.swift` to Key Files table with role description
