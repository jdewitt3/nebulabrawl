extends RefCounted
## FILL-IN SOUND EFFECTS, made in code.
##
## Every SFX cue has a recipe below, so any cue without a file can get a rough
## placeholder (TITLE > AUDIO CUE LIST > [FILL-IN SOUNDS]). Fill-ins are rendered
## into memory when the game runs. They are never written to res://audio/sfx/,
## and a real file with the cue's name always plays instead.
##
## A recipe is a list of layers mixed together. Layer keys (all optional except d):
##   w     wave: sine, tri, square, saw, noise          f    Hz, or [start, end] for a sweep
##   d     duration (s)        t  delay (s)             v    volume (0..1)
##   a     attack (s)          s  decay curve (higher = snappier; 0 = flat then cut)
##   k     sweep curve (<1 sweeps early, >1 late)       duty pulse width for square
##   lp    low-pass Hz, or [start, end]                 hp   high-pass Hz
##   vib   [rate Hz, depth semitones]                   fm   [ratio, index] (sine/tri only)
##   rep   [count, gap s] repeats the layer;  rf / rv multiply pitch / volume per repeat
##   crush sample-and-hold rate in Hz (bit-crushed grit)
##
## Takes: take 1 is the recipe exactly as written. Every later take ("NEW TAKE")
## nudges pitch, length, brightness and layer balance by a random amount that is
## fixed for that cue and take number, so a take always sounds the same.

const RATE := 22050

