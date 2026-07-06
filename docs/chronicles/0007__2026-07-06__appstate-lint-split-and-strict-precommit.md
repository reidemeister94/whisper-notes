# Fix CI lint failure: split AppState + strict pre-commit

> Chronicle: 0007__2026-07-06__appstate-lint-split-and-strict-precommit.md
> Status: Completed

## Context

CI run 28794834663 (push to `main`) failed at the **Lint** step with two SwiftLint
violations in `Sources/WhisperNotes/AppState.swift`:
- `file_length`: 557 lines (warning threshold 500)
- `type_body_length`: 410 lines (warning threshold 400)

Both are *warnings* per `.swiftlint.yml`, but CI runs `swiftlint lint --strict`, which
promotes every warning to an error — so the push went red while the local commit passed.

**Key references:**
- `Sources/WhisperNotes/AppState.swift` — oversized `@MainActor` state class.
- `.swiftlint.yml` — `file_length.warning: 500`, `type_body_length.warning: 400`.
- `.github/workflows/ci.yml` — Lint step: `swiftlint lint --strict`.
- `.pre-commit-config.yaml` — local SwiftLint hook: `swiftlint lint --quiet --force-exclude` (no `--strict`).

## Objective (The WHY)

Two goals: (1) get CI green now by bringing `AppState.swift` back under the thresholds;
(2) close the gap that let this reach CI at all — the local pre-commit hook was *less*
strict than CI, so a warning-level violation could be committed and pushed without any
local signal. Making the local hook match CI (`--strict`) means this class of failure is
caught at commit time, before push.

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| State | `Sources/WhisperNotes/AppState.swift` | Recording/transcription/Voxtral methods moved out; `voxtralService` widened `private`→internal |
| State | `Sources/WhisperNotes/AppState+Transcription.swift` (new) | `extension AppState` holding the moved flow |
| Tooling | `.pre-commit-config.yaml` | Add `--strict` to the SwiftLint hook |

## Discoveries & Insights

- **2026-07-06**: SwiftLint counts each type/extension declaration's body length
  separately — moving methods into `extension AppState` (even in the same file) removes
  them from the primary type's `type_body_length`; a new file also removes them from
  `file_length`. This is the idiomatic way to satisfy both rules without deleting code.
- **2026-07-06**: Local pre-commit hook only lints *changed* files, but `file_length` /
  `type_body_length` violations always live in a changed file (you can't grow a file
  without editing it), so `--strict` locally reliably catches this class. Gap remaining:
  a config threshold change could make an untouched file violate — only CI's full-repo
  lint catches that. Acceptable.
- **2026-07-06**: Once lint passed, CI's **Build** step ran for the first time in a while
  and revealed a latent break: `Sources/Cvoxtral/voxtral_metal.m` used `MTLCompileOptions.mathMode`
  / `MTLMathModeFast` — macOS 15 SDK symbols (they replaced the deprecated `fastMathEnabled`).
  CI's `macos-14` runner SDK lacks them → hard compile error, while local builds passed
  because (a) the dev SDK is newer and (b) the Cvoxtral target was cached and not recompiled.
  Fixed with a compile-time SDK guard (`__MAC_OS_X_VERSION_MAX_ALLOWED >= 150000`) plus a
  runtime `@available(macOS 15.0, *)` so the deployment target (`.macOS(.v14)`) stays honored.
  Lesson: prior CI reds died at Lint before Build, masking this — a green Lint can uncover
  the next latent gate.

---

## CLAUDE.md Updates

### Updates to apply:

- [x] `.agents/rules/architecture.md` — Key-files map now points the recording/transcription/Voxtral
      flow at `AppState+Transcription.swift` and notes the SwiftLint `--strict` thresholds (500 lines / 400 type-body).
