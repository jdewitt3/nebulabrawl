extends Node
## AUDIO HOOKS (autoloaded as "Audio")
##
## The game never points at audio files directly. It asks for cues by NAME and
## this script looks for a matching file:
##     res://audio/music/<cue>.ogg / .wav / .mp3
##     res://audio/sfx/<cue>.ogg / .wav / .mp3
## No file yet? Nothing plays, but the cue still shows up in the on-screen
## HUD (toggle with F1) so you can see exactly when each one fires.
##
## Music rules:
##   * Cues with "_loop" in the name loop automatically.
##   * "<set>_intro" plays once, then hands off to "<set>_loop".
##   * "<loop>_danger" is an optional LAYER: it starts in sync with <loop>
##     (silent) and fades in while any crew member is at low HP.
##     Make it the same length/tempo as the loop it belongs to!

const PixelFont := preload("res://scripts/pixel_font.gd")
const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const LAYER_SUFFIX := "_danger"

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
	"attack_swing": "Crew member starts a basic attack.",
	"attack_hit": "Attack connects with an enemy.",
	"critical_hit": "SMAAAASH!! critical hit.",
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

var hud_visible := true
var hud_hidden := false  # screens can hide the HUD temporarily
var hud_y := 36

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
	_music.stream = stream
	_music.volume_db = linear_to_db(0.0001) if fade > 0.0 else 0.0
	_music.play()
	_start_layer(cue)
	if fade > 0.0:
		_fade = create_tween().set_parallel()
		_fade.tween_method(_set_vol.bind(_music), 0.0, 1.0, fade)
		if _music_old.playing:
			_fade.tween_method(_set_vol.bind(_music_old), db_to_linear(_music_old.volume_db), 0.0, fade)
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
			_fade.tween_method(_set_vol.bind(p), db_to_linear(p.volume_db), 0.0, fade)
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
	_layer_fade.tween_method(_set_vol.bind(_layer), db_to_linear(_layer.volume_db), 1.0 if on else 0.0, 1.0)


func play_sfx(cue: String, quiet := false) -> void:
	var s := _load(SFX_DIR, cue)
	if not quiet:
		_note("SFX " + cue, s != null)
	if s == null:
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = s
	p.play()


func has_music(cue: String) -> bool:
	return _load(MUSIC_DIR, cue) != null


func has_sfx(cue: String) -> bool:
	return _load(SFX_DIR, cue) != null


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
	p.volume_db = linear_to_db(maxf(v, 0.0001))


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
	_layer.stream = ls
	_layer.volume_db = 0.0 if _danger else linear_to_db(0.0001)
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

func _note(text: String, found: bool) -> void:
	_events.append({"text": text, "found": found, "age": 0.0})
	if _events.size() > 4:
		_events.pop_front()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		hud_visible = not hud_visible


func _process(delta: float) -> void:
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
		var c: Color = GREEN if e.found else DIM
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
