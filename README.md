# MIDISTRUCT V2.0 — Master Studio Edition


Download release ➡️➡️➡️➡️➡️➡️➡️

If you are lost on github, direct link: 
[https://drive.google.com/file/d/1MBx-2WobnAimE5tOX7PpRVWsvC7EbFH6/view?usp=sharing](https://drive.google.com/file/d/1yz-LiCSxarPrC5GLXv3d87ZF3ODSVMi9/view?usp=sharing)



**Algorithmic MIDI Composer for REAPER**  
*Developed by [Acrosonus Mastering](https://acrosonus.com)*  
*Licensed under [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)*

---

MIDISTRUCT is a ReaScript (Lua) that generates complete, multi-track MIDI arrangements directly inside REAPER from a chord progression. It composes drums, bass, pad/chords, melody, and counter-melody simultaneously, applying over 30 professional-grade musicality algorithms in a single click.

<a href="https://ibb.co/ynZ4HqQG"><img src="https://i.ibb.co/QFTDyMKz/Capture-d-cran-2026-06-12-154236.png" alt="Capture-d-cran-2026-06-12-154236" border="0"></a><br /><br />
---

## Features

### Core Generation Engine
- **Full arrangement from chords** — input any chord progression (e.g. `Am:4 F:4 C:4 G:4`) and receive a complete, structured song with Intro, Verse, Pre-Chorus, Chorus, Bridge, and Outro sections
- **5 dedicated MIDI tracks** — Drums, Bass, Pad-Chords, Melody, Counter-Melody, each created and color-coded automatically
- **Automatic key and scale inference** — detects the tonal center from the chord progression and derives the appropriate scale for melodic content
- **Deterministic seeding** — every generation is reproducible via a fixed random seed, or truly random when set to 0

### Style System
- **7 production styles** — Pop, Techno (Peak), Lo-Fi Hip Hop, R&B/Soul, Classic House, Trap/Future, Rock/Alt
- **Style hybridization** — blend two styles with a continuous mix ratio, interpolating BPM, swing, energy, legato, groove maps, and pattern data
- **Per-style groove maps** — sub-step time-warping tables (Lo-Fi, R&B, Pop, House, Rock…) applied to every instrument

### Musicality Algorithms (30+ options)

**Humanization & Feel**
- Deterministic Groove — fixed push/pull pocket with a 25% Gaussian noise layer for a consistent-yet-human feel
- MIDI Sidechain Drums — snare events duck hi-hat velocity automatically
- Rubato engine — bar-position-aware micro-timing shifts (phrase breath, pre-downbeat anticipation)
- Organic Groove Maps — per-style sub-step offsets applied globally across all instruments

**Melody & Phrasing**
- Core melodic motif system — generates a signature phrase from style-specific intervals and applies it with evolution across sections (transposition, octave shift, harmonization)
- Question & Answer phrasing — alternates tension/open endings (A phrases) with resolution cadences (A2/B phrases)
- Melodic Breath (Asphyxia Rule) — forces a rest bar after 3 consecutive melodic bars
- Smart Grace Notes — adds leading ornaments to motif landing points
- Melodic Motif Syncopation — stochastically shifts motif step positions by ±1
- Pitch-Linked Dynamics — scales note velocity proportionally to pitch height
- Analog Pitchbend Sag — simulates analog synth pitch droop on sustained notes

**Harmony & Voice Leading**
- Optimal Voice Leading — minimizes inter-chord distance by evaluating all inversions across octaves
- Evolving Voicings (Drop 2/3) — opens dense chorus voicings via drop-2 or drop-3 transformations
- Harmonic Anticipation — pads land one 16th-note early on chord changes (≈40% probability)
- Secondary Diminished Chords — inserts chromatic passing diminished chords between whole-step changes
- Secondary Dominants — probabilistically inserts V7/x chords before chord arrivals
- Predictive Modal Interchange — borrows the subdominant as a parallel minor on final chords
- Pre-Chorus Rhythmic Harmonic Pedal — locks the bass to the tonic pedal through pre-chorus bars

**Rhythm & Drums**
- Euclidean Sequences — generates rhythmically even polyrhythmic percussion patterns (k-in-n algorithm)
- Linear Drumming — realistic fills and flam articulations, no simultaneous hits
- Hi-Hat Groove Pocket — velocity-modulates hi-hats relative to kick and beat position
- Laid-Back Snare — adds a +16-tick micro-delay on backbeats for a behind-the-beat feel
- Metric Velocity Hierarchy — scales velocity by beat strength (downbeat > mid > upbeat > off-beat)
- Beat Drop Silence — clears the last 4 steps of the pre-chorus for a dramatic drop entrance

**Bass**
- Diatonic Bass Approach — in-scale conjoint movement toward chord root on bar transitions
- Fluid Bass Passing Notes — chromatic half-step and third-based approach notes
- Bass Ghost Notes — inserts dead/grace notes one step before accented bass hits
- Bass Octave Jumps — adds an upper-octave pop articulation on syncopated bass steps

**Dynamics & Structure**
- Narrative Arc (Macro-Dynamics) — applies per-section dynamic scaling that evolves within each section (Intro fades in, Outro fades out, Chorus peaks)
- Strict Counterpoint via Transformation — generates counter-melody by retrograde or contrary motion from the main phrase cache
- Contrary Counterpoint — forces counter-melody to move in the opposite direction of the main melody
- Polyrhythmic Pads — places pad hits on a 3-against-4 grid for rhythmic tension
- MPE CC Automations — generates CC74 (filter) and CC1 (mod/tension) curves on pad and pre-chorus builds

### Other Capabilities
- **17 chord preset progressions** spanning Pop, Jazz, Soul, Rock, Blues, House, and Techno
- **Named chord syntax** — supports maj, min, dim, aug, dim7, maj7, m7, 7, sus2, sus4, add9, 9, m9, 5 chord types with chromatic roots and variable bar duration
- **Colored section regions** — REAPER timeline markers created per section with color-coded overlays
- **Generation history log** — appends a detailed plain-text report to `MIDISTRUCT_History.txt` in the project folder after each generation
- **Persistent settings** — all parameters saved and restored between sessions via REAPER's ExtState system
- **Full undo support** — generation is wrapped in a REAPER undo block

---

## Requirements

- [REAPER](https://www.reaper.fm/) 7.0 or later
- **ReaImGui** extension (install via [ReaPack](https://reapack.com/) → ReaTeam Extensions → `reaper_imgui`)

---

## Installation

1. Download `midistruct_v11_ultimate.lua`
2. Place it in your REAPER scripts folder:
   - Windows: `%APPDATA%\REAPER\Scripts\`
   - macOS: `~/Library/Application Support/REAPER/Scripts/`
3. In REAPER: `Actions > Show action list > Load` → select the file
4. Optionally assign it to a toolbar button or keyboard shortcut

---

## Usage

1. Run the script from the Actions list or your assigned shortcut
2. The MIDISTRUCT V11.0 window opens with 7 collapsible panels:
   - **Harmony & Chord Progression** — enter chords manually or pick a preset
   - **Playing Style Hybridization** — select primary style, optional secondary style, and mix ratio
   - **Musical Humanization & Phrasing** — groove and musicality toggles
   - **Technical & Musical Evolutions** — advanced rhythm and harmony algorithms
   - **Master Studio Processing** — director-level dynamics and voice leading
   - **Groove & Performance Options** — articulations, ornaments, and micro-expressions
   - **General Writing Parameters** — complexity (1–10), random seed, track replacement
3. Click **GENERATE ALGORITHMIC ARRANGEMENT IN REAPER**
4. Five tracks appear at the cursor position. Assign instruments and mix.

### Chord Syntax

```
Root[Quality]:Duration  ...
```

Examples:
```
Am:4 F:4 C:4 G:4
Cmaj7:2 Am7:2 Fmaj7:2 G7:2
Dm9:4 Gmaj7:4 Cmaj7:4 Am7:4
```

Supported qualities: `maj` `min` / `m` `dim` `aug` `dim7` `maj7` `m7` `7` `sus4` `sus2` `add9` `9` `m9` `5`  
Duration is in bars (integer). Omitting the quality defaults to major.

---

## Track Layout

| Track | Color | Content |
|---|---|---|
| `[MIDISTRUCT] DRUMS` | Red | Kick, snare, hi-hat, ghost notes, fills, crash — channel 10 |
| `[MIDISTRUCT] BASS` | Blue | Root-position bass line with approach notes and articulations |
| `[MIDISTRUCT] PAD-CHORDS` | Purple | Voiced chord pads with CC11 swell curves and optional CC74/CC1 |
| `[MIDISTRUCT] MELODY` | Green | Main melodic line with CC1 vibrato and optional pitchbend sag |
| `[MIDISTRUCT] COUNTER-MEL` | Orange | Counterpoint or call-and-response secondary melodic voice |

Each track is split into MIDI items per section (Intro, Verse, Pre-Chorus, Chorus, Bridge, Outro) for easy arrangement.

---

## Architecture Notes

The engine is structured around three main layers:

**`RNG` / `Humanizer`** — deterministic LCG pseudo-random number generator with Gaussian timing, velocity, and rubato methods. All stochastic decisions in the engine are routed through this object, making every generation reproducible from its seed.

**`Engine`** — the composition core. Accepts style indices, mix ratio, complexity, seed, and option flags. Methods:
- `parse_chords()` — tokenizes chord text into pitch-class and quality data
- `_infer_key()` — derives global scale from chord weights
- `_build_core_motif()` — generates the song's signature melodic phrase
- `_apply_secondary_dominants()` — probabilistically enriches the harmony
- `_gen_melody()` / `_gen_counter_melody()` / `_gen_drums()` / `_gen_bass()` / `_gen_pad()` — per-bar MIDI data generators
- `generate_song()` — orchestrates the full structure and returns bar data

**MIDI Writer (`write_midi_multi_track`)** — maps bar data onto REAPER items using `CreateNewMIDIItemInProj` and `MIDI_InsertNote`. Section-grouped items allow Fixed Item Lanes workflow. All PPQ timing includes swing offsets, groove map shifts, push/pull values, and humanizer output.

---

MIDISTRUCT V2.0 Master Studio Engine - Changelog

(Compared to V1)

UI & Core Architecture

    ReaImGui Integration: Completely replaced the native REAPER GetUserInputs dialogue boxes with a comprehensive, interactive RealmGui interface featuring collapsible headers, real-time toggles, and dropdowns.

    High-Performance Cache: Localized standard math functions (m_floor, m_sin, m_pi, etc.) at the top of the script to significantly optimize DSP performance and calculation speeds during generation.

    Advanced Generation Logging: The MIDISTRUCT_History.txt log has been expanded to record all active UI toggles, hybridization ratios, and detailed arrangement structures.

Algorithmic Harmony & Melody

    Predictive Modal Interchange: The engine can now intelligently borrow chords from parallel modes (e.g., swapping a major subdominant for a minor IV) at the end of progressions.

    Secondary Diminished Chords: Added logic to allow diminished passing chords to cohabitate smoothly with secondary dominants for smoother harmonic transitions.

    Optimal Voice Leading: Implemented keyboardist-style voice conduction to minimize interval jumps between chord changes.

    Evolving Voicings (Drop 2/Drop 3): Chorus pad voicings can now automatically apply Drop 2 or Drop 3 chord inversions to open up the harmonic spectrum.

    Smart Grace Notes & Ornamentations: The melody engine now dynamically inserts scale-aware grace notes and micro-ornamentations on strong beats.

    Question & Answer Phrasing: Added structural logic to enforce tension on "A" phrases (ending on the dominant) and resolution on "A2/Ap" phrases (ending on the tonic).

Rhythm & Groove Engine

    Euclidean Percussion: Added a generator for Euclidean rhythms (e.g., 3/16, 5/16) to create cyclic, polyrhythmic ghost note patterns.

    Organic Groove Maps: Replaced static swing with style-specific sub-step time-warping arrays (Lofi, R&B, House, etc.) that shift individual 16th notes to mimic human pocket-playing.

    Deterministic Hybrid Groove: The humanizer now blends a fixed, deterministic "push/pull" pocket with Gaussian micro-variances, simulating human breath and consistency rather than pure RNG noise.

    Drum Linear Fills & Flams: Snare rolls and fills now utilize linear drumming logic to avoid physically impossible overlapping hits, incorporating realistic flams on strong beats.

    Laid-back Snare & Groove Pocket Hats: Toggles added to micro-shift the snare late on beats 2 and 4, while hi-hat velocities now duck and weave around kick drum hits.

Bass & Arrangement

    Diatonic Bass Approach: The bassline can now walk using in-scale conjoint movement rather than strictly chromatic approach notes.

    Physical Bass Groove: Added Slap-style Bass Octave Jumps and rhythmic Bass Ghost Notes to enhance the physical feel of the low-end.

    Narrative Arc (Macro-Dynamics): Velocity and intensity now scale globally across the arrangement, building naturally from the Intro through the final Chorus.

    Beat Drop Silence: The engine can now algorithmically mute the kick, bass, and pads in the final bar of a Pre-Chorus to create modern "beat drop" transitions.

    Polyrhythmic Pads: Pads can now trigger in a hypnotic 3-vs-4 polyrhythm instead of standard block chords.

Expression & MIDI Automation

    MPE CC Automations: Automatically generates CC74 (Filter) and CC1 (Tension) curves that track the dynamics and intensity of the current section.

    Analog Pitchbend Sag: Long synth notes now simulate the analog pitch instability of hardware synthesizers by generating custom pitch-bend curves that "sag" and recover.

    Pitch-Linked Dynamics: Higher melodic notes naturally trigger higher MIDI velocities to mimic physical acoustic instruments.

## License

Copyright © 2026 Acrosonus Mastering Studio  
Released under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for full terms.  
You are free to use, modify, and redistribute this script under the same license.
