extends Node2D
## Title screen, plus an "AUDIO CUE LIST" page for auditioning sounds in-game.
## Picking a cue there plays it and opens a small mixer panel to set its volume.
## The SFX column's first row opens the FILL-IN SOUNDS panel, which makes
## placeholder sounds for cues with no file (see sfx_synth.gd).

signal start_battle(kind: String)

const PixelFont := preload("res://scripts/pixel_font.gd")
const OPTIONS := ["STANDARD BATTLE", "BOSS BATTLE", "AUDIO CUE LIST"]
const WHITE := Color("f0f0ff")
const DIM := Color("7a7a9a")
const YELLOW := Color("ffe066")
const GREEN := Color("66ff99")
const FILL := Color("66ccff")
const VISIBLE_ROWS := 13
const MIXER_ROWS := ["VOLUME", "PLAY AGAIN", "RESET TO 0 DB", "DONE"]
const MIXER_BOX := Rect2(16, 30, 288, 0)  # height grows with the rows
const STOP_ROW := "[STOP MUSIC]"
const FILLIN_ROW := "[FILL-IN SOUNDS...]"
const FILLIN_BOX := Rect2(16, 30, 288, 124)
const FILLIN_ROWS := ["GENERATE", "NEW TAKES", "CLEAR", "DONE"]

var index := 0
var page := "menu"
var t := 0.0
var stars: Array[Vector3] = []
var planet: ImageTexture
var locked := false
var col := 0
var rows := [0, 0]
var lists := [[], []]
var mixer_row := 0
var fillin_row := 0
var fillin_armed := ""   # a FILLIN_ROWS entry waiting for a second Z to confirm
var fillin_status := ""


func _ready() -> void:
	Audio.hud_y = 72
	for i in 110:
		stars.append(Vector3(randf() * 320.0, randf() * 180.0, float(randi_range(1, 3))))
	planet = _make_planet()
	lists[0] = [STOP_ROW] + Audio.MUSIC_CUES.keys()
	lists[1] = [FILLIN_ROW] + Audio.SFX_CUES.keys()


func _process(delta: float) -> void:
	t += delta
	for i in stars.size():
		var s := stars[i]
		s.x -= s.z * 6.0 * delta
		if s.x < 0.0:
			s.x += 320.0
		stars[i] = s
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if page == "menu":
		if event.is_action_pressed("up", true):
			index = (index - 1 + OPTIONS.size()) % OPTIONS.size()
			Audio.play_sfx("menu_move")
		elif event.is_action_pressed("down", true):
			index = (index + 1) % OPTIONS.size()
			Audio.play_sfx("menu_move")
		elif event.is_action_pressed("confirm"):
			Audio.play_sfx("menu_select")
			match index:
				0, 1:
					locked = true
					start_battle.emit("standard" if index == 0 else "boss")
				2:
					page = "cues"
					Audio.hud_hidden = true
					Audio.rescan()  # pick up files dropped in since the last look
		return
	if page == "mixer":
		_mixer_input(event)
		return
	if page == "fillins":
		_fillins_input(event)
		return
	# cue list page
	var n: int = lists[col].size()
	if event.is_action_pressed("up", true):
		rows[col] = (rows[col] - 1 + n) % n
	elif event.is_action_pressed("down", true):
		rows[col] = (rows[col] + 1) % n
	elif event.is_action_pressed("left") or event.is_action_pressed("right"):
		col = 1 - col
	elif event.is_action_pressed("confirm"):
		var cue: String = lists[col][rows[col]]
		if cue == STOP_ROW:
			Audio.stop_music(0.3)
		elif cue == FILLIN_ROW:
			Audio.rescan()
			page = "fillins"
			fillin_row = 0
			fillin_armed = ""
			fillin_status = ""
		else:
			Audio.rescan()
			Audio.audition(_kind(), cue)
			page = "mixer"
			mixer_row = 0
	elif event.is_action_pressed("cancel"):
		page = "menu"
		Audio.hud_hidden = false
		Audio.play_music("title_loop", 0.5)


