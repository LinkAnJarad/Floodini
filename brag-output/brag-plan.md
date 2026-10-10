# Brag Plan: Floodini

## What is this app?
Floodini is an offline-first AI emergency companion for flood safety in the Philippines. After a one-time download, its AI runs on the phone: you ask by voice or text in Filipino, English, or Taglish, it answers from safety guides saved on the device, finds nearby hospitals, clinics and shelter candidates with walking directions, and queues "I'm safe" and help messages that text your emergency contacts the moment signal returns.

## The angle
The product is built for the exact moment the internet is gone. The whole video is a calm "app-store" feature tour with one idea underneath it: **every other app stops when the signal drops; Floodini is built to start there.** The visual proof is the pixel-art mascot plus a phone that keeps working: the "Offline mode · Handa na" chip stays green while everything happens. No jokes about disasters. Reassuring, specific, and honest.

Honesty guardrails for every scene and line:
- Say only what the app does: offline chat and voice, saved guides, nearby lookup with directions, queued SMS.
- Do not claim live alerts, current road or flood conditions, medical diagnosis, or guaranteed delivery. Directions come from Google Maps (needs data) and queued messages are "sent" when handed to the network.
- The outro carries "One-time download. Not an official emergency service."
- All names and numbers on screen are fictional (Juan Dela Cruz, Maria Dela Cruz, 0917-XXX-XXXX style placeholders). No real contacts.

## Hook (first 2-3 seconds)
Warm cream background. The pixel-art Floodini mascot pops in, then the wordmark **Floodini** and the tagline **"Handa kahit offline."** sit clean and centered (product name + tagline, the app-store hook). Narration opens on the problem: "When the signal drops, Floodini doesn't."

## Key moments (the middle)
- **Ask by voice, answer from saved guides.** The phone shows the Chat tab. A tap on the 64 dp mic starts the cyan waveform ("Nakikinig… magsalita na"); a Filipino question bubble appears ("Paano gamutin ang sugat at pagdurugo?"), then a numbered answer streams in with the green "Guides saved" chip visible.
- **Nearby aid with walking directions.** Three result cards slide in one by one: a clinic, a "possible shelter" with its amber "confirm before relying on it" note, a hospital, each with a distance pill; the last one is tapped and shows "Walking directions".
- **Send later.** The user taps "Queue "I'm safe" · Ligtas ako". The queue card appears as "Waiting for signal", signal bars come back, and the chip flips to green "Sent".

## Outro / punchline
Back to the cream background and the mascot. Line: **"Floodini. Handa kahit offline."** with a small CTA-style "Built for the Philippines. Available now on Android." — only if the team is happy to say "available"; otherwise "Built for the Philippines." plus the disclaimer line "One-time download. Not an official emergency service."

## User flow worth showing
1. Entry: open Floodini, "Offline mode · Handa na" chip, empty chat with the mascot ("Kumusta? Nandito si Floodini.").
2. Key action: tap the mic, ask in Filipino; then find nearby aid; then queue "I'm safe".
3. Result: a cited step-by-step answer, a walking-directions button, a queue item that turns "Sent".

## Tone
- Preset: app-store
- Creative direction: calm, reassuring emergency companion; Filipino context; no jokes about disasters.
- Interpretation: feature-card structure (feature name, then one supporting line), title-case labels, slide and wipe transitions around 0.4 s, unhurried holds, and restraint: the warmth comes from the mascot and palette, not from jokes or hype.

## Format: landscape — 1920x1080
## Duration: 25 seconds (voice-over inside the window)

## Visual identity (from the project: lib/ui/theme.dart + DESIGN.md)
- Background: cream #F7EED1 (hook and outro); app surface #F7F9FA; cards #FFFFFF
- Accent: River Blue #168AAD (primary), Deep Teal #0F4C5C (header, titles), Floodini Cyan #25C9D5 (voice waveform, glow)
- Text: Deep Carbon #12181B
- Semantic: Safe Green #2E9E6B (status chips), Caution Amber #F5A623 (warnings), SOS Red #D62828 (help request only, never decorative)
- Display font: Inter 700; Body font: Inter 400/600
- Strongest visual element: the pixel-art mascot (`assets/images/floodini_mascot.png`, 172x202 transparent PNG, render with crisp nearest-neighbour scaling, never smoothed or redrawn) and the Android phone frame showing the real Floodini screens.

## Share copy (draft)
Floodini is an offline-first AI emergency companion for floods: ask in Filipino, English or Taglish, get answers from saved safety guides, find nearby help, and queue an "I'm safe" text that sends when signal returns. Handa kahit offline.

## Voiceover script (Kokoro, voice af_heart unless changed; English only)
Fit inside 25 s; the Filipino tagline stays on screen, not spoken. About 50 words.

1. (Scene 1) "When the signal drops, Floodini doesn't."
2. (Scene 2) "An emergency companion that runs entirely on your phone. Ask by voice, in Filipino, English, or Taglish, and it answers from saved safety guides."
3. (Scene 3) "Find nearby help, with walking directions."
4. (Scene 4) "Queue your I'm safe message. It sends the moment signal returns."
5. (Scene 5) "Floodini. Ready, even offline."

Narration complements the visuals and does not read the on-screen text word for word; if the generated audio overruns the window, cut lines and regenerate rather than stretching past 25 s.

