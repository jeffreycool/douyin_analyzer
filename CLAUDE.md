# Douyin Analyzer

Douyin video content analyzer — download video, extract audio, ASR transcription, AI summary.

## Quick Commands

```bash
flutter pub get              # Install dependencies
flutter analyze              # Static analysis
flutter test                 # Run tests
flutter build macos          # Build macOS app
flutter run -d macos         # Run in debug mode
```

## Architecture

**Pattern**: Service-based with GetX dependency injection (no Bloc, no Riverpod).

```
Pipeline Flow:
  URL Input → DownloadService → AudioService → AsrService → ClaudeService → Markdown Summary

Service Registration Order (main.dart):
  1. DownloadService  (leaf, no deps)
  2. AudioService     (leaf, no deps)
  3. AsrService       (leaf, no deps)
  4. ClaudeService    (leaf, no deps)
  5. PipelineService  (depends on all above)

All services use Get.put() — NOT Get.lazyPut() — to ensure onInit() fires correctly.
```

## Project Structure

```
lib/
├── main.dart                  # Entry point, service registration, theme
├── core/constants.dart        # Tool paths, whisper model, prompt template
├── models/video_info.dart     # VideoInfo data class, PipelineStatus enum
├── controllers/
│   └── home_controller.dart   # UI state management
├── services/
│   ├── download_service.dart  # HTTP-based Douyin video download (no yt-dlp)
│   ├── audio_service.dart     # FFmpeg: video → WAV (16kHz mono)
│   ├── asr_service.dart       # whisper-cli: audio → text (Chinese)
│   ├── claude_service.dart    # Claude CLI: text → Markdown summary
│   └── pipeline_service.dart  # Orchestrates all stages
└── pages/
    ├── home_page.dart         # Input + progress + history
    ├── result_page.dart       # Markdown summary + export
    └── settings_page.dart     # Tool paths display
```

## External Tool Dependencies

| Tool | Path | Install |
|------|------|---------|
| FFmpeg | `/opt/homebrew/bin/ffmpeg` | `brew install ffmpeg` |
| whisper-cli | `/opt/homebrew/bin/whisper-cli` | `brew install whisper-cpp` |
| Claude CLI | `/Users/jeffrey/.local/bin/claude` | Claude Code Max Plan |

**Whisper model**: `~/.local/share/whisper-models/ggml-base.bin` (base, Chinese)
**Working directory**: `~/.douyin_analyzer/run_{timestamp}/` (auto-cleanup on error)

## Key Design Decisions

- **No yt-dlp**: Douyin extractor broken since 2023. Uses direct HTTP approach instead:
  follow redirect → parse iesdouyin.com JSON → replace "playwm"→"play" for watermark-free URL.
- **Claude via stdin**: Prompt sent through stdin pipe to avoid shell argument length limits.
  Uses `CLAUDECODE=''` env var to prevent nested session detection.
- **macOS sandbox disabled**: Required for Process.run() to call external CLI tools.
  See `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`.

## Coding Conventions

- **State management**: GetX reactive (`.obs`, `Obx()`)
- **Routing**: GetX named routes (`Get.toNamed('/result')`)
- **File naming**: snake_case for all Dart files
- **Theme**: Material 3, seed color `#7B61FF`, light/dark mode, `.AppleSystemUIFont`
- **Error handling**: Each service has its own Exception class (DownloadException, etc.)
  PipelineService catches and wraps all into PipelineException with stage info.

## Known Issues

- Douyin may change iesdouyin.com page structure at any time — check `_ROUTER_DATA`
  and `RENDER_DATA` parsing in `download_service.dart` if downloads break.
- whisper-cli with base model may produce lower accuracy for dialects/accents.
  Upgrade to `ggml-large-v3.bin` for better results (but slower).
