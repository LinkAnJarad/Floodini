# Hyperframes Composition Brief: Floodini

## Objective
Create a short launch-style brag video for Floodini.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 25 seconds

## Source Material
- Project root: the Floodini Flutter project (not a website, so screens are recreated in HTML from the app's code and design tokens)
- Primary files read: README.md, DESIGN.md (pasted), lib/ui/theme.dart, the chat, nearby and send-later screens, assets/images/floodini_mascot.png, the three bundled guide files (for real source titles)
- Product name: Floodini
- Tagline / strongest claim: "Handa kahit offline." / the whole thing keeps working without a signal
- Key UI or visual moment to recreate: the Chat tab with mic, waveform and a cited answer; the Nearby result cards with "Walking directions"; the Send later queue turning from "Waiting for signal" to "Sent"
- Copy that must appear verbatim:
  - Floodini
  - Handa kahit offline.
  - Offline mode · Handa na
  - Kumusta? Nandito si Floodini.
  - Nakikinig… magsalita na
  - Paano gamutin ang sugat at pagdurugo?
  - Queue "I'm safe" · Ligtas ako
  - Not an official emergency service.

## Creative Direction
- Tone preset: app-store
- Creative direction: calm, reassuring emergency companion; Filipino context; no jokes about disasters
- Interpretation: feature cards (name + two short supporting lines), clean slides and wipes around 0.4 s, unhurried holds, nothing loud
- Angle: every other app stops when the signal drops; Floodini is built to start there. The proof is the phone: the "Offline mode · Handa na" chip stays green while the AI answers, finds help and queues a message.
- Hook: cream background, pixel mascot pops in, then "Floodini" and "Handa kahit offline."
- Outro / punchline: "Floodini. Handa kahit offline." with "Built for the Philippines." and "Not an official emergency service."
- Avoid: generic SaaS language; abstract filler; alarm sounds; any claim about live alerts, diagnosis or guaranteed delivery; real names or numbers

## Visual Identity
- Background: cream #F7EED1 (hook, outro); app surface #F7F9FA
- Text: Deep Carbon #12181B; titles Deep Teal #0F4C5C
- Accent: River Blue #168AAD, Floodini Cyan #25C9D5; Safe Green #2E9E6B, Caution Amber #F5A623, SOS Red #D62828 (help request only)
- Display font: Inter 700 (local woff2); Body font: Inter 400/600
- Visual references from the project: pixel mascot (pixelated rendering only), the Material 3 app UI from lib/ui/theme.dart

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract.

1. Hook — 3.5 s — mascot + wordmark + tagline
2. Offline chat, by voice — 7.5 s — mic tap, waveform, Filipino question, cited answer
3. Nearby help — 4.5 s — three cards one by one, tap "Walking directions"
4. Send later — 5.5 s — tap "I'm safe", Waiting for signal, signal returns, Sent
5. Outro — 4 s — mascot, tagline, "Built for the Philippines.", disclaimer

## Audio
- Audio role: warm bed under the voice-over, sparse professional accents
- Audio arc: gentle fade in, ducked under each narration line, relaxed between lines, fades out under the last line
- Music: happy-beats-business-moves-vol-12 (copied to assets/music/bed.mp3)
- Music treatment: volume lane on the bed: 0.30-0.38 between lines, 0.14 under narration, fade-out in the last second
- Music cue guidance: bundled preset (about 110 BPM). Optional locks near 8.74 (answer starts), 13.11 (first Nearby card), 17.02/17.47 (tap on "I'm safe"), 22.93 (outro lines).
- Audio-reactive treatment: skipped (optional, not needed for this tone)
- Audio-coupled moments:
  - Scene 2 — simulated mic tap, then the answer steps arrive on the beat
  - Scene 3 — three cards arrive one by one on the beat grid, then a tap
  - Scene 4 — tap, queue card, chip flips to Sent with a soft chime
- SFX selection guidance: quiet and warm; clicks for taps, a card slide for each result card, one gentle bong for "Sent", soft impact for the mascot and logo
- Exact SFX choice: copied to assets/sfx/ (tap, card-slide, sent, pop); placed after the animation timing was set
- Voice-over: Kokoro af_heart, five English clips in assets/audio/vo-1..5.wav (timed to their scenes)

## Hyperframes Instructions
Domain skills read: hyperframes-core, hyperframes-cli, hyperframes-audio (volume lanes). Requirements as in the brag skill: show real UI, keep text readable, 25 s, run `npx hyperframes check` before render, keep everything local.
