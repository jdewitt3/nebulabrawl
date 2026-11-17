extends Node
## AUDIO HOOKS (autoloaded as "Audio")
##
## The game never points at audio files directly. It asks for cues by NAME and
## this script looks for a matching file:
##     res://audio/music/<cue>.ogg / .wav / .mp3
##     res://audio/sfx/<cue>.ogg / .wav / .mp3
## No file yet? Nothing plays (unless the SFX cue has a fill-in, see below), but
## the cue still shows up in the on-screen HUD (toggle with F1) so you can see
## exactly when each one fires.
##
## Music rules:
##   * Cues with "_loop" in the name loop automatically.
##   * "<set>_intro" plays once, then hands off to "<set>_loop".
##   * "<loop>_danger" is an optional LAYER: it starts in sync with <loop>
##     (silent) and fades in while any crew member is at low HP.
##     Make it the same length/tempo as the loop it belongs to!
##
## Per-cue volume: set in-game from TITLE > AUDIO CUE LIST (pick a cue, press Z).
## Saved to res://audio/volumes.cfg so the mix travels with the project.
##
## Fill-in SFX: TITLE > AUDIO CUE LIST > [FILL-IN SOUNDS] can generate a rough
## placeholder for every SFX cue that has no file (recipes in sfx_synth.gd).
## Fill-ins are rendered in memory, never written to audio/sfx/, and a real file
## always plays instead. Which cues use one (and which take) is saved to
## res://audio/fillins.cfg.

const PixelFont := preload("res://scripts/pixel_font.gd")
const SfxSynth := preload("res://scripts/sfx_synth.gd")
const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const LAYER_SUFFIX := "_danger"
const VOLUME_FILE := "res://audio/volumes.cfg"
const VOLUME_FILE_FALLBACK := "user://volumes.cfg"  # used if res:// is read-only (exported builds)
const VOLUME_MIN := -30.0
const VOLUME_MAX := 12.0
const FILLIN_FILE := "res://audio/fillins.cfg"
const FILLIN_FILE_FALLBACK := "user://fillins.cfg"

const MUSIC_CUES := {
	"title_loop": "Title screen.",
	"battle_intro": "Normal battle starts (one-shot, then battle_loop).",
	"battle_loop": "Normal battle music.",
	"battle_loop_danger": "Layer over battle_loop when someone is low on HP.",
	"boss_intro": "Boss battle starts (one-shot, then boss_loop).",
	"boss_loop": "Boss battle music, phase 1.",
	"boss_loop_danger": "Layer over boss_loop when someone is low on HP.",
	"boss_phase2_loop": "Boss drops below 50% HP. Crossfades from boss_loop.",
	"boss_phase2_loop_danger": "Layer over boss_phase2_loop.",
	"victory": "You won! (one-shot, then victory_loop).",
	"victory_loop": "Optional loop after the victory fanfare.",
	"defeat": "The whole crew got knocked out.",
	"flee": "The crew ran away successfully.",
}

const SFX_CUES := {
	"menu_move": "Cursor moves.",
	"menu_select": "Confirm a choice.",
	"menu_back": "Cancel / go back.",
	"menu_error": "Can't do that (no EN, etc.).",
	"text_blip": "Typewriter text ticks (every few letters).",
	"encounter": "Battle transition swirl.",
	"timing_start": "BASH timing bar appears.",
	"timing_perfect": "Timing: pressed dead center.",
	"timing_great": "Timing: close to center.",
	"timing_good": "Timing: inside the zone.",
	"timing_weak": "Timing: pressed outside the zone.",
	"timing_miss": "Timing: never pressed.",
	"attack_swing": "Basic attack swings (after the timing bar).",
	"attack_hit": "Attack connects with an enemy.",
	"critical_hit": "SMAAAASH!! (a PERFECT on the timing bar).",
	"miss": "Attack misses.",
	"enemy_attack": "Enemy lunges to attack.",
	"player_hurt": "Crew member takes damage.",
	"enemy_defeat": "An enemy is defeated.",
	"boss_defeat": "The boss explodes.",
	"party_ko": "A crew member's HP meter hits zero.",
	"guard": "Crew member guards.",
	"heal": "HP restored.",
	"energy": "EN restored.",
	"revive": "KO'd crew member revived.",
	"tech_laser": "LASER VOLLEY.",
	"tech_overdrive": "OVERDRIVE.",
	"tech_zap": "ARC WELDER.",
	"tech_shield": "SHIELD WALL.",
	"tech_psi": "STARSTORM.",
	"stun": "Someone gets stunned.",
	"drain": "Boss drains EN.",
	"enemy_heal": "Enemy heals itself.",
	"item_use": "Using an item.",
	"grenade": "PLASMA GRENADE explosion.",
	"duck_squeak": "The rubber duck.",
	"run_away": "Successfully fled.",
	"run_fail": "Couldn't escape.",
	"boss_roar": "Boss appears / enters phase 2.",
}

