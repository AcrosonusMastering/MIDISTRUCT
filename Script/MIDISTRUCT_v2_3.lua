-- ==============================================================================
-- MIDISTRUCT V2.3 -- REAPER EDITION (RealmGui Master Studio Engine)
-- Algorithmic MIDI Composer for REAPER
-- Developed by Acrosonus Mastering
-- Copyright Acrosonus Mastering Studio (C) 2026 Licensed under GNU GPL v3
-- ==============================================================================

local reaper = reaper
if not reaper then reaper = _G.reaper end

-- ==============================================================================
-- CACHE HAUTE PERFORMANCE (Optimisation)
-- ==============================================================================
local m_floor = math.floor
local m_max   = math.max
local m_min   = math.min
local m_abs   = math.abs
local m_sin   = math.sin
local m_sqrt  = math.sqrt
local m_log   = math.log
local m_cos   = math.cos
local m_exp   = math.exp
local m_pi    = math.pi or 3.14159265358979323846

local MIDI_CH = { drums=9, bass=1, pad=2, melody=3, counter=4 }

-- ==============================================================================
-- ★ VÉRIFICATION REAIMGUI
-- ==============================================================================
if not reaper.APIExists("ImGui_GetVersion") then
    reaper.MB("MIDISTRUCT requires the 'RealmGui' extension to run.\n\nPlease install it via ReaPack (ReaTeam Extensions) and restart REAPER.", "Error - RealmGui missing", 0)
    return
end
local ctx = reaper.ImGui_CreateContext('MIDISTRUCT V2.2')

-- ==============================================================================
-- ★ RNG DÉTERMINISTE (Génération de nombres pseudo-aléatoires)
-- ==============================================================================
local RNG = {}
RNG.__index = RNG

function RNG:new(seed) 
    return setmetatable({seed = seed or os.time()}, self) 
end

function RNG:rand()
    self.seed = (self.seed * 1103515245 + 12345) % 2147483648
    return self.seed / 2147483648
end

function RNG:randint(a, b) 
    return a + m_floor(self:rand() * (b - a + 1)) 
end