## The mixer's rows. SFX cues without a supplied file also get fill-in rows.
func _mixer_rows() -> Array:
	if _kind() != "sfx":
		return MIXER_ROWS
	match Audio.sfx_source(_cue()):
		"none":
			return ["VOLUME", "PLAY AGAIN", "RESET TO 0 DB", "MAKE FILL-IN", "DONE"]
		"fill-in":
			return ["VOLUME", "PLAY AGAIN", "RESET TO 0 DB", "NEW TAKE", "CLEAR FILL-IN", "DONE"]
	return MIXER_ROWS


func _mixer_input(event: InputEvent) -> void:
	var cue := _cue()
	var mrows := _mixer_rows()
	mixer_row = mini(mixer_row, mrows.size() - 1)
	if event.is_action_pressed("up", true):
		mixer_row = (mixer_row - 1 + mrows.size()) % mrows.size()
	elif event.is_action_pressed("down", true):
		mixer_row = (mixer_row + 1) % mrows.size()
	elif mixer_row == 0 and (event.is_action_pressed("left", true) or event.is_action_pressed("right", true)):
		var step := 1.0 if event.is_action_pressed("right", true) else -1.0
		Audio.set_volume(_kind(), cue, Audio.get_volume(_kind(), cue) + step)
		if _kind() == "sfx" and not event.is_echo():
			Audio.audition("sfx", cue)  # hear each change; music adjusts live
	elif event.is_action_pressed("confirm"):
		match mrows[mixer_row]:
			"PLAY AGAIN":
				Audio.audition(_kind(), cue)
			"RESET TO 0 DB":
				Audio.set_volume(_kind(), cue, 0.0)
				if _kind() == "sfx":
					Audio.audition("sfx", cue)
			"MAKE FILL-IN":
				Audio.generate_fillin(cue)
				Audio.audition("sfx", cue)
				mixer_row = _mixer_rows().find("NEW TAKE")
			"NEW TAKE":
				Audio.new_take(cue)
				Audio.audition("sfx", cue)
			"CLEAR FILL-IN":
				Audio.clear_fillin(cue)
				mixer_row = _mixer_rows().find("MAKE FILL-IN")
			"DONE":
				_close_mixer()
	elif event.is_action_pressed("cancel"):
		_close_mixer()


func _close_mixer() -> void:
	Audio.save_volumes()
	page = "cues"


func _fillins_input(event: InputEvent) -> void:
	if event.is_action_pressed("up", true):
		fillin_row = (fillin_row - 1 + FILLIN_ROWS.size()) % FILLIN_ROWS.size()
		fillin_armed = ""
	elif event.is_action_pressed("down", true):
		fillin_row = (fillin_row + 1) % FILLIN_ROWS.size()
		fillin_armed = ""
	elif event.is_action_pressed("confirm"):
		var row: String = FILLIN_ROWS[fillin_row]
		var used := Audio.fillin_cues().size()
		match row:
			"GENERATE":
				var made := Audio.generate_fillins()
				fillin_status = ("MADE " + _count(made, "FILL-IN") + ".") if made > 0 else "EVERY SFX CUE ALREADY HAS A SOUND."
			"NEW TAKES", "CLEAR":
				# Both throw away takes you may have picked, so they ask twice.
				if used == 0:
					fillin_status = "NO FILL-INS YET."
				elif fillin_armed != row:
					fillin_armed = row
					fillin_status = "PRESS Z AGAIN TO " + ("REPLACE ALL " if row == "NEW TAKES" else "CLEAR ALL ") \
						+ _count(used, "FILL-IN") + "."
					return
				elif row == "NEW TAKES":
					fillin_status = "NEW TAKES FOR " + _count(Audio.new_takes(), "FILL-IN") + "."
				else:
					fillin_status = "CLEARED " + _count(Audio.clear_fillins(), "FILL-IN") + "."
			"DONE":
				page = "cues"
		fillin_armed = ""
	elif event.is_action_pressed("cancel"):
		page = "cues"


func _fillin_label(row: String) -> String:
	match row:
		"GENERATE":
			var n := Audio.missing_sfx().size()
			return "GENERATE FILL-INS FOR %d MISSING CUE%s" % [n, "" if n == 1 else "S"] if n > 0 \
				else "GENERATE FILL-INS (NONE MISSING)"
		"NEW TAKES":
			return "NEW TAKES FOR ALL " + _count(Audio.fillin_cues().size(), "FILL-IN")
		"CLEAR":
			return "CLEAR ALL " + _count(Audio.fillin_cues().size(), "FILL-IN")
	return row


