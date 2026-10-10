# Floodini — local-first disaster-aid demo

Floodini is an Android demo for testing four local-first components: **LLM chat, offline RAG, Filipino speech, and nearby aid lookup**. Chat combines the LLM, RAG, and voice; Nearby and Send later are separate tabs.

This is not an official emergency service. It does not fetch current weather alerts, evacuation orders, road conditions, or facility availability. Do not rely on its guidance or map extract as a substitute for local responders or health professionals.

## Core features and implementation

### 1. Local LLM and image input

- Uses Gemma 4 E2B Instruct (`.litertlm`) through `flutter_edge_ai` and the LiteRT-LM engine (`flutter_edge_ai_litertlm`).
- The model is downloaded into this app's private storage and runs on-device after installation. It does not reuse EdgeGallery's private model files.
- The Chat tab supports text and image prompts. Image input is a general multimodal test only; **photo injury triage or risk assessment is not implemented**.
- The system instruction limits the demo to immediate flood danger and basic floodwater/wound safety, and tells the model not to invent live conditions or facility status.

### 2. Offline RAG for health and floodwater questions

- Uses Gecko-110m-en (`Gecko_256_quant.tflite`, Apache-2.0, ungated) with `flutter_edge_ai_embeddings`, `flutter_edge_ai_rag`, and the SQLite vector-store provider `flutter_edge_ai_sqlite`.
- Bundles three Markdown sources: `assets/pagasa_floods_citizen.md`, `assets/who_flood_safety_rag.md`, and `assets/cdc_emergency_wound_care_rag.md`.
- The Markdown chunker reads YAML front matter for provenance, splits at heading boundaries, preserves the heading path, and uses a 160-word maximum with 24-word overlap. Retrieval-cue and suggested-answer-policy sections are not embedded as evidence.
- Semantic retrieval runs for each user query while the index is ready. It supplies up to four passages whose initial similarity score meets the `0.35` threshold. Passage title, section, publisher, and source URL are included in Gemma's prompt; the model is instructed to cite the numbered sources. If no passage meets the threshold, no unrelated context is added.
- The SQLite index is stored on-device. After the model and index are prepared, retrieval works offline. The threshold is a demo starting point and should be evaluated against Filipino and English queries before broader use.

**Embedding model:** Gecko-110m-en is downloaded from Hugging Face without an account or token (about 115 MB plus a 0.8 MB tokenizer). It is English-only, so Filipino questions may retrieve poorly against the English corpus; evaluate before relying on it. The model and generated SQLite index remain in app-private storage.

The sources have important limits: the WHO summary is from the Eastern Mediterranean Region and needs Philippine localization; the CDC wound-care source is U.S. guidance; and the PAGASA file is a static public guide, not a live bulletin. The collection is a demo corpus, not a complete DOH-reviewed clinical knowledge base. Do not use model output for diagnosis or medication decisions.

### 3. Filipino voice in chat (speech-to-text and text-to-speech)

- The Chat composer has a **mic** button (speak one message) and a **hands-free** toggle. Hands-free loops: listen, send, read the reply aloud, listen again, and stops after two silent listens or when toggled off. Recording stops on its own after about 1.5 s of silence (fixed −38 dBFS gate; it may need tuning on noisy phones).
- The system prompt asks the model to answer in the language the user used. Whisper is forced to Filipino (`tl`), so English speech may transcribe poorly.

- STT uses the on-device Whisper Tiny model through Flutter Edge AI, with Filipino/Tagalog language code `tl`; recording is mono 16 kHz PCM and is transcribed locally.
- TTS uses an installed Filipino voice supplied by Android, accepting `fil` or `tl` locales such as `fil-PH`/`tl-PH`. If no Filipino voice is installed, replies are read with the phone's default voice.
- This is a system-voice test, not a bundled Filipino neural TTS model. Install an offline Filipino voice in Android's speech settings if available.

### 4. Nearby evacuation/health-center lookup

