# MidiStruct 
### Algorithmic MIDI Composer for REAPER
⭕ SCRIPT IN THE RELEASE ======>>>>>>>>>>>>>
> A full-featured procedural MIDI generation engine written in ReaScript Lua.  
> From a chord progression and a style, generates a complete 3–4 minute arrangement in seconds.

⭕if you're lost on github a direct link  on google drive:
https://drive.google.com/file/d/1-1CLod3uDC64E_h-czeiHEshXBwIWIqG/view?usp=sharing

---

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: REAPER](https://img.shields.io/badge/Platform-REAPER%206%2B-orange.svg)](https://www.reaper.fm)
[![Language: Lua](https://img.shields.io/badge/Language-Lua-blue.svg)](https://www.lua.org)
[![No dependencies](https://img.shields.io/badge/Dependencies-None-green.svg)]()

---

## What It Does

MidiStruct is not an arpeggiator or a random pattern generator.  
It is a **compositional engine** that applies real music theory rules to build a structured song from scratch.

Given a chord progression like `Am:4 F:4 C:4 G:4` and a style (Pop, R&B, Lo-Fi, Rock…), it generates:

- **5 separate, color-coded MIDI tracks** — Drums, Bass, Pad/Chords, Lead Melody, Counter-Melody
- **Named MIDI items per section** on every track
- **Color-coded timeline regions** — Intro, Verse, PreChorus, Chorus 1/2/3, Bridge, Outro
- **Tempo automation** — Bridge slows down, final Chorus pushes forward
- **CC#11 Expression curves** on Pad (exponential swell per chord)
- **CC#1 Modulation** on Melody (vibrato on long notes only)
- **A text report** with seed, key, structure and hook description

Every generation is identified by a **numeric seed** — the same seed always produces the exact same result.

---

## What Makes It Different

Most commercial MIDI generators (Scaler 2, Captain Plugins, UJAM) generate patterns.  
MidiStruct generates **music** — with compositional rules that most plugins don't implement at all.

| Feature |  MidiStruct |
|---------|---------------|
| Global key inference | ✅ Pitch class voting |
| Melodic phrase structure | ✅ A-A'-B-A per 4 bars |
| Hook repetition rule ×3  | ✅ State machine |
| Push & Pull per section | ✅ Chorus push / Verse pull |
| Inter-track Call & Response | ✅ Shared density map |
| Secondary dominants | ✅ 35% insertion probability |
| Walking bass with approach | ✅ Chromatic approach note |
| CC swell (exponential curve) | ✅ 1st-order step response |
| Open/closed hi-hat logic | ✅ Per-style hat_open_steps |
| Ride cymbal (lofi/jazz) | ✅ Ride bell on beats 1 & 3 |
| REAPER color-coded regions | ✅ Per-section with Chorus 1/2/3 |
| Full seed reproducibility | ✅ Custom LCG, 100% deterministic |
And more

Technical Music Specifications
<details>Composition & Harmony

    Automatically inferred tonality

    Coherent global scale throughout the track

    Secondary dominants

    Harmonic extensions (9/11/13) on pads

    Bridge modulation +2 semitones

Arrangement & Structure

    Hook with genre-signature intervals

    3x inter-section repetition

    Intra-phrase repetition (A-A'-B-A2)

    Unique climax with velocity crescendo

    Melodic contour per section

    Stripped-back Intro/Outro

    Inter-track call and response

Instrumentation & Performance

    Pad voice leading

    Chromatic passing notes

    Section-specific bassline with walking bass and chromatic approach

    Open/closed hi-hats, ride cymbal

    Snare rolls and ghost notes

MIDI & Expression

    Note durations driven by musical role

    Rhythmic push & pull per section

    Real MIDI swing

    Exponential CC swell

    CC vibrato with delayed onset
   </details>
---

## Screenshots
<img width="943" height="989" alt="Image" src="https://github.com/user-attachments/assets/983e35e4-39a7-4628-b5ee-d806ea7cf6c2" />


---

## Installation

**1.** Download `MidiStruct.lua` from this repository.

**2.** Copy it to your REAPER Scripts folder:

| OS | Path |
|----|------|
| Windows | `%APPDATA%\REAPER\Scripts\` |
| macOS | `~/Library/Application Support/REAPER/Scripts/` |
| Linux | `~/.config/REAPER/Scripts/` |

**3.** In REAPER: `Actions > Show Action List > New ReaScript`  
Browse to the `.lua` file and confirm.

**4.** *(Optional)* Assign a keyboard shortcut to `Script: MidiStruct.lua`.

**No external dependencies.** The script uses only the Lua API embedded in REAPER.  
Compatible with **REAPER 6.x and 7.x** on Windows, macOS and Linux.

---

## Quick Start

1. Open a blank REAPER project (or any existing project — tracks are added at the end)
2. Place the edit cursor where you want the track to start
3. Run the script
4. Fill in the 3 dialogs (see below)
5. Wait 1 seconds
6. Press Play

---

## Usage

The script presents **3 successive dialogs** on each run.

### Dialog 1 — Style

```
Style (1=Pop 2=Tech 3=LoFi 4=RnB 5=House 6=Trap 7=Rock),
Style 2 mix (0=None),
Mix % (0-100),
Complexity (1-10),
Seed (0=Random)
```

| # | Style | BPM | Swing | Scale | Character |
|---|-------|-----|-------|-------|-----------|
| 1 | Pop / Dua Lipa | 124 | 12% | Major | Catchy, tight |
| 2 | Techno (Peak) | 133 | 0% | Phrygian | Mechanical, tense |
| 3 | Lo-Fi Hip Hop | 85 | 35% | Pentatonic min | Swing heavy, ride cymbal |
| 4 | R&B / Soul | 92 | 28% | Dorian | Groovy, expressive |
| 5 | Classic House | 124 | 25% | Minor | 4/4 kick, swung hat |
| 6 | Trap / Future | 140 | 10% | Minor | Sparse, dark |
| 7 | Rock / Alt | 120 | 0% | Pentatonic min | High energy, open hat |

**Style blending:** enter a second style number and a mix percentage.  
`1,4,40` = 60% Pop + 40% R&B. BPM and swing are linearly interpolated.

**Complexity (1–10):** controls melody density, ghost note frequency and passing note probability.  
Recommended starting value: **6**.

**Seed:** `0` = random. Any other integer = fully reproducible.  
The seed is printed in the confirmation dialog and saved to the text report.

---

### Dialog 2 — Chord Preset

```
Preset number (0=Manual) 1-17
```

Type a preset number or `0` for manual chord entry.

| # | Preset | Chords | Best with |
|---|--------|--------|-----------|
| 1 | Pop I-V-vi-IV | C G Am F | Pop, House |
| 2 | Pop vi-IV-I-V | Am F C G | Pop, R&B |
| 3 | Pop I-IV-vi-V | C F Am G | Pop |
| 4 | 50s I-vi-IV-V | C Am F G | Pop, Rock |
| 5 | Minor i-VII-VI | Am G F G | R&B, Trap |
| 6 | Minor i-iv-VII | Am Dm G C | R&B, House |
| 7 | Andalusian i-VII-VI-V | Am G F E | Techno, Lo-Fi |
| 8 | Minor ii-V-i | Dm Am E7 Am | Jazz, Soul |
| 9 | Jazz ii-V-I | Dm7 G7 Cmaj7 Cmaj7 | Jazz, Lo-Fi |
| 10 | Soul Am7 groove | Am7 D9 Gmaj7 Cmaj7 | R&B, Jazz |
| 11 | Neo-Soul | Dm9 Gmaj7 Cmaj7 Am7 | R&B, Lo-Fi |
| 12 | Rock I-IV-V | A D E E | Rock |
| 13 | Rock i-VI-III-VII | Am F C G | Rock, Pop |
| 14 | Rock Power i-VII-VI | Am G F G | Rock, Trap |
| 15 | Blues 12 bars | A A A A D D A A E D A E | Rock, Lo-Fi |
| 16 | House vi-I-V-IV | Am C G F | House, Pop |
| 17 | Techno i-VI-III-VII | Am F C G | Techno, House |

---

### Dialog 3 — Manual Chords *(only if preset = 0)*

```
Chords e.g.: Am:4 F:4 C:4 G:4
```

**Syntax:** `NOTE[QUALITY][:BARS]` separated by spaces.

**Notes:** `C  C#  Db  D  D#  Eb  E  F  F#  Gb  G  G#  Ab  A  A#  Bb  B`

**Qualities:**

| Syntax | Type | Example |
|--------|------|---------|
| *(none)* | Major | `C` |
| `m` / `min` | Minor | `Am` |
| `maj7` | Major 7 | `Cmaj7` |
| `m7` | Minor 7 | `Am7` |
| `7` | Dominant 7 | `G7` |
| `9` | Dominant 9 | `D9` |
| `m9` | Minor 9 | `Dm9` |
| `add9` | Add 9 | `Cadd9` |
| `sus4` | Sus4 | `Gsus4` |
| `sus2` | Sus2 | `Dsus2` |
| `dim` | Diminished | `Bdim` |
| `aug` | Augmented | `Eaug` |
| `5` | Power chord | `A5` |

**Duration:** number of bars (default: 4).  
Examples: `Am:4 F:4 C:4 G:4` — `Dm7:2 G7:2 Cmaj7:4` — `A:4 D:4 E:4 E:4`

---

## Output

After a standard run (Am-F-C-G, Pop style, complexity 6):

```
5 MIDI tracks created and color-coded
~120 named MIDI items  (sections × tracks)
8 color-coded timeline regions
3 automatic tempo markers  (Bridge −2 BPM / Chorus 3 +1 BPM / Outro reset)
CC#11 curves on PAD track  (exponential swell, ~1 point per sixteenth note)
CC#1 curves on MELODY track  (vibrato envelope on notes ≥ 2 steps)
Architect_V26_rapport.txt saved to project folder
```

### Track reference

| Track | Color | MIDI Ch | Content |
|-------|-------|---------|---------|
| DRUMS | Red | 10 | Kick 36, Snare 38, HH 42/46, Ride 51/53, Crash 49 |
| BASS | Blue | 1 | Monophonic, octaves 2–3, walking + chromatic approach |
| PAD-CHORDS | Purple | 1 | Voiced chords, octaves 4–5, CC#11 swell |
| MELODY | Green | 1 | Lead line, octaves 4–5, CC#1 vibrato |
| COUNTER-MEL | Orange | 1 | Responds in melody silences |

---

## Technical Highlights

### Deterministic RNG — Lehmer LCG
Self-contained linear congruential generator (ANSI C constants) embedded in Lua.  
Period = 2³¹. Same seed → same output, guaranteed, cross-platform.

### Key Inference — Pitch Class Voting
Chord roots weighted ×2 vs inner voices. Mode detection via minor third presence.  
Style overrides ambiguous cases (Pop → major, Trap → minor, R&B → Dorian).

### Melodic Humanization — Box-Muller + Rubato
Gaussian timing jitter: `σ = 5.5 / tightness`. Step-position rubato (beat anticipation,
phrase-end pull). Global Push/Pull per section: Chorus −12 ticks, Verse +10 ticks.

### Hook Architecture — ×3 Repetition State Machine
4 variation levels (original → +1 degree → +octave → +octave+third harmony).  
Motif advances to next variation only after 3 identical plays.

### Melodic Phrasing — A-A'-B-A Structure
4-bar phrase cycles: statement → slight variation → contrast → resolution.  
Single climax note forced at step 10 with velocity arc toward and away from it.

### CC Automation — Exponential First-Order Response
Pad swell: `val = start + (peak − start) × (1 − e^{−3t})` — one CC#11 point per 60 PPQ.  
Melody vibrato: 3-point CC#1 envelope, onset after 1/3 of note duration.

### Inter-Track Call & Response
Shared `density_map[0..15]` filled by melody generation, read by counter-melody
and bass. Counter-melody targets melody silences; bass enriches them on odd bars.

### Secondary Dominants
Before chord changes with root distance ≥ 3 semitones: 35% chance of inserting
`V7/X` chord (`sec_dom = (next_root + 7) mod 12`).

### Walking Bass
Chromatic approach note on step 15: one semitone below (or above) the next chord
root. Velocity −18, duration 40% of a step.

---

## VSTi Recommendations

| Track | Suggestions |
|-------|-------------|
| DRUMS | EzDrummer, Superior Drummer, BFD, Addictive Drums, MT-Power Drumkit |
| BASS | Modo Bass, Scarbee Basses, Trilian, any GM bass |
| PAD | Spitfire LABS, Kontakt libraries, Diva, Omnisphere *(needs CC#11)* |
| MELODY | Synthesizer V, EAST WEST Voices, any lead synth with CC#1 vibrato |
| COUNTER-MEL | Same as melody, or flute/violin VSTi for timbral contrast |

> **CC#11 note:** if your pad VSTi does not respond to CC#11 Expression,
> map it internally to volume/expression, or use a REAPER JS MIDI filter
> to redirect CC#11 → CC#7.

---

## Working with Seeds

```
Seed = 0        → Random. Different result every run.
Seed = 1234567  → Reproducible. Identical result every run, forever.
```

**Recommended workflow:**
1. Run 10–20 times with seed = 0, note seeds of promising results
2. Listen quickly (30 seconds per version)
3. Reload the best one with its exact seed
4. Edit manually — the script gives you the 80%, you provide the 20%

The seed is always printed in the confirmation dialog and saved in
`Architect_V26_rapport.txt` in the project folder.

---

## Known Limitations

- The Bridge modulation (+2 semitones) is not exposed as a dialog parameter.
  To disable: select all Bridge MIDI items, Ctrl+A in piano roll, transpose −2 semitones on BASS/PAD/MELODY/COUNTER-MEL tracks.
- The engine generates without evaluating. It does not know if a melody is good.
  That judgment is yours — generate multiple seeds and keep what works.
- Drum note mapping follows GM standard. Non-GM drum plugins may require remapping.

---

## File Structure

```
MidiStruct.lua              Main script (single file, no dependencies)
MidiStruct_user_manual_EN.md       User manual (English)
MidiStruct_technical_description_EN.md  Technical documentation (English)
LICENSE                        GNU GPL v3
README.md                      This file
```

---

## License

```
MidiStruct — Algorithmic MIDI Composer for REAPER
Copyright (C) 2025 Acrosonus Mastering

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

https://www.gnu.org/licenses/gpl-3.0.html
```

**What this means in practice:**
- ✅ Free to use, modify and share
- ✅ Use in your own productions — no restrictions
- ✅ Fork and improve — contributions welcome
- ❌ Cannot be included in a closed-source commercial product
- ❌ Derivative works must remain open source under GPL v3

---

## Contributing

Issues and pull requests are welcome.

If you find a bug in REAPER, please include:
- REAPER version
- Operating system
- The chord progression and style settings used
- The exact error message from the REAPER console (`Actions > ReaScript > Show REAPER console`)

If you improve the musical engine, please document the compositional rule
you implemented — not just the code change.

---