function RNG:choices(seq, weights)
    local total, cumul = 0, 0
    for _, w in ipairs(weights) do total = total + w end
    local r = self:rand() * total
    for i, w in ipairs(weights) do
        cumul = cumul + w
        if r <= cumul then return seq[i] end
    end
    return seq[#seq]
end

function RNG:gauss(mu, sigma)
    local u1 = m_max(1e-9, self:rand())
    local u2 = self:rand()
    return (m_sqrt(-2.0 * m_log(u1)) * m_cos(2.0 * m_pi * u2)) * sigma + mu
end

function RNG:shuffle(t)
    for i = #t, 2, -1 do
        local j = self:randint(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- ==============================================================================
-- ★ UTILITAIRES & ALGORITHMES
-- ==============================================================================
local function table_contains(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function deep_copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deep_copy(v) end
    return c
end

local function clamp(v, lo, hi) return m_max(lo, m_min(hi, v)) end
local function round(v) return m_floor(v + 0.5) end

local function reaper_color(r, g, b)
    return r + g * 256 + b * 65536 + 0x1000000
end

local function generate_euclidean(k, n)
    local sequence = {}
    local bucket = 0
    for i = 0, n - 1 do
        bucket = bucket + k
        if bucket >= n then
            bucket = bucket - n
            sequence[i] = true
        else
            sequence[i] = false
        end
    end
    return sequence
end

local function get_chord_tones_in_range(chord_pcs, scale, lo, hi)
    local tones = {}
    for _, n in ipairs(scale) do
        if n >= lo and n <= hi then
            local pc = n % 12
            for _, c_pc in ipairs(chord_pcs) do
                if pc == c_pc then
                    tones[#tones+1] = n
                    break
                end
            end
        end
    end
    return tones
end

local function nearest_chord_tone(chord_tones, target, avoid_note, rng)
    if not chord_tones or #chord_tones == 0 then return nil end
    local best_note = nil
    local min_dist = 99999
    for _, n in ipairs(chord_tones) do
        local dist = m_abs(n - target)
        if avoid_note and n == avoid_note and rng:rand() < 0.60 then
            dist = dist + 5
        end
        if dist < min_dist then
            min_dist = dist
            best_note = n
        end
    end
    return best_note
end

-- ==============================================================================
-- ★ HUMANIZER, GROOVE MAPS & RUBATO (V11)
-- ==============================================================================
local Humanizer = {}
Humanizer.__index = Humanizer

function Humanizer:new(rng) return setmetatable({rng = rng}, self) end

function Humanizer:timing(base_tick, tightness, step, deterministic)
    local sigma = 5.5 / clamp(tightness or 1.2, 0.1, 5.0)
    if deterministic and step then
        local push_pull = 0
        if step % 4 == 2 then 
            push_pull = 18 / (tightness or 1.2)
        elseif step % 2 == 1 then 
            push_pull = 8 / (tightness or 1.2)
        end
        return m_floor(base_tick + push_pull + self.rng:gauss(0, sigma * 0.25))
    else
        return m_floor(base_tick + self.rng:gauss(0, sigma))
    end
end

function Humanizer:velocity(base, spread)
    return clamp(m_floor(self.rng:gauss(base, 13 * (spread or 1.0))), 1, 127)
end

function Humanizer:rubato(step, intensity)
    intensity = intensity or 1.0
    if step % 16 == 15 then return m_floor(self.rng:gauss(-6, 2.0) * intensity)
    elseif step % 8 == 7 then return m_floor(self.rng:gauss(-3, 1.5) * intensity)
    elseif step % 4 == 0 then return m_floor(self.rng:gauss(2, 1.0) * intensity)
    end
    return 0
end

local GROOVE_MAPS = {
    lofi   = {[0]=8,  [1]=-15, [2]=22, [3]=0, [4]=-25, [5]=-8, [6]=28, [7]=-12, [8]=15, [9]=-20, [10]=30, [11]=0, [12]=-35, [13]=-10, [14]=20, [15]=-15},
    rnb    = {[0]=0,  [1]=-8,  [2]=15, [3]=0, [4]=-12, [5]=-6, [6]=18, [7]=-8,  [8]=0,  [9]=-8,  [10]=15, [11]=0, [12]=-15, [13]=-6,  [14]=18, [15]=-8},
    pop    = {[0]=0,  [1]=-6,  [2]=4,  [3]=0, [4]=-8,  [5]=-4, [6]=6,  [7]=0,   [8]=0,  [9]=-6,  [10]=4,  [11]=0, [12]=-10, [13]=-4,  [14]=8,  [15]=0},
    techno = {}, 
    house  = {[0]=0,  [1]=-5,  [2]=10, [3]=0, [4]=0,   [5]=-5, [6]=15, [7]=0,   [8]=0,  [9]=-5,  [10]=10, [11]=0, [12]=0,   [13]=-5,  [14]=15, [15]=0},
    trap   = {[0]=0,  [1]=0,   [2]=0,  [3]=0, [4]=0,   [5]=0,  [6]=0,  [7]=0,   [8]=0,  [9]=0,   [10]=0,  [11]=0, [12]=0,   [13]=0,   [14]=0,  [15]=0},
    rock   = {[0]=0,  [1]=-10, [2]=5,  [3]=-5,[4]=0,   [5]=-10,[6]=5,  [7]=-5,  [8]=0,  [9]=-10, [10]=5,  [11]=-5,[12]=0,   [13]=-10, [14]=5,  [15]=-5}
}

-- ==============================================================================
-- ★ THÉORIE MUSICALE
-- ==============================================================================
local SCALES = {
    major          = {0,2,4,5,7,9,11}, 
    minor          = {0,2,3,5,7,8,10},
    dorian         = {0,2,3,5,7,9,10},
    phrygian       = {0,1,3,5,7,8,10},
    mixo           = {0,2,4,5,7,9,10},
    pentatonic_maj = {0,2,4,7,9}, 
    pentatonic_min = {0,3,5,7,10},
    harmonic_minor = {0,2,3,5,7,8,11} -- sensible pour cadences dominantes en mineur
}

local STYLE_SCALE = {
    pop = "major", lofi = "pentatonic_min", rnb = "dorian",
    techno = "phrygian", house = "minor", trap = "minor", rock = "pentatonic_min"
}

local NOTE_MAP = {
    ["C"]=0, ["C#"]=1, ["Db"]=1, ["D"]=2, ["D#"]=3, ["Eb"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["Gb"]=6, ["G"]=7, ["G#"]=8, ["Ab"]=8, ["A"]=9, ["A#"]=10, ["Bb"]=10, ["B"]=11
}
local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

local CHORD_INTERVALS = {
    ["maj"] = {0,4,7}, ["min"] = {0,3,7}, ["dim"] = {0,3,6}, ["aug"] = {0,4,8},
    ["dim7"] = {0,3,6,9}, ["maj7"] = {0,4,7,11}, ["m7"] = {0,3,7,10},
    ["7"] = {0,4,7,10}, ["sus4"] = {0,5,7}, ["sus2"] = {0,2,7}, ["add9"] = {0,4,7,14},
    ["9"] = {0,4,7,10,14}, ["m9"] = {0,3,7,10,14}, ["5"] = {0,7}
}

local SIGNATURE_INTERVALS = {
    pop = {7,9,5}, lofi = {3,5,7}, rnb = {9,7,12},
    techno = {1,6,11}, house = {7,5,3}, trap = {3,10,7}, rock = {7,5,10}
}

local CHORD_PRESETS = {
    {name="Pop I-V-vi-IV (C)", chords="C:4 G:4 Am:4 F:4"},
    {name="Pop vi-IV-I-V (Am)", chords="Am:4 F:4 C:4 G:4"},
    {name="Pop I-IV-vi-V (C)", chords="C:4 F:4 Am:4 G:4"},
    {name="50s I-vi-IV-V (C)", chords="C:4 Am:4 F:4 G:4"},
    {name="Minor i-VII-VI (Am)", chords="Am:4 G:4 F:4 E:4"},
    {name="Minor i-iv-VII (Am)", chords="Am:4 Dm:4 G:4 E:4"},
    {name="Andalusian i-VII-VI-V (Am)", chords="Am:4 G:4 F:4 E:4"},
    {name="Minor ii-V-i (Dm)", chords="Dm:4 Am:4 E7:4 Am:4"},
    {name="Jazz ii-V-I (C)", chords="Dm7:4 G7:4 Cmaj7:4 Cmaj7:4"},
    {name="Soul Am7 groove", chords="Am7:4 D9:4 Gmaj7:4 Cmaj7:4"},
    {name="Neo-Soul (Dm)", chords="Dm9:4 Gmaj7:4 Cmaj7:4 Am7:4"},
    {name="Rock I-IV-V (A)", chords="A:4 D:4 E:4 E:4"},
    {name="Rock i-VI-III-VII (Am)", chords="Am:4 F:4 C:4 G:4"},
    {name="Rock Power i-VII-VI", chords="Am:4 G:4 F:4 G:4"},
    {name="Blues 12 bars (A)", chords="A:4 A:4 A:4 A:4 D:4 D:4 A:4 A:4 E:4 D:4 A:4 E:4"},
    {name="House vi-I-V-IV (Am)", chords="Am:4 C:4 G:4 F:4"},
    {name="Techno i-VI-III-VII", chords="Am:4 F:4 C:4 G:4"}
}

local SECTION_TARGET_DEGREE = { 
    Intro={degree=5,oct_offset=0}, Verse={degree=3,oct_offset=0}, 
    PreChorus={degree=6,oct_offset=0}, Chorus={degree=8,oct_offset=1}, 
    Bridge={degree=2,oct_offset=0}, Outro={degree=1,oct_offset=0} 
}

local SECTION_DYN = { Intro=0.52, Verse=0.70, PreChorus=0.84, Chorus=1.00, Bridge=0.65, Outro=0.48 }
local SECTION_CONTOUR = { Intro="flat", Verse="wave", PreChorus="rise", Chorus="peak", Bridge="fall", Outro="fall" }
local SECTION_REGION_COLOR = { Intro={50,50,120}, Verse={40,110,60}, PreChorus={120,100,20}, Chorus={160,30,30}, Bridge={80,40,130}, Outro={30,80,90} }
local SECTION_PUSH_PULL = { Chorus = -12, PreChorus = -6, Verse = 10, Bridge = 8, Intro = 0, Outro = 5 }

-- ==============================================================================
-- ★ STYLES PRO
-- ==============================================================================
local STYLE_PRO = {
    {name="Pop", bpm=110, swing=18, hat_swing_extra=6, kick={0,3,8,11}, snare={4,12}, energy=0.75, tightness=1.6, legato=0.88, scale_type="pop", rubato_intensity=0.6, use_ride=false, hat_open_steps={6,14}},
    {name="Techno (Peak)", bpm=133, swing=0, hat_swing_extra=0, kick={0,4,8,12}, snare={4,12}, energy=0.85, tightness=2.0, legato=0.70, scale_type="techno", rubato_intensity=0.2, use_ride=false, hat_open_steps={}},
    {name="Lo-Fi Hip Hop", bpm=85, swing=35, hat_swing_extra=15, kick={0,6,8,14}, snare={4,12}, energy=0.45, tightness=0.6, legato=1.10, scale_type="lofi", rubato_intensity=1.4, use_ride=true, hat_open_steps={4,12}},
    {name="R&B / Soul", bpm=92, swing=28, hat_swing_extra=12, kick={0,5,8,13}, snare={4,12}, energy=0.62, tightness=0.9, legato=1.05, scale_type="rnb", rubato_intensity=1.2, use_ride=false, hat_open_steps={4,12}},
    {name="Classic House", bpm=124, swing=25, hat_swing_extra=8, kick={0,4,8,12}, snare={4,12}, energy=0.65, tightness=1.2, legato=0.90, scale_type="house", rubato_intensity=0.6, use_ride=false, hat_open_steps={8}},
    {name="Trap / Future", bpm=140, swing=10, hat_swing_extra=5, kick={0,10,12}, snare={8}, energy=0.80, tightness=1.6, legato=0.65, scale_type="trap", rubato_intensity=0.5, use_ride=false, hat_open_steps={}},
    {name="Rock / Alt", bpm=120, swing=0, hat_swing_extra=0, kick={0,4,8,12}, snare={4,12}, energy=0.90, tightness=1.8, legato=0.75, scale_type="rock", rubato_intensity=0.3, use_ride=false, hat_open_steps={0,4,8,12}},
}

local function blend_styles(s1, s2, ratio)
    if not s2 or ratio <= 0 then return deep_copy(s1) end
    local r = ratio / 100
    local b = deep_copy(s1)
    for k, v in pairs(s1) do 
        if type(v) == "number" and s2[k] then
            b[k] = v * (1 - r) + s2[k] * r 
        end 
    end
    b.kick = (r > 0.5) and deep_copy(s2.kick) or deep_copy(s1.kick)
    b.snare = (r > 0.5) and deep_copy(s2.snare) or deep_copy(s1.snare)
    b.scale_type = (r > 0.5) and s2.scale_type or s1.scale_type
    b.use_ride = (r > 0.5) and s2.use_ride or s1.use_ride
    b.hat_open_steps = (r > 0.5) and deep_copy(s2.hat_open_steps) or deep_copy(s1.hat_open_steps)
    return b
end

-- ==============================================================================
-- ★ CONDUITE DES VOIX INTELLIGENTE (Voice Leading)
-- ==============================================================================
local function get_chord_inversions(pcs)
    local inversions = {}
    local r0 = {}
    for _, pc in ipairs(pcs) do r0[#r0+1] = pc end
    table.sort(r0)
    inversions[#inversions+1] = r0

    if #pcs >= 3 then
        local r1 = {}
        for i=2, #r0 do r1[#r1+1] = r0[i] end
        r1[#r1+1] = r0[1] + 12
        table.sort(r1)
        inversions[#inversions+1] = r1

        local r2 = {}
        for i=3, #r0 do r2[#r2+1] = r0[i] end
        r2[#r2+1] = r0[1] + 12
        r2[#r2+1] = r0[2] + 12
        table.sort(r2)
        inversions[#inversions+1] = r2
    end
    return inversions
end

local function best_voicing(chord_pcs, prev_notes, use_optimal_lead)
    if not prev_notes or #prev_notes == 0 or not use_optimal_lead then
        local res = {}
        for _, pc in ipairs(chord_pcs) do res[#res+1] = pc + 60 end
        table.sort(res)
        return res
    end
    local inversions = get_chord_inversions(chord_pcs)
    local best_v = nil
    local min_dist = 99999
    for _, inv in ipairs(inversions) do
        for oct = 3, 5 do
            local candidate = {}
            for _, pc in ipairs(inv) do candidate[#candidate+1] = pc + oct * 12 end
            table.sort(candidate)
            local dist = 0
            for i=1, m_min(#candidate, #prev_notes) do
                dist = dist + m_abs(candidate[i] - prev_notes[i])
            end
            dist = dist + m_abs(#candidate - #prev_notes) * 7
            if dist < min_dist then min_dist = dist; best_v = candidate end
        end
    end
    return best_v or prev_notes
end

local function make_drop_voicing(voicing, drop_type)
    if #voicing < 3 then return voicing end
    local res = deep_copy(voicing)
    table.sort(res)
    if drop_type == 2 then
        local idx = #res - 1
        res[idx] = res[idx] - 12
    elseif drop_type == 3 then
        local idx = #res - 2
        if idx >= 1 then res[idx] = res[idx] - 12 end
    end
    table.sort(res)
    return res
end

-- ==============================================================================
-- ★ HISTORIQUE DE GÉNÉRATION
-- ==============================================================================
local function log_history(engine, song_data, key_name, chords_text, preset_idx)
    local proj_path = reaper.GetProjectPath("") or ""
    if proj_path == "" then proj_path = reaper.GetResourcePath() end
    local path = proj_path .. "/MIDISTRUCT_History.txt"
    local f = io.open(path, "a")
    if not f then return nil end

    local preset_name = "Manual Entry"
    if preset_idx and preset_idx > 1 and CHORD_PRESETS[preset_idx - 1] then
        preset_name = CHORD_PRESETS[preset_idx - 1].name
    end

    local dur_sec = #song_data * 4 * (60.0 / engine.cfg.bpm)

    f:write("==================================================\n")
    f:write("DATE       : " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    f:write("ENGINE     : MIDISTRUCT V2.2 MASTER STUDIO\n")
    f:write("SEED       : " .. tostring(engine.seed) .. "\n")
    f:write("--------------------------------------------------\n")
    
    f:write("[HARMONY & STRUCTURE]\n")
    f:write("Key        : " .. (key_name or "?") .. "\n")
    f:write("Scale      : " .. (engine._scale_key or "?") .. "\n")
    f:write("Chords     : " .. chords_text .. " (" .. preset_name .. ")\n")
    f:write("Duration   : " .. string.format("%.1f", dur_sec) .. " sec (" .. #song_data .. " bars)\n\n")

    f:write("[STYLE & HYBRIDIZATION]\n")
    f:write("Style 1    : " .. (engine.style_name or "?") .. "\n")
    if engine.style2_name then
        f:write("Style 2    : " .. engine.style2_name .. "\n")
        f:write("Mix ratio  : " .. engine.mix_ratio .. "%\n")
    else
        f:write("Style 2    : None (Pure)\n")
    end
    f:write("BPM        : " .. m_floor(engine.cfg.bpm) .. "\n")
    f:write("Swing      : " .. m_floor(engine.cfg.swing or 0) .. "%\n")
    f:write("Complexity : " .. engine.comp .. "/10\n\n")

    f:write("[ACTIVE PERFORMANCE OPTIONS]\n")
    local opts_list = {}
    
    if engine.options.deterministic_groove then table.insert(opts_list, "Deterministic Groove") end
    if engine.options.midi_sidechain_drums then table.insert(opts_list, "MIDI Sidechain Drums") end
    if engine.options.diatonic_bass_approach then table.insert(opts_list, "Diatonic Bass Approach") end
    if engine.options.q_and_a_phrasing then table.insert(opts_list, "Question & Answer Phrasing") end
    if engine.options.euclidean_percussion then table.insert(opts_list, "Euclidean Sequences") end
    if engine.options.organic_groove_maps then table.insert(opts_list, "Organic Groove Maps") end
    if engine.options.bass_octave_jumps then table.insert(opts_list, "Bass Octave Jumps") end
    if engine.options.humanized_strumming then table.insert(opts_list, "Humanized Chord Strumming") end
    if engine.options.diminished_passing then table.insert(opts_list, "Secondary Diminished Chords") end
    if engine.options.strict_counterpoint then table.insert(opts_list, "Strict Counterpoint") end
    if engine.options.cc_automation_curves then table.insert(opts_list, "MPE CC Automations") end
    if engine.options.bass_ghost_notes then table.insert(opts_list, "Bass Ghost Notes") end
    if engine.options.macro_dynamics then table.insert(opts_list, "Macro-Dynamics") end
    if engine.options.polyrhythmic_pad then table.insert(opts_list, "Polyrhythmic Pads") end
    if engine.options.optimal_voice_leading then table.insert(opts_list, "Optimal Voice Leading") end
    if engine.options.laidback_snare then table.insert(opts_list, "Laid-Back snare") end
    if engine.options.metric_velocity_hierarchy then table.insert(opts_list, "Metric Velocity Hierarchy") end
    if engine.options.modal_interchange then table.insert(opts_list, "Predictive Modal Interchange") end
    if engine.options.harmonic_anticipation then table.insert(opts_list, "Harmonic Anticipation") end
    if engine.options.phrase_breath then table.insert(opts_list, "Melodic Breath") end
    if engine.options.voicing_opened then table.insert(opts_list, "Evolving Voicings") end
    if engine.options.groove_pocket_hat then table.insert(opts_list, "Hi-Hat Groove Pocket") end
    if engine.options.bass_passages then table.insert(opts_list, "Fluid Bass Passing Notes") end
    if engine.options.harmonic_pedal then table.insert(opts_list, "Pre-Chorus Harmonic Pedal") end
    if engine.options.contrary_movement then table.insert(opts_list, "Contrary Counterpoint") end
    if engine.options.motivic_shift then table.insert(opts_list, "Melodic Motif Syncopation") end
    if engine.options.smart_grace_notes then table.insert(opts_list, "Smart Grace Notes") end
    if engine.options.pitch_bend_sag then table.insert(opts_list, "Analog Pitchbend Sag") end
    if engine.options.dynamics_contour then table.insert(opts_list, "Pitch-Linked Dynamics") end
    if engine.options.beat_drop then table.insert(opts_list, "Beat Drop Silence") end
    if engine.options.drum_linear_fills then table.insert(opts_list, "Linear Drumming Fills") end

    if #opts_list == 0 then
        f:write("No extra options enabled.\n")
    else
        for _, opt in ipairs(opts_list) do
            f:write(" - " .. opt .. "\n")
        end
    end
    f:write("\n")

    f:write("[ARRANGEMENT STRUCTURE]\n")
    local cs, cc = "", 0
    for _, bar in ipairs(song_data) do
        if bar.section ~= cs then
            if cs ~= "" then f:write("  - " .. cs .. " : " .. cc .. " bars\n") end
            cs = bar.section; cc = 0
        end
        cc = cc + 1
    end
    if cs ~= "" then f:write("  - " .. cs .. " : " .. cc .. " bars\n") end

    f:write("==================================================\n\n")
    f:close()
    return path
end

-- ==============================================================================
-- ★ MOTEUR DE COMPOSITION (ENGINE)
-- ==============================================================================
local Engine = {}
Engine.__index = Engine

function Engine:new(s1_idx, s2_idx, mix, comp, seed, options)
    local obj = setmetatable({}, self)
    obj.comp = clamp(comp or 6, 1, 10)
    obj.seed = seed or m_floor(reaper.time_precise() * 1000)
    obj.rng = RNG:new(obj.seed)
    obj.human = Humanizer:new(obj.rng)
    local s1 = STYLE_PRO[s1_idx] or STYLE_PRO[1]
    local s2 = (s2_idx and s2_idx > 0) and STYLE_PRO[s2_idx] or nil
    obj.cfg = blend_styles(s1, s2, mix or 0)
    obj.style_name = s1.name
    obj.style2_name = s2 and s2.name or nil
    obj.mix_ratio = mix or 0
    obj.tightness = obj.cfg.tightness or 1.2
    obj.legato = obj.cfg.legato or 0.88
    obj.options = options or {}
    
    obj._prev_voicing = nil
    obj._prev_melody_last_note = nil
    obj._core_motif = nil
    obj._global_scale = nil
    obj._global_root = nil
    obj._scale_intervals = nil
    obj._scale_key = nil
    obj._key_name = ""
    obj._modulation_st = 2
    obj._sig_intervals = SIGNATURE_INTERVALS[obj.cfg.scale_type] or {7,5,3}
    obj._hook_play_count = 0
    obj._hook_variation = 0
    obj._phrase_cache = {}
    obj._melody_play_streak = 0
    return obj
end

function Engine:parse_chords(text)
    local res = {}
    text = string.gsub(text, "[\n\r]", "")
    local parsed = {}
    for word in string.gmatch(text, "%S+") do
        local name, dur_s = string.match(word, "([^:]+):?(%d*)")
        local dur = tonumber(dur_s) or 4
        local root_str, string_match = string.match(name, "^([A-G][#b]?)(.*)")
        if root_str then
            local root_pc = NOTE_MAP[root_str]
            if root_pc then
                parsed[#parsed+1] = {root_pc=root_pc, quality_str=string_match, dur=dur, name=name}
            end
        end
    end

    if self.options.modal_interchange and #parsed >= 3 then
        for idx, item in ipairs(parsed) do
            local is_last = (idx == #parsed or idx == #parsed - 1)
            local subdominant = (parsed[1].root_pc + 5) % 12
            if is_last and item.root_pc == subdominant and (item.quality_str == "" or item.quality_str == "maj") then
                if self.rng:rand() < 0.35 then
                    item.quality_str = "min"
                    item.name = item.name:gsub("maj", "") .. "m"
                end
            end
        end
    end

    for _, item in ipairs(parsed) do
        local root_pc = item.root_pc
        local quality_str = string.lower(item.quality_str or "")
        local intervals, quality = CHORD_INTERVALS["maj"], "maj"

        if string.find(quality_str,"m7") then intervals, quality=CHORD_INTERVALS["m7"], "min"
        elseif string.find(quality_str,"maj7") then intervals, quality=CHORD_INTERVALS["maj7"], "maj"
        elseif string.find(quality_str,"m9") then intervals, quality=CHORD_INTERVALS["m9"], "min"
        elseif string.find(quality_str,"add9") then intervals, quality=CHORD_INTERVALS["add9"], "maj"
        elseif string.find(quality_str,"9") then intervals, quality=CHORD_INTERVALS["9"], "dom"
        elseif string.find(quality_str,"7") then intervals, quality=CHORD_INTERVALS["7"], "dom"
        elseif string.find(quality_str,"sus4") then intervals, quality=CHORD_INTERVALS["sus4"], "sus"
        elseif string.find(quality_str,"sus2") then intervals, quality=CHORD_INTERVALS["sus2"], "sus"
        elseif string.find(quality_str,"dim7") then intervals, quality=CHORD_INTERVALS["dim7"], "dim"
        elseif string.find(quality_str,"dim") then intervals, quality=CHORD_INTERVALS["dim"], "dim"
        elseif string.find(quality_str,"aug") then intervals, quality=CHORD_INTERVALS["aug"], "aug"
        elseif string.find(quality_str,"5") then intervals, quality=CHORD_INTERVALS["5"], "pow"
        elseif string.find(quality_str,"min") or string.match(quality_str,"^m") then intervals, quality=CHORD_INTERVALS["min"],"min"
        end

        local pcs = {}
        for _, iv in ipairs(intervals) do pcs[#pcs+1] = (root_pc+iv)%12 end
        for _ = 1, item.dur do
            res[#res+1] = {root=root_pc, pcs=pcs, quality=quality, name=item.name}
        end
    end
    return res
end

function Engine:_infer_key(bars)
    local pc_weight = {}
    for i=0,11 do pc_weight[i]=0 end
    for _, bar in ipairs(bars) do
        for _, pc in ipairs(bar.pcs) do pc_weight[pc]=pc_weight[pc]+1 end
        pc_weight[bar.root] = pc_weight[bar.root]+2
    end
    local best_root, best_score = 0, -1
    for pc=0,11 do
        if pc_weight[pc]>best_score then best_score=pc_weight[pc]; best_root=pc end
    end
    local has_minor_third = pc_weight[(best_root+3)%12] > 0
    local scale_key = STYLE_SCALE[self.cfg.scale_type] or "minor"
    if not has_minor_third and (scale_key=="minor" or scale_key=="dorian") then scale_key="major" end
    if has_minor_third and scale_key=="major" then scale_key="minor" end
    
    local scale_intervals = SCALES[scale_key] or SCALES["minor"]
    local global_scale = {}
    for oct=3,6 do
        for _, iv in ipairs(scale_intervals) do
            local n = best_root+iv+oct*12
            if n>=48 and n<=84 then global_scale[#global_scale+1] = n end
        end
    end
    table.sort(global_scale)
    local unique = {}
    for i,n in ipairs(global_scale) do
        if i==1 or n~=global_scale[i-1] then unique[#unique+1] = n end
    end
    self._global_scale = unique
    self._global_root = best_root
    self._scale_intervals = scale_intervals
    self._scale_key = scale_key
    self._key_name = NOTE_NAMES[best_root+1].." "..scale_key
end

function Engine:_nearest_scale_note(midi_note, scale_override)
    local sc = scale_override or self._global_scale
    if not sc or #sc==0 then return midi_note end
    local best, min_d = sc[1], 999
    for _, n in ipairs(sc) do
        local d = m_abs(n-midi_note)
        if d<min_d then min_d=d; best=n end
    end
    return best
end

function Engine:_scale_degree_note(degree, octave, semitone_offset)
    semitone_offset = semitone_offset or 0
    if not self._scale_intervals then return 60 end
    local ivs = self._scale_intervals
    local n = #ivs
    local oct_extra = m_floor((degree-1)/n)
    local idx = ((degree-1)%n)+1
    return self._global_root+ivs[idx]+(octave+oct_extra)*12+semitone_offset
end

function Engine:_build_modulated_scale(semitones)
    if not self._scale_intervals then return self._global_scale end
    local new_root = (self._global_root+semitones)%12
    local sc = {}
    for oct=3,6 do
        for _, iv in ipairs(self._scale_intervals) do
            local n = new_root+iv+oct*12
            if n>=48 and n<=84 then sc[#sc+1] = n end
        end
    end
    table.sort(sc)
    local unique = {}
    for i,n in ipairs(sc) do
        if i==1 or n~=sc[i-1] then unique[#unique+1] = n end
    end
    return unique
end

-- [FIX] Fusionne les pitch-classes d'un accord altéré (dominante secondaire, emprunt modal)
-- dans la gamme diatonique de base, pour que la mélodie/contre-mélodie "voient" la
-- sensible/tension de l'accord au lieu de se limiter à la gamme fixe du morceau.
function Engine:_build_chord_aware_scale(base_scale, chord_pcs)
    if not chord_pcs or #chord_pcs == 0 then return base_scale end
    local sc = {}
    for _, n in ipairs(base_scale) do sc[#sc+1] = n end
    for oct=3,6 do
        for _, pc in ipairs(chord_pcs) do
            local n = pc + oct*12
            if n>=48 and n<=84 then sc[#sc+1] = n end
        end
    end
    table.sort(sc)
    local unique = {}
    for i,n in ipairs(sc) do
        if i==1 or n~=sc[i-1] then unique[#unique+1] = n end
    end
    return unique
end

local function is_dominant(chord_root, next_root, global_root)
    local dom = (global_root+7)%12
    return chord_root==dom and (next_root==global_root or next_root==(global_root+5)%12)
end

function Engine:_apply_secondary_dominants(bars)
    if #bars < 2 then return bars end
    local result = {}
    local nb = #bars
    
    local next_bar = bars[1]
    
    for i = nb, 1, -1 do
        local bar = bars[i]
        
        local insertions = {}
        local sec_dom_root = (next_bar.root + 7) % 12
        local resolves_by_fifth = (((sec_dom_root + 7) % 12) == next_bar.root)
        local diff_up = (next_bar.root - bar.root) % 12

        if self.options.diminished_passing and diff_up == 2 and self.rng:rand() < 0.45 then
            local pass_root = (bar.root + 1) % 12
            local dim_pcs = {}
            for _, iv in ipairs(CHORD_INTERVALS["dim7"]) do dim_pcs[#dim_pcs+1] = (pass_root+iv)%12 end
            table.insert(insertions, {root=pass_root, pcs=dim_pcs, quality="dim", name="PassDim", is_secondary_dominant=true})
        end
        
        if resolves_by_fifth and (sec_dom_root ~= bar.root) and self.rng:rand() < 0.35 then
            local sec_pcs = {}
            for _, iv in ipairs(CHORD_INTERVALS["7"]) do sec_pcs[#sec_pcs+1] = (sec_dom_root+iv)%12 end
            table.insert(insertions, {root=sec_dom_root, pcs=sec_pcs, quality="dom", name="SecDom", is_secondary_dominant=true})
        end

        local is_dom = is_dominant(bar.root, next_bar.root, self._global_root)
        if is_dom and self.rng:rand()<0.35 then
            local pass_root = (next_bar.root+1)%12
            local pass_pcs = {}
            for _, iv in ipairs(CHORD_INTERVALS["7"]) do pass_pcs[#pass_pcs+1] = (pass_root+iv)%12 end
            table.insert(insertions, {root=pass_root,pcs=pass_pcs,quality="dom",name="Sub",is_secondary_dominant=true})
        end
        
        for j = #insertions, 1, -1 do
            table.insert(result, 1, insertions[j])
            next_bar = insertions[j]
        end
        
        table.insert(result, 1, bar)
        next_bar = bar
    end
    
    return result
end

-- [IMPROVEMENT A] _build_core_motif + _gen_melody
function Engine:_build_core_motif()
    local arch_type = self.rng:choices({"syncopated", "backloaded", "call"}, {0.4, 0.35, 0.25})
    local rhythm
    if arch_type == "syncopated" then
        rhythm = {-2, 1, 4, 8, 12}
    elseif arch_type == "backloaded" then
        local start = self.rng:choices({2, 3}, {0.5, 0.5})
        rhythm = {start, 6, 10, 14}
    else -- call
        rhythm = {0, 8, 12, 14}
    end
    
    local contour_patterns = {
        {0, 2, -1, -1, 0, 0},    -- +3rd leap, step down
        {0, 3, -1, -1, -1, 0},   -- +4th leap, step down
        {0, 4, -1, -2, -1, 0},   -- +5th leap, fall shape
        {0, 1, 1, 2, 0, 0},      -- Call shape (ascent + hold)
        {0, 2, 1, -1, -2, 0}     -- Peak then descent (fall shape)
    }
    
    local contour = contour_patterns[self.rng:randint(1,#contour_patterns)]
    
    local base_degree = self.rng:choices({1, 5}, {0.5, 0.5}) -- Focus hook start on stable degrees
    local base_oct = self.rng:choices({4, 5}, {0.6, 0.4})
    local notes = {}
    local cursor_degree = base_degree

    for i, ival in ipairs(contour) do
        cursor_degree = clamp(cursor_degree + ival, 1, #self._scale_intervals * 3)
        
        -- Force the motif to resolve on scale degree 1 or 5 on the last note
        -- [FIX] 15% de chance d'autoriser une résolution "suspendue" sur le degré 3,
        -- pour éviter que chaque génération retombe systématiquement sur tonique/dominante.
        if i == #contour then
            local n_deg = #self._scale_intervals
            local function circ_dist(deg)
                local d = ((cursor_degree - deg) % n_deg + n_deg) % n_deg
                return m_min(d, n_deg - d)
            end
            local candidates = (self.rng:rand() < 0.15) and {1, 5, 3} or {1, 5}
            local best_deg, best_dist = candidates[1], circ_dist(candidates[1])
            for k=2, #candidates do
                local d = circ_dist(candidates[k])
                if d < best_dist then best_dist = d; best_deg = candidates[k] end
            end
            cursor_degree = cursor_degree - ((cursor_degree - best_deg) % n_deg)
        end
        notes[i] = self:_scale_degree_note(cursor_degree, base_oct)
    end
    
    self._core_motif = {rhythm=rhythm, notes=notes, base_oct=base_oct, contour=contour, base_deg=base_degree, archetype=arch_type}
    self._hook_play_count, self._hook_variation = 0, 0
end

local function borrow_chord(chord, rng)
    local borrowings={
        {root=(chord.root+5)%12, quality="min"},  -- iv
        {root=(chord.root+8)%12, quality="maj"},  -- bVI
        {root=(chord.root+10)%12, quality="maj"}, -- bVII
        {root=(chord.root+3)%12, quality="maj"},  -- bIII
        {root=(chord.root+1)%12, quality="maj"},  -- bII (Napolitain)
    }
    local pick = borrowings[rng:randint(1,#borrowings)]
    local ivs = CHORD_INTERVALS[pick.quality] or CHORD_INTERVALS["min"]
    local pcs = {}
    for _, iv in ipairs(ivs) do pcs[#pcs+1] = (pick.root+iv)%12 end
    return {root=pick.root,pcs=pcs,quality=pick.quality,name="Borrow",is_altered=true}
end

-- [IMPROVEMENT A] _build_core_motif + _gen_melody (Updated Signature with 'double')
function Engine:_gen_melody(chord, is_chorus, bar_num, section, phrase_role, chorus_index, is_dominant_chord, semitone_offset, strip_level, density_map, macro_dyn, double, base_density, chord_scale_override)
    semitone_offset = semitone_offset or 0
    strip_level = strip_level or 0
    if not self._global_scale or #self._global_scale==0 then return {} end

    local has_asphyxia = false
    if self.options.phrase_breath and self._melody_play_streak >= 3 then
        has_asphyxia = true
        self._melody_play_streak = 0
    end

    local melody = {}
    local contour = SECTION_CONTOUR[section] or "wave"
    local cur_scale = chord_scale_override or ((semitone_offset ~= 0) and self:_build_modulated_scale(semitone_offset) or self._global_scale)
    local target_info = SECTION_TARGET_DEGREE[section] or {degree=5,oct_offset=0}

    if self.options.q_and_a_phrasing then
        if phrase_role == "A" or phrase_role == "B" then
            target_info = {degree=5, oct_offset=0}
        elseif phrase_role == "A2" or phrase_role == "Ap" then
            target_info = {degree=1, oct_offset=0}
        end
    end

    local target_oct = 4 + target_info.oct_offset + (is_chorus and 1 or 0)
    local target_note = clamp(self:_scale_degree_note(target_info.degree,target_oct,semitone_offset), 48, 84)

    local function role_dur(is_pass, is_strong, is_resol, is_mot)
        if is_pass then return 1 end
        if is_resol then return self.rng:choices({3,4},{0.55,0.45}) end
        if is_mot then return self.rng:choices({2,3},{0.65,0.35}) end
        if is_strong then return self.rng:choices({2,3},{0.70,0.30}) end
        return self.rng:choices({1,2},{0.40,0.60})
    end
    local cache_key = section..(chorus_index and tostring(chorus_index) or "")

    if has_asphyxia then
        melody[14] = {note=target_note, dur=4, is_resolution=true}
        if density_map then density_map[14] = 1 end
        self._prev_melody_last_note = target_note
        return melody
    end

    -- Ap (Hook Repetition) Caching + Pitch Variation (A3)
    if phrase_role=="Ap" and self._phrase_cache[cache_key] then
        for s, m in pairs(self._phrase_cache[cache_key]) do
            local note = m.note
            if not m.is_motif then
                local dir = self.rng:choices({1, -1}, {0.5, 0.5})
                local current_idx = 1
                for idx, n in ipairs(cur_scale) do if n >= note then current_idx = idx; break end end
                note = cur_scale[clamp(current_idx + dir, 1, #cur_scale)] or note
            end
            melody[s] = {note=note, dur=m.dur, is_motif=m.is_motif, harmony=m.harmony, is_cached=true}
            if double and m.is_motif then
                local current_idx = 1
                for idx, n in ipairs(cur_scale) do if n >= note then current_idx = idx; break end end
                melody[s].harmony_double = cur_scale[m_min(current_idx + 2, #cur_scale)] or (note + 3)
            end
            if density_map then density_map[s]=1 end
        end
        self._melody_play_streak = self._melody_play_streak + 1
        
        local last_s = -1
        for s=15, 0, -1 do
            if melody[s] then self._prev_melody_last_note = melody[s].note; break end
        end
        return melody
    end

    if phrase_role=="A2" and self._phrase_cache[cache_key] then
        for s, m in pairs(self._phrase_cache[cache_key]) do
            local note = m.note
            if not m.is_motif and not m.is_climax and self.rng:rand()<0.55 then
                local dir = (note < target_note) and 2 or -2
                note = self:_nearest_scale_note(clamp(note+dir,48,84), cur_scale)
            end
            melody[s] = {note=note, dur=m.dur, is_motif=m.is_motif, harmony=m.harmony, is_cached=true}
            if density_map then density_map[s]=1 end
        end
        melody[14] = {note=target_note, dur=role_dur(false,true,true,false), is_resolution=true}
        melody[15] = nil
        self._melody_play_streak = self._melody_play_streak + 1
        
        local last_s = -1
        for s=15, 0, -1 do
            if melody[s] then self._prev_melody_last_note = melody[s].note; break end
        end
        return melody
    end

    -- Skeleton-first architecture
    local skeleton_weights = { [0] = 1.0, [8] = 0.85, [4] = 0.65, [12] = 0.65 }
    local prev_skeleton_note = self._prev_melody_last_note or target_note

    for _, step in ipairs({0, 8, 4, 12}) do
        if not melody[step] and self.rng:rand() < skeleton_weights[step] then
            local lo = is_chorus and 60 or 52
            local hi = is_chorus and 84 or 79
            local chord_tones = get_chord_tones_in_range(chord.pcs, cur_scale, lo, hi)
            local chosen_note = nearest_chord_tone(chord_tones, prev_skeleton_note, self._prev_melody_last_note, self.rng)
            if chosen_note then
                melody[step] = {note = chosen_note, dur = role_dur(false, step%4==0, false, false), is_chord_tone = true}
                if density_map then density_map[step] = 1 end
                prev_skeleton_note = chosen_note
            end
        end
    end

    local climax_step = 10
    if section=="Chorus" or section=="PreChorus" then
        local climax_note = clamp(self:_nearest_scale_note(target_note+(self._sig_intervals[1] or 7),cur_scale), 60, 84)
        melody[climax_step] = {note=climax_note, dur=role_dur(false,true,false,false), is_climax=true}
        if density_map then density_map[climax_step] = 1 end
    end

    if (phrase_role=="A" or phrase_role=="Ap" or phrase_role=="A2") and self._core_motif and strip_level==0 then
        local shift, oct_boost, do_harmony = 0, 0, false
        if self._hook_variation == 1 then shift = 1
        elseif self._hook_variation == 2 then oct_boost = 12
        elseif self._hook_variation == 3 then oct_boost = 12; do_harmony = true 
        elseif self._hook_variation == 4 then shift = 2
        elseif self._hook_variation == 5 then shift = -1 end
        
        self._hook_play_count = self._hook_play_count + 1
        if self._hook_play_count >= 3 then
            self._hook_play_count = 0
            self._hook_variation = (self._hook_variation % 5) + 1
        end
        if is_chorus and chorus_index and chorus_index >= 2 then oct_boost = oct_boost + 12 end

        local rhythm_offset = 0
        if phrase_role == "A" then
            local first_step = self._core_motif.rhythm[1]
            if first_step >= 0 then
                local target_first = self.rng:choices({0, 4, 8}, {0.4, 0.4, 0.2})
                rhythm_offset = target_first - first_step
            end
        end

        if phrase_role == "A" and self._core_motif.archetype == "syncopated" then
            local pitch = self:_nearest_scale_note(self._core_motif.notes[1] + shift*2, cur_scale)
            pitch = clamp(pitch+oct_boost, is_chorus and 60 or 52, is_chorus and (79+oct_boost) or 74)
            melody[14] = {note=pitch, dur=1, is_motif=true, tension_vel_mult=0.75, has_grace_note=true}
            if density_map then density_map[14] = 1 end
        end

        for i, step in ipairs(self._core_motif.rhythm) do
            if step < 0 then goto skip_step end
            local target_step = step + rhythm_offset
            if self.options.motivic_shift and self.rng:rand() < 0.30 then
                target_step = clamp(target_step + self.rng:choices({-1, 1}, {0.5, 0.5}), 0, 15)
            end
            if target_step >= 0 and target_step <= 15 and not melody[target_step] and self._core_motif.notes[i] then
                local snapped = self:_nearest_scale_note(self._core_motif.notes[i] + shift*2, cur_scale)
                snapped = clamp(snapped+oct_boost, is_chorus and 60 or 52, is_chorus and (79+oct_boost) or 74)
                local harmony = nil
                if do_harmony and i%2==0 then harmony = self:_nearest_scale_note(snapped+4, cur_scale) end
                local has_grace = self.options.smart_grace_notes and target_step%4==0 and self.rng:rand()<0.40
                melody[target_step] = {note=snapped, harmony=harmony, dur=role_dur(false,target_step%4==0,false,true), is_motif=true, has_grace_note=has_grace}
                if double and (phrase_role == "A" or phrase_role == "Ap") then
                    local current_idx = 1
                    for idx, n in ipairs(cur_scale) do if n >= snapped then current_idx = idx; break end end
                    melody[target_step].harmony_double = cur_scale[m_min(current_idx + 2, #cur_scale)] or (snapped + 3)
                end
                if density_map then density_map[target_step] = 1 end
            end
            ::skip_step::
        end

        if phrase_role == "A" then
            if self._core_motif.archetype == "backloaded" then
                melody[0] = nil
                if density_map then density_map[0] = 0 end
            elseif self._core_motif.archetype == "call" then
                for s=4, 7 do
                    melody[s] = nil
                    if density_map then density_map[s] = 0 end
                end
            end
        end
    end

    if phrase_role=="B" then
        local b_offset = (section == "Chorus") and -9 or ((section == "Verse") and -5 or -7)
        local b_base = self:_nearest_scale_note(clamp(target_note + b_offset, 48, 72), cur_scale)
        local b_idx = 1
        for idx, n in ipairs(cur_scale) do if n >= b_base then b_idx = idx; break end end
        b_base = cur_scale[m_min(#cur_scale, b_idx + 1)] or b_base
        
        for _, s in ipairs({0,4,8,12}) do
            if not melody[s] then
                melody[s] = {note=self:_nearest_scale_note(clamp(b_base+self.rng:choices({0,2,-2,3,-3},{0.4,0.2,0.2,0.1,0.1}),48,72), cur_scale), dur=role_dur(false,true,false,false)}
                if density_map then density_map[s] = 1 end
            end
        end
    end

    local start_note
    if contour=="rise" or contour=="peak" then start_note = target_note-7
    elseif contour=="fall" then start_note = target_note+5 else start_note = target_note-2 end
    start_note = self:_nearest_scale_note(clamp(start_note,48,84), cur_scale)

    for s=0,15 do
        if not melody[s] then
            local step_mult = (s<=7) and 1.1 or ((s<=11) and 0.85 or 0.40)
            if s==3 or s==7 or s==11 then step_mult=step_mult*1.15 end

            if self.rng:rand() <= clamp((base_density+(is_dominant_chord and 0.25 or 0.0))*step_mult,0.05,0.95) then
                local cn
                if contour=="rise" then cn=start_note+round((s/15.0)*(target_note-start_note))
                elseif contour=="fall" then cn=start_note-round((s/15.0)*(start_note-target_note))
                elseif contour=="peak" then
                    local peak = target_note+5
                    if s<=climax_step then cn=start_note+round((s/climax_step)*(peak-start_note))
                    else cn=peak-round(((s-climax_step)/(15-climax_step))*(peak-target_note)) end
                elseif contour=="wave" then cn=target_note+round(m_sin(s*0.8)*3)
                else cn=target_note end
                
                local snapped = self:_nearest_scale_note(clamp(cn,48,84), cur_scale)
                local is_passing = false
                
                if s%2==1 and self.rng:rand()<0.20 then
                    local chromatic = (melody[s-1] and melody[s-1].note or snapped) + self.rng:choices({1,-1},{0.5,0.5})
                    local in_scale = false
                    for _, gn in ipairs(cur_scale) do if gn==chromatic then in_scale=true; break end end
                    if not in_scale and chromatic>=48 and chromatic<=84 then snapped=chromatic; is_passing=true end
                end

                local dyn_mult = 1.0
                if self.options.dynamics_contour then dyn_mult = 0.85 + ((snapped - 48) / 36) * 0.3 end
                melody[s] = {note=snapped, dur=role_dur(is_passing, s%4==0, false, false), is_passing=is_passing, tension_vel_mult=(is_dominant_chord and 1.15 or 1.0)*dyn_mult}
                if density_map then density_map[s] = 1 end
            end
        end
    end

    if phrase_role=="A2" or phrase_role=="B" then
        melody[14] = {note=target_note, dur=role_dur(false,true,true,false), is_resolution=true}
        melody[15] = nil
    end

    -- A4 Anti-Stagnation Fix (Max 2 repeated notes, 3rd forces departure)
    local last_pitch = nil
    local repeat_count = 0
    for s=0,15 do
        if melody[s] then
            if last_pitch and melody[s].note == last_pitch then
                repeat_count = repeat_count + 1
                if repeat_count >= 2 then
                    local dir = (section == "Chorus" or section == "PreChorus") and 2 or -2
                    local current_idx = 1
                    for idx, n in ipairs(cur_scale) do if n >= melody[s].note then current_idx = idx; break end end
                    local step_dir = dir > 0 and 1 or -1
                    melody[s].note = cur_scale[clamp(current_idx + step_dir, 1, #cur_scale)] or melody[s].note
                    last_pitch = melody[s].note
                    repeat_count = 0
                end
            else
                last_pitch = melody[s].note
                repeat_count = 0
            end
        end
    end

    local notes_written = 0
    for s=0,15 do if melody[s] then notes_written = notes_written + 1 end end
    self._melody_play_streak = (notes_written > 1) and (self._melody_play_streak + 1) or 0

    if phrase_role=="A" then
        self._phrase_cache[cache_key] = {}
        for s, m in pairs(melody) do 
            self._phrase_cache[cache_key][s] = {note=m.note, dur=m.dur, is_motif=m.is_motif, harmony=m.harmony, is_climax=m.is_climax} 
        end
    end
    
    local last_s = -1
    for s=15, 0, -1 do
        if melody[s] then self._prev_melody_last_note = melody[s].note; break end
    end

    return melody
end

function Engine:_gen_counter_melody(melody, chord, section, semitone_offset, strip_level, density_map, force_counter, base_density, dyn, chord_scale_override, extra_chance)
    semitone_offset = semitone_offset or 0
    
    if not force_counter then
        if section~="Chorus" and section~="Bridge" and section~="Verse" then return {} end
        if (strip_level or 0) > 0 then return {} end
        if self.rng:rand() > (0.70 + (extra_chance or 0)) then return {} end
    end

    local cur_scale = chord_scale_override or ((semitone_offset~=0) and self:_build_modulated_scale(semitone_offset) or self._global_scale)
    if not cur_scale or #cur_scale==0 then return {} end
    local cm = {}
    local cache_key = section

    if (force_counter or (self.options.strict_counterpoint and self._phrase_cache[cache_key] and self.rng:rand() < 0.65)) then
        local src = self._phrase_cache[cache_key] or melody
        if not src then return {} end
        if self.rng:rand() < 0.5 and not force_counter then
            for s, m in pairs(src) do 
                local target_s = 15 - s
                if target_s >= 0 and (not density_map or density_map[target_s] ~= 1) then 
                    cm[target_s] = {note=m.note, dur=m.dur, is_response=true} 
                end 
            end
        else
            -- Contrary Counterpoint Focus
            local pivot = self:_scale_degree_note(5, 4, semitone_offset)
            for s, m in pairs(src) do
                if not density_map or density_map[s] ~= 1 then
                    local diff = m.note - pivot
                    cm[s] = {note=self:_nearest_scale_note(pivot - diff, cur_scale), dur=m.dur, is_response=false}
                end
            end
        end
        return cm
    end

    local base = clamp(self._global_root + (self._scale_intervals and self._scale_intervals[3] or 4) + 4*12, 52, 72)
    base = self:_nearest_scale_note(base, cur_scale)
    local cm_density = m_min(0.45, (base_density or 0.15) * (dyn or 1.0) * 0.8)
    
    for s=0,15 do
        local mel_busy = density_map and (density_map[s] == 1)
        if not mel_busy and self.rng:rand() < cm_density then
            local offset = self.rng:choices({0,2,-2,3,-3},{0.4,0.2,0.2,0.1,0.1})
            if (force_counter or self.options.contrary_movement) and melody then
                local prev_mel = melody[m_max(0, s-2)]
                local curr_mel = melody[s] or melody[m_min(15, s+2)]
                if prev_mel and curr_mel then
                    if curr_mel.note > prev_mel.note then offset = self.rng:choices({-2, -3, -4}, {0.4, 0.4, 0.2})
                    elseif curr_mel.note < prev_mel.note then offset = self.rng:choices({2, 3, 4}, {0.4, 0.4, 0.2}) end
                end
            end
            local n = self:_nearest_scale_note(clamp(base+offset,48,79), cur_scale)
            cm[s] = {note=n, dur=(not (density_map and density_map[m_max(0,s-1)] == 1) and s>0) and 2 or 1, is_response=(not mel_busy)}
        end
    end
    return cm
end

-- [IMPROVEMENT B] _gen_drums (Section-Aware Fills)
-- [FIX] Choisit une variante de fill en évitant de répéter deux fois de suite
-- la même variante pour un type de transition donné (Build/Break/Release).
function Engine:_pick_fill_variant(fill_type, n)
    self._last_fill_variant = self._last_fill_variant or {}
    local last = self._last_fill_variant[fill_type]
    local choice = self.rng:randint(1, n)
    if n > 1 and choice == last then
        choice = (choice % n) + 1
    end
    self._last_fill_variant[fill_type] = choice
    return choice
end

function Engine:_gen_drums(is_chorus, is_pre_drop, section, local_bar, strip_level, macro_dyn, next_section)
    local drums = {kick={},snare={},hat={},ghost={},fills={},crash={}}
    local dyn = macro_dyn or (SECTION_DYN[section] or 1.0)
    local energy = self.cfg.energy * dyn
    local swing_ticks = m_floor((self.cfg.swing or 0)*240/100)
    local drum_mult = (strip_level and strip_level>=2) and 0.5 or 1.0
    local use_ride = self.cfg.use_ride or (section=="Bridge" and self.cfg.scale_type=="lofi")
    local open_steps = self.cfg.hat_open_steps or {}
    local is_beat_drop = self.options.beat_drop and is_pre_drop and self.rng:rand() < 0.35
    local kick_steps_active = {}
    local is_pop_style = (self.cfg.scale_type == "pop")

    for s=0,15 do
        if is_beat_drop and s >= 12 then break end
        local swing_off = (s%2==1) and swing_ticks or 0
        if table_contains(self.cfg.kick,s) and self.rng:rand()<drum_mult then
            drums.kick[#drums.kick+1] = {step=s,swing_off=swing_off,vel=self.human:velocity(108*energy,0.5)}
            kick_steps_active[s] = true
        end
        if is_pre_drop and s>=12 and s%2==0 then
            drums.kick[#drums.kick+1] = {step=s,swing_off=0,vel=self.human:velocity(90*energy,0.6)}
            kick_steps_active[s] = true
        end

        local snare_here = table_contains(self.cfg.snare,s)
        if self.cfg.scale_type == "trap" and (s == 4 or s == 12) and self.rng:rand() < 0.30 then
            snare_here = true
        end
        
        if snare_here and self.rng:rand()<drum_mult then
            local is_flam = self.options.drum_linear_fills and (s == 4 or s == 12) and self.rng:rand() < 0.25
            drums.snare[#drums.snare+1] = {step=s,swing_off=swing_off,vel=self.human:velocity((s==4 or s==12) and 115*energy or 100*energy,0.6),is_flam=is_flam}
        end

        if not snare_here and s%2==1 and self.rng:rand()<(0.18*self.comp/10*drum_mult) then
            drums.ghost[#drums.ghost+1] = {step=s,swing_off=swing_off,vel=self.human:velocity(22*energy,1.3)}
        end

        local block_hat = self.options.drum_linear_fills and (snare_here or (is_pre_drop and s >= 12))
        if not block_hat then
            local hat_vel_base = is_chorus and 74 or 58
            if section=="PreChorus" then hat_vel_base = clamp(hat_vel_base+s*2,1,127) end

            if s%2==0 and self.rng:rand()<(is_chorus and 0.92 or 0.82*drum_mult) then
                if use_ride then
                    drums.hat[#drums.hat+1] = {step=s,swing_off=0,note=(s==0 or s==8) and 53 or 51,vel=self.human:velocity(hat_vel_base*0.85,0.9)}
                else
                    local is_open = table_contains(open_steps,s)
                    local base_v = hat_vel_base

                    if is_pop_style then
                        if s == 0 or s == 8 then base_v = base_v
                        elseif s == 4 or s == 12 then base_v = m_max(1, base_v - 12)
                        else base_v = m_max(1, base_v - 20) end
                    elseif self.options.groove_pocket_hat then
                        base_v = (s%4==0) and base_v*1.1 or base_v*0.8
                        if kick_steps_active[s] then base_v = base_v + 12 end
                    end

                    if self.options.midi_sidechain_drums and snare_here then
                        base_v = base_v * 0.55
                    end

                    drums.hat[#drums.hat+1] = {step=s,swing_off=0,note=is_open and 46 or 42,vel=self.human:velocity(is_open and base_v*1.1 or base_v,0.9),dur=is_open and 220 or 95}
                end
            end
            if s%2==1 and self.rng:rand()<((is_chorus and 0.55 or 0.35)*drum_mult) then
                local off_vel_base = self.options.groove_pocket_hat and kick_steps_active[s] and 50 or 40
                if is_pop_style then off_vel_base = m_max(1, hat_vel_base - 20) end
                drums.hat[#drums.hat+1] = {step=s,swing_off=swing_ticks,note=use_ride and 51 or 42,vel=self.human:velocity(off_vel_base,1.1),dur=95}
            end
            
            if is_pop_style and is_chorus and table_contains({2, 6, 10, 14}, s) and not block_hat then
                local pop_lift_exists = false
                for _, h in ipairs(drums.hat) do if h.step == s then pop_lift_exists = true; break end end
                if not pop_lift_exists then
                    drums.hat[#drums.hat+1] = {step=s,swing_off=0,note=42,vel=self.human:velocity(52,1.0),dur=80}
                end
            end
        end
    end

    if self.options.euclidean_percussion and section ~= "Intro" and section ~= "Outro" then
        local k = self.rng:choices({3, 5, 7}, {0.4, 0.4, 0.2})
        local euclid_seq = generate_euclidean(k, 16)
        local rot_offset = self.rng:randint(0, 4)
        for s=0, 15 do
            if euclid_seq[(s + rot_offset) % 16] and not is_beat_drop then
                drums.ghost[#drums.ghost+1] = {step=s, swing_off=0, vel=self.human:velocity(65*energy, 1.1), note=37}
            end
        end
    end

    if local_bar==0 and not is_beat_drop then 
        drums.crash[#drums.crash+1] = {step=0,vel=self.human:velocity(is_chorus and 115*dyn or 95*dyn,0.4)} 
    end

    -- B1-B4: Intelligent Section-Aware Fills
    local do_fill = not is_beat_drop and (is_pre_drop or (local_bar % 4 == 3))
    
    if do_fill and next_section then
        local function remove_drum_on_step(drum_list, step)
            for i=#drum_list, 1, -1 do
                if drum_list[i].step == step then table.remove(drum_list, i) end
            end
        end

        if next_section == "Chorus" or next_section == "PreChorus" then
            -- Build Fill (3 variantes, anti-répétition)
            for s=12, 15 do 
                remove_drum_on_step(drums.hat, s) 
                remove_drum_on_step(drums.snare, s)
                remove_drum_on_step(drums.kick, s)
            end
            local variant = self:_pick_fill_variant("build", 3)
            if variant == 1 then
                -- Crescendo classique sur la caisse claire
                drums.snare[#drums.snare+1] = {step=12, swing_off=0, vel=self.human:velocity(70, 0.4)}
                drums.snare[#drums.snare+1] = {step=13, swing_off=0, vel=self.human:velocity(85, 0.4)}
                drums.snare[#drums.snare+1] = {step=14, swing_off=0, vel=self.human:velocity(100, 0.4)}
                drums.snare[#drums.snare+1] = {step=15, swing_off=0, vel=self.human:velocity(110, 0.4)}
                drums.hat[#drums.hat+1] = {step=13, swing_off=0, note=42, vel=self.human:velocity(45, 0.5)}
                drums.hat[#drums.hat+1] = {step=14, swing_off=0, note=42, vel=self.human:velocity(55, 0.5)}
                drums.hat[#drums.hat+1] = {step=15, swing_off=0, note=42, vel=self.human:velocity(65, 0.5)}
            elseif variant == 2 then
                -- Appui kick + roulement resserré sur les 3 derniers 16èmes
                drums.kick[#drums.kick+1] = {step=12, swing_off=0, vel=self.human:velocity(88, 0.4)}
                drums.snare[#drums.snare+1] = {step=13, swing_off=0, vel=self.human:velocity(80, 0.4)}
                drums.snare[#drums.snare+1] = {step=14, swing_off=0, vel=self.human:velocity(95, 0.4)}
                drums.snare[#drums.snare+1] = {step=15, swing_off=0, vel=self.human:velocity(115, 0.4)}
                drums.hat[#drums.hat+1] = {step=13, swing_off=0, note=42, vel=self.human:velocity(40, 0.5)}
            else
                -- Syncopé avec charleston ouvert avant la résolution
                drums.snare[#drums.snare+1] = {step=13, swing_off=0, vel=self.human:velocity(78, 0.4)}
                drums.kick[#drums.kick+1] = {step=14, swing_off=0, vel=self.human:velocity(85, 0.4)}
                drums.hat[#drums.hat+1] = {step=14, swing_off=0, note=46, vel=self.human:velocity(60, 0.5), dur=180}
                drums.snare[#drums.snare+1] = {step=15, swing_off=0, vel=self.human:velocity(118, 0.4)}
            end
            drums.crash[#drums.crash+1] = {step=15, vel=self.human:velocity(100, 0.4)}
        
        elseif next_section == "Bridge" then
            -- Break Fill (3 variantes, anti-répétition)
            for s=12, 15 do
                remove_drum_on_step(drums.kick, s)
                remove_drum_on_step(drums.snare, s)
                remove_drum_on_step(drums.hat, s)
            end
            local variant = self:_pick_fill_variant("break", 3)
            if variant == 1 then
                -- Silence complet, crash au dernier temps
                drums.crash[#drums.crash+1] = {step=15, vel=self.human:velocity(95, 0.4)}
            elseif variant == 2 then
                -- Crash anticipé qui sonne dans le vide avant le Bridge
                drums.crash[#drums.crash+1] = {step=12, vel=self.human:velocity(90, 0.4)}
            else
                -- Descente de toms sèche, sans crash (arrêt plus discret)
                drums.fills[#drums.fills+1] = {step=13, swing_off=0, vel=self.human:velocity(55, 0.4), note=45}
                drums.fills[#drums.fills+1] = {step=15, swing_off=0, vel=self.human:velocity(60, 0.4), note=41}
            end
            
        elseif next_section == "Verse" or next_section == "Outro" then
            -- Release Fill (3 variantes, anti-répétition)
            for s=12, 15 do remove_drum_on_step(drums.snare, s) end
            local variant = self:_pick_fill_variant("release", 3)
            if variant == 1 then
                drums.fills[#drums.fills+1] = {step=12, swing_off=0, vel=self.human:velocity(75, 0.4), note=41}
                drums.fills[#drums.fills+1] = {step=14, swing_off=0, vel=self.human:velocity(65, 0.4), note=41}
                drums.fills[#drums.fills+1] = {step=15, swing_off=0, vel=self.human:velocity(70, 0.4), note=53}
            elseif variant == 2 then
                drums.fills[#drums.fills+1] = {step=12, swing_off=0, vel=self.human:velocity(72, 0.4), note=41}
                drums.fills[#drums.fills+1] = {step=13, swing_off=0, vel=self.human:velocity(60, 0.4), note=45}
                drums.fills[#drums.fills+1] = {step=14, swing_off=0, vel=self.human:velocity(65, 0.4), note=41}
                drums.fills[#drums.fills+1] = {step=15, swing_off=0, vel=self.human:velocity(70, 0.4), note=53}
            else
                -- Version minimale/plus spacieuse
                drums.fills[#drums.fills+1] = {step=15, swing_off=0, vel=self.human:velocity(68, 0.4), note=53}
            end
            
        else
            -- Groove Fill
            if self.rng:rand() < 0.22 then
                local function is_occupied(step)
                    for _, k in ipairs(drums.kick) do if k.step == step then return true end end
                    for _, sn in ipairs(drums.snare) do if sn.step == step then return true end end
                    return false
                end
                for _, s in ipairs({13, 15}) do
                    if not is_occupied(s) then
                        drums.ghost[#drums.ghost+1] = {step=s, swing_off=0, vel=self.human:velocity(self.rng:randint(20, 35), 0.5), note=38}
                    end
                end
                if self.options.drum_linear_fills then
                    drums.snare[#drums.snare+1] = {step=15, swing_off=0, vel=self.human:velocity(80, 0.5), is_flam=true}
                end
            end
        end
    elseif not is_beat_drop and self.rng:rand() < 0.22 then
        -- Default sporadic groove fills for non-transition sections
        local function is_occupied(step)
            for _, k in ipairs(drums.kick) do if k.step == step then return true end end
            for _, sn in ipairs(drums.snare) do if sn.step == step then return true end end
            return false
        end
        for _, s in ipairs({13, 15}) do
            if not is_occupied(s) then
                drums.ghost[#drums.ghost+1] = {step=s, swing_off=0, vel=self.human:velocity(self.rng:randint(20, 35), 0.5), note=38}
            end
        end
    end

    return drums
end

function Engine:_gen_bass(chord, next_chord_root, is_chorus, section, semitone_offset, bar_idx, density_map, strip_level)
    semitone_offset = semitone_offset or 0
    bar_idx = bar_idx or 0

    local root = ((chord.root+semitone_offset)%12)+36
    local fifth = ((chord.root+semitone_offset+7)%12)+36
    local third = ((chord.root+semitone_offset+(chord.quality=="min" and 3 or 4))%12)+36
    local next_root_note = next_chord_root and ((next_chord_root+semitone_offset)%12+36) or root
    
    local cur_scale = (semitone_offset~=0) and self:_build_modulated_scale(semitone_offset) or self._global_scale

    local bass, style = {}, self.cfg.scale_type or "pop"
    local is_sparse = (section=="Verse" or section=="Bridge" or section=="Intro" or section=="Outro" or (strip_level and strip_level >= 1))

    if self.options.harmonic_pedal and section == "PreChorus" then
        root = (self._global_root + semitone_offset) % 12 + 36
        for s=0, 14, 2 do bass[s] = root end
        if bar_idx % 2 == 1 then bass[15] = next_root_note end
    else
        if style == "pop" then
            bass[0] = root
            local dir = (next_root_note > root) and 1 or -1
            bass[14] = self:_nearest_scale_note(root + dir * 2, cur_scale)
            if not is_sparse and bar_idx % 2 == 1 and self.rng:rand() < 0.4 then
                bass[8] = {note = root + 12, is_pop = true}
            end
            -- [FIX] Tierce en note de passage : sans ça la basse pop reste figée
            -- root/octave, ce qui manque de mouvement mélodique.
            if not is_sparse and not bass[8] and self.rng:rand() < 0.3 then
                bass[8] = third
            end
        elseif style == "rnb" or style == "lofi" then
            bass[0] = root
            if not is_sparse then
                -- [FIX] Utilise la vraie tierce de l'accord (majeure ou mineure selon
                -- chord.quality) au lieu de forcer une tierce mineure sur tous les accords.
                bass[6] = third
                bass[7] = {note = bass[6], is_ghost = true}
                bass[8] = fifth
                bass[12] = self:_nearest_scale_note(next_root_note - 2, cur_scale)
            end
            local dir = (next_root_note > root) and -1 or 1
            bass[14] = self:_nearest_scale_note(next_root_note + dir, cur_scale)
            bass[15] = {note = bass[14], is_ghost = true}
        elseif style == "house" then
            bass[0] = root
            bass[4] = root
            bass[8] = root
            bass[12] = root
            bass[7] = {note = root - 1, is_ghost = true}
        elseif style == "trap" then
            bass[0] = root
            if not is_sparse then
                bass[self.rng:choices({8, 10}, {0.5, 0.5})] = root
                if self.rng:rand() < 0.4 then
                    bass[12] = root - 12
                end
            end
        elseif style == "techno" then
            for s=0, 14, 2 do bass[s] = root end
            bass[14] = root
            bass[15] = m_max(24, root - 1)
        elseif style == "rock" then
            bass[0] = root
            bass[4] = fifth
            bass[8] = root
            bass[12] = fifth
            -- [FIX] Tierce de passage occasionnelle entre root et fifth pour casser
            -- la rigidité root-fifth-root-fifth.
            if not is_sparse and self.rng:rand() < 0.3 then
                bass[6] = third
            end
            if self.options.bass_passages then
                bass[13] = next_root_note - 2
                bass[14] = next_root_note - 1
                bass[15] = next_root_note
            end
        else
            -- Fallback
            bass[0] = root; bass[8] = root; bass[12] = fifth; bass[14] = next_root_note
        end
    end

    if is_chorus then 
        for s, n in pairs(bass) do 
            if type(n) == "table" then
                n.note = n.note + 12
            else
                bass[s] = n + 12 
            end
        end 
    end

    if self.options.bass_ghost_notes then
        local ghost_pass = {}
        for s=0, 15 do
            if bass[s] and type(bass[s]) == "number" and s > 0 and not bass[s-1] and self.rng:rand() < 0.35 then
                ghost_pass[s-1] = {note = bass[s], is_ghost = true}
            end
        end
        for s, g in pairs(ghost_pass) do bass[s] = g end
    end

    if self.options.bass_octave_jumps and style ~= "pop" then
        for _, s in ipairs({6, 14, 15}) do
            if bass[s] and type(bass[s]) == "number" and self.rng:rand() < 0.35 then
                bass[s] = {note = bass[s] + 12, is_pop = true}
            end
        end
    end

    return bass
end

-- [IMPROVEMENT D] _gen_pad (Arpeggio/Comping Modes)
function Engine:_gen_pad(chord, section, semitone_offset, strip_level, macro_dyn, rep, bar_ctx)
    bar_ctx = bar_ctx or 0
    semitone_offset = semitone_offset or 0
    local dyn = macro_dyn or (SECTION_DYN[section] or 0.8)
    local pad = {}

    local pcs = {}
    for _, pc in ipairs(chord.pcs) do pcs[#pcs+1] = (pc+semitone_offset)%12 end

    if (section=="Verse" or section=="Bridge") and chord.quality~="dim" and chord.quality~="aug" and chord.quality~="pow" then
        local ninth = (chord.root+semitone_offset+14)%12
        local already=false
        for _, p in ipairs(pcs) do if p==ninth then already=true; break end end
        if not already then pcs[#pcs+1] = ninth end
    end

    if section=="PreChorus" and chord.quality=="min" then pcs[#pcs+1] = (chord.root+semitone_offset+17)%12 end
    if section=="Chorus" and (chord.quality=="maj" or chord.quality=="dom") then pcs[#pcs+1] = (chord.root+semitone_offset+21)%12 end

    local voicing = best_voicing(pcs, self._prev_voicing, self.options.optimal_voice_leading)
    if self.options.voicing_opened and section == "Chorus" then 
        voicing = make_drop_voicing(voicing, (#voicing >= 4) and 3 or 2) 
    end
    self._prev_voicing = voicing

    -- D4: Mode Sparse (Atmospheric Intro)
    if section == "Intro" and (strip_level and strip_level >= 2) then
        local vel = self.human:velocity(60 * dyn, 0.7)
        pad[#pad+1] = {step=0, notes={voicing[1]}, vel=vel, dur=4, anticipated=false}
        return pad
    end

    -- D1: Mode Arpeggio
    if section == "Intro" or section == "Verse" or section == "Outro" then
        local arp_steps = {0, 2, 4, 6, 8, 10, 12, 14}
        local cycle = 2 * (#voicing - 1)
        if cycle <= 0 then cycle = 1 end
        -- [FIX] Alterne le contour (aller-retour vs montée continue) selon la mesure,
        -- pour éviter que l'arpège soit identique bar après bar sur toute une section.
        local use_updown = (bar_ctx % 2 == 0)
        for i, s in ipairs(arp_steps) do
            local pos = (i - 1) % cycle
            local note_idx
            if use_updown then
                note_idx = (pos < #voicing) and (pos + 1) or (cycle - pos + 1)
            else
                note_idx = (pos % #voicing) + 1
            end
            local vel = self.human:velocity(clamp(54 + i*2 * dyn, 1, 127), 0.7)
            pad[#pad+1] = {step=s, notes={voicing[note_idx]}, vel=vel, dur=1.8, anticipated=false}
        end
        return pad
    end

    -- D2: Mode Comping
    if section == "PreChorus" then
        -- [FIX] Deux motifs de comping alternés par mesure pour casser la répétition
        -- exacte d'un PreChorus à l'autre.
        local comp_steps = (bar_ctx % 2 == 0) and {0, 3, 6, 8, 11, 14} or {0, 2, 5, 8, 10, 13}
        local base_vel = 65 * dyn
        for i, s in ipairs(comp_steps) do
            local vel = self.human:velocity(clamp(base_vel * (0.7 + i * 0.05), 1, 127), 0.7)
            pad[#pad+1] = {step=s, notes=voicing, vel=vel, dur=0.4, anticipated=false}
        end
        return pad
    end

    -- D3: Mode Block (Chorus & Bridge)
    local steps = {0,4,8,12}
    local poly_dur = 4
    if self.options.polyrhythmic_pad then steps = {0, 3, 6, 9, 12, 15}; poly_dur = 0.85 end

    for idx, s in ipairs(steps) do
        local vel = self.human:velocity(clamp((s==0 and 68 or 54) + (idx-1)*2 * dyn,1,127),0.7)
        local is_anticipated = self.options.harmonic_anticipation and s == 0 and self.rng:rand() < 0.40
        pad[#pad+1] = {step=is_anticipated and -1 or s, notes=voicing, vel=vel, dur=poly_dur, anticipated=is_anticipated}
    end
    return pad
end

-- [FIX] Structure de morceau adaptée au style : techno/trap privilégient une boucle
-- hypnotique sans Bridge modal (peu idiomatique pour ces genres), avec des refrains
-- plus longs pour un effet "peak-time" plutôt qu'un format couplet/refrain pop classique.
local STYLE_STRUCTURE = {
    techno = {
        {"Intro", 2, false, 2}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
        {"Chorus", 4, false, 0}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
        {"Chorus", 4, false, 0}, {"Outro", 2, false, 2},
    },
    trap = {
        {"Intro", 1, false, 2}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
        {"Chorus", 2, false, 0}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
        {"Chorus", 2, false, 0}, {"Outro", 1, false, 2},
    },
}
local DEFAULT_STRUCTURE = {
    {"Intro", 2, false, 2}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
    {"Chorus", 2, false, 0}, {"Verse", 2, false, 0}, {"PreChorus", 1, false, 0},
    {"Chorus", 2, false, 0}, {"Bridge", 1, true, 1}, {"Chorus", 2, false, 0},
    {"Outro", 1, false, 2},
}

-- [IMPROVEMENT C] generate_song (Chorus Evolution Patch)
function Engine:generate_song(chords_text)
    local bars = self:parse_chords(chords_text)
    if #bars==0 then return {}, "" end

    self:_infer_key(bars)
    self:_build_core_motif()
    bars = self:_apply_secondary_dominants(bars)

    local structure = STYLE_STRUCTURE[self.cfg.scale_type] or DEFAULT_STRUCTURE

    local phrase_roles, song_data, bar_num, chorus_count, verse_count = {"A","Ap","B","A2"}, {}, 0, 0, 0

    for s_idx, sec in ipairs(structure) do
        local section_type, repeats, is_modulated, base_strip_level = sec[1], sec[2], sec[3], sec[4]
        local semitone_off = is_modulated and self._modulation_st or 0
        if section_type=="Chorus" then chorus_count=chorus_count+1 end
        if section_type=="Verse" then verse_count=verse_count+1 end
        local chorus_idx = (section_type=="Chorus") and chorus_count or nil
        -- [FIX] Le Chorus a un vrai système d'escalade (chorus_idx) mais le Verse n'avait
        -- aucune notion d'index : couplet 1 et couplet 2 étaient arrangés à l'identique.
        -- Un deuxième couplet gagne classiquement une couche en plus (contre-mélodie légère,
        -- densité un peu montée) pour maintenir l'intérêt avant le refrain suivant.
        local verse_idx = (section_type=="Verse") and verse_count or nil
        
        local next_struct = structure[s_idx + 1]
        local actual_next_section = next_struct and next_struct[1] or nil

        for rep=1,repeats do
            local cur_nb = #bars
            local dominant_flags={}
            for i=1,cur_nb do 
                local dom_root_context = is_modulated and ((self._global_root + semitone_off) % 12) or self._global_root
                dominant_flags[i]=is_dominant(bars[i].root, bars[(i%cur_nb)+1].root, dom_root_context) 
            end

            for i, chord in ipairs(bars) do
                local c = chord
                if section_type=="Bridge" then c=borrow_chord(chord,self.rng) end
                local effective_chord={root=(c.root+semitone_off)%12, pcs=c.pcs, quality=c.quality, name=c.name, is_secondary_dominant=c.is_secondary_dominant, is_altered=c.is_altered}
                local is_last_bar_of_sec = (rep == repeats and i == cur_nb)

                -- [FIX] Cadence finale garantie : sans ça, la toute dernière mesure du morceau
                -- joue simplement le prochain accord de la boucle du Outro, qui peut très bien
                -- être un V (dominante) ou tout autre accord non-résolu. Un "hit" doit se
                -- terminer sur la tonique. On force la dernière mesure du Outro sur l'accord
                -- de tonique réel de la progression (ou, à défaut, sur triade construite).
                if section_type == "Outro" and s_idx == #structure and is_last_bar_of_sec then
                    local tonic_bar = nil
                    for _, b in ipairs(bars) do
                        if b.root == self._global_root and not b.is_secondary_dominant and not b.is_altered then
                            tonic_bar = b; break
                        end
                    end
                    if tonic_bar then
                        effective_chord = {root=self._global_root, pcs=tonic_bar.pcs, quality=tonic_bar.quality, name="Final "..(tonic_bar.name or "")}
                    else
                        local tonic_quality = (self._scale_key=="major" or self._scale_key=="mixo") and "maj" or "min"
                        local tonic_pcs = {}
                        for _, iv in ipairs(CHORD_INTERVALS[tonic_quality]) do tonic_pcs[#tonic_pcs+1] = (self._global_root+iv)%12 end
                        effective_chord = {root=self._global_root, pcs=tonic_pcs, quality=tonic_quality, name="Final Tonic"}
                    end
                end

                local is_chorus, is_pre_drop = (section_type=="Chorus"), (section_type=="PreChorus" and is_last_bar_of_sec)
                local local_bar = (rep-1)*cur_nb+(i-1)
                local next_sec_for_drums = is_last_bar_of_sec and actual_next_section or nil
                
                local current_strip_level = base_strip_level
                local double_melody = false
                local force_counter = false

                -- C1: Chorus strip level evolution
                if is_chorus then
                    if chorus_idx == 1 then
                        current_strip_level = 1
                    elseif chorus_idx == 2 then
                        current_strip_level = 0
                    elseif chorus_idx and chorus_idx >= 3 then
                        current_strip_level = 0
                        double_melody = true
                        force_counter = true
                    end
                end

                -- [FIX] Escalade Verse : le couplet 2+ gagne une chance de contre-mélodie
                -- légère, absente du couplet 1, pour créer une vraie progression d'arrangement
                -- au lieu de deux couplets strictement identiques en densité.
                -- (extra_chance augmente la probabilité plutôt que de forcer le mode "miroir
                -- de phrase" du Chorus, qui dépend d'un cache inter-section pas fiable ici.)
                local verse_density_boost = 1.0
                local verse_extra_chance = 0
                if section_type == "Verse" and verse_idx and verse_idx >= 2 then
                    verse_extra_chance = 0.35
                    verse_density_boost = 1.10
                end
                
                local macro_dyn = SECTION_DYN[section_type] or 1.0

                -- [FIX] Escalade de dynamique entre refrains successifs : le dernier
                -- refrain doit "taper" plus fort que le premier, pas juste être plus dense.
                if is_chorus and chorus_idx then
                    macro_dyn = macro_dyn * (1.0 + m_min(chorus_idx - 1, 3) * 0.045)
                end

                if self.options.macro_dynamics then
                    local progress = (repeats*cur_nb > 1) and (local_bar / (repeats*cur_nb - 1)) or 0
                    if section_type == "Outro" then macro_dyn = macro_dyn * (1.1 - 0.6 * progress)
                    elseif section_type == "Intro" then macro_dyn = macro_dyn * (0.6 + 0.5 * progress)
                    else macro_dyn = macro_dyn * (0.85 + 0.3 * progress) end
                end

                local phrase_role = phrase_roles[(bar_num%4)+1]
                local base_density = (0.13 + self.comp*0.036 + (is_chorus and 0.08 or 0)) * macro_dyn * verse_density_boost
                if phrase_role == "B" then base_density = base_density * 1.20 end
                if current_strip_level > 0 then base_density = base_density * 0.40 end

                -- [FIX] Gamme locale "chord-aware" : sur une dominante secondaire ou un
                -- accord emprunté, la mélodie doit voir la sensible/tension de l'accord
                -- au lieu de rester bloquée sur la gamme diatonique fixe du morceau.
                local chord_scale_override = nil
                if effective_chord.is_secondary_dominant or effective_chord.is_altered then
                    local base_scale = (semitone_off ~= 0) and self:_build_modulated_scale(semitone_off) or self._global_scale
                    chord_scale_override = self:_build_chord_aware_scale(base_scale, effective_chord.pcs)
                end

                local density_map = {}
                for s=0,15 do density_map[s]=0 end

                local melody = self:_gen_melody(effective_chord, is_chorus, bar_num, section_type, phrase_role, chorus_idx, dominant_flags[i], semitone_off, current_strip_level, density_map, macro_dyn, double_melody, base_density, chord_scale_override)
                local counter = self:_gen_counter_melody(melody, effective_chord, section_type, semitone_off, current_strip_level, density_map, force_counter, base_density, macro_dyn, chord_scale_override, verse_extra_chance)
                local drums_data = self:_gen_drums(is_chorus, is_pre_drop, section_type, local_bar, current_strip_level, macro_dyn, next_sec_for_drums)
                local is_beat_drop_active = (self.options.beat_drop and is_pre_drop and #drums_data.kick == 0)
                local bass_data = self:_gen_bass(effective_chord, bars[(i%cur_nb)+1].root, is_chorus, section_type, semitone_off, local_bar, density_map, current_strip_level)
                local pad_data = self:_gen_pad(effective_chord, section_type, semitone_off, current_strip_level, macro_dyn, rep, local_bar)

                if is_beat_drop_active then
                    for s = 12, 15 do bass_data[s] = nil end
                    for _, p in ipairs(pad_data) do if p.step >= 12 then p.vel = 0; p.notes = {} end end
                end

                song_data[#song_data+1] = {
                    section = section_type, chorus_index = chorus_idx, is_pre_drop = is_pre_drop,
                    dyn = macro_dyn, strip_level = current_strip_level, melody = melody, counter_melody = counter,
                    drums = drums_data, bass = bass_data, pad = pad_data
                }
                bar_num = bar_num + 1
            end
        end
    end
    return song_data, self._key_name
end

-- ==============================================================================
-- ★ REAPER TRACK & MARKER MANAGEMENT
-- ==============================================================================
local function create_track(idx, name, r, g, b)
    reaper.InsertTrackAtIndex(idx, true)
    local track = reaper.GetTrack(0, idx)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
    reaper.SetTrackColor(track, reaper_color(r, g, b))
    return track
end

local function insert_section_regions(song_data, start_pos, bpm)
    local spb, current_sec, start_bar, marker_idx = 4 * (60.0 / bpm), "", 1, 0
    for i, bar in ipairs(song_data) do
        local sec = bar.section .. (bar.chorus_index and (" " .. bar.chorus_index) or "")
        if sec ~= current_sec then
            if current_sec ~= "" then
                local col = SECTION_REGION_COLOR[string.match(current_sec, "%a+")] or {100, 100, 100}
                reaper.AddProjectMarker2(0, true, start_pos + (start_bar - 1) * spb, start_pos + (i - 1) * spb, current_sec, marker_idx, reaper_color(col[1], col[2], col[3]))
                marker_idx = marker_idx + 1
            end
            current_sec, start_bar = sec, i
        end
    end
    if current_sec ~= "" then
        local col = SECTION_REGION_COLOR[string.match(current_sec, "%a+")] or {100, 100, 100}
        reaper.AddProjectMarker2(0, true, start_pos + (start_bar - 1) * spb, start_pos + #song_data * spb, current_sec, marker_idx, reaper_color(col[1], col[2], col[3]))
    end
end

local TRACKS_DEF = {
    {name="[MIDISTRUCT] DRUMS", r=200,g=50, b=50 },
    {name="[MIDISTRUCT] BASS", r=50, g=140,b=220},
    {name="[MIDISTRUCT] PAD-CHORDS", r=140,g=60, b=220},
    {name="[MIDISTRUCT] MELODY", r=50, g=200,b=100},
    {name="[MIDISTRUCT] COUNTER-MEL", r=220,g=140,b=40 },
}

local function delete_old_midistruct_tracks()
    local i = 0
    while i < reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if string.find(name, "%[MIDISTRUCT%]") then reaper.DeleteTrack(track) else i = i + 1 end
    end
end

local function insert_pitch_bend(take, ppq_pos, val, chan)
    local lsb = val % 128
    local msb = m_floor(val / 128)
    reaper.MIDI_InsertCC(take, false, false, ppq_pos, 0xE0, chan or 0, lsb, msb, false)
end

-- ==============================================================================
-- ★ MIDI WRITER
-- ==============================================================================
local function write_midi_multi_track(song_data, engine, clean_old_tracks)
    if #song_data==0 then return end
    if clean_old_tracks then delete_old_midistruct_tracks() end
    
    local track_count = reaper.CountTracks(0)
    local PPQ, bpm, start_pos = 240, engine.cfg.bpm, reaper.GetCursorPosition()
    local spb = 4*(60.0/bpm)
    reaper.SetTempoTimeSigMarker(0,-1,0,-1,-1,bpm,4,4,false)
    insert_section_regions(song_data, start_pos, bpm)

    local tracks = {}
    for t, def in ipairs(TRACKS_DEF) do tracks[t] = create_track(track_count+t-1, def.name, def.r, def.g, def.b) end

    local sections_list, seen_sections = {}, {}
    for i, bar in ipairs(song_data) do
        local key = bar.section..(bar.chorus_index and tostring(bar.chorus_index) or "")
        if not seen_sections[key] then
            seen_sections[key] = true
            if #sections_list > 0 then sections_list[#sections_list].end_bar = i-1 end
            sections_list[#sections_list+1] = {key=key, section=bar.section, chorus_index=bar.chorus_index, start_bar=i, end_bar=#song_data}
        end
    end

    local takes_map = {}
    for _, si in ipairs(sections_list) do
        takes_map[si.key] = {}
        local label = si.section..(si.chorus_index and " "..si.chorus_index or "")
        for t, def in ipairs(TRACKS_DEF) do
            local item = reaper.CreateNewMIDIItemInProj(tracks[t], start_pos + (si.start_bar-1)*spb, start_pos + si.end_bar*spb, false)
            local take = reaper.GetActiveTake(item)
            if take then
                reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",def.name.." | "..label,true)
                reaper.MIDI_DisableSort(take)
                takes_map[si.key][t] = take
            end
        end
    end

    local function get_takes(bar) return takes_map[bar.section..(bar.chorus_index and tostring(bar.chorus_index) or "")] end
    
    local function bar_ppq_offset(b_idx, bar)
        local key = bar.section..(bar.chorus_index and tostring(bar.chorus_index) or "")
        for _, si in ipairs(sections_list) do if si.key==key then return (b_idx - si.start_bar)*16*PPQ end end
        return (b_idx-1)*16*PPQ
    end

    local rubato_intensity = engine.cfg.rubato_intensity or 1.0
    -- [FIX] Le swing n'était appliqué qu'à la batterie (via swing_off) ; basse, pad et
    -- mélodies restaient sur une grille droite, ce qui désaligne tout le reste de
    -- l'arrangement par rapport au groove swingué dans les styles Pop/R&B/Lo-Fi/House.
    local swing_ticks = m_floor((engine.cfg.swing or 0)*240/100)
    local function swing_for(step) return (step%2==1) and swing_ticks or 0 end

    for b_idx, bar in ipairs(song_data) do
        local takes = get_takes(bar)
        if not takes then goto next_bar end

        local b_off, cutoff, dyn, strip = bar_ppq_offset(b_idx, bar), bar.is_pre_drop and 12 or 16, bar.dyn, bar.strip_level or 0
        local t_drums, t_bass, t_pad, t_mel, t_cm = takes[1], takes[2], takes[3], takes[4], takes[5]
        local active_groove_map = GROOVE_MAPS[engine.cfg.scale_type] or {}
        
        -- V11: Le Push/Pull s'applique désormais à tous les calculs de timings de la mesure entière
        local push_pull_ticks = SECTION_PUSH_PULL[bar.section] or 0

        if engine.options.cc_automation_curves then
            local filter_base = clamp(m_floor(40 + (dyn * 60)), 10, 127)
            reaper.MIDI_InsertCC(t_pad, false, false, b_off + push_pull_ticks, 0xB0, MIDI_CH.pad, 74, filter_base, false)
            if bar.is_pre_drop then
                for step=0, 15 do
                    local tension_val = m_floor((step/15) * 127)
                    reaper.MIDI_InsertCC(t_pad, false, false, b_off + m_floor(step*PPQ) + push_pull_ticks, 0xB0, MIDI_CH.pad, 1, tension_val, false)
                    reaper.MIDI_InsertCC(t_pad, false, false, b_off + m_floor(step*PPQ) + push_pull_ticks, 0xB0, MIDI_CH.pad, 74, clamp(filter_base + tension_val, 0, 127), false)
                end
            end
        end

        if strip < 2 then
            -- Reset systematique du CC1 en debut de bloc mélodique
            reaper.MIDI_InsertCC(t_mel, false, false, b_off, 0xB0, MIDI_CH.melody, 1, 0, false)
            
            local climax_s = 10
            for s=0,15 do if bar.melody and bar.melody[s] and bar.melody[s].is_climax then climax_s=s; break end end
            for s=0,15 do
                if s>=cutoff then break end
                local m = bar.melody and bar.melody[s]
                if m then
                    local organic_shift = (engine.options.organic_groove_maps and active_groove_map[s]) and active_groove_map[s] or 0
                    local rubato_t = engine.human:rubato(s,rubato_intensity)*(PPQ/120)
                    local base_ppq = m_max(b_off, b_off + m_floor(s*PPQ) + m_floor(rubato_t) + push_pull_ticks + organic_shift + swing_for(s))
                    
                    local ppq = engine.human:timing(base_ppq, engine.tightness, s, engine.options.deterministic_groove)
                    
                    local dur_ppq = m_floor((m.dur or 2)*PPQ*(engine.legato or 0.88))
                    if m.is_passing then dur_ppq=m_floor(PPQ*0.35) end
                    local dist = m_abs(s-climax_s)
                    local cboost = m_max(0, 1.0-dist*0.08)
                    local vel_base = 90*dyn*(1.0+cboost*0.25)
                    
                    if m.is_resolution then vel_base=vel_base*1.10 end
                    if m.is_passing then vel_base=vel_base*0.65 end
                    if m.is_motif then vel_base=vel_base*1.05 end
                    if m.is_climax then vel_base=vel_base*1.20 end
                    if m.tension_vel_mult then vel_base=vel_base*m.tension_vel_mult end
                    
                    if engine.options.metric_velocity_hierarchy then
                        vel_base = vel_base * ((s==0) and 1.15 or ((s==8) and 1.02 or ((s==4 or s==12) and 0.94 or ((s%2==1) and 0.72 or 0.85))))
                    end
                    local vel = engine.human:velocity(clamp(vel_base,1,127),0.60)
                    local note_end = m_max(ppq+20, ppq+dur_ppq)

                    if m.has_grace_note then
                        if ppq - b_off >= 35 then
                            reaper.MIDI_InsertNote(t_mel,false,false, m_max(b_off, ppq-30), m_max(b_off, ppq-8), MIDI_CH.melody, clamp(m.note-1,48,84), clamp(vel-30,1,127), false)
                        end
                    elseif m.is_motif and s%4==0 and engine.rng:rand()<0.25 then
                        if ppq - b_off >= 35 then
                            reaper.MIDI_InsertNote(t_mel,false,false, m_max(b_off, ppq-35), m_max(b_off, ppq-7), MIDI_CH.melody, clamp(m.note-1,48,84), clamp(vel-38,1,127), false)
                        end
                    end

                    reaper.MIDI_InsertNote(t_mel,false,false, ppq, note_end, MIDI_CH.melody, clamp(m.note,48,84), vel, false)
                    if m.harmony then reaper.MIDI_InsertNote(t_mel,false,false, ppq, note_end, MIDI_CH.melody, clamp(m.harmony,48,84), clamp(vel-8,1,127), false) end
                    
                    -- C2 Double Harmony implementation
                    if m.harmony_double then 
                        reaper.MIDI_InsertNote(t_mel,false,false, ppq, note_end, MIDI_CH.melody, clamp(m.harmony_double,48,84), clamp(m_floor(vel*0.72),1,127), false) 
                    end

                    if dur_ppq >= 2*PPQ and not m.is_passing then
                        local vib_start = ppq + m_floor(dur_ppq/3)
                        local vib_depth = is_chorus and 18 or 10
                        reaper.MIDI_InsertCC(t_mel,false,false, vib_start, 0xB0, MIDI_CH.melody, 1, 0, false)
                        reaper.MIDI_InsertCC(t_mel,false,false, vib_start + m_floor(dur_ppq/3), 0xB0, MIDI_CH.melody, 1, clamp(vib_depth,0,127), false)
                        reaper.MIDI_InsertCC(t_mel,false,false, note_end - 20, 0xB0, MIDI_CH.melody, 1, 0, false)
                    end
                    
                    if engine.options.pitch_bend_sag and dur_ppq >= 3*PPQ and s >= 8 and t_mel then
                        local bend_start = note_end - m_floor(dur_ppq * 0.4)
                        insert_pitch_bend(t_mel, bend_start, 8192, MIDI_CH.melody)
                        local steps = 6
                        local step_time = m_floor((note_end - bend_start) / steps)
                        for i=1, steps do
                            local t_ppq = bend_start + i * step_time
                            if t_ppq >= note_end then break end
                            local factor = i / steps
                            local val = 8192 - m_floor(1200 * (factor * factor))
                            insert_pitch_bend(t_mel, t_ppq, clamp(val, 0, 16383), MIDI_CH.melody)
                        end
                        insert_pitch_bend(t_mel, note_end + 1, 8192, MIDI_CH.melody)
                    end
                end
            end
        end

        if bar.counter_melody and strip<1 then
            for s=0,15 do
                if s>=cutoff then break end
                local cm = bar.counter_melody[s]
                if cm then
                    local organic_shift = (engine.options.organic_groove_maps and active_groove_map[s]) and active_groove_map[s] or 0
                    local ppq = m_max(b_off, engine.human:timing(b_off+m_floor(s*PPQ)+push_pull_ticks+organic_shift+swing_for(s), engine.tightness*0.9, s, engine.options.deterministic_groove))
                    reaper.MIDI_InsertNote(t_cm,false,false, ppq, ppq+m_floor((cm.dur or 1)*PPQ*0.85), MIDI_CH.counter, clamp(cm.note,48,84), engine.human:velocity(cm.is_response and 80*dyn or 70*dyn,0.8), false)
                end
            end
        end

        if strip<2 then
            for s=0,15 do
                if s>=cutoff then break end
                local n_data = bar.bass[s]
                if n_data then
                    local pitch = type(n_data)=="table" and n_data.note or n_data
                    local is_ghost = type(n_data)=="table" and n_data.is_ghost or false
                    local is_pop = type(n_data)=="table" and n_data.is_pop or false
                    local organic_shift = (engine.options.organic_groove_maps and active_groove_map[s]) and active_groove_map[s] or 0
                    -- V11: Push/pull appliqué sur la basse
                    local ppq = engine.human:timing(b_off+m_floor(s*PPQ)+push_pull_ticks+organic_shift+swing_for(s), engine.tightness, s, engine.options.deterministic_groove)
                    local dur = is_ghost and m_floor(PPQ*0.15) or (is_pop and m_floor(PPQ*0.25) or ((s==15) and m_floor(PPQ*0.40) or m_floor(PPQ*0.82)))
                    local vb = is_ghost and 30 or (is_pop and 105 or ((s==15) and 72 or 88))
                    
                    if engine.options.metric_velocity_hierarchy and not is_ghost and not is_pop then 
                        vb = vb * ((s==0 or s==8) and 1.1 or 0.9) 
                    end
                    reaper.MIDI_InsertNote(t_bass,false,false, ppq,ppq+dur,MIDI_CH.bass,clamp(pitch,24,60),engine.human:velocity(vb*dyn,0.65),false)
                end
            end
        end

        for _, p in ipairs(bar.pad) do
            if p.step<cutoff then
                -- V11: Push/pull appliqué sur les pads
                -- [FIX] Le pad était la seule piste sans swing ni micro-timing humanisé
                -- (contrairement basse/batterie/mélodie) : il tombait pile sur la grille,
                -- ce qui le désolidarisait du reste du groove dans les styles swingués.
                local ppq = engine.human:timing(b_off+m_floor(p.step*PPQ)+push_pull_ticks+swing_for(p.step), engine.tightness*0.85, p.step, engine.options.deterministic_groove)
                local dur_ppq = m_floor(p.dur*PPQ*0.90)-20
                if p.anticipated then ppq = m_max(0, b_off - 240 + push_pull_ticks); dur_ppq = dur_ppq + 240 end
                
                local swell_start_val = 40
                local swell_peak_val  = clamp(m_floor(100*dyn), 40, 127)
                local swell_end_val   = m_floor(swell_peak_val * 0.82)
                local step_ppq = 60
                local steps_count = m_max(1, m_floor(dur_ppq / step_ppq))
                local attack_steps = m_floor(steps_count * 0.65)
                local release_steps = steps_count - attack_steps
                
                for si = 0, steps_count do
                    local cc_ppq = ppq + si * step_ppq
                    if cc_ppq >= ppq + dur_ppq then break end
                    local val
                    if si <= attack_steps then
                        local t = si / m_max(1, attack_steps)
                        local exp_val = 1.0 - m_exp(-3.0 * t)
                        val = swell_start_val + m_floor((swell_peak_val - swell_start_val) * exp_val)
                    else
                        local t = (si - attack_steps) / m_max(1, release_steps)
                        val = swell_peak_val - m_floor((swell_peak_val - swell_end_val) * t)
                    end
                    reaper.MIDI_InsertCC(t_pad, false, false, cc_ppq, 0xB0, MIDI_CH.pad, 11, clamp(val, 0, 127), false)
                end
                
                local strum_offset = 0
                for _, n in ipairs(p.notes) do
                    local current_ppq = ppq + (engine.options.humanized_strumming and strum_offset or 0)
                    reaper.MIDI_InsertNote(t_pad,false,false, current_ppq, current_ppq+m_max(20,dur_ppq),MIDI_CH.pad, clamp(n,48,84),m_floor(p.vel),false)
                    strum_offset = strum_offset + engine.rng:randint(2, 6)
                end
            end
        end

        local function insert_drum(type, items, default_note, default_dur)
            for _, d in ipairs(items) do
                if d.step<cutoff then
                    local organic_shift = (engine.options.organic_groove_maps and active_groove_map[d.step]) and active_groove_map[d.step] or 0
                    -- V11: Push/pull appliqué sur la batterie
                    local ppq = engine.human:timing(b_off+m_floor(d.step*PPQ)+(d.swing_off or 0)+organic_shift+push_pull_ticks, engine.tightness*(type=="ghost" and 0.7 or 1.0), d.step, engine.options.deterministic_groove)
                    
                    if engine.options.laidback_snare and type=="snare" and (d.step==4 or d.step==12) then 
                        ppq = ppq + 16 
                    end
                    if type=="snare" and d.is_flam then
                        reaper.MIDI_InsertNote(t_drums,false,false,m_max(b_off, ppq-18),m_max(b_off, ppq-18)+40,MIDI_CH.drums,38,clamp(d.vel-40,1,127),false) 
                    end
                    reaper.MIDI_InsertNote(t_drums,false,false,ppq,ppq+(d.dur or default_dur),MIDI_CH.drums,d.note or default_note,d.vel,false)
                end
            end
        end

        insert_drum("kick", bar.drums.kick, 36, 110)
        insert_drum("snare", bar.drums.snare, 38, 115)
        insert_drum("ghost", bar.drums.ghost, 38, 80)
        insert_drum("hat", bar.drums.hat, 42, 95)
        insert_drum("fill", bar.drums.fills, 38, 55)
        
        for _, cr in ipairs(bar.drums.crash) do 
            local cr_ppq = b_off+m_floor(cr.step*PPQ)+push_pull_ticks
            reaper.MIDI_InsertNote(t_drums,false,false, cr_ppq, cr_ppq+800, MIDI_CH.drums, 49, cr.vel, false) 
        end
        
        ::next_bar::
    end

    for _, si in ipairs(sections_list) do
        for t=1,#TRACKS_DEF do 
            if takes_map[si.key] and takes_map[si.key][t] then reaper.MIDI_Sort(takes_map[si.key][t]) end 
        end
    end
    reaper.UpdateArrange()
end

-- ==============================================================================
-- ★ PERSISTANCE & SETTINGS
-- ==============================================================================
local function save_settings(s1, s2, mix, comp, seed, chords, clean_tracks, preset_idx, opts)
    reaper.SetExtState("MIDISTRUCT", "s1", tostring(s1), true)
    reaper.SetExtState("MIDISTRUCT", "s2", tostring(s2), true)
    reaper.SetExtState("MIDISTRUCT", "mix", tostring(mix), true)
    reaper.SetExtState("MIDISTRUCT", "comp", tostring(comp), true)
    reaper.SetExtState("MIDISTRUCT", "seed", tostring(seed), true)
    reaper.SetExtState("MIDISTRUCT", "chords", chords, true)
    reaper.SetExtState("MIDISTRUCT", "clean_tracks", clean_tracks and "1" or "0", true)
    reaper.SetExtState("MIDISTRUCT", "preset_idx", tostring(preset_idx), true)
    for k, v in pairs(opts) do reaper.SetExtState("MIDISTRUCT", "opt_"..k, v and "1" or "0", true) end
end

local function load_settings()
    local function get_bool(key, default)
        local raw = reaper.GetExtState("MIDISTRUCT", key)
        return (raw == "") and default or (raw == "1")
    end

    local opts = {
        deterministic_groove = get_bool("opt_deterministic_groove", false),
        diatonic_bass_approach = get_bool("opt_diatonic_bass_approach", false),
        q_and_a_phrasing = get_bool("opt_q_and_a_phrasing", false),
        midi_sidechain_drums = get_bool("opt_midi_sidechain_drums", false),
        humanized_strumming = get_bool("opt_humanized_strumming", false),
        bass_octave_jumps = get_bool("opt_bass_octave_jumps", false),
        euclidean_percussion = get_bool("opt_euclidean_percussion", false),
        diminished_passing = get_bool("opt_diminished_passing", false),
        organic_groove_maps = get_bool("opt_organic_groove_maps", false),
        strict_counterpoint = get_bool("opt_strict_counterpoint", false),
        cc_automation_curves = get_bool("opt_cc_automation_curves", false),
        bass_ghost_notes = get_bool("opt_bass_ghost_notes", true),
        macro_dynamics = get_bool("opt_macro_dynamics", true),
        polyrhythmic_pad = get_bool("opt_polyrhythmic_pad", true),
        bass_passages = get_bool("opt_bass_passages", true),
        harmonic_pedal = get_bool("opt_harmonic_pedal", true),
        contrary_movement = get_bool("opt_contrary_movement", true),
        motivic_shift = get_bool("opt_motivic_shift", true),
        smart_grace_notes = get_bool("opt_smart_grace_notes", true),
        pitch_bend_sag = get_bool("opt_pitch_bend_sag", true),
        beat_drop = get_bool("opt_beat_drop", true),
        drum_linear_fills = get_bool("opt_drum_linear_fills", true),
        dynamics_contour = get_bool("opt_dynamics_contour", true),
        harmonic_anticipation = get_bool("opt_harmonic_anticipation", true),
        phrase_breath = get_bool("opt_phrase_breath", true),
        voicing_opened = get_bool("opt_voicing_opened", true),
        groove_pocket_hat = get_bool("opt_groove_pocket_hat", true),
        optimal_voice_leading = get_bool("opt_optimal_voice_leading", true),
        laidback_snare = get_bool("opt_laidback_snare", true),
        metric_velocity_hierarchy = get_bool("opt_metric_velocity_hierarchy", true),
        modal_interchange = get_bool("opt_modal_interchange", true)
    }

    return tonumber(reaper.GetExtState("MIDISTRUCT", "s1")) or 1,
           tonumber(reaper.GetExtState("MIDISTRUCT", "s2")) or 0,
           tonumber(reaper.GetExtState("MIDISTRUCT", "mix")) or 0,
           tonumber(reaper.GetExtState("MIDISTRUCT", "comp")) or 5,
           tonumber(reaper.GetExtState("MIDISTRUCT", "seed")) or 0,
           reaper.GetExtState("MIDISTRUCT", "chords") == "" and "Am:4 F:4 C:4 G:4" or reaper.GetExtState("MIDISTRUCT", "chords"),
           reaper.GetExtState("MIDISTRUCT", "clean_tracks") ~= "0",
           tonumber(reaper.GetExtState("MIDISTRUCT", "preset_idx")) or 2, opts
end

-- ==============================================================================
-- ★ REAIMGUI INTERFACE
-- ==============================================================================
local s1, s2, mix, comp, seed, chords, clean_tracks, preset_idx, opts = load_settings()
local report_text = "Ready to compose...\n\nModify your chords and enable Master Studio options, then click 'GENERATE ALGORITHMIC ARRANGEMENT'."

local function run_composition_engine()
    local actual_seed = (seed == 0) and (m_floor(reaper.time_precise() * 1000) % 2147483647) or seed
    if actual_seed == 0 then actual_seed = 777 end

    local engine = Engine:new(s1, s2, mix, comp, actual_seed, opts)
    local song, key_name = engine:generate_song(chords)

    if not song or #song == 0 then
        reaper.MB("Chord syntax not understood.\n\nValid examples:\n Am:4 F:4 C:4 G:4\n Cmaj7:2 Am7:2 Fmaj7:2 G7:2", "MIDISTRUCT - Error", 0)
        return
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    write_midi_multi_track(song, engine, clean_tracks)
    local log_path = log_history(engine, song, key_name, chords, preset_idx)
    
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("MIDISTRUCT V2.2 | "..(engine.style_name or "").." | Seed:"..tostring(engine.seed), -1)

    local dur_sec = #song * 4 * (60.0 / engine.cfg.bpm)
    local lines = {
        "=== STUDIO V2.2 COMPOSITION REPORT ===", 
        "Detected Key      : " .. (key_name or "?"), 
        "Diatonic Scale    : " .. (engine._scale_key or "?"), 
        "Final BPM         : " .. m_floor(engine.cfg.bpm), 
        "Swing             : " .. m_floor(engine.cfg.swing or 0) .. "%",
        "Complexity        : " .. engine.comp .. "/10", 
        "Deterministic Seed: " .. tostring(engine.seed),
        "Total Bars        : " .. #song,
        "Duration          : " .. string.format("%.1f", dur_sec) .. " sec"
    }

    table.insert(lines, "\nMaster Studio Algorithms Applied:")
    local active_ui_opts = {}
    if opts.deterministic_groove then table.insert(active_ui_opts, "  [X] Deterministic Groove") end
    if opts.bass_ghost_notes then table.insert(active_ui_opts, "  [X] Physical Groove (Bass Ghost Notes)") end
    if opts.macro_dynamics then table.insert(active_ui_opts, "  [X] Narrative Arc (Section Macro-Dynamics)") end
    if opts.polyrhythmic_pad then table.insert(active_ui_opts, "  [X] Rhythmic Hypnosis (Polyrhythmic Pads)") end
    if opts.optimal_voice_leading then table.insert(active_ui_opts, "  [X] Optimal Voice Leading") end
    if opts.laidback_snare then table.insert(active_ui_opts, "  [X] Temporal Micro-Shift (Laid-Back snare)") end
    if opts.metric_velocity_hierarchy then table.insert(active_ui_opts, "  [X] Metric Velocity Hierarchy") end
    if opts.modal_interchange then table.insert(active_ui_opts, "  [X] Predictive Modal Interchange") end
    if opts.euclidean_percussion then table.insert(active_ui_opts, "  [X] Euclidean Sequences") end
    if opts.organic_groove_maps then table.insert(active_ui_opts, "  [X] Organic Groove Maps") end
    if opts.cc_automation_curves then table.insert(active_ui_opts, "  [X] MPE CC Automations") end
    if opts.strict_counterpoint then table.insert(active_ui_opts, "  [X] Strict Counterpoint") end
    
    for _, opt in ipairs(active_ui_opts) do
        table.insert(lines, opt)
    end
    if #active_ui_opts == 0 then table.insert(lines, "  (None)") end

    table.insert(lines, "\nArrangement Structure:")
    local cs, cc = "", 0
    for _, bar in ipairs(song) do
        if bar.section ~= cs then
            if cs ~= "" then table.insert(lines, "  - " .. cs .. " : " .. cc .. " bars") end
            cs = bar.section; cc = 0
        end
        cc = cc + 1
    end
    if cs ~= "" then table.insert(lines, "  - " .. cs .. " : " .. cc .. " bars") end
    table.insert(lines, "\n[READY] Studio tracks generated. Fluctuat nec mergitur")

    if log_path then 
        table.insert(lines, "\n[LOG] History saved and appended to:\n  -> " .. log_path) 
    end
    report_text = table.concat(lines, "\n")
end

local function render_imgui()
    reaper.ImGui_SetNextWindowSize(ctx, 620, 880, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, 'MIDISTRUCT V2.2 - Master Studio Edition', true)

    if visible then
        reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "MIDISTRUCT V2.2")
        reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, " - Master Studio MIDI Composer")
        reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)

        if reaper.ImGui_CollapsingHeader(ctx, "1. Harmony & Chord Progression", reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
            local preset_names = {"Manual Entry"}
            for i=1, #CHORD_PRESETS do preset_names[#preset_names+1] = CHORD_PRESETS[i].name end
            local combo_changed, new_preset_idx = reaper.ImGui_Combo(ctx, "Presets", preset_idx - 1, table.concat(preset_names, '\0') .. '\0')
            if combo_changed then 
                preset_idx = new_preset_idx + 1; 
                if preset_idx > 1 then chords = CHORD_PRESETS[preset_idx - 1].chords end 
            end
            local text_changed, new_chords = reaper.ImGui_InputText(ctx, "Chords", chords)
            if text_changed then chords = new_chords; preset_idx = 1 end
            reaper.ImGui_Spacing(ctx)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "2. Playing Style Hybridization", reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
            local styles = {}; for i=1, #STYLE_PRO do styles[#styles+1] = STYLE_PRO[i].name end
            local s1_changed, new_s1 = reaper.ImGui_Combo(ctx, "Primary Style", s1 - 1, table.concat(styles, '\0') .. '\0')
            if s1_changed then s1 = new_s1 + 1 end

            table.insert(styles, 1, "None (Pure)")
            local s2_changed, new_s2 = reaper.ImGui_Combo(ctx, "Secondary Style", s2, table.concat(styles, '\0') .. '\0')
            if s2_changed then s2 = new_s2 end

            if s2 > 0 then 
                local mix_changed, new_mix = reaper.ImGui_SliderInt(ctx, "Mix Ratio (%)", mix, 0, 100); 
                if mix_changed then mix = new_mix end 
            end
            reaper.ImGui_Spacing(ctx)
        end

        local function chk(label, var) local c, v = reaper.ImGui_Checkbox(ctx, label, var); return c, v end

        if reaper.ImGui_CollapsingHeader(ctx, "3. Musical Humanization & Phrasing", reaper.ImGui_TreeNodeFlags_DefaultOpen()) then
            reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "Feeling & Interaction:")
            local c_g, v_g = chk("Deterministic Groove (Constant imperfection vs RNG noise)", opts.deterministic_groove); if c_g then opts.deterministic_groove = v_g end
            local c_sd, v_sd = chk("MIDI Sidechain Drums (Snare ducks Hi-Hat velocity)", opts.midi_sidechain_drums); if c_sd then opts.midi_sidechain_drums = v_sd end
            
            reaper.ImGui_Spacing(ctx); reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "Musicality:")
            local c_ba, v_ba = chk("Diatonic Bass Approach (In-scale conjoint movement)", opts.diatonic_bass_approach); if c_ba then opts.diatonic_bass_approach = v_ba end
            local c_qa, v_qa = chk("Question & Answer Phrasing (Tension/Resolution logic)", opts.q_and_a_phrasing); if c_qa then opts.q_and_a_phrasing = v_qa end
            reaper.ImGui_Spacing(ctx)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "4. Technical & Musical Evolutions") then
            reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "Rhythm & Groove:")
            local c1, v1 = chk("Euclidean Sequences (Cyclic polyrhythmic percussions)", opts.euclidean_percussion); if c1 then opts.euclidean_percussion = v1 end
            local c2, v2 = chk("Organic Groove Maps (Sub-Step Time-Warping per Style)", opts.organic_groove_maps); if c2 then opts.organic_groove_maps = v2 end
            local c26, v26 = chk("Bass Octave Jumps (Disco/Funk slap syncopation)", opts.bass_octave_jumps); if c26 then opts.bass_octave_jumps = v26 end
            
            reaper.ImGui_Spacing(ctx); reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "Harmony & Melody:")
            local c27, v27 = chk("Humanized Chord Strumming (Micro-delays on block chords)", opts.humanized_strumming); if c27 then opts.humanized_strumming = v27 end
            local c3, v3 = chk("Secondary Diminished Chords (Passing diminished chords)", opts.diminished_passing); if c3 then opts.diminished_passing = v3 end
            local c4, v4 = chk("Strict Counterpoint via Transformation (Inversion / Retrograde)", opts.strict_counterpoint); if c4 then opts.strict_counterpoint = v4 end
            
            reaper.ImGui_Spacing(ctx); reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "Timbre & Expression:")
            local c5, v5 = chk("MPE CC Automations (CC74 Filter / CC1 Tension curves)", opts.cc_automation_curves); if c5 then opts.cc_automation_curves = v5 end
            reaper.ImGui_Spacing(ctx)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "5. Master Studio Processing") then
            reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "V9 Director Concepts:")
            local c6, v6 = chk("Physical Groove (Bass Ghost Notes / Dead Notes)", opts.bass_ghost_notes); if c6 then opts.bass_ghost_notes = v6 end
            local c7, v7 = chk("Narrative Arc (Section Macro-Dynamics / Crescendo)", opts.macro_dynamics); if c7 then opts.macro_dynamics = v7 end
            local c8, v8 = chk("Rhythmic Hypnosis (3-vs-4 Polyrhythmic Pads)", opts.polyrhythmic_pad); if c8 then opts.polyrhythmic_pad = v8 end
            
            reaper.ImGui_Spacing(ctx); reaper.ImGui_TextColored(ctx, 0xFF44AAFF, "V8 Human & Acoustic Algorithms:")
            local c9, v9 = chk("Optimal Voice Leading (Keyboardist voice conduction)", opts.optimal_voice_leading); if c9 then opts.optimal_voice_leading = v9 end
            local c10, v10 = chk("Temporal Micro-Shift (Laid-Back snare groove)", opts.laidback_snare); if c10 then opts.laidback_snare = v10 end
            local c11, v11 = chk("Metric Velocity Hierarchy", opts.metric_velocity_hierarchy); if c11 then opts.metric_velocity_hierarchy = v11 end
            local c12, v12 = chk("Predictive Modal Interchange", opts.modal_interchange); if c12 then opts.modal_interchange = v12 end
            reaper.ImGui_Spacing(ctx)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "6. Groove & Performance Options") then
            reaper.ImGui_TextColored(ctx, 0xFF44CCAA, "Studio Grooves & Articulations:")
            local c13, v13 = chk("Harmonic Anticipation", opts.harmonic_anticipation); if c13 then opts.harmonic_anticipation = v13 end
            local c14, v14 = chk("Melodic Breath (Asphyxia Rule)", opts.phrase_breath); if c14 then opts.phrase_breath = v14 end
            local c15, v15 = chk("Evolving Voicings (Drop 2/3)", opts.voicing_opened); if c15 then opts.voicing_opened = v15 end
            local c16, v16 = chk("Hi-Hat Groove Pocket", opts.groove_pocket_hat); if c16 then opts.groove_pocket_hat = v16 end
            local c17, v17 = chk("Fluid Bass Passing Notes", opts.bass_passages); if c17 then opts.bass_passages = v17 end
            local c18, v18 = chk("Pre-Chorus Rhythmic Harmonic Pedal", opts.harmonic_pedal); if c18 then opts.harmonic_pedal = v18 end
            local c19, v19 = chk("Contrary Counterpoint for counter-melody", opts.contrary_movement); if c19 then opts.contrary_movement = v19 end
            local c20, v20 = chk("Melodic Motif Syncopation", opts.motivic_shift); if c20 then opts.motivic_shift = v20 end
            local c21, v21 = chk("Smart Grace Notes (Ornamentations)", opts.smart_grace_notes); if c21 then opts.smart_grace_notes = v21 end
            local c22, v22 = chk("Analog Pitchbend Sag (Synths)", opts.pitch_bend_sag); if c22 then opts.pitch_bend_sag = v22 end
            local c23, v23 = chk("Pitch-Linked Dynamics", opts.dynamics_contour); if c23 then opts.dynamics_contour = v23 end
            local c24, v24 = chk("Beat Drop Silence transition", opts.beat_drop); if c24 then opts.beat_drop = v24 end
            local c25, v25 = chk("Linear Drumming (Realistic Fills & Flams)", opts.drum_linear_fills); if c25 then opts.drum_linear_fills = v25 end
            reaper.ImGui_Spacing(ctx)
        end

        if reaper.ImGui_CollapsingHeader(ctx, "7. General Writing Parameters") then
            local comp_changed, new_comp = reaper.ImGui_SliderInt(ctx, "Global Complexity", comp, 1, 10); if comp_changed then comp = new_comp end
            local seed_changed, new_seed = reaper.ImGui_InputInt(ctx, "Random Seed (0 = Random)", seed); if seed_changed then seed = clamp(new_seed, 0, 2147483647) end
            local clean_changed, new_clean = reaper.ImGui_Checkbox(ctx, "Replace previous MIDISTRUCT tracks", clean_tracks); if clean_changed then clean_tracks = new_clean end
            reaper.ImGui_Spacing(ctx)
        end

        reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFF1FA04F)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF28C262)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF147537)
        if reaper.ImGui_Button(ctx, " GENERATE ALGORITHMIC ARRANGEMENT IN REAPER ", -1, 44) then
            run_composition_engine()
            save_settings(s1, s2, mix, comp, seed, chords, clean_tracks, preset_idx, opts)
        end
        reaper.ImGui_PopStyleColor(ctx, 3)
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_InputTextMultiline(ctx, "##report", report_text, -1, 150, reaper.ImGui_InputTextFlags_ReadOnly())
        reaper.ImGui_End(ctx)
    end

    if open then 
        reaper.defer(render_imgui) 
    else 
        save_settings(s1, s2, mix, comp, seed, chords, clean_tracks, preset_idx, opts) 
    end
end

-- ==============================================================================
-- ★ INIT
-- ==============================================================================
math.randomseed(os.time())
reaper.defer(render_imgui)