func _count(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "S"]


func _kind() -> String:
	return "music" if col == 0 else "sfx"


func _cue() -> String:
	return lists[col][rows[col]]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("07040f"))
	for s in stars:
		var c := [Color("40406a"), Color("8080b0"), Color("e0e0ff")][int(s.z) - 1] as Color
		draw_rect(Rect2(int(s.x), int(s.y), 1, 1), c)
	draw_texture(planet, Vector2(214, 108))
	if page == "menu":
		_draw_menu()
	else:
		_draw_cues()
	if page == "mixer":
		_draw_mixer()
	elif page == "fillins":
		_draw_fillins()


func _draw_menu() -> void:
	var title := "NEBULA BRAWL"
	var s := 3
	var x0 := 160 - PixelFont.width(title, s) / 2
	for i in title.length():
		var y := 20.0 + roundf(sin(t * 3.0 + i * 0.5) * 2.0)
		var c := Color.from_hsv(fmod(t * 0.08 + i * 0.04, 1.0), 0.45, 1.0)
		PixelFont.draw(self, Vector2(x0 + i * PixelFont.ADVANCE * s, y), title[i], c, s, Color("3a1a6a"))
	var sub := "- A SPACE RPG COMBAT DEMO -"
	PixelFont.draw(self, Vector2(160 - PixelFont.width(sub) / 2, 50), sub, DIM)
	for i in OPTIONS.size():
		var text: String = OPTIONS[i]
		var x := 160 - PixelFont.width(text) / 2
		var y := 84 + i * 14
		if i == index:
			if int(t * 4.0) % 2 == 0:
				PixelFont.draw(self, Vector2(x - 11, y), "▶", YELLOW)
			PixelFont.draw(self, Vector2(x, y), text, YELLOW, 1, Color(0, 0, 0, 1))
		else:
			PixelFont.draw(self, Vector2(x, y), text, WHITE, 1, Color(0, 0, 0, 1))
	PixelFont.draw(self, Vector2(8, 122), "CREATED BY JIM DEWITT", WHITE, 1, Color(0, 0, 0, 1))
	PixelFont.draw(self, Vector2(8, 132), "ROCHESTER MUSIC LAB", Color("88ccff"), 1, Color(0, 0, 0, 1))
	PixelFont.draw(self, Vector2(8, 142), "FOR NON-COMMERCIAL USE ONLY", DIM, 1, Color(0, 0, 0, 1))
	PixelFont.draw(self, Vector2(8, 158), "Z: SELECT  X: BACK  F1: AUDIO HUD", DIM, 1, Color(0, 0, 0, 1))
	PixelFont.draw(self, Vector2(8, 168), "IN BATTLE: F2 WIN F3 LOSE F4 LOW HP F7 AUTO", DIM, 1, Color(0, 0, 0, 1))


func _draw_cues() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0, 0.7))
	PixelFont.draw(self, Vector2(6, 5), "AUDIO CUES  Z: PLAY + VOLUME  X: BACK", YELLOW)
	PixelFont.draw(self, Vector2(6, 16), "GREEN = FILE", GREEN)
	PixelFont.draw(self, Vector2(90, 16), "BLUE = FILL-IN", FILL)
	PixelFont.draw(self, Vector2(186, 16), "GRAY = NO SOUND", DIM)
	var heads := ["MUSIC  (AUDIO/MUSIC/)", "SFX  (AUDIO/SFX/)"]
	for c in 2:
		var x := 6 + c * 160
		PixelFont.draw(self, Vector2(x, 29), heads[c], WHITE if c == col else DIM)
		var list: Array = lists[c]
		var scroll := clampi(rows[c] - VISIBLE_ROWS / 2, 0, maxi(0, list.size() - VISIBLE_ROWS))
		for r in range(scroll, mini(list.size(), scroll + VISIBLE_ROWS)):
			var y := 40 + (r - scroll) * 10
			var cue: String = list[r]
			var color := DIM
			if cue == STOP_ROW:
				color = GREEN
			elif cue == FILLIN_ROW:
				color = FILL
			elif c == 0:
				color = GREEN if Audio.has_music(cue) else DIM
			else:
				color = {"file": GREEN, "fill-in": FILL, "none": DIM}[Audio.sfx_source(cue)]
			if c == col and r == rows[c]:
				draw_rect(Rect2(x - 2, y - 2, 154, 11), Color(1, 1, 1, 0.12))
				PixelFont.draw(self, Vector2(x, y), "▶", YELLOW)
			elif not _is_action(cue) and Audio.get_volume("music" if c == 0 else "sfx", cue) != 0.0:
				draw_rect(Rect2(x + 1, y + 2, 3, 3), YELLOW)  # this cue has a volume trim
			PixelFont.draw(self, Vector2(x + 8, y), cue, color)
	# about the highlighted row
	var sel := _cue()
	if sel == FILLIN_ROW:
		var missing := Audio.missing_sfx().size()
		var line := ("%d SFX CUES HAVE NO SOUND. Z: FILL THEM IN" % missing) if missing > 0 \
			else _count(Audio.fillin_cues().size(), "FILL-IN") + " IN USE. Z: NEW TAKES OR CLEAR"
		PixelFont.draw(self, Vector2(6, 171), line, FILL)
	elif sel != STOP_ROW:
		var line := "VOLUME: " + _db_text(Audio.get_volume(_kind(), sel))
		PixelFont.draw(self, Vector2(6, 171), line, DIM)
		var src := _source_text()
		PixelFont.draw(self, Vector2(6 + PixelFont.width(line) + 18, 171), src[0], src[1])