- Uses Geolocator for a device location fix and a bundled Overpass Turbo GeoJSON extract at `assets/export.geojson`.
- Parses mapped hospitals, clinics/doctors, and cautious **shelter candidates**; the local finder filters by selected facility type and radius, computes distances, and sorts nearest first.
- Tapping a result opens **walking directions** from your live position in Google Maps (falling back to any app that handles a `geo:` link). Maps needs mobile data unless you saved an offline map area, and it cannot see flooded or closed roads; the screen says so.
- The lookup is offline and coverage is partial (the current extract covers only parts of Metro Manila and nearby areas). The screen displays the extract timestamp and OpenStreetMap attribution. A mapped entry is not confirmation that a facility is open, safe, or operating as an evacuation center; verify locally before travel.

### 5. Onboarding and Send later (queued SMS)

- **Onboarding:** on first launch the welcome screen asks for your name, one or more emergency contacts (name + mobile number, add as many as you like) and a required disclaimer checkbox, then **Get Started** saves them (in app-private preferences) and downloads the models. It reappears only if the profile or a model is missing.
- **Send later tab:** queue an **"I'm safe"** message or a **help request** (with an optional note). Each is texted to every emergency contact **automatically as soon as the phone has cellular service**. The text includes the **last recorded location** as a Google Maps link and the time it was recorded, filled in at the moment of sending, plus when the message was queued so recipients can tell it is delayed. Location is recorded when the tab opens, when you queue a message, and when you tap **Update**.
- **How it sends:** direct SMS through Android's `SmsManager` (needs the **SEND_SMS** permission, requested when you first queue a message; standard SMS rates apply). The queue lives in native code (`SendLaterQueue.kt`) so the app and a WorkManager job (`SendQueueWorker.kt`) share one queue and never double-send. While anything is waiting, the open app retries every ~20 s and WorkManager about once a minute, even with the app closed; Android battery saving (Doze) can delay that. Each recipient is marked sent when the phone confirms the hand-off to the network. That is not proof the recipient received it.
- Messages are plain ASCII to keep SMS parts at 160 characters. Dual-SIM phones use the default SMS SIM. The SMS permission is restricted on Google Play; this is meant for sideloaded builds.

## Design

The UI follows the Floodini Emergency Design System (`DESIGN.md` from Stitch): River Blue / Deep Teal / Floodini Cyan with SOS Red, Caution Amber and Safe Green, light and dark themes (follows the phone's setting), 56 dp touch targets, 16-24 dp rounded cards, and a persistent bottom navigation bar for **Chat**, **Nearby** and **Send later**. The theme and shared widgets live in `lib/ui/` (`theme.dart`, the pixel-art mascot, status chips, the voice waveform).

- The mascot is `assets/images/floodini_mascot.png` and is drawn without smoothing. Do not redraw it.
- The "Offline mode · Handa na" chip appears only inside the app shell, which is reached only after the profile and all models are installed.
- Fonts: the theme asks for **Inter**. Until the Inter font files are added under `assets/fonts/` and declared in `pubspec.yaml`, Android's default font is used.
- Quick topics on the Chat screen cover only what the bundled guides contain (floods and wound care).

## Architecture

Features are split into app-owned `domain/` contracts, plugin/device `data/` adapters, and injected `presentation/` screens. `main.dart` initializes runtimes and wires adapters; `app/home_tabs.dart` composes the Chat and Nearby tabs; `app/setup_gate.dart` shows a welcome screen and downloads the models on first launch. Widget tests use fake adapters so component logic can be tested without model downloads, a microphone, or GPS hardware.

The current demo does **not** include live alert feeds, automated photo triage, or SMS delivery receipts (only hand-off to the network is confirmed).

## Build and test on Android

Requirements:

- Android API 30 or newer.
- 64-bit ARM (`arm64-v8a`); the LiteRT-LM Android inference runtime used here does not target x86 emulators.
- 8 GB or more RAM is recommended for Gemma multimodal use.
- Wi-Fi for first-time model downloads and several GB of free storage. Gemma 4 E2B alone is about 2.6 GB; the Gecko embedder, Whisper, and the SQLite index require additional space.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

Install with `flutter install -d <device-id>` after enabling USB debugging, or copy the APK to the phone. On first launch, tap **Get Started** to download Whisper, the Gecko embedder (and index the guidance), and Gemma. Grant microphone permission when you first use the mic; in Nearby, grant location permission and tap **Find nearby aid**. The app's initial model downloads require a connection; chat inference, RAG retrieval, and the bundled facility lookup are local after setup.

