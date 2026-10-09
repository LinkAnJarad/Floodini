# Walang Signal — Gemma 4 E2B smoke test

This is a small on-device text, image, and speech test for `flutter_edge_ai`. It is not yet the disaster-aid app: there is no RAG knowledge base, triage workflow, or SOS flow in this build.

## Component structure

Features use domain contracts, data adapters, and injected presentation screens so they can be developed/tested independently before tab composition. See [`docs/component-boundaries.md`](docs/component-boundaries.md) for the handoff rules and GPS extension point.

## Try it on Android

Android requirements:

- Android API 30 or newer.
- A 64-bit ARM (`arm64-v8a`) phone. LiteRT-LM's Android inference library is available for this ABI only; x86 devices/emulators cannot run this model.
- 8 GB+ RAM is recommended for multimodal inference.
- Wi-Fi and roughly 3 GB of free phone storage for the first model download.

Build the APK:

```sh
flutter pub get
flutter test
flutter build apk --debug --target-platform android-arm64
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

Install it with `flutter install -d <device-id>` (after enabling USB debugging), or copy the APK to the phone. **Chat:** tap **Download model** once; Gemma 4 E2B is about 2.59 GB and stored separately from EdgeGallery. Once installed, text and photo chat run locally. **Speech:** open the Speech tab, install Whisper, then record a short Filipino sample (up to 30 seconds) for on-device transcription using Whisper's `tl` language code. The Filipino TTS test probes the Android system for an installed `fil-PH`/`tl-PH` voice and reports whether Android marks it offline. Flutter Edge AI's published Qwen3-TTS languages do not include Filipino, so this is a device-voice availability test, not a bundled Filipino neural TTS model. Use the photo button in Chat to take or select an image; an image-only prompt defaults to “Describe this image.”

Chat replies are a runtime smoke test, not official emergency guidance. The displayed backend label reports the backend selected by LiteRT-LM when it is available. Microphone capture starts only after tapping **Start recording**; captured audio is processed on-device.

