extends Node
## Checks for fill-in sound effects. Run with:
##   godot --headless --path . -- --test=fillin_test
## Exits 0 if everything passes, 1 if anything fails.
##
## "Supplied" files and the fill-in state go in a scratch folder under user://,
## so your real audio/sfx/, audio/fillins.cfg and audio/volumes.cfg are never
## touched. The real fill-in state is reloaded at the end.

const SfxSynth := preload("res://scripts/sfx_synth.gd")
const Title := preload("res://scripts/title.gd")
const SCRATCH := "user://fillin_test/"

var failures: Array = []


func _ready() -> void:
	print("== Nebula Brawl fill-in SFX checks ==")
	_check_recipes()
	await _check_audio()
	await _check_menu()
	_restore()
	for p in Audio._sfx:
		p.stop()  # quitting mid-sound leaks the playback
	await get_tree().create_timer(0.3).timeout  # let the mixer let go of it
	print("%d failure(s)" % failures.size() if failures else "all checks passed")
	get_tree().quit(1 if failures else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


# --- recipes -----------------------------------------------------------------

func _check_recipes() -> void:
	print("-- recipes")
	var cues: Array = Audio.SFX_CUES.keys()
	var no_recipe := cues.filter(func(c): return not SfxSynth.has_recipe(c))
	check(no_recipe.is_empty(), "every SFX cue has a recipe %s" % ("" if no_recipe.is_empty() else str(no_recipe)))
	var strays := SfxSynth.RECIPES.keys().filter(func(c): return not Audio.SFX_CUES.has(c))
	check(strays.is_empty(), "every recipe belongs to an SFX cue %s" % ("" if strays.is_empty() else str(strays)))

	var started := Time.get_ticks_msec()
	var bad := []
	var seen := {}
	var dupes := []
	for cue in cues:
		var w := SfxSynth.make(cue)
		if w == null:
			continue
		var len_s := w.get_length()
		var peak := _peak(w)
		if len_s < 0.02 or len_s > 2.0 or peak < 0.05 or peak > 1.0:
			bad.append("%s (%.2fs, peak %.2f)" % [cue, len_s, peak])
		var key := str(SfxSynth.RECIPES[cue])
		if seen.has(key):
			dupes.append("%s = %s" % [cue, seen[key]])
		seen[key] = cue
	check(bad.is_empty(), "every fill-in is 0.02-2 s long and audible without clipping %s" % ("" if bad.is_empty() else str(bad)))
	check(dupes.is_empty(), "no two cues share a recipe %s" % ("" if dupes.is_empty() else str(dupes)))
	print("       (rendered %d fill-ins in %d ms)" % [cues.size(), Time.get_ticks_msec() - started])

	var a1 := SfxSynth.make("attack_hit", 1).data
	check(a1 == SfxSynth.make("attack_hit", 1).data, "the same take always renders the same sound")
	var a2 := SfxSynth.make("attack_hit", 2).data
	check(a2 != a1, "take 2 sounds different from take 1")
	check(a2 == SfxSynth.make("attack_hit", 2).data, "take 2 is repeatable too")
	check(SfxSynth.make("not_a_cue") == null, "unknown cues get no fill-in")


func _peak(w: AudioStreamWAV) -> float:
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	return peak / 32768.0


# --- Audio autoload ------------------------------------------------------------

func _check_audio() -> void:
	print("-- generate, new take, clear")
	var res_sfx_before := _listing(Audio.SFX_DIR)
	var sfx := SCRATCH + "sfx/"
	DirAccess.make_dir_recursive_absolute(sfx)
	for f in DirAccess.get_files_at(sfx):
		DirAccess.remove_absolute(sfx + f)
	DirAccess.remove_absolute(SCRATCH + "fillins.cfg")
	Audio.sfx_dir = sfx
	Audio.fillin_file = SCRATCH + "fillins.cfg"
	Audio._load_fillins()  # starts empty: nothing saved in the scratch folder yet
	_write_tone(sfx + "attack_hit.wav")
	var supplied_md5 := FileAccess.get_md5(sfx + "attack_hit.wav")
	Audio.rescan()
	var total: int = Audio.SFX_CUES.size()

	check(Audio.sfx_source("attack_hit") == "file", "a cue with a file reports 'file'")
	check(Audio.sfx_source("miss") == "none", "a cue with nothing reports 'none'")
	check(Audio.sfx_stream("miss") == null, "a cue with nothing is silent")
	check(Audio.missing_sfx().size() == total - 1, "missing count skips the cue with a file")

	check(Audio.generate_fillins() == total - 1, "generate makes one fill-in per missing cue")
	check(Audio.fillin_cues().size() == total - 1, "every missing cue now has a fill-in")
	check(Audio.missing_sfx().is_empty(), "nothing is missing afterwards")
	check(Audio.sfx_source("attack_hit") == "file", "the supplied cue still uses its file")
	check(_is_tone(Audio.sfx_stream("attack_hit")), "the supplied cue still plays its file")
	check(Audio.sfx_source("miss") == "fill-in", "a missing cue reports 'fill-in'")
	check(Audio.fillin_take("miss") == 1, "a new fill-in starts at take 1")
	var miss := Audio.sfx_stream("miss")
	check(miss is AudioStreamWAV and is_equal_approx(miss.get_length(), SfxSynth.make("miss").get_length()),
		"a missing cue plays its own recipe")
	check(Audio.generate_fillins() == 0, "generating again makes nothing new")

	check(DirAccess.get_files_at(sfx) == PackedStringArray(["attack_hit.wav"]), "no fill-in is written into the sfx folder")
	check(FileAccess.get_md5(sfx + "attack_hit.wav") == supplied_md5, "the supplied file is unchanged")
	check(_listing(Audio.SFX_DIR) == res_sfx_before, "res://audio/sfx/ is untouched")

	var cfg := ConfigFile.new()
	check(cfg.load(Audio.fillin_file) == OK and cfg.get_section_keys("sfx").size() == total - 1,
		"fill-ins are saved to the fill-in file")

	var waited := 0
	while Audio.fillins_rendering() > 0 and waited < 600:
		await frames()
		waited += 1
	check(Audio.fillins_rendering() == 0, "background render finishes (%d frames)" % waited)

	# A trim set in the mixer applies to a fill-in too.
	Audio.set_volume("sfx", "guard", -6.0)
	Audio.play_sfx("guard")
	var p: AudioStreamPlayer = Audio._sfx[(Audio._sfx_next - 1 + Audio._sfx.size()) % Audio._sfx.size()]
	check(p.stream == Audio.sfx_stream("guard") and is_equal_approx(p.volume_db, -6.0), "play_sfx plays the fill-in with its volume trim")
	Audio.set_volume("sfx", "guard", 0.0)

	print("-- a real file always wins")
	_write_tone(sfx + "miss.wav")
	Audio.rescan()
	check(Audio.sfx_source("miss") == "file", "a file dropped in later replaces the fill-in")
	check(_is_tone(Audio.sfx_stream("miss")), "...and is what plays")
	check(not Audio.new_take("miss"), "no new take for a cue with a file")
	check(not Audio.generate_fillin("miss"), "no fill-in made for a cue with a file")
	check(Audio.fillin_cues().size() == total - 2, "the fill-in count drops by one")
	DirAccess.remove_absolute(sfx + "miss.wav")
	Audio.rescan()
	check(Audio.sfx_source("miss") == "fill-in", "remove the file and the fill-in comes back")

	print("-- new takes and clearing")
	var take1 := Audio.sfx_stream("menu_move")
	check(Audio.new_take("menu_move") and Audio.fillin_take("menu_move") == 2, "new take moves a cue to take 2")
	check(Audio.sfx_stream("menu_move").data != take1.data, "take 2 plays a different sound")
	var n := Audio.new_takes()
	check(n == total - 1 and Audio.fillin_take("menu_move") == 3 and Audio.fillin_take("heal") == 2,
		"new takes for all moves every fill-in on one take")
	Audio.clear_fillin("heal")
	check(Audio.sfx_source("heal") == "none" and Audio.sfx_stream("heal") == null, "clearing one fill-in silences it")
	check(Audio.generate_fillin("heal") and Audio.fillin_take("heal") == 1, "a cleared cue can get a fresh fill-in")

	var saved: Dictionary = Audio._fillins.duplicate()
	Audio._load_fillins()
	check(Audio._fillins == saved, "fill-ins and their takes survive a restart")

	check(Audio.clear_fillins() == total - 1, "clear all reports how many it removed")
	check(Audio.fillin_cues().is_empty() and Audio.missing_sfx().size() == total - 1, "clear all leaves only the supplied file")
	cfg = ConfigFile.new()
	cfg.load(Audio.fillin_file)
	check(not cfg.has_section("sfx"), "the cleared state is saved")
	check(FileAccess.get_md5(sfx + "attack_hit.wav") == supplied_md5, "the supplied file is still unchanged")


func _write_tone(path: String) -> void:
	SfxSynth.render([{"w": "sine", "f": 440.0, "d": 0.1, "v": 0.3}]).save_to_wav(path)


## Is this the 0.1 s test tone written by _write_tone (and not a fill-in)?
func _is_tone(s: AudioStream) -> bool:
	return s != null and absf(s.get_length() - 0.1) < 0.01


func _listing(dir: String) -> PackedStringArray:
	return DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()


# --- sound menu -------------------------------------------------------------------

func _check_menu() -> void:
	print("-- sound menu")
	var total: int = Audio.SFX_CUES.size()
	var title := Title.new()
	add_child(title)
	await frames()
	title.page = "cues"
	title.col = 1
	title.rows[1] = 0
	check(title.lists[1][0] == Title.FILLIN_ROW, "the SFX column starts with the fill-in row")
	_press(title, "confirm")
	check(title.page == "fillins", "Z on the fill-in row opens the fill-in panel")
	check(title._fillin_label("GENERATE") == "GENERATE FILL-INS FOR %d MISSING CUES" % (total - 1),
		"the panel offers to fill in the missing cues")
	await frames(2)  # draws the panel
	_press(title, "confirm")
	check(Audio.fillin_cues().size() == total - 1, "GENERATE makes the fill-ins")
	check(title.fillin_status.begins_with("MADE %d" % (total - 1)), "the panel says how many it made")
	_press(title, "down")
	_press(title, "down")
	_press(title, "confirm")
	check(Audio.fillin_cues().size() == total - 1, "CLEAR asks again before clearing")
	_press(title, "confirm")
	check(Audio.fillin_cues().is_empty(), "a second Z clears them")
	_press(title, "cancel")
	check(title.page == "cues", "X closes the panel")

	title.rows[1] = title.lists[1].find("heal")
	_press(title, "confirm")
	check(title.page == "mixer", "Z on a cue opens its mixer")
	check(title._mixer_rows().has("MAKE FILL-IN"), "a cue with no sound offers MAKE FILL-IN")
	await frames(2)
	_select_mixer_row(title, "MAKE FILL-IN")
	_press(title, "confirm")
	check(Audio.sfx_source("heal") == "fill-in", "MAKE FILL-IN makes one for that cue")
	check(title._mixer_rows()[title.mixer_row] == "NEW TAKE", "the cursor moves to NEW TAKE")
	_press(title, "confirm")
	check(Audio.fillin_take("heal") == 2, "NEW TAKE re-rolls it")
	_select_mixer_row(title, "CLEAR FILL-IN")
	_press(title, "confirm")
	check(Audio.sfx_source("heal") == "none", "CLEAR FILL-IN removes it")
	title.page = "cues"  # (closing with X/DONE would save volumes.cfg, which this test leaves alone)

	title.rows[1] = title.lists[1].find("attack_hit")
	_press(title, "confirm")
	check(not title._mixer_rows().has("MAKE FILL-IN") and not title._mixer_rows().has("NEW TAKE"),
		"a cue with a file has no fill-in rows")
	await frames(2)
	title.page = "cues"
	title.queue_free()


func _press(node: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	node._unhandled_input(ev)


func _select_mixer_row(title: Node, row: String) -> void:
	title.mixer_row = title._mixer_rows().find(row)


func _restore() -> void:
	Audio.sfx_dir = Audio.SFX_DIR
	Audio.fillin_file = Audio.FILLIN_FILE
	Audio._load_fillins()
	Audio.rescan()
	for f in DirAccess.get_files_at(SCRATCH + "sfx/"):
		DirAccess.remove_absolute(SCRATCH + "sfx/" + f)
	DirAccess.remove_absolute(SCRATCH + "fillins.cfg")
