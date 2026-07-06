# Cohere Transcribe Engine & Recording Smoke Test

> Chronicle: 0006__2026-07-06__cohere-transcribe-engine-and-recording-smoke-test.md
> Status: Completed

## Context

WhisperNotes needed a higher-quality Italian speech-to-text engine while staying usable as an end-user macOS app. A separate prototype existed, but product code could not depend on that project. Users also reported that clicking the recording button did nothing and that the correct engine was not clearly visible in Settings.

## Objective (The WHY)

Add Cohere Transcribe 03-2026 as a self-contained local engine inside WhisperNotes, keep setup guided from the app, and verify the actual app can record audio and produce a Markdown note with the new engine. The app must not reference the standalone `italian-transcriber` project.

## Decisions

| Decision | Rationale |
|----------|-----------|
| Bundle `Resources/CohereBackend/` in `WhisperNotesLib` | Keeps the product self-contained while allowing Python ML dependencies outside the app binary |
| Install Cohere dependencies into App Support | End users run one setup command from Settings; app can then use `~/Library/Application Support/WhisperNotes/CohereBackend/venv/bin/python` |
| Keep engine selection explicit | Settings shows `Whisper`, `Cohere Transcribe 03-2026`, and `Voxtral Realtime 4B` with descriptions |
| Use direct input tap audio capture | The prior mixer-style AVAudioEngine capture could produce silent WAVs; direct input tap + converter records real microphone input |
| Add hidden smoke-test mode | `--cohere-recording-smoke-test` verifies microphone recording, Cohere transcription, database insert, and Markdown output end to end |

## Affected Areas

| Area | Files/Modules | Impact |
|------|---------------|--------|
| Package resources | `Package.swift`, `build.sh` | Bundles and copies `WhisperNotes_WhisperNotesLib.bundle` with Cohere backend scripts |
| Transcription | `CohereService.swift`, `Resources/CohereBackend/` | Runs bundled backend via configured Python executable |
| Settings | `SettingsView.swift`, `AppState.swift`, `Models.swift` | Engine selector, Cohere setup command, engine-specific languages |
| Recording | `AudioRecorder.swift`, `RecordingView.swift` | Direct input tap, stable record hit target, folder commit before recording |
| Verification | `CohereRecordingSmokeTest.swift`, `WhisperNotesApp.swift` | Hidden end-to-end app recording smoke test |

## Discoveries & Insights

- **2026-07-06**: `Bundle.module` resources in an SPM library target are emitted as `WhisperNotes_WhisperNotesLib.bundle`; a hand-built `.app` must copy that bundle into `Contents/Resources`.
- **2026-07-06**: Cohere's backend needs `trust_remote_code=True` and Hugging Face access to `CohereLabs/cohere-transcribe-03-2026`; user setup should surface `hf auth login` / model access errors clearly.
- **2026-07-06**: Cohere language `"auto"` is treated as Italian in the app because this integration is optimized for Italian notes.
- **2026-07-06**: Real app verification passed with `--cohere-recording-smoke-test`: recording started, transcription completed, and a Markdown note was written.
- **2026-07-06**: SwiftUI record-button styling can accidentally shrink the interactive area; the record control should keep tap handling on the full visual target.

## Verification

- `swift test`
- `swift test --filter CohereServiceTests`
- `swiftlint lint` (existing file/type length warnings in `AppState.swift`)
- `./build.sh`
- `WhisperNotes.app/Contents/MacOS/WhisperNotes --cohere-recording-smoke-test`