const GREEN := Color("66ff99")
const DIM := Color("9090b0")
const RED := Color("ff4466")
const FILL := Color("66ccff")  # a generated fill-in is playing

var hud_visible := true
var hud_hidden := false  # screens can hide the HUD temporarily
var hud_y := 36
var sfx_dir := SFX_DIR  # tests point these somewhere else
var fillin_file := FILLIN_FILE

var _music: AudioStreamPlayer
var _music_old: AudioStreamPlayer  # the outgoing track during a crossfade
var _layer: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _current := ""
var _current_found := false
var _next_loop := ""
var _danger := false
var _fade: Tween
var _layer_fade: Tween
var _cache := {}
var _events: Array = []
var _hud: Node2D

# Volume = per-cue trim (dB, from the mixer) + fader (0..1, for fades/layers).
var _volumes := {"music": {}, "sfx": {}}
var _trim := {}    # player -> trim dB of the cue it's playing
var _fader := {}   # player -> fade level 0..1
var _cue_of := {}  # player -> cue name it's playing

# Fill-ins: _fillins (cue -> take number) is the saved state and is only touched
# on the main thread. Rendered sounds go in _rendered (cue -> [take, stream]),
# which a background task also writes, so it's guarded by _render_lock.
var _fillins := {}
var _rendered := {}
var _render_lock := Mutex.new()
var _render_task := -1
var _render_dirty := false
var _found_path := {}  # _load() key -> the file it found


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music = _make_player("Music")
	_music_old = _make_player("Music")
	_layer = _make_player("Music")
	_music.finished.connect(_on_music_finished.bind(_music))
	_music_old.finished.connect(_on_music_finished.bind(_music_old))
	for i in 10:
		_sfx.append(_make_player("SFX"))
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_hud = Node2D.new()
	_hud.draw.connect(_draw_hud)
	canvas.add_child(_hud)
	_load_volumes()
	_load_fillins()


func _exit_tree() -> void:
	if _render_task != -1:
		WorkerThreadPool.wait_for_task_completion(_render_task)
		_render_task = -1


# --- public API --------------------------------------------------------------

## Play a music cue. fade > 0 crossfades from whatever is playing.
## then_loop: cue to start when this one ends (for intro -> loop).
func play_music(cue: String, fade := 0.0, then_loop := "") -> void:
	if cue == _current and (_music.playing or not _current_found):
		return
	if _fade and _fade.is_valid():
		_fade.kill()
	_music_old.stop()
	_layer.stop()
	var stream := _load(MUSIC_DIR, cue)
	_current = cue
	_current_found = stream != null
	_next_loop = then_loop
	_note("♪ " + cue, _current_found)
	if stream == null:
		_music.stop()
		if then_loop != "":
			_next_loop = ""
			play_music(then_loop, fade)
		return
	if fade > 0.0 and _music.playing:
		var tmp := _music_old
		_music_old = _music
		_music = tmp
	else:
		_music.stop()
	_assign(_music, "music", cue, stream)
	_set_vol(0.0 if fade > 0.0 else 1.0, _music)
	_music.play()
	_start_layer(cue)
	if fade > 0.0:
		_fade = create_tween().set_parallel()
		_fade.tween_method(_set_vol.bind(_music), 0.0, 1.0, fade)
		if _music_old.playing:
			_fade.tween_method(_set_vol.bind(_music_old), _fader.get(_music_old, 1.0), 0.0, fade)
		_fade.chain().tween_callback(_music_old.stop)


## Convenience: "<set>_intro" then "<set>_loop".
func play_set(set_name: String) -> void:
	play_music(set_name + "_intro", 0.0, set_name + "_loop")