const RECIPES := {
	# ---------------------------------------------------------------- menus & text
	"menu_move": [{"w": "tri", "f": 1500.0, "d": 0.035, "v": 0.22, "s": 3.0}],
	"menu_select": [{"w": "square", "duty": 0.25, "f": 880.0, "d": 0.05, "v": 0.15, "lp": 5000.0},
		{"w": "square", "duty": 0.25, "f": 1320.0, "t": 0.05, "d": 0.09, "v": 0.15, "lp": 5000.0}],
	"menu_back": [{"w": "square", "duty": 0.25, "f": [900.0, 520.0], "d": 0.08, "v": 0.14, "lp": 4000.0}],
	"menu_error": [{"w": "square", "f": 180.0, "d": 0.08, "v": 0.2, "lp": 1500.0, "rep": [2, 0.1]}],
	"text_blip": [{"w": "square", "duty": 0.25, "f": 1050.0, "d": 0.022, "v": 0.09, "lp": 3500.0, "s": 1.5}],

	# ---------------------------------------------------------------- battle flow
	"encounter": [{"w": "saw", "f": [180.0, 1500.0], "d": 0.9, "v": 0.12, "k": 0.8, "lp": [900.0, 4500.0], "vib": [16.0, 1.2], "s": 0.7},
		{"w": "noise", "d": 0.9, "v": 0.14, "lp": [400.0, 6000.0], "a": 0.3, "s": 1.2},
		{"w": "square", "duty": 0.25, "f": 523.0, "d": 0.07, "v": 0.08, "lp": 5000.0, "rep": [8, 0.1], "rf": 1.12, "rv": 0.92}],
	"run_away": [{"w": "noise", "d": 0.04, "v": 0.22, "lp": 1800.0, "s": 3.0, "rep": [5, 0.07], "rv": 0.85},
		{"w": "tri", "f": [380.0, 1700.0], "t": 0.18, "d": 0.4, "v": 0.18, "k": 0.7, "vib": [8.0, 0.3]}],
	"run_fail": [{"w": "noise", "d": 0.04, "v": 0.22, "lp": 1800.0, "s": 3.0, "rep": [3, 0.07]},
		{"w": "noise", "t": 0.24, "d": 0.12, "v": 0.32, "lp": 900.0, "s": 2.5},
		{"w": "sine", "f": [180.0, 70.0], "t": 0.24, "d": 0.14, "v": 0.32},
		{"w": "square", "f": [460.0, 230.0], "t": 0.34, "d": 0.32, "v": 0.1, "lp": 1600.0, "vib": [6.0, 0.4], "s": 1.0}],

	# ---------------------------------------------------------------- BASH timing bar
	"timing_start": [{"w": "square", "duty": 0.25, "f": [500.0, 1000.0], "d": 0.07, "v": 0.13, "k": 0.5, "lp": 5000.0},
		{"w": "tri", "f": 2000.0, "t": 0.07, "d": 0.05, "v": 0.12}],
	"timing_perfect": [{"w": "sine", "f": 1568.0, "d": 0.5, "v": 0.18, "s": 2.2},
		{"w": "sine", "f": 2349.0, "d": 0.4, "v": 0.1, "s": 2.5},
		{"w": "tri", "f": 1046.0, "d": 0.06, "v": 0.14, "rep": [3, 0.045], "rf": 1.26},
		{"w": "noise", "t": 0.05, "d": 0.45, "v": 0.05, "hp": 6500.0, "a": 0.05}],
	"timing_great": [{"w": "sine", "f": 1175.0, "d": 0.32, "v": 0.17, "s": 2.5},
		{"w": "sine", "f": 1568.0, "t": 0.05, "d": 0.3, "v": 0.12, "s": 2.5}],
	"timing_good": [{"w": "sine", "f": 988.0, "d": 0.24, "v": 0.17, "s": 2.8},
		{"w": "tri", "f": 1976.0, "d": 0.08, "v": 0.04}],
	"timing_weak": [{"w": "tri", "f": [330.0, 260.0], "d": 0.13, "v": 0.22, "s": 2.5},
		{"w": "noise", "d": 0.06, "v": 0.14, "lp": 900.0, "s": 3.0}],
	"timing_miss": [{"w": "square", "f": [420.0, 150.0], "d": 0.36, "v": 0.13, "lp": 1400.0, "s": 1.2, "vib": [7.0, 0.3]}],

	# ---------------------------------------------------------------- attacks
	"attack_swing": [{"w": "noise", "d": 0.16, "v": 0.28, "lp": [1200.0, 5200.0], "hp": 600.0, "a": 0.03, "s": 1.6},
		{"w": "saw", "f": [200.0, 120.0], "d": 0.13, "v": 0.1, "lp": 900.0}],
	"attack_hit": [{"w": "noise", "d": 0.07, "v": 0.38, "lp": 3400.0, "s": 3.0},
		{"w": "sine", "f": [240.0, 85.0], "d": 0.12, "v": 0.42},
		{"w": "square", "f": [900.0, 300.0], "d": 0.04, "v": 0.08, "lp": 3000.0}],
	"critical_hit": [{"w": "noise", "d": 0.5, "v": 0.5, "lp": [7000.0, 600.0], "s": 2.2},
		{"w": "sine", "f": [180.0, 40.0], "d": 0.45, "v": 0.55},
		{"w": "square", "f": [1300.0, 250.0], "d": 0.12, "v": 0.12, "lp": 4500.0},
		{"w": "sine", "f": 2637.0, "t": 0.03, "d": 0.5, "v": 0.08, "s": 2.0},
		{"w": "noise", "t": 0.1, "d": 0.05, "v": 0.2, "lp": 2500.0, "rep": [3, 0.08], "rv": 0.7}],
	"miss": [{"w": "noise", "d": 0.12, "v": 0.2, "hp": 1500.0, "lp": [3000.0, 7000.0], "a": 0.02, "s": 1.8},
		{"w": "tri", "f": [950.0, 480.0], "t": 0.04, "d": 0.2, "v": 0.14, "k": 0.6}],
	"enemy_attack": [{"w": "saw", "f": [150.0, 420.0], "d": 0.22, "v": 0.15, "lp": 1600.0, "vib": [25.0, 0.8], "k": 1.4, "a": 0.04},
		{"w": "noise", "d": 0.18, "v": 0.18, "lp": [800.0, 2600.0], "hp": 300.0, "a": 0.05}],
	"player_hurt": [{"w": "square", "duty": 0.35, "f": [440.0, 160.0], "d": 0.16, "v": 0.2, "lp": 2400.0},
		{"w": "noise", "d": 0.1, "v": 0.3, "lp": 2600.0, "s": 3.0},
		{"w": "sine", "f": [160.0, 60.0], "d": 0.14, "v": 0.3}],
	"guard": [{"w": "tri", "f": 1250.0, "d": 0.22, "v": 0.14, "fm": [1.41, 1.5], "s": 2.2},
		{"w": "noise", "d": 0.04, "v": 0.22, "hp": 2500.0, "s": 3.0},
		{"w": "sine", "f": [220.0, 140.0], "d": 0.1, "v": 0.22}],
	"stun": [{"w": "tri", "f": 1400.0, "d": 0.6, "v": 0.1, "vib": [11.0, 2.0], "s": 1.0},
		{"w": "sine", "f": [1900.0, 2500.0], "d": 0.06, "v": 0.09, "k": 0.5, "rep": [4, 0.13], "rf": 0.94},
		{"w": "noise", "d": 0.05, "v": 0.18, "lp": 2000.0, "s": 3.0}],

	# ---------------------------------------------------------------- techs
	"tech_laser": [{"w": "square", "f": [1900.0, 320.0], "d": 0.11, "v": 0.15, "k": 0.5, "lp": 5000.0, "rep": [3, 0.13], "rf": 0.94},
		{"w": "sine", "f": [900.0, 260.0], "d": 0.1, "v": 0.12, "fm": [2.5, 3.0], "rep": [3, 0.13], "rf": 0.94},
		{"w": "noise", "d": 0.03, "v": 0.1, "hp": 3000.0, "rep": [3, 0.13]}],
	"tech_overdrive": [{"w": "saw", "f": [70.0, 520.0], "d": 0.55, "v": 0.16, "k": 1.3, "lp": [500.0, 3500.0], "vib": [30.0, 0.5], "a": 0.05, "s": 0.4},
		{"w": "square", "f": [35.0, 260.0], "d": 0.55, "v": 0.07, "k": 1.3, "lp": 1200.0, "s": 0.4},
		{"w": "noise", "t": 0.52, "d": 0.45, "v": 0.5, "lp": [6000.0, 500.0], "s": 2.2},
		{"w": "sine", "f": [160.0, 38.0], "t": 0.52, "d": 0.45, "v": 0.55}],
	"tech_zap": [{"w": "saw", "f": [1700.0, 260.0], "d": 0.16, "v": 0.15, "crush": 4500.0, "lp": 6500.0},
		{"w": "noise", "d": 0.05, "v": 0.18, "hp": 2500.0, "crush": 7000.0, "rep": [4, 0.06], "rv": 0.8},
		{"w": "square", "f": 110.0, "d": 0.32, "v": 0.08, "lp": 900.0, "vib": [50.0, 1.0], "s": 1.5}],
	"tech_shield": [{"w": "sine", "f": [180.0, 620.0], "d": 0.5, "v": 0.22, "k": 0.6, "vib": [12.0, 0.3], "s": 1.2},
		{"w": "tri", "f": 1240.0, "t": 0.15, "d": 0.45, "v": 0.06, "vib": [16.0, 0.2], "a": 0.08},
		{"w": "noise", "d": 0.4, "v": 0.06, "lp": 1800.0, "a": 0.1}],
	"tech_psi": [{"w": "sine", "f": [100.0, 45.0], "d": 1.3, "v": 0.3, "a": 0.25, "s": 1.2, "vib": [4.0, 0.5]},
		{"w": "noise", "d": 1.2, "v": 0.14, "lp": [600.0, 4500.0], "a": 0.5, "s": 1.0},
		{"w": "tri", "f": 2637.0, "t": 0.1, "d": 0.18, "v": 0.09, "rep": [8, 0.11], "rf": 0.89, "rv": 0.95},
		{"w": "sine", "f": 3951.0, "t": 0.15, "d": 0.12, "v": 0.05, "rep": [6, 0.15], "rf": 0.84}],
	"heal": [{"w": "sine", "f": 784.0, "d": 0.2, "v": 0.15, "rep": [3, 0.07], "rf": 1.26},
		{"w": "sine", "f": [1568.0, 2093.0], "t": 0.14, "d": 0.35, "v": 0.07, "a": 0.05, "vib": [6.0, 0.15]},
		{"w": "noise", "t": 0.1, "d": 0.35, "v": 0.04, "hp": 6500.0, "a": 0.1}],
	"energy": [{"w": "saw", "f": [300.0, 1300.0], "d": 0.3, "v": 0.1, "k": 0.7, "crush": 6000.0, "lp": 4000.0},
		{"w": "sine", "f": 1320.0, "t": 0.22, "d": 0.3, "v": 0.13, "s": 2.0},
		{"w": "sine", "f": 1980.0, "t": 0.28, "d": 0.28, "v": 0.08, "s": 2.0},
		{"w": "noise", "d": 0.2, "v": 0.06, "hp": 4000.0, "crush": 8000.0}],
	"revive": [{"w": "tri", "f": 523.0, "d": 0.18, "v": 0.2, "rep": [4, 0.08], "rf": 1.19},
		{"w": "sine", "f": 1046.0, "t": 0.3, "d": 0.7, "v": 0.13, "a": 0.03, "vib": [5.0, 0.15], "s": 1.5},
		{"w": "sine", "f": 1568.0, "t": 0.3, "d": 0.7, "v": 0.08, "s": 1.5},
		{"w": "noise", "t": 0.25, "d": 0.6, "v": 0.05, "hp": 6500.0, "a": 0.15}],
	"item_use": [{"w": "noise", "d": 0.06, "v": 0.18, "lp": 3000.0, "hp": 800.0, "s": 2.0, "rep": [2, 0.06]},
		{"w": "sine", "f": [600.0, 1300.0], "t": 0.12, "d": 0.08, "v": 0.18, "k": 0.5},
		{"w": "tri", "f": 1760.0, "t": 0.19, "d": 0.08, "v": 0.1}],
	"grenade": [{"w": "noise", "d": 0.75, "v": 0.6, "lp": [5500.0, 300.0], "s": 2.2},
		{"w": "sine", "f": [120.0, 30.0], "d": 0.7, "v": 0.6},
		{"w": "saw", "f": [1400.0, 180.0], "d": 0.35, "v": 0.13, "crush": 3500.0, "lp": 5000.0},
		{"w": "sine", "f": [600.0, 2200.0], "t": 0.05, "d": 0.3, "v": 0.06, "fm": [3.0, 2.0]}],
	"duck_squeak": [{"w": "square", "duty": 0.2, "f": [1050.0, 1650.0], "d": 0.11, "v": 0.14, "k": 0.5, "lp": 3500.0, "vib": [38.0, 0.7], "s": 0.5},
		{"w": "square", "duty": 0.2, "f": [1650.0, 1150.0], "t": 0.11, "d": 0.16, "v": 0.13, "lp": 3500.0, "vib": [38.0, 0.7], "s": 1.5},
		{"w": "noise", "d": 0.25, "v": 0.03, "hp": 3000.0, "a": 0.03}],

	# ---------------------------------------------------------------- enemies
	"enemy_defeat": [{"w": "square", "duty": 0.25, "f": 880.0, "d": 0.06, "v": 0.12, "lp": 4000.0, "rep": [5, 0.06], "rf": 0.84},
		{"w": "noise", "d": 0.45, "v": 0.22, "lp": [4000.0, 400.0], "s": 1.8},
		{"w": "sine", "f": [300.0, 60.0], "d": 0.3, "v": 0.22}],
	"enemy_heal": [{"w": "sine", "f": 440.0, "d": 0.25, "v": 0.14, "rep": [3, 0.1], "rf": 1.19, "fm": [2.0, 1.2]},
		{"w": "tri", "f": [700.0, 900.0], "t": 0.2, "d": 0.4, "v": 0.07, "vib": [9.0, 0.4], "a": 0.08}],
	"drain": [{"w": "saw", "f": [1100.0, 140.0], "d": 0.7, "v": 0.13, "k": 0.6, "lp": [4000.0, 600.0], "vib": [9.0, 0.6], "s": 0.8},
		{"w": "noise", "d": 0.65, "v": 0.14, "lp": [5000.0, 300.0], "a": 0.05, "s": 1.0},
		{"w": "sine", "f": [220.0, 70.0], "t": 0.2, "d": 0.5, "v": 0.2, "a": 0.1}],
	"boss_roar": [{"w": "saw", "f": [72.0, 58.0], "d": 1.4, "v": 0.2, "lp": [500.0, 1600.0], "a": 0.2, "vib": [5.0, 0.5], "crush": 3000.0, "s": 1.0},
		{"w": "saw", "f": [76.0, 61.0], "d": 1.4, "v": 0.18, "lp": [500.0, 1600.0], "a": 0.2, "s": 1.0},
		{"w": "square", "f": [108.0, 88.0], "d": 1.3, "v": 0.09, "lp": 900.0, "a": 0.25, "s": 1.0},
		{"w": "noise", "d": 1.3, "v": 0.16, "lp": 900.0, "a": 0.3, "crush": 5000.0, "s": 1.0},
		{"w": "sine", "f": 7800.0, "d": 1.2, "v": 0.025, "a": 0.4, "s": 1.0}],
	"boss_defeat": [{"w": "noise", "d": 1.4, "v": 0.6, "lp": [6000.0, 220.0], "s": 2.0},
		{"w": "sine", "f": [100.0, 26.0], "d": 1.3, "v": 0.6},
		{"w": "noise", "t": 0.15, "d": 0.08, "v": 0.3, "lp": 2500.0, "rep": [6, 0.15], "rv": 0.8},
		{"w": "square", "f": [800.0, 50.0], "d": 0.9, "v": 0.12, "lp": 2000.0, "crush": 3000.0},
		{"w": "sine", "f": 7800.0, "d": 0.6, "v": 0.03, "s": 3.0}],

	# ---------------------------------------------------------------- the crew
	"party_ko": [{"w": "square", "f": [520.0, 110.0], "d": 0.8, "v": 0.16, "lp": 1800.0, "vib": [7.0, 0.6], "s": 1.2},
		{"w": "noise", "d": 0.12, "v": 0.2, "lp": 2000.0, "s": 3.0},
		{"w": "sine", "f": [130.0, 55.0], "t": 0.6, "d": 0.3, "v": 0.3}],
}

