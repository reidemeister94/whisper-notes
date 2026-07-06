# Research: Replace whisper.cpp with Voxtral Mini 4B Realtime for Streaming STT

Related plan: 0001__2026-04-06__implementation_plan__voxtral-realtime-stt.md

## Selected Approach

**Recommended:** voxtral.c direct C integration via SPM
**Why:** Eliminates Python dependency entirely. voxtral.c (by antirez) is a zero-dependency pure C implementation of Voxtral Mini 4B Realtime with Metal GPU backend, streaming API (`vox_stream_t`), and memory-mapped weights. Swift has native C interop -- no bridge layer needed. This matches WhisperNotes' "no external dependencies" philosophy.
**Key implementation guidance:**
- Wrap voxtral.c as an SPM `.target` (C sources) or `.systemLibrary` with a module map
- Use `vox_stream_init()` / `vox_stream_feed()` / `vox_stream_get()` for real-time token streaming
- AudioRecorder must be refactored from AVAudioRecorder (file-based) to AVAudioEngine (tap-based) for real-time PCM buffer access
- Model weights (~8.9GB bf16) are memory-mapped from safetensors, loading is near-instant
- On M4 Pro with 48GB RAM, fp16/bf16 model fits comfortably (model needs ~8.9GB)
**Anti-patterns to avoid:**
- Do NOT embed Python interpreter -- adds ~100MB to binary, version management nightmare, breaks "no external dependencies" principle
- Do NOT use subprocess + WebSocket (Python voxmlx server) -- adds operational complexity (user must start/manage Python server), fragile IPC, defeats the purpose of a native app
- Do NOT use mlx-audio Python package directly -- requires Python runtime on user's machine

## Web Research

### Voxtral Mini 4B Realtime Model Specifications
**Query:** "mlx-community Voxtral-Mini-4B-Realtime-2602-fp16 HuggingFace streaming"
**Queried:** 2026-04-06
**Key findings:**
- 4B parameter model: ~970M audio encoder + ~3.4B LLM decoder -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
- Italian WER: 3.27% at 480ms delay, 2.37% at 2400ms on FLEURS -- excellent for Italian -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
- Configurable delay: 80ms to 2400ms (multiples of 80ms), recommended 480ms -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
- Throughput: >12.5 tokens/second -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
- 13 languages supported: ar, de, en, es, fr, hi, it, nl, pt, zh, ja, ko, ru -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
- Apache 2.0 license -- Source: [HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)
**Relevance:** Validates model quality for Italian; 3.27% WER at 480ms is excellent. M4 Pro 48GB can handle fp16 easily.