func stop_music(fade := 0.5) -> void:
	_next_loop = ""
	_current = ""
	_current_found = false
	if _fade and _fade.is_valid():
		_fade.kill()
	if fade <= 0.0:
		_stop_all()
		return
	_fade = create_tween().set_parallel()
	for p in [_music, _music_old, _layer]:
		if p.playing:
			_fade.tween_method(_set_vol.bind(p), _fader.get(p, 1.0), 0.0, fade)
	_fade.chain().tween_callback(_stop_all)


## Fade the "_danger" layer in or out.
func set_danger(on: bool) -> void:
	if on == _danger:
		return
	_danger = on
	_note("DANGER " + ("ON" if on else "OFF"), _layer.playing)
	if _layer_fade and _layer_fade.is_valid():
		_layer_fade.kill()
	if not _layer.playing:
		return
	_layer_fade = create_tween()
	_layer_fade.tween_method(_set_vol.bind(_layer), _fader.get(_layer, 1.0), 1.0 if on else 0.0, 1.0)


## Plays the cue's file, or its fill-in if it has no file (see sfx_stream()).
func play_sfx(cue: String, quiet := false) -> void:
	var s := _load(sfx_dir, cue)
	var fill := false
	if s == null:
		s = _fillin(cue)
		fill = s != null
	if not quiet:
		_note("SFX " + cue, s != null and not fill, fill)
	if s == null:
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	_assign(p, "sfx", cue, s)
	_set_vol(1.0, p)
	p.play()


## Restart a cue from the top (used by the cue list / mixer).
func audition(kind: String, cue: String) -> void:
	if kind == "sfx":
		play_sfx(cue)
	else:
		stop_music(0.0)
		play_music(cue)


func get_volume(kind: String, cue: String) -> float:
	return _volumes[kind].get(cue, 0.0)


## Set a cue's volume trim in dB. Applies immediately, even mid-playback.
func set_volume(kind: String, cue: String, db: float) -> void:
	db = clampf(db, VOLUME_MIN, VOLUME_MAX)
	if is_zero_approx(db):
		_volumes[kind].erase(cue)
	else:
		_volumes[kind][cue] = db
	for p in _cue_of:
		if _cue_of[p] == kind + "/" + cue:
			_trim[p] = db
			_apply_vol(p)


func save_volumes() -> void:
	var cfg := ConfigFile.new()
	for kind in _volumes:
		for cue in _volumes[kind]:
			cfg.set_value(kind, cue, _volumes[kind][cue])
	if cfg.save(VOLUME_FILE) != OK:
		cfg.save(VOLUME_FILE_FALLBACK)


func has_music(cue: String) -> bool:
	return _load(MUSIC_DIR, cue) != null


## True if a sound effect has a supplied file (fill-ins don't count).
func has_sfx(cue: String) -> bool:
	return _load(sfx_dir, cue) != null


## Look for new or removed files on the next lookup (cached results are dropped).
func rescan() -> void:
	_cache.clear()
	_found_path.clear()


# --- fill-in sound effects ---------------------------------------------------

## Where a sound effect comes from: "file" (supplied), "fill-in" (generated)
## or "none". A supplied file always wins, even over an existing fill-in.
func sfx_source(cue: String) -> String:
	if has_sfx(cue):
		return "file"
	return "fill-in" if _fillins.has(cue) else "none"


## What play_sfx() would play for a cue right now (null = silence).
func sfx_stream(cue: String) -> AudioStream:
	var s := _load(sfx_dir, cue)
	return s if s else _fillin(cue)


## The supplied file a cue plays ("" if there isn't one). kind: "music" or "sfx".
func file_for(kind: String, cue: String) -> String:
	var dir := MUSIC_DIR if kind == "music" else sfx_dir
	return _found_path.get(dir + cue, "") if _load(dir, cue) != null else ""


## SFX cues with no file and no fill-in.
func missing_sfx() -> Array:
	return SFX_CUES.keys().filter(func(c): return sfx_source(c) == "none" and SfxSynth.has_recipe(c))


## SFX cues currently playing a fill-in (a cue with a supplied file isn't one).
func fillin_cues() -> Array:
	return SFX_CUES.keys().filter(func(c): return sfx_source(c) == "fill-in")


## Which take of its fill-in a cue uses (0 = it has none).
func fillin_take(cue: String) -> int:
	return _fillins.get(cue, 0)


