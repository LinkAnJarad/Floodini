# Component boundaries and handoff

This app is organized as small feature slices so each can be built and tested before it is composed into the tabbed app.

## Dependency direction

```text
main.dart                 plugin initialization + concrete adapter wiring
app/                      app shell and tab composition
features/<feature>/
  domain/                  app-owned contracts and simple value types
  data/                    plugin/device/network/storage adapters
  presentation/            Flutter screens; depend on domain contracts only
test/<feature>/            widget tests with fake domain adapters
```

Rules for new components:

1. Put the interface the UI needs in `features/<feature>/domain/`.
2. Put package-specific or platform-specific code in `features/<feature>/data/` and implement the domain interface there.
3. Inject the interface into the presentation widget's constructor. Do not import a platform plugin or concrete data adapter into a presentation screen.
4. Test the screen against a fake implementation of the domain interface. Keep real permission, microphone, GPS, model, and file integration as a separate device smoke test.
5. Add a feature tab only in `app/home_tabs.dart`; keep app-wide plugin initialization and concrete adapter construction in `main.dart` / `app/walang_signal_app.dart`.
6. Keep data provenance, permission/error states, and offline behavior visible in the domain result or UI; never hide those policies inside a widget.

## Current component seams

| Feature | Domain contract | Data adapter | Presentation | Test |
|---|---|---|---|---|
| Chat + images | `GemmaChatBackend`, `ChatImagePicker` | LiteRT-LM and image picker | `GemmaChatScreen` | `test/features/chat/gemma_chat_screen_test.dart` |
| Filipino speech test | `SpeechTestBackend`, `FilipinoTtsVoiceStatus` | Whisper, recorder, Android TTS | `SpeechTestScreen` | `test/features/speech/speech_test_screen_test.dart` |
| App composition | `WalangSignalHome` receives feature backends | Constructed in `main.dart` | `app/home_tabs.dart` | `test/app/home_tabs_test.dart` |

## GPS / nearby aid extension point

Add a `features/locations/` slice rather than putting GPS logic in `WalangSignalHome`:

- `domain/location_provider.dart`: permission state and a location fix (coordinates, accuracy, timestamp).
- `domain/aid_facility_repository.dart`: query nearby facilities from a local/offline source.
- `domain/aid_facility.dart`: facility ID, name, type, coordinates, contact/address, source, and last-verified date.
- `data/`: Android location adapter plus an offline repository backed by a bundled data file or local database.
- `presentation/nearby_aid_screen.dart`: permission, no-fix, no-results, stale-data, and result states; render sorted distances without owning GPS or data-source logic.
- `test/features/locations/`: fake the location provider and repository to test permission handling, distance ordering, radius filtering, and unavailable/stale data.

The GPS feature is not a verified aid directory until its source dataset and update cadence are chosen. Keep that provenance in each facility record so a nearest result is not mistaken for a confirmed open shelter or clinic.
