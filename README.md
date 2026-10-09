# Walang Signal — local-first disaster-aid demo

Walang Signal is an Android demo for testing four local-first components: **LLM chat, offline RAG, Filipino speech, and nearby aid lookup**. Chat combines the LLM and RAG tests; Speech and Nearby are separate tabs.

This is not an official emergency service. It does not fetch current weather alerts, evacuation orders, road conditions, or facility availability. Do not rely on its guidance or map extract as a substitute for local responders or health professionals.

## Core features and implementation

### 1. Local LLM and image input

- Uses Gemma 4 E2B Instruct (`.litertlm`) through `flutter_edge_ai` and the LiteRT-LM engine (`flutter_edge_ai_litertlm`).
- The model is downloaded into this app's private storage and runs on-device after installation. It does not reuse EdgeGallery's private model files.
- The Chat tab supports text and image prompts. Image input is a general multimodal test only; **photo injury triage or risk assessment is not implemented**.
- The system instruction limits the demo to immediate flood danger and basic floodwater/wound safety, and tells the model not to invent live conditions or facility status.

### 2. Offline RAG for health and floodwater questions

- Uses EmbeddingGemma with `flutter_edge_ai_embeddings`, `flutter_edge_ai_rag`, and the SQLite vector-store provider `flutter_edge_ai_sqlite`.
- Bundles three Markdown sources: `assets/pagasa_floods_citizen.md`, `assets/who_flood_safety_rag.md`, and `assets/cdc_emergency_wound_care_rag.md`.
- The Markdown chunker reads YAML front matter for provenance, splits at heading boundaries, preserves the heading path, and uses a 160-word maximum with 24-word overlap. Retrieval-cue and suggested-answer-policy sections are not embedded as evidence.
- Semantic retrieval runs for each user query while the index is ready. It supplies up to four passages whose initial similarity score meets the `0.35` threshold. Passage title, section, publisher, and source URL are included in Gemma's prompt; the model is instructed to cite the numbered sources. If no passage meets the threshold, no unrelated context is added.
- The SQLite index is stored on-device. After the model and index are prepared, retrieval works offline. The threshold is a demo starting point and should be evaluated against Filipino and English queries before broader use.

**Hugging Face setup for EmbeddingGemma:** sign in to Hugging Face, accept the Gemma terms on the `litert-community/embeddinggemma-300m` model page, and create a read token. In the Chat tab's RAG card, enter the token when preparing the knowledge base. The app uses it for the gated model/tokenizer download, clears the field afterward, and does not save it in app preferences or source code. The model and generated SQLite index remain in app-private storage.

The sources have important limits: the WHO summary is from the Eastern Mediterranean Region and needs Philippine localization; the CDC wound-care source is U.S. guidance; and the PAGASA file is a static public guide, not a live bulletin. The collection is a demo corpus, not a complete DOH-reviewed clinical knowledge base. Do not use model output for diagnosis or medication decisions.

### 3. Filipino speech-to-text and text-to-speech

- STT uses the on-device Whisper Tiny model through Flutter Edge AI, with Filipino/Tagalog language code `tl`; recording is mono 16 kHz PCM and is transcribed locally.
- TTS uses an installed Filipino voice supplied by Android, accepting `fil` or `tl` locales such as `fil-PH`/`tl-PH`. The Speech tab reports whether the voice is available and marked as network-dependent.
- This is a system-voice test, not a bundled Filipino neural TTS model. Install an offline Filipino voice in Android's speech settings if available.

### 4. Nearby evacuation/health-center lookup

- Uses Geolocator for a device location fix and a bundled Overpass Turbo GeoJSON extract at `assets/export.geojson`.
- Parses mapped hospitals, clinics/doctors, and cautious **shelter candidates**; the local finder filters by selected facility type and radius, computes distances, and sorts nearest first.
- The lookup is offline and coverage is partial (the current extract covers only parts of Metro Manila and nearby areas). The screen displays the extract timestamp and OpenStreetMap attribution. A mapped entry is not confirmation that a facility is open, safe, or operating as an evacuation center; verify locally before travel.

## Architecture

Features are split into app-owned `domain/` contracts, plugin/device `data/` adapters, and injected `presentation/` screens. `main.dart` initializes runtimes and wires adapters; `app/home_tabs.dart` composes the Chat, Speech, and Nearby tabs. Widget tests use fake adapters so component logic can be tested without model downloads, a microphone, or GPS hardware.

The current demo does **not** include queued SOS SMS, an “I'm safe” delivery workflow, live alert feeds, or automated photo triage.

## Build and test on Android

Requirements:

- Android API 30 or newer.
- 64-bit ARM (`arm64-v8a`); the LiteRT-LM Android inference runtime used here does not target x86 emulators.
- 8 GB or more RAM is recommended for Gemma multimodal use.
- Wi-Fi for first-time model downloads and several GB of free storage. Gemma 4 E2B alone is about 2.6 GB; EmbeddingGemma, Whisper, and the SQLite index require additional space.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

Install with `flutter install -d <device-id>` after enabling USB debugging, or copy the APK to the phone. On first use, download Gemma from Chat. To enable RAG, prepare the local knowledge base and provide the Hugging Face read token as described above. In Speech, install Whisper and grant microphone permission; in Nearby, grant location permission and tap **Find nearby aid**. The app's initial model downloads require a connection; chat inference, RAG retrieval, and the bundled facility lookup are local after setup.