## Make a fill-in for every SFX cue that has neither a file nor a fill-in.
## Returns how many were made. Supplied files are never touched.
func generate_fillins() -> int:
	var made := 0
	for cue in missing_sfx():
		_fillins[cue] = 1
		made += 1
	_fillins_changed()
	return made


## Make a fill-in for one cue (only if it has no file). Returns true if made.
func generate_fillin(cue: String) -> bool:
	if sfx_source(cue) != "none" or not SfxSynth.has_recipe(cue):
		return false
	_fillins[cue] = 1
	_fillins_changed()
	return true


## Replace a cue's fill-in with a new take (a variation on the same recipe).
func new_take(cue: String) -> bool:
	if sfx_source(cue) != "fill-in":
		return false
	_fillins[cue] += 1
	_fillins_changed()
	return true


## A new take for every cue playing a fill-in. Returns how many changed.
func new_takes() -> int:
	var cues := fillin_cues()
	for cue in cues:
		_fillins[cue] += 1
	_fillins_changed()
	return cues.size()


func clear_fillin(cue: String) -> void:
	_fillins.erase(cue)
	_fillins_changed()


## Remove every fill-in, including dormant ones under a supplied file.
## Returns how many were playing.
func clear_fillins() -> int:
	var n := fillin_cues().size()
	_fillins.clear()
	_fillins_changed()
	return n


## How many fill-ins are still waiting to be rendered in the background.
## (Playing one before it's ready just renders it on the spot.)
func fillins_rendering() -> int:
	return _stale_fillins().size()


# --- internals ---------------------------------------------------------------

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, "Master")


func _set_vol(v: float, p: AudioStreamPlayer) -> void:
	_fader[p] = v
	_apply_vol(p)


func _apply_vol(p: AudioStreamPlayer) -> void:
	p.volume_db = linear_to_db(maxf(_fader.get(p, 1.0), 0.0001)) + _trim.get(p, 0.0)


## Load a cue into a player and pick up that cue's volume trim.
func _assign(p: AudioStreamPlayer, kind: String, cue: String, stream: AudioStream) -> void:
	p.stream = stream
	_cue_of[p] = kind + "/" + cue
	_trim[p] = get_volume(kind, cue)


func _load_volumes() -> void:
	for path in [VOLUME_FILE, VOLUME_FILE_FALLBACK]:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		for kind in _volumes:
			if cfg.has_section(kind):
				for cue in cfg.get_section_keys(kind):
					_volumes[kind][cue] = float(cfg.get_value(kind, cue))


## The rendered fill-in for a cue (null if it has none). Renders it now if the
## background pass hasn't got to it yet.
func _fillin(cue: String) -> AudioStreamWAV:
	var take: int = _fillins.get(cue, 0)
	if take == 0:
		return null
	_render_lock.lock()
	var r: Array = _rendered.get(cue, [])
	_render_lock.unlock()
	if not r.is_empty() and r[0] == take:
		return r[1]
	var w := SfxSynth.make(cue, take)
	_render_lock.lock()
	_rendered[cue] = [take, w]
	_render_lock.unlock()
	return w


## [cue, take] pairs whose current take hasn't been rendered yet.
func _stale_fillins() -> Array:
	var jobs := []
	_render_lock.lock()
	for cue in _fillins:
		var r: Array = _rendered.get(cue, [])
		if r.is_empty() or r[0] != _fillins[cue]:
			jobs.append([cue, _fillins[cue]])
	_render_lock.unlock()
	return jobs


func _fillins_changed() -> void:
	_render_lock.lock()
	for cue in _rendered.keys():
		if not _fillins.has(cue):
			_rendered.erase(cue)
	_render_lock.unlock()
	_render_dirty = true
	save_fillins()


func save_fillins() -> void:
	var cfg := ConfigFile.new()
	for cue in _fillins:
		cfg.set_value("sfx", cue, _fillins[cue])
	if cfg.save(fillin_file) != OK and fillin_file == FILLIN_FILE:
		cfg.save(FILLIN_FILE_FALLBACK)


