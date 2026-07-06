# Implementation Plan: Replace whisper.cpp with Voxtral Mini 4B Realtime via voxtral.c

## WORKFLOW STATE
Status: In Progress
Current Phase: 3 (Chronicle)
Phases remaining: 3, 4, 5, 6, 7
**Sections:** WORKFLOW STATE | Brainstorming Summary | Approach Decision | Detailed Analysis | Implementation Steps
Research: docs/plans/0001__research.md
Chronicle: TBD -- decided in Phase 3
Verification: TBD

## Brainstorming Summary

**Task:** Replace WhisperNotes' batch whisper.cpp transcription with real-time streaming STT using Voxtral Mini 4B Realtime, so words appear while the user speaks.

**Understanding:**
- **WHAT:** (1) Replace whisper-cli subprocess with voxtral.c C library integrated via SPM, (2) Switch from batch post-recording transcription to real-time streaming during recording, (3) Update RecordingView to show live transcription text, (4) Update settings to configure voxtral model path and delay
- **WHY:** Current flow (record -> stop -> wait for transcription) is slow and non-interactive. User wants words appearing as they speak, with highest quality Italian transcription. Voxtral Mini 4B achieves 3.27% WER on Italian at 480ms delay -- better than whisper.cpp large-v3 for real-time use.

**Approaches considered:**
1. **voxtral.c direct C integration** -- Wrap antirez's pure C implementation as SPM target, call streaming API from Swift | Complexity: HIGH | Risk: Metal shader compilation in SPM; voxtral.c API stability (actively developed)
2. **Python voxmlx + WebSocket** -- Run voxmlx as local WebSocket server, Swift connects via URLSessionWebSocketTask | Complexity: MEDIUM | Risk: User must manage Python server; adds Python dependency; fragile IPC

**Recommended: voxtral.c direct C integration**
This approach eliminates all Python dependencies, keeps the app self-contained, and provides the lowest-latency path (in-process, no IPC). voxtral.c already has Metal GPU backend for Apple Silicon, memory-mapped weights for fast loading, and a clean streaming C API (`vox_stream_t`). The 16kHz sample rate matches the existing AudioRecorder. The main risk is SPM integration of the C sources (especially Metal shaders), but this is a one-time setup cost.

**Evaluation verdict:** PROCEED WITH CHANGES
The direction is correct. Changes needed: (1) voxtral.c Metal shaders may need to be pre-compiled as a metallib rather than compiled at build time via SPM -- verify during implementation, (2) Model download/management needs a solution (8.9GB safetensors) -- consider a first-run download helper or manual instruction, (3) Language list must be reduced from 30 to 13 supported languages.

**Complexity:** HIGH | **Risk:** SPM Metal shader integration; model distribution (8.9GB); voxtral.c API stability

**Key risks identified:**
- voxtral.c Metal shader compilation may not work through SPM's C target -- may need xcframework or pre-compiled metallib
- Model weights are 8.9GB -- need download/management strategy (not bundled in app)
- voxtral.c is actively developed by antirez -- API may change; need to pin a specific commit
- Language support drops from 30 to 13 -- existing users with unsupported language selections need migration
- AVAudioEngine tap + voxtral.c streaming on same thread could cause audio glitches if inference is slow

## Approach Decision

**Selected:** voxtral.c direct C integration
**User modifications:** None
**Confirmed:** 2026-04-06

## Detailed Analysis

### Critical Evaluation (Complexity Score: 9/10)

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Reversibility | 2 | Replacing core transcription engine + streaming architecture |
| Blast radius | 2 | 7+ files modified, fundamentally changes recording flow |
| Ambiguity | 2 | Multiple valid approaches with different tradeoffs |
| Novelty | 2 | First C interop, first streaming STT in this codebase |
| Stakes | 1 | User-facing but not security/data integrity |

### RISK 1: Metal Shader Integration via SPM
- **What:** voxtral.c uses Metal compute shaders for GPU acceleration on Apple Silicon. SPM C targets can compile .c files but Metal shader compilation (.metal -> .metallib) requires the Metal compiler toolchain.
- **Why it matters:** Without GPU acceleration, inference would fall back to CPU-only, which may not achieve real-time performance.
- **Mitigation:** (a) Pre-compile metallib and include as resource, (b) Use xcframework approach, (c) Build voxtral.c as a static library via build.sh and link it
- **Severity:** HIGH

### RISK 2: Model Distribution
- **What:** Voxtral Mini 4B bf16 weights are ~8.9GB safetensors files. Cannot bundle in app.
- **Why it matters:** User must download model before app works. Poor first-run experience.
- **Mitigation:** Settings page with model directory browser (similar to current whisper-cli path). Add download instructions or a download helper that fetches from HuggingFace. Consider 4-bit quantized variant (~2.5GB) as default.
- **Severity:** MEDIUM

### RISK 3: voxtral.c API Stability
- **What:** voxtral.c is a recent project by antirez, actively evolving. API may change.
- **Why it matters:** Breaking changes in voxtral.c could break WhisperNotes builds.
- **Mitigation:** Pin to a specific git commit/tag. Wrap voxtral.c API in a thin Swift protocol so the interface is stable even if implementation changes.
- **Severity:** MEDIUM

### RISK 4: Audio Thread Safety
- **What:** AVAudioEngine tap callback runs on a real-time audio thread. Calling `vox_stream_feed()` from this thread could block if inference is slow.
- **Why it matters:** Audio dropouts, glitches, or buffer overruns.
- **Mitigation:** Feed audio samples into a lock-free ring buffer from the audio thread. Process the ring buffer on a dedicated background thread that calls `vox_stream_feed()`.
- **Severity:** HIGH

