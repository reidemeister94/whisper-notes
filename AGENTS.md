# WhisperNotes

## Principles to always follow

Think critically from first principles; prize simplicity above all. Maximize efficiency, maintainability, and state-of-the-art quality while keeping every requested feature. Say everything in the fewest clear words — cutting useless words, never necessary information. These principles bind every line, claim, gate, skill, phase, and subagent in development-skills; any skipped gate, suppressed test, swallowed warning, or hidden failure is a violation, whatever the intent. On conflict, pick the application least surprising to a critical reader.

0. **Don't pander · be critical.** Challenge assumptions, push back on bad ideas. No flattery openers. User confirmation validates the decision, not the analysis.
1. **Think before coding.** State assumptions explicitly. Ask when unclear. Don't guess, don't hide confusion.
2. **Plan before implementing.** Explore → plan → lock the HOW (edge cases · data shapes · error semantics · contract boundaries · test scope · rollback) → code.
3. **Simplicity by default.** Minimum code that solves the problem. Filters before adding anything: can this be one fewer file / abstraction / config / dependency? · would removing it cause a real failure? A refactor must measurably improve one of: clear · descriptive · efficient · performant · reliable · robust · maintainable.
4. **Surgical changes.** Every changed line traces to the request. No refactoring of adjacent code. No error handling for impossible scenarios. Clean up only your own mess.
5. **All signal, zero noise.** No dead branches, no defensive try/catch on safe paths, no wrapper-for-nothing functions, no unused imports. No filler openers, no trailing summaries when the diff is the answer.
6. **Comments explain WHY, not WHAT.** Non-obvious business logic, hidden constraints, workarounds — yes. Restating what the next line does — no.
7. **TDD: Red → Green → Refactor.** No production code without a failing test first. One test = one cycle. Wrote production code before the test? Delete it. Untestable (UI-heavy / infrastructure / config-only) → closest automated check + documented WHY + manual evidence.
8. **No claim without fresh evidence.** IDENTIFY → RUN → READ → VERIFY → CLAIM. *"I'm confident"* is not a step. Skipping any step = lying, not verifying.
9. **Root cause, not symptoms.** Fix the underlying error, never suppress it. `# type: ignore`, swallowed exceptions, disabled tests, `--no-verify` are admissions the bug is winning.
10. **Document every discovery** (anything you lacked at the start — non-obvious, domain·infrastructure·company·project-specific). WHY → `docs/chronicles/`, HOW → `docs/plans/`; a critical always-read fact → one line in the `AGENTS.md` list; a topic with depth → `.agents/rules/<topic>.md` (same convention), indexed from `AGENTS.md`. Fewest words. Pay investigation costs once.
11. **Slim docs · English · memory ≈ empty.** `AGENTS.md` ≤ 70 lines: principles → *use development-skills* → single fewest-words list of the most critical, non-trivial domain·infra·company·project facts → index to `.agents/rules/`; no section headings. Each rules file: same convention, vertical per topic. English only across all artifacts. Teammates share only the repo — memory is per-machine and invisible to them: project facts live in `AGENTS.md` / `.agents/rules/`, never in memory; machine-specific facts → gitignored `.claude/CLAUDE.md` / `~/.codex/AGENTS.md`; memory stays ≈ empty.
12. **Communicate to be understood.** When communicating with the user, explain concepts in the simplest accurate language that preserves all important information. Lead with the answer, define assumptions, name trade-offs or caveats when they matter, and use concise structure. Do not omit relevant details for brevity; simplify wording, not substance. Speak plainly and clearly — no obscure terms or wording that creates ambiguity or misunderstanding for the user.

Always use the `development-skills` plugin for every task on this project (brainstorming, development, bug fixing, new feature, ...). If the plugin is not available on the user's system, notice it and tell the user to download it.

Native macOS app (Swift/SwiftUI): audio recording + transcription via whisper.cpp. SQLite is the sole source of truth, with one-way Markdown filesystem sync. No external dependencies — only SwiftUI, AVFoundation, SQLite3.

- Build: `swift build` · `swift build -c release` · `./build.sh` (signed .app bundle). Test: `swift test` (96 tests). Lint/format: `make lint` · `make format` (SwiftLint 140-col, SwiftFormat 4-space, 140). `make setup-dev-env` installs hooks.
- Pre-commit hooks (trailing-whitespace, end-of-file-fixer, SwiftLint, SwiftFormat) + commitizen conventional-commit messages run on every commit. Do not `--no-verify`.
- Platform: macOS 14+ (Sonoma), Apple Silicon (arm64), Swift 5.9+.
- Data: DB + audio in `~/Library/Application Support/WhisperNotes/`; Markdown in `~/Documents/Whisper Notes/` (configurable in Settings).
- Testability: library/executable split — `@testable import WhisperNotesLib`; `Database(path:)` and `AppState(db:mdSync:)` accept injection for temp DBs.
- In progress: migrating whisper.cpp → Voxtral streaming STT (voxtral.c C interop). Shipped code still uses `whisper-cli`. See `docs/plans/0001__2026-04-06__implementation_plan__voxtral-realtime-stt.md`.
- Maps & deeper docs: `docs/ATLAS.md` (decisions + plans), `ARCHITECTURE.md` (diagrams, DB schema, component map), `CONTRIBUTING.md`.

## Rules

| Rule | Scope (paths:) | Topic |
|------|----------------|-------|
| `.agents/rules/architecture.md` | `Sources/**`, `Tests/**` | State / DB / markdown-sync / process patterns, key files |
| `.agents/rules/ui-conventions.md` | `Sources/**` | SwiftUI pitfalls, keyboard shortcuts, drag-and-drop |
