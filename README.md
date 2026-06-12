**🎹 MIDISTRUCT V2**
=======================

**Master Studio Engine for REAPER**
-----------------------------------

A full-featured procedural MIDI generation engine written in ReaScript Lua.

From a chord progression and a style, it generates a complete, humanized multi-track arrangement in seconds, directly inside REAPER.

**🚀 What It Does**
-------------------

**MIDISTRUCT is not a simple arpeggiator or a random pattern generator.** It is a compositional engine that applies real music theory rules to build a structured song from scratch.

Given a chord progression like Am:4 F:4 C:4 G:4 and a style (Pop, R&B, Lo-Fi, Rock…), it generates:

*   **5 separate, color-coded MIDI tracks** — Drums, Bass, Pad/Chords, Lead Melody, Counter-Melody.
    
*   **A beautifully integrated UI** using ReaImGui directly inside REAPER.
    
*   **Named MIDI items** per section on every track.
    
*   **Color-coded timeline regions** — Intro, Verse, PreChorus, Chorus, Bridge, Outro.
    
*   **MPE & CC Automations** — CC74 Filter sweeps, CC1 Tension curves, and Vibrato.
    
*   **Humanized Groove Mechanics** — Push/pull per section, Gaussian micro-variations, and rubato.
    
*   **A text report** detailing the seed, key, structure, and generation history.
    

**Every generation is identified by a numeric seed** — the same seed always produces the exact same result.

**🌟 What Makes It Different**
------------------------------

Most commercial MIDI generators (Scaler 2, Captain Plugins, UJAM) generate static patterns. **MIDISTRUCT generates music** — with compositional rules that most plugins don't implement at all, acting as a virtual studio partner.

**Feature**

**MIDISTRUCT V11.0**

**Style Morphing**

✅ Blend two styles (e.g., 60% House + 40% Trap)

**Global Key Inference**

✅ Pitch class voting and automatic scale detection

**Advanced Voice Leading**

✅ Calculates minimum distance for chord inversions

**Deterministic Humanization**

✅ Gaussian algorithms for timing/velocity jitter

**Euclidean Rhythms**

✅ Cyclic polyrhythmic ghost notes for percussion

**Inter-track Call & Response**

✅ Counter-melody reads the main melody's density map

**Secondary Dominants**

✅ Automatic injection of passing diminished/dominant chords

**Question & Answer Phrasing**

✅ Phrases resolve to Dominant (Q) or Tonic (A)

**MPE & CC Swells**

✅ Advanced automation curves for pads and leads

**ReaImGui Interface**

✅ Modern, non-blocking UI within REAPER

**Full Seed Reproducibility**

✅ Custom PRNG, 100% deterministic

**🎵 Features Breakdown**
-------------------------

### **Composition & Harmony**

*   **Automatically inferred tonality** and coherent global scale.
    
*   **Voice leading optimized** like a real keyboardist (Drop 2/Drop 3 voicings in choruses).
    
*   **Modal interchange** and secondary dominant injection.
    
*   **Smart grace notes** and contrary movement for counter-melodies.
    

### **Arrangement & Structure**