func _is_action(row: String) -> bool:
	return row == STOP_ROW or row == FILLIN_ROW


## [text, color] saying where the highlighted cue's sound comes from.
func _source_text() -> Array:
	var cue := _cue()
	if _kind() == "music":
		return ["FILE: " + Audio.file_for("music", cue).get_file(), GREEN] if Audio.has_music(cue) else ["NO FILE YET", DIM]
	match Audio.sfx_source(cue):
		"file":
			return ["FILE: " + Audio.file_for("sfx", cue).get_file(), GREEN]
		"fill-in":
			return ["FILL-IN, TAKE %d" % Audio.fillin_take(cue), FILL]
	return ["NO FILE YET", DIM]


func _draw_mixer() -> void:
	var mrows := _mixer_rows()
	var cue := _cue()
	var cues: Dictionary = Audio.MUSIC_CUES if _kind() == "music" else Audio.SFX_CUES
	var about := PixelFont.wrap(cues.get(cue, ""), 45)
	var r := MIXER_BOX
	var top := 16 + about.size() * 9  # cue name, description, then where the sound comes from
	r.size.y = top + 24 + mrows.size() * 12
	draw_rect(r, Color(0.04, 0.03, 0.1, 0.97))
	draw_rect(r, YELLOW, false, 1.0)
	var x := r.position.x + 8
	var y := r.position.y + 6
	PixelFont.draw(self, Vector2(x, y), cue, YELLOW)
	for i in about.size():
		PixelFont.draw(self, Vector2(x, y + 10 + i * 9), about[i], DIM)
	var src := _source_text()
	PixelFont.draw(self, Vector2(x, y + top), ("MUSIC" if _kind() == "music" else "SFX") + ": " + src[0], src[1])
	for i in mrows.size():
		var ry := y + top + 16 + i * 12
		var sel := i == mini(mixer_row, mrows.size() - 1)
		if sel and int(t * 4.0) % 2 == 0:
			PixelFont.draw(self, Vector2(x, ry), "▶", YELLOW)
		PixelFont.draw(self, Vector2(x + 8, ry), mrows[i], WHITE if sel else DIM)
		if i == 0:
			_draw_volume_meter(Vector2(x + 58, ry), Audio.get_volume(_kind(), cue), sel)
		elif mrows[i] == "NEW TAKE":
			PixelFont.draw(self, Vector2(x + 92, ry), "A VARIATION ON THE SAME SOUND", DIM)
		elif mrows[i] == "MAKE FILL-IN":
			PixelFont.draw(self, Vector2(x + 92, ry), "PLAYS UNTIL YOU ADD A FILE", DIM)