func _load_fillins() -> void:
	_fillins.clear()
	var paths := [fillin_file]
	if fillin_file == FILLIN_FILE:
		paths.append(FILLIN_FILE_FALLBACK)
	for path in paths:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		if cfg.has_section("sfx"):
			for cue in cfg.get_section_keys("sfx"):
				if SFX_CUES.has(cue) and SfxSynth.has_recipe(cue):
					_fillins[cue] = maxi(1, int(cfg.get_value("sfx", cue)))
		break
	_render_dirty = true


## Starts a background render for fill-ins that need one (called every frame).
func _pump_renders() -> void:
	if _render_task != -1:
		if not WorkerThreadPool.is_task_completed(_render_task):
			return
		WorkerThreadPool.wait_for_task_completion(_render_task)
		_render_task = -1
	if not _render_dirty:
		return
	_render_dirty = false
	var jobs := _stale_fillins()
	if not jobs.is_empty():
		_render_task = WorkerThreadPool.add_task(_render_jobs.bind(jobs), false, "fill-in sfx")


## Runs on a worker thread: only reads its job list and writes _rendered.
func _render_jobs(jobs: Array) -> void:
	for job in jobs:
		_render_lock.lock()
		var r: Array = _rendered.get(job[0], [])
		_render_lock.unlock()
		if not r.is_empty() and r[0] == job[1]:
			continue  # already rendered on the spot by play_sfx()
		var w := SfxSynth.make(job[0], job[1])
		_render_lock.lock()
		_rendered[job[0]] = [job[1], w]
		_render_lock.unlock()


func _stop_all() -> void:
	_music.stop()
	_music_old.stop()
	_layer.stop()


func _start_layer(cue: String) -> void:
	if not cue.ends_with("_loop"):
		return
	var ls := _load(MUSIC_DIR, cue + LAYER_SUFFIX)
	if ls == null:
		return
	_assign(_layer, "music", cue + LAYER_SUFFIX, ls)
	_set_vol(1.0 if _danger else 0.0, _layer)
	_layer.play()


func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p == _music and _next_loop != "":
		var n := _next_loop
		_next_loop = ""
		play_music(n)


func _load(dir: String, cue: String) -> AudioStream:
	var key := dir + cue
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for ext in EXTENSIONS:
		var path: String = dir + cue + "." + ext
		if ResourceLoader.exists(path):
			s = load(path)
		elif FileAccess.file_exists(path):
			s = _load_raw(path, ext)  # not imported yet (e.g. dropped in while the editor was closed)
		if s:
			_found_path[key] = path
			break
	if s and dir == MUSIC_DIR:
		_set_loop(s, cue.contains("_loop"))
	_cache[key] = s
	return s


func _load_raw(path: String, ext: String) -> AudioStream:
	match ext:
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			var m := AudioStreamMP3.new()
			m.data = FileAccess.get_file_as_bytes(path)
			return m
	return null


func _set_loop(s: AudioStream, loop: bool) -> void:
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = loop
	elif s is AudioStreamWAV:
		if loop:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		else:
			s.loop_mode = AudioStreamWAV.LOOP_DISABLED


# --- on-screen cue HUD -------------------------------------------------------

func _note(text: String, found: bool, fill := false) -> void:
	_events.append({"text": text, "found": found, "fill": fill, "age": 0.0})
	if _events.size() > 4:
		_events.pop_front()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		hud_visible = not hud_visible


func _process(delta: float) -> void:
	_pump_renders()
	for e in _events:
		e.age += delta
	_events = _events.filter(func(e): return e.age < 6.0)
	_hud.queue_redraw()


func _draw_hud() -> void:
	if not hud_visible or hud_hidden:
		return
	var lines := []
	if _current == "":
		lines.append(["NOW ♪ -", DIM])
	else:
		lines.append(["NOW ♪ " + _current, GREEN if _current_found else DIM])
	if _danger:
		lines.append(["+ DANGER LAYER", RED])
	for e in _events:
		var c: Color = GREEN if e.found else (FILL if e.fill else DIM)
		c.a = 1.0 if e.age < 4.0 else 0.5
		lines.append([e.text, c])
	var y := hud_y
	for l in lines:
		var text: String = l[0]
		var w: int = PixelFont.width(text)
		var x := 318 - w
		_hud.draw_rect(Rect2(x - 2, y - 1, w + 4, 9), Color(0, 0, 0, 0.6))
		PixelFont.draw(_hud, Vector2(x, y), text, l[1])
		y += 9