*   **4-bar phrase cycles:** statement → slight variation → contrast → resolution (A-A'-B-A2).
    
*   **Unique climax notes** forced in Chorus/PreChorus with velocity crescendos.
    
*   **Melodic contours** specific to sections (e.g., "wave" for Verse, "peak" for Chorus).
    
*   **Stripped-back Intro/Outro** with progressive macro-dynamics.
    

### **Instrumentation & Performance**

*   **Section-specific basslines** with walking bass, chromatic approaches, disco octaves, and dead notes.
    
*   **Open/closed hi-hats, ride cymbals, and MIDI sidechaining** (snare ducks hi-hat velocity).
    
*   **Beat drop silence:** smartly mutes bass and pads right before a heavy chorus.
    

### **MIDI & Expression**

*   **Rhythmic push & pull** per section (Chorus rushes slightly, Verse lays back).
    
*   **Organic groove maps** applying sub-step time-warping per genre.
    
*   **Analog pitchbend sag** simulating vintage synthesizer drift on sustained notes.
    
*   **Exponential CC swell** for pads.
    

**📸 Screenshots**
------------------

_The modern ReaImGui interface directly inside REAPER._

_Generated colored tracks, regions, and named items in the arrange view._

**📥 Installation**
-------------------

1.  **Install ReaImGui** via ReaPack (ReaTeam Extensions) in REAPER. _This is mandatory._
    
2.  **Download** MIDISTRUCT\_V2.lua from this repository.
    
3.  **Copy it** to your REAPER Scripts folder:
    

**OS**

**Path**

**Windows**

%APPDATA%\\REAPER\\Scripts\\

**macOS**

~/Library/Application Support/REAPER/Scripts/

**Linux**

~/.config/REAPER/Scripts/

1.  In REAPER: Go to Actions > Show Action List > New action... > Load ReaScript. Browse to the .lua file and confirm.
    
2.  _(Optional)_ Assign a keyboard shortcut or toolbar button to Script: MIDISTRUCT\_V2.lua.
    

**⚡ Quick Start**
-----------------

1.  Open a blank REAPER project (or an existing one).
    
2.  Run the MIDISTRUCT script. A modern ReaImGui window will appear.
    
3.  Select a **Chord Preset** (or type your own, e.g., Am:4 F:4 C:4 G:4).
    
4.  Select your **Primary Style** (e.g., Pop, Lo-Fi, Techno).
    
5.  Tweak any **Master Studio toggles** (like Beat Drop, MPE CC Curves, or Euclidean Rhythms).
    
6.  Click the large green **GENERATE ALGORITHMIC ARRANGEMENT** button.
    
7.  Assign VST instruments to the 5 newly created tracks and press Play!
    

**🎛️ Usage: The ReaImGui Interface**
-------------------------------------

Unlike older versions, V11 uses a single, beautifully organized window with 7 collapsible sections:

### **1\. Harmony & Chord Progression**

Select from 17 built-in presets (Jazz ii-V-I, Andalusian, Neo-Soul, etc.) or enter manual chords.

*   **Syntax:** NOTE\[QUALITY\]:BARS separated by spaces.
    
*   **Example:** Am7:4 D9:4 Gmaj7:4 Cmaj7:4
    

### **2\. Playing Style Hybridization**

Choose a Primary Style and an optional Secondary Style.

*   **Styles:** Pop, Techno, Lo-Fi Hip Hop, R&B/Soul, Classic House, Trap/Future, Rock/Alt.
    
*   **Mix Ratio:** A slider (0-100%) blends the BPM, swing, scale tendencies, and drum patterns of the two styles.
    

### **3\. Musical Humanization & Phrasing**

Toggle core interaction features like Deterministic Groove, MIDI Sidechain Drums, Diatonic Bass Approach, and Question & Answer Phrasing.

### **4\. Technical & Musical Evolutions (V10/V11)**

Enable cutting-edge features:

*   **Euclidean Sequences:** Adds cyclic polyrhythmic ghost percussions.
    
*   **Strict Counterpoint:** Forces the counter-melody to use classical inversion/retrograde transformations.
    
*   **MPE CC Automations:** Automatically writes CC74 and CC1 automation.
    

### **5\. Master Studio Processing**

Shape the narrative arc with Macro-Dynamics (global volume swelling through the arrangement), Physical Groove (bass ghost notes), and Predictive Modal Interchange.

### **6\. Groove & Performance Options**

Legacy toggles to heavily customize the performance: Humanized Strumming, Analog Pitchbend Sag, Beat Drop Silence, Linear Drumming, and more.

### **7\. General Writing Parameters**

Set the global **Complexity (1-10)** (controls melody density and ornamentations), define a specific **Seed**, and choose whether to replace old MIDISTRUCT tracks automatically.

**🎚️ Output & Track Reference**
--------------------------------

After a standard run, you get:

**Track**

**Color**

**Content**

**\[MIDISTRUCT\] DRUMS**

🔴 Red

Kick, Snare, HH, Ride, Ghost notes, Fills, Crash

**\[MIDISTRUCT\] BASS**

🔵 Blue

Monophonic, octaves 2–3, walking + chromatic approach

**\[MIDISTRUCT\] PAD-CHORDS**

🟣 Purple

Voiced chords, octaves 4–5, CC#11/CC74 swells

**\[MIDISTRUCT\] MELODY**

🟢 Green

Lead line, octaves 4–5, CC#1 vibrato & pitch bends

**\[MIDISTRUCT\] COUNTER-MEL**

🟠 Orange

Responds in melody silences, contrary motion

**🎹 VSTi Recommendations**
---------------------------

To get the most out of the generated MIDI, here are some recommended instruments:

**Track**

**Suggestions**

**DRUMS**

Superior Drummer, Addictive Drums, XO, Battery, MT-Power Drumkit (Free)

**BASS**

Modo Bass, Trilian, Scarbee Bass, or any analog synth bass (e.g., Diva, Serum)

**PAD-CHORDS**

Omnisphere, Diva, Spitfire LABS (Free), Arturia Pigments _(Ensure CC74/CC11 mapping)_

**MELODY**

Synthesizer V, Kontakt leads, Serum, or expressive physical modeling synths

**COUNTER-MEL**

Woodwinds, bells, or a contrasting synth pluck (e.g., DX7 emulations)

**🎲 Working with Seeds**
-------------------------

*   Seed = 0 → **Random.** Different result every run.
    
*   Seed = 1234567 → **Reproducible.** Identical result every run, forever.
    

**Recommended workflow:**

1.  Generate multiple times with Seed = 0.
    
2.  Check the REAPER arrange view and quickly listen to the result.
    
3.  If you hear a motif or groove you love, check the generated MIDISTRUCT\_History.txt in your project folder to find its seed.
    
4.  Reload the script, enter that exact seed, and you can regenerate that specific idea while tweaking instrumentation or mixing.
    

_The script gives you the 80% foundation; you provide the 20% human touch!_

**⚠️ Known Limitations**
------------------------

*   **MPE/CC Routings:** The engine generates CC74, CC1, and Pitchbend data. If your VSTi does not respond to these, you may need to map them internally (e.g., route CC74 to the synth's filter cutoff).
    
*   **Drum Mapping:** Drum notes strictly follow the General MIDI (GM) standard (Kick 36, Snare 38, etc.). Non-GM drum plugins will require MIDI remapping.
    

**📜 License & Credits**
------------------------

**Development and Design:** Acrosonus Mastering Studio (C) 2026

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

**Dependencies:** Massive thanks to the incredible team behind the REAPER API and the ReaImGui framework by cfillion.

_Happy Composing! - Acrosonus Mastering Studio_