func _draw_fillins() -> void:
	var r := FILLIN_BOX
	draw_rect(r, Color(0.04, 0.03, 0.1, 0.97))
	draw_rect(r, FILL, false, 1.0)
	var x := r.position.x + 8
	var y := r.position.y + 6
	PixelFont.draw(self, Vector2(x, y), "FILL-IN SOUNDS", FILL)
	var about := "PLACEHOLDER SFX MADE IN CODE FOR CUES THAT HAVE NO FILE, EACH SUITED TO ITS CUE. " \
		+ "NOTHING IS WRITTEN TO AUDIO/SFX/, AND A FILE YOU ADD ALWAYS PLAYS INSTEAD."
	var ly := y + 12
	for line in PixelFont.wrap(about, 45):
		PixelFont.draw(self, Vector2(x, ly), line, DIM)
		ly += 9
	var files := 0
	for cue in Audio.SFX_CUES:
		if Audio.has_sfx(cue):
			files += 1
	var counts := "FILES %d   FILL-INS %d   NO SOUND %d" % [files, Audio.fillin_cues().size(), Audio.missing_sfx().size()]
	PixelFont.draw(self, Vector2(x, ly + 3), counts, WHITE)
	for i in FILLIN_ROWS.size():
		var ry := ly + 17 + i * 11
		var sel := i == fillin_row
		var row: String = FILLIN_ROWS[i]
		if sel and int(t * 4.0) % 2 == 0:
			PixelFont.draw(self, Vector2(x, ry), "▶", YELLOW)
		var c := WHITE if sel else DIM
		if sel and fillin_armed == row:
			c = YELLOW
		PixelFont.draw(self, Vector2(x + 8, ry), _fillin_label(row), c)
	var status := fillin_status
	var busy := Audio.fillins_rendering()
	if busy > 0:
		status = (status + " " if status != "" else "") + "RENDERING... %d LEFT" % busy
	PixelFont.draw(self, Vector2(x, r.end.y - 11), status, YELLOW)


## "< -3 DB >" plus a bar from VOLUME_MIN to VOLUME_MAX with a tick at 0 dB.
func _draw_volume_meter(pos: Vector2, db: float, selected: bool) -> void:
	var col_text := YELLOW if selected else WHITE
	var text := _db_text(db)
	PixelFont.draw(self, pos, "<", DIM)
	PixelFont.draw(self, pos + Vector2(10, 0), text, col_text)
	PixelFont.draw(self, pos + Vector2(10 + PixelFont.width(text) + 4, 0), ">", DIM)
	var bx := pos.x + 76
	var bw := 100.0
	var span := Audio.VOLUME_MAX - Audio.VOLUME_MIN
	draw_rect(Rect2(bx, pos.y + 1, bw, 5), Color(0, 0, 0, 0.8))
	var fill := (db - Audio.VOLUME_MIN) / span * bw
	draw_rect(Rect2(bx, pos.y + 1, roundf(fill), 5), GREEN if db <= 0.0 else Color("ff8844"))
	var zero := roundf(bx + (0.0 - Audio.VOLUME_MIN) / span * bw)
	draw_rect(Rect2(zero, pos.y - 1, 1, 9), WHITE)


func _db_text(db: float) -> String:
	if is_zero_approx(db):
		return "0 DB"
	return "%+d DB" % int(db)


func _make_planet() -> ImageTexture:
	var img := Image.create(100, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(50, 32)
	var bands := [Color("e07a5a"), Color("c05a70"), Color("f0a070"), Color("a04a78"), Color("e07a5a")]
	var ring := Color("c8b0ff")
	# back half of the ring
	_ring(img, center, ring, true)
	for y in 64:
		for x in 100:
			var d := Vector2(x, y) - center
			if d.length() > 24.5:
				continue
			var bi := int((y + sin(x * 0.18) * 2.0) / 6.0) % bands.size()
			var c: Color = bands[bi]
			var light := d.normalized().dot(Vector2(-0.7, -0.7)) if d.length() > 0.0 else 1.0
			var shade := d.length() / 24.5 * (0.5 - light * 0.5)
			if shade > 0.45 or (shade > 0.3 and (x + y) % 2 == 0):
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	_ring(img, center, ring, false)
	return ImageTexture.create_from_image(img)


func _ring(img: Image, center: Vector2, c: Color, back: bool) -> void:
	for y in 64:
		for x in 100:
			var dx := (x - center.x) / 46.0
			var dy := (y - center.y) / 8.0
			var r := dx * dx + dy * dy
			if r < 0.72 or r > 1.0:
				continue
			if (y < center.y) != back:
				continue
			img.set_pixel(x, y, c if r < 0.86 else c.darkened(0.3))
