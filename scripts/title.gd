extends Node2D
## Title screen, plus an "AUDIO CUE LIST" page for auditioning sounds in-game.

signal start_battle(kind: String)

const PixelFont := preload("res://scripts/pixel_font.gd")
const OPTIONS := ["STANDARD BATTLE", "BOSS BATTLE", "AUDIO CUE LIST"]
const WHITE := Color("f0f0ff")
const DIM := Color("7a7a9a")
const YELLOW := Color("ffe066")
const GREEN := Color("66ff99")
const VISIBLE_ROWS := 14

var index := 0
var page := "menu"
var t := 0.0
var stars: Array[Vector3] = []
var planet: ImageTexture
var locked := false
var col := 0
var rows := [0, 0]
var lists := [[], []]


func _ready() -> void:
	Audio.hud_y = 72
	for i in 110:
		stars.append(Vector3(randf() * 320.0, randf() * 180.0, float(randi_range(1, 3))))
	planet = _make_planet()
	lists[0] = ["[STOP MUSIC]"] + Audio.MUSIC_CUES.keys()
	lists[1] = Audio.SFX_CUES.keys()


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
		if col == 1:
			Audio.play_sfx(cue)
		elif cue == "[STOP MUSIC]":
			Audio.stop_music(0.3)
		else:
			Audio.play_music(cue)
	elif event.is_action_pressed("cancel"):
		page = "menu"
		Audio.hud_hidden = false
		Audio.play_music("title_loop", 0.5)


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
	PixelFont.draw(self, Vector2(6, 5), "AUDIO CUES   Z: PLAY  X: BACK", YELLOW)
	PixelFont.draw(self, Vector2(6, 16), "GREEN = FILE FOUND. GRAY = NO FILE YET.", DIM)
	var heads := ["MUSIC  (AUDIO/MUSIC/)", "SFX  (AUDIO/SFX/)"]
	for c in 2:
		var x := 6 + c * 160
		PixelFont.draw(self, Vector2(x, 29), heads[c], WHITE if c == col else DIM)
		var list: Array = lists[c]
		var scroll := clampi(rows[c] - VISIBLE_ROWS / 2, 0, maxi(0, list.size() - VISIBLE_ROWS))
		for r in range(scroll, mini(list.size(), scroll + VISIBLE_ROWS)):
			var y := 40 + (r - scroll) * 10
			var cue: String = list[r]
			var found: bool
			if c == 0:
				found = cue == "[STOP MUSIC]" or Audio.has_music(cue)
			else:
				found = Audio.has_sfx(cue)
			if c == col and r == rows[c]:
				draw_rect(Rect2(x - 2, y - 2, 154, 11), Color(1, 1, 1, 0.12))
				PixelFont.draw(self, Vector2(x, y), "▶", YELLOW)
			PixelFont.draw(self, Vector2(x + 8, y), cue, GREEN if found else DIM)


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