const _WAVES := {"sine": 0, "tri": 1, "square": 2, "saw": 3, "noise": 4}


static func has_recipe(cue: String) -> bool:
	return RECIPES.has(cue)


## Builds the fill-in for a cue (null if it has no recipe). The same cue and take
## always give the same sound.
static func make(cue: String, take := 1) -> AudioStreamWAV:
	if not RECIPES.has(cue):
		return null
	var layers: Array = RECIPES[cue]
	var rng_seed := hash("%s#%d" % [cue, take])
	if take > 1:
		layers = vary(layers, rng_seed)
	return render(layers, rng_seed)


## A new take of a recipe: up to 2 semitones up or down, 15% longer or shorter,
## a little brighter or darker, and a different balance between the layers.
static func vary(layers: Array, rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pitch := pow(2.0, rng.randf_range(-2.0, 2.0) / 12.0)
	var time := rng.randf_range(0.85, 1.15)
	var tone := rng.randf_range(0.8, 1.25)
	var out := []
	for src in layers:
		var l: Dictionary = src.duplicate(true)
		l.d = float(l.d) * time
		if l.has("t"):
			l.t = float(l.t) * time
		if l.has("a"):
			l.a = float(l.a) * time
		if l.has("rep"):
			l.rep = [l.rep[0], float(l.rep[1]) * time]
		if l.get("w", "sine") != "noise":
			l.f = _scale(l.get("f", 440.0), pitch)
		if l.has("lp"):
			l.lp = _scale(l.lp, pitch * tone)
		if l.has("hp"):
			l.hp = float(l.hp) * pitch * tone
		l.v = float(l.get("v", 0.3)) * rng.randf_range(0.75, 1.15)
		out.append(l)
	return out


static func _scale(v: Variant, by: float) -> Variant:
	if v is Array:
		return [float(v[0]) * by, float(v[1]) * by]
	return float(v) * by


static func render(layers: Array, rng_seed: int = 1) -> AudioStreamWAV:
	var total := 0.0
	for l in layers:
		var rep: Array = l.get("rep", [1, 0.0])
		total = maxf(total, float(l.get("t", 0.0)) + (int(rep[0]) - 1) * float(rep[1]) + float(l.d))
	var n := int(total * RATE) + 32
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for l in layers:
		var rep: Array = l.get("rep", [1, 0.0])
		for r in int(rep[0]):
			_voice(buf, l, float(l.get("t", 0.0)) + r * float(rep[1]), r, rng)
	var peak := 0.0
	for x in buf:
		peak = maxf(peak, absf(x))
	var gain := 0.95 / peak if peak > 0.95 else 1.0  # never boost: recipes keep their relative levels
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _voice(buf: PackedFloat32Array, l: Dictionary, start: float, r: int, rng: RandomNumberGenerator) -> void:
	var d: float = l.d
	var wave: int = _WAVES.get(l.get("w", "sine"), 0)
	var f: Variant = l.get("f", 440.0)
	var fr: float = pow(float(l.get("rf", 1.0)), r)
	var f0: float = (float(f[0]) if f is Array else float(f)) * fr
	var f1: float = (float(f[1]) if f is Array else float(f)) * fr
	var ratio := f1 / f0
	var k: float = l.get("k", 1.0)
	var vol: float = float(l.get("v", 0.3)) * pow(float(l.get("rv", 1.0)), r)
	var att: float = maxf(float(l.get("a", 0.004)), 0.001)
	var shape: float = l.get("s", 2.0)
	var lpv: Variant = l.get("lp", 0.0)
	var lp0: float = float(lpv[0]) if lpv is Array else float(lpv)
	var lp1: float = float(lpv[1]) if lpv is Array else float(lpv)
	var hp: float = l.get("hp", 0.0)
	var hp_a := exp(-TAU * hp / RATE)
	var vib: Array = l.get("vib", [0.0, 0.0])
	var vib_r: float = vib[0]
	var vib_d: float = float(vib[1]) / 12.0
	var duty: float = l.get("duty", 0.5)
	var fm: Array = l.get("fm", [0.0, 0.0])
	var fm_r: float = fm[0]
	var fm_i: float = fm[1]
	var crush: float = l.get("crush", 0.0)
	var crush_n := maxi(1, int(RATE / crush)) if crush > 0.0 else 1
	var i0 := int(start * RATE)
	var count := mini(int(d * RATE), buf.size() - i0)
	var ph := 0.0
	var mph := 0.0
	var lp_y := 0.0
	var hp_y := 0.0
	var hp_x := 0.0
	var held := 0.0
	for j in count:
		var t := j / float(RATE)
		var x := t / d
		var freq := f0 * pow(ratio, pow(x, k)) if ratio != 1.0 else f0
		if vib_d != 0.0:
			freq *= pow(2.0, sin(TAU * vib_r * t) * vib_d)
		freq = minf(freq, RATE * 0.45)  # stay under Nyquist after a take's pitch shift
		ph += freq / RATE
		ph -= floorf(ph)
		var s := 0.0
		match wave:
			0:
				s = sin(TAU * ph + (sin(TAU * mph) * fm_i if fm_r > 0.0 else 0.0))
			1:
				var p2 := ph + (sin(TAU * mph) * fm_i * 0.16 if fm_r > 0.0 else 0.0)
				p2 -= floorf(p2)
				s = 4.0 * absf(p2 - 0.5) - 1.0
			2:
				s = 1.0 if ph < duty else -1.0
			3:
				s = 2.0 * ph - 1.0
			4:
				s = rng.randf() * 2.0 - 1.0
		if fm_r > 0.0:
			mph += freq * fm_r / RATE
			mph -= floorf(mph)
		if crush_n > 1:
			if j % crush_n == 0:
				held = s
			s = held
		if lp0 > 0.0:
			var c := minf(lerpf(lp0, lp1, x), RATE * 0.45)
			lp_y += (1.0 - exp(-TAU * c / RATE)) * (s - lp_y)
			s = lp_y
		if hp > 0.0:
			hp_y = hp_a * (hp_y + s - hp_x)
			hp_x = s
			s = hp_y
		var env := minf(t / att, 1.0) * (pow(1.0 - x, shape) if shape > 0.0 else 1.0)
		buf[i0 + j] += s * env * vol