## Audio direction
- Role: warm bed under the voice-over, sparse professional accents.
- Music: bundled "Happy Beats / Business Moves vol. 12" (about 110 BPM, steady and light), starting at 0 s.
- Music treatment: fade in over the first 0.5 s; duck to 0.12-0.15 under the narration; return to normal between lines; fade out over the last 1.5 s.
- Music cue guidance: preset read from `assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`. Strong cues in the window: about 8.74 s (the answer starts to stream), 13.11 s (first Nearby card), 17.47 s (the "I'm safe" tap), 22.93 s (the outro logo). Beat grid is about every 0.545 s, which suits sequential card reveals (accents only; keep readable text spaced wider).
- Audio-reactive treatment: subtle; the mascot's glow and the cyan waveform may breathe with music energy. No decorative waveform bars.
- SFX posture: sparse and motion-matched: soft UI taps for the mic, directions and "Queue" buttons; light card slides for the Nearby cards; a gentle chime when the chip turns "Sent".
- Audio-coupled moments: mic tap, the Nearby cards arriving one by one, the "Sent" chip flip.
- Restraint rule: no alarms, sirens, impact hits or anything that sounds like an emergency alert; this video must feel calm.

## Storyboard

### Scene 1 — Hook — 3.5 s
Cream background. The mascot pops in at centre (a soft scale and glow), then "Floodini" and "Handa kahit offline." fade up beneath it, held clean for at least 1.2 s. No phone yet.
Sequential/interaction: none.
Audio intent: warm, welcoming; music fades up; the voice says "When the signal drops, Floodini doesn't."
Audio-coupled idea: a single soft pop when the mascot lands.
Music: warm, light, steady.
Transition mood: clean slide → Scene 2

### Scene 2 — Offline chat, by voice — 7.5 s (0:03.5 to 0:11.0)
Left: feature card "Offline AI Chat" with the line "Ask in Filipino, English, or Taglish." Right: a phone showing the Floodini header with the green "Offline mode · Handa na" chip and the Chat tab. The mic is tapped, the cyan waveform pulses with "Nakikinig… magsalita na", then a user bubble "Paano gamutin ang sugat at pagdurugo?" appears and an answer streams in as numbered steps (1. press with a clean cloth, 2. raise the limb if possible, 3. get urgent help if the wound is deep), with the green "Guides saved" chip and the line "Gabay ito at hindi kapalit ng propesyonal na tulong." under it.
Sequential/interaction: yes — simulated tap on the mic, waveform, then the answer typed in step by step.
Audio intent: calm confidence; the answer arrives on the 8.74 s cue.
Audio-coupled idea: soft tap on the mic; light ticks as the answer types.
Music: steady bed, ducked under the voice.
Transition mood: clean wipe → Scene 3

### Scene 3 — Nearby help — 4.5 s (0:11.0 to 0:15.5)
Feature card "Nearby Aid" with "Walking directions to hospitals, clinics, and shelter candidates." The phone shows the Nearby tab: three result cards slide in one by one (Marikina City Health Center, 1.2 km; a possible evacuation center with the amber "confirm before relying on it" note, 2.4 km; Lung Center of the Philippines, 6.1 km). The first card gets a tap and its "Walking directions" label highlights.
Sequential/interaction: yes — three cards arrive one by one on the beat grid; a simulated tap on the first.
Audio intent: gentle, helpful; first card lands on the 13.11 s cue.
Audio-coupled idea: three soft card slides; one tap.
Music: steady bed, ducked under the voice.
Transition mood: slide → Scene 4

### Scene 4 — Send later — 5.5 s (0:15.5 to 0:21.0)
Feature card "Send Later" with "Queued messages send when signal returns." The phone shows the Send later tab. "Queue "I'm safe" · Ligtas ako" is tapped on the 17.47 s cue; a queue card appears "I'm safe · Waiting for signal" with the amber chip; a signal-bars icon fills in the status area; the chip flips to green "Sent" with "2/2 sent". Contacts shown are fictional (Maria Dela Cruz, Pedro Santos). The red help-request button is visible but not tapped.
Sequential/interaction: yes — simulated tap, queue card appears, chip state change from waiting to sent.
Audio intent: relief; a gentle chime on "Sent".
Audio-coupled idea: tap sound on the button; a soft chime on the chip flip.
Music: steady bed, ducked under the voice, rising slightly after "Sent".
Transition mood: soft crossfade → Scene 5

### Scene 5 — Outro — 4 s (0:21.0 to 0:25.0)
Cream background and the mascot again. "Floodini. Handa kahit offline." appears with the small line "Built for the Philippines." and the disclaimer "One-time download. Not an official emergency service." The logo moment lands on the 22.93 s cue.
Sequential/interaction: none.
Audio intent: warm resolution; music fades out over the last 1.5 s; the voice says "Floodini. Ready, even offline."
Audio-coupled idea: none beyond the cue-aligned logo landing.
Music: warm resolution, fade out.
Transition mood: end card, no outgoing transition.

**Music mood for this video:** upbeat but calm.
**Audio summary:** A warm light bed under a clear English narration, sparse motion-matched UI sounds, and a soft chime when the message is sent; no alarms or impacts.

## Notes for composition
- The app is Flutter, not a website, so the phone screens must be recreated in HTML from the real Floodini screens (layout, copy and colors from `lib/ui/theme.dart`, the chat, nearby and send-later screens, and DESIGN.md). Real phone screenshots would replace these if provided.
- Fonts: Inter (not bundled in the app yet); the composition should load it itself.
- The mascot PNG must be shown with `image-rendering: pixelated`.