### Hidden Assumptions
- "voxtral.c compiles cleanly as part of an SPM package" -- may not hold due to Metal shaders, platform-specific code, or build flags
- "M4 Pro can run Voxtral bf16 in real-time" -- likely true (31.6ms/step on M3 Max, M4 Pro should be faster) but not verified
- "Auto-detect language works in voxtral.c" -- needs verification; Voxtral may require explicit language setting

### Italian Language Quality
Voxtral Mini 4B Realtime Italian benchmarks (FLEURS):
- 480ms delay: 3.27% WER (recommended balance)
- 960ms delay: 2.46% WER
- 2400ms delay: 2.37% WER (near-offline quality)
- Offline (Voxtral Transcribe 2.0): 2.17% WER

For comparison, whisper-large-v3-turbo typically achieves ~4-6% WER on Italian. Voxtral is strictly better.

## Implementation Steps

### Phase 1: voxtral.c SPM Integration (HIGH RISK -- do first)

1. **Clone voxtral.c** at a pinned commit into the project (as git submodule or vendored sources)
2. **Create SPM C target** `Cvoxtral` with voxtral.c sources
   - Files: `voxtral.c`, `voxtral.h`, `voxtral_audio.h`, Metal shaders
   - Handle Metal shader compilation (likely needs pre-compiled metallib)
   - Add necessary compiler flags (e.g., `-DUSE_METAL`)
3. **Update Package.swift**: Add `Cvoxtral` target, add dependency from `WhisperNotesLib` to `Cvoxtral`
4. **Verify**: `swift build` succeeds with voxtral.c linked

### Phase 2: VoxtralService (Swift Wrapper)

5. **Create `VoxtralService.swift`** -- Swift wrapper around voxtral.c C API
   - `init(modelDir: String, delayMs: Int)`
   - `func startStreaming() -> AsyncStream<String>` -- yields tokens as they arrive
   - `func feedAudio(_ samples: UnsafePointer<Float>, count: Int)` -- feeds PCM samples
   - `func finishStreaming() -> String` -- flush remaining tokens, return full text
   - `func transcribeFile(_ url: URL) -> String` -- batch mode for re-transcription
6. **Create `VoxtralError` enum** mirroring `WhisperError` pattern
7. **Add ring buffer** for thread-safe audio transfer from audio thread to processing thread

### Phase 3: AudioRecorder Refactor

8. **Refactor `AudioRecorder.swift`**: Switch from AVAudioRecorder to AVAudioEngine
   - Install tap on inputNode at 16kHz mono float32
   - Expose audio buffer callback for real-time streaming
   - Simultaneously write to WAV file for permanent storage (use AVAudioFile)
   - Keep existing permission handling, timer, elapsed time

### Phase 4: Recording Flow Integration

9. **Update `AppState.swift`**:
   - Replace `whisperPath`/`modelPath` with `voxtralModelDir: String` and `voxtralDelay: Int`
   - Add `@Published var streamingText: String = ""` for live transcription display
   - Refactor `recordAndTranscribe()` to start streaming transcription when recording begins
   - Keep `isTranscribing` for backward compat but it now means "recording + transcribing"
10. **Update `RecordingView.swift`**:
    - Add live transcription text area below recording controls
    - Show streaming text updating in real-time
    - Remove "Transcribing..." spinner (transcription happens during recording)
    - Add visual indicator that transcription is active (e.g., waveform + text)

### Phase 5: Settings & Configuration

11. **Update `SettingsView.swift`**:
    - Replace whisper-cli/model path with voxtral model directory browser
    - Add transcription delay slider (80-2400ms, default 480ms)
    - Add model directory existence check
    - Remove whisper-cli status indicators
12. **Update `Models.swift`**:
    - Reduce `SupportedLanguage.all` to Voxtral's 13 supported languages
    - Handle migration for users with unsupported language selections (fall back to auto/English)

### Phase 6: Cleanup & Testing

13. **Remove `WhisperService.swift`** (replaced by VoxtralService)
14. **Update UserDefaults keys**: Migrate whisperPath/modelPath to voxtralModelDir
15. **Update tests**: Replace WhisperService tests with VoxtralService tests
16. **Update CLAUDE.md**: Document new architecture, model requirements, build changes

### Files to Modify

| File | Change |
|------|--------|
| `Package.swift` | Add Cvoxtral target, link from WhisperNotesLib |
| `Sources/WhisperNotes/WhisperService.swift` | DELETE (replaced by VoxtralService) |
| NEW `Sources/WhisperNotes/VoxtralService.swift` | Swift wrapper for voxtral.c streaming API |
| `Sources/WhisperNotes/AudioRecorder.swift` | AVAudioRecorder -> AVAudioEngine with tap |
| `Sources/WhisperNotes/RecordingView.swift` | Add live transcription text display |
| `Sources/WhisperNotes/AppState.swift` | New settings, streaming text, refactored recording flow |
| `Sources/WhisperNotes/SettingsView.swift` | Voxtral model dir, delay config |
| `Sources/WhisperNotes/Models.swift` | Reduce language list to 13 |
| `Sources/WhisperNotes/LanguageSetupView.swift` | Update for reduced language list |
| `build.sh` | Include Cvoxtral in build, handle Metal shaders |