### voxtral.c -- Pure C Implementation
**Query:** "voxtral.c antirez API voxtral.h streaming C API"
**Queried:** 2026-04-06
**Key findings:**
- Zero external dependencies, only C standard library + platform acceleration (Metal/MPS on macOS) -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- Memory-mapped bf16 weights from safetensors, near-instant loading -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- Streaming API: `vox_stream_init()`, `vox_stream_feed(samples, n_samples)`, `vox_stream_get(out_tokens, max)`, `vox_stream_free()` -- Source: [GitHub voxtral.h](https://github.com/antirez/voxtral.c/blob/main/voxtral.h)
- Live microphone support on macOS via AudioQueue Services -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- ~31.6ms/step on M3 Max for 60s audio; M4 Pro should be faster -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- `vox_set_delay()` controls latency/accuracy tradeoff -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- Configurable processing interval via `vox_set_processing_interval()` -- Source: [GitHub](https://github.com/antirez/voxtral.c)
- Continuous mode via `vox_stream_set_continuous()` -- Source: [GitHub](https://github.com/antirez/voxtral.c)
**Relevance:** This is the critical finding. A clean C API with streaming support that Swift can call natively. No Python needed.

### localvoxtral -- Reference macOS App
**Query:** "localvoxtral macOS app Voxtral Mini 4B real-time transcription"
**Queried:** 2026-04-06
**Key findings:**
- Native macOS menu bar app using WebSocket to connect to voxmlx Python backend -- Source: [GitHub](https://github.com/T0mSIlver/localvoxtral)
- Architecture: Swift app -> WebSocket -> Python voxmlx server (OpenAI Realtime API protocol) -- Source: [GitHub](https://github.com/T0mSIlver/localvoxtral)
- Requires user to run separate Python server process -- operational complexity -- Source: [GitHub](https://github.com/T0mSIlver/localvoxtral)
**Relevance:** Validates the WebSocket approach works but highlights its downsides (separate server process, Python dependency). We can do better with voxtral.c.

### mlx-audio Python Package
**Query:** "mlx-audio Voxtral Mini 4B Realtime speech to text Python"
**Queried:** 2026-04-06
**Key findings:**
- Python library for STT/TTS on Apple Silicon via MLX framework -- Source: [GitHub](https://github.com/Blaizzy/mlx-audio)
- Supports streaming: `model.stream_transcribe(audio="file.wav")` -- Source: [GitHub](https://github.com/Blaizzy/mlx-audio)
- No built-in live microphone capture; file/buffer based -- Source: [GitHub](https://github.com/Blaizzy/mlx-audio)
- Requires Python runtime and pip dependencies -- Source: [PyPI](https://pypi.org/project/mlx-audio/)
**Relevance:** Confirms mlx-audio requires Python runtime. Not suitable for a native Swift app without a bridging layer.

### Swift-Python Interop Patterns
**Query:** "Swift Python interop macOS app 2025 subprocess vs embedded"
**Queried:** 2026-04-06
**Key findings:**
- Embedding Python adds ~100MB to binary -- Source: [DEV Community](https://dev.to/eldare/embedding-python-interpreter-inside-a-macos-app-and-publish-to-the-app-store-successfully-4bop)
- PythonKit exists but is fragile for complex use cases -- Source: [Swift Forums](https://forums.swift.org/t/python-interop-with-pythonkit/28386)
- Swift 6.2 Subprocess package is modern replacement for Foundation Process -- Source: [Michael Tsai](https://mjtsai.com/blog/2025/10/30/swift-6-2-subprocess/)
- Cannot rely on system Python version -- must bundle -- Source: [DEV Community](https://dev.to/eldare/embedding-python-interpreter-inside-a-macos-app-and-publish-to-the-app-store-successfully-4bop)
**Relevance:** Python embedding is heavyweight and fragile. Subprocess requires managing a separate process. Both are inferior to direct C interop.

### Swift C Library Interop via SPM
**Query:** "Swift C library interop SPM systemLibrary clang module map macOS 2025"
**Queried:** 2026-04-06
**Key findings:**
- SPM supports `.target` for C sources with auto-generated module maps -- Source: [Swift.org](https://www.swift.org/documentation/articles/wrapping-c-cpp-library-in-swift.html)
- Convention: prefix C wrapper targets with "C" (e.g., "Cvoxtral") -- Source: [rderik.com](https://rderik.com/blog/making-a-c-library-available-in-swift-using-the-swift-package/)
- Place headers in `include/` directory for automatic module map generation -- Source: [The.Swift.Dev](https://theswiftdev.com/how-to-use-c-libraries-in-swift/)
- Metal shaders can be compiled and linked as part of SPM target -- Source: [Swift Forums](https://forums.swift.org/t/c-c-interop-improvements-with-swiftpm-for-libraries/76821)
**Relevance:** Directly applicable. voxtral.c sources can be wrapped as an SPM C target.

## Codebase Analysis

### WhisperService (Current Transcription Engine)
**Files examined:** `Sources/WhisperNotes/WhisperService.swift`
**Execution flow:** `AppState.recordAndTranscribe()` -> creates `WhisperService` -> `service.transcribe(audioURL:)` -> spawns Foundation `Process` running whisper-cli -> reads stdout -> returns text
**Patterns found:**
- Batch-only: records full audio to file, then transcribes after recording stops
- Configurable language (passed as `-l` flag)
- Configurable timeout (default 300s)
- Error handling: `WhisperError` enum with `.cliNotFound`, `.modelNotFound`, `.processFailed`
- Returns cleaned text (strips timestamps, joins lines)
**Implications for implementation:** WhisperService must be replaced with a new VoxtralService that supports both streaming (real-time during recording) and batch (file transcription) modes. The error enum pattern should be preserved.

### AudioRecorder (Audio Capture)
**Files examined:** `Sources/WhisperNotes/AudioRecorder.swift`
**Execution flow:** `RecordingView` owns `AudioRecorder` -> `startRecording()` -> AVAudioRecorder writes 16kHz mono PCM WAV to temp file -> `stopRecording()` returns file URL
**Patterns found:**
- Uses AVAudioRecorder (file-based, not buffer-based)
- Records at 16kHz, mono, 16-bit PCM -- matches Voxtral's expected input (VOX_SAMPLE_RATE=16000)
- Timer updates elapsed time at 0.1s intervals
- Permission handling for microphone access
**Implications for implementation:** Must switch from AVAudioRecorder to AVAudioEngine with an audio tap to get real-time PCM buffers. The 16kHz sample rate is already correct. Must still save to file for permanent storage while simultaneously streaming to voxtral.c.

### RecordingView (UI)
**Files examined:** `Sources/WhisperNotes/RecordingView.swift`
**Patterns found:**
- Two states: recording controls vs transcribing spinner
- After stop: calls `state.recordAndTranscribe()` which is async batch
- No live transcription display
**Implications for implementation:** Needs a third state: "recording + live transcription". Must show streaming text while recording. The "transcribing" spinner state may become unnecessary (transcription happens during recording).

### AppState (State Management)
**Files examined:** `Sources/WhisperNotes/AppState.swift`
**Patterns found:**
- `isTranscribing` flag drives UI state
- `recordAndTranscribe()` is the integration point: handles audio file storage, calls WhisperService, creates transcription, handles errors
- Settings: `whisperPath`, `modelPath` stored in UserDefaults
- `language` setting passed to WhisperService
**Implications for implementation:** `whisperPath`/`modelPath` become `voxtralModelDir` (path to safetensors directory). Need new published property for streaming transcription text. `recordAndTranscribe()` flow changes fundamentally.

### SettingsView
**Files examined:** `Sources/WhisperNotes/SettingsView.swift`
**Patterns found:**
- Settings for whisper-cli path and model path with file existence checks
- Browse buttons for file selection
**Implications for implementation:** Replace whisper-cli/model path settings with voxtral model directory path. Add delay configuration (80-2400ms).

### Models
**Files examined:** `Sources/WhisperNotes/Models.swift`
**Patterns found:**
- 30 languages in `SupportedLanguage.all` including auto-detect
- Voxtral only supports 13 languages
**Implications for implementation:** Must reduce `SupportedLanguage.all` to Voxtral's 13 supported languages, or keep the full list but mark unsupported ones. Auto-detect behavior needs investigation (Voxtral may not support it the same way).

### Package.swift
**Files examined:** `Package.swift`
**Patterns found:**
- Swift 5.9, macOS 14+
- No external dependencies
- Single library target + executable target + test target
- Links sqlite3 system library
**Implications for implementation:** Add Cvoxtral target wrapping voxtral.c sources. Add dependency from WhisperNotesLib on Cvoxtral. Metal shader compilation needs to be handled.

## Reusable Patterns

### voxtral.c Streaming Pattern
**Where found:** [GitHub voxtral.h](https://github.com/antirez/voxtral.c/blob/main/voxtral.h)
**What it does:** Feed audio incrementally, get tokens as they're ready
**Code:**
```c
vox_ctx_t *ctx = vox_load("/path/to/model");
vox_set_delay(ctx, 480); // ms
vox_stream_t *s = vox_stream_init(ctx);
// In audio callback:
vox_stream_feed(s, float_samples, n_samples);
// In processing loop:
const char *tokens[64];
int n = vox_stream_get(s, tokens, 64);
for (int i = 0; i < n; i++) printf("%s", tokens[i]);
// When done:
vox_stream_finish(s);
vox_stream_free(s);
vox_free(ctx);
```

### AVAudioEngine Tap Pattern (for real-time PCM)
**Where found:** Apple Developer Documentation
**What it does:** Captures audio buffers in real-time for processing
**Code:**
```swift
let engine = AVAudioEngine()
let input = engine.inputNode
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
    // buffer.floatChannelData![0] contains Float samples
    // Feed to vox_stream_feed()
}
try engine.start()
```

## Sources

| # | Source | URL | Trust Tier |
|---|--------|-----|------------|
| 1 | HuggingFace - Voxtral Mini 4B Realtime | https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602 | 1 |
| 2 | GitHub - antirez/voxtral.c | https://github.com/antirez/voxtral.c | 2 |
| 3 | GitHub - T0mSIlver/localvoxtral | https://github.com/T0mSIlver/localvoxtral | 3 |
| 4 | GitHub - Blaizzy/mlx-audio | https://github.com/Blaizzy/mlx-audio | 3 |
| 5 | GitHub - awni/voxmlx | https://github.com/awni/voxmlx | 3 |
| 6 | Swift.org - Wrapping C/C++ Library | https://www.swift.org/documentation/articles/wrapping-c-cpp-library-in-swift.html | 1 |
| 7 | Mistral AI - Voxtral Blog | https://mistral.ai/news/voxtral-transcribe-2 | 1 |
| 8 | DEV Community - Embedding Python in macOS | https://dev.to/eldare/embedding-python-interpreter-inside-a-macos-app-and-publish-to-the-app-store-successfully-4bop | 4 |

## Rejected Alternatives (reference only)

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Python subprocess + WebSocket (voxmlx server) | Proven pattern (localvoxtral), OpenAI Realtime API compatibility | User must manage Python server, fragile IPC, extra process, Python dependency | Breaks "no external dependencies" principle; poor UX requiring server management |
| Embedded Python (PythonKit + mlx-audio) | Direct access to mlx-audio API | +100MB binary, Python version management, fragile bridge, conflicts with "no dependencies" | Too heavyweight; version management nightmare |
| mlx-audio via subprocess (batch) | Simple, similar to current whisper-cli pattern | No streaming (defeats purpose), still requires Python | Doesn't achieve real-time goal |
| Keep whisper.cpp, add streaming separately | Lower risk, incremental | whisper.cpp doesn't support real-time streaming well; Voxtral quality is superior for Italian | Doesn't achieve quality or streaming goals |
