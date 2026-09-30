extends RefCounted
## PIXEL ART, DRAWN AS TEXT.
## Each sprite lists the LEFT HALF of every row. It gets mirrored into a
## symmetric image and a dark outline is added automatically around it.
## "." is transparent, "k" is the outline color, other letters come from the
## sprite's palette. Edit the letters to redraw a character!

const OUTLINE := Color("140c22")

const DEFS := {
	# --- enemies ---------------------------------------------------------
	"gloop": {
		"pal": {"s": "b8c0d8", "S": "5c6480", "c": "a8f0ff", "w": "ffffff", "g": "72e46a", "G": "2f9a4c", "r": "ff4466", "y": "ffd23c"},
		"rows": [
			".....sssssssss",
			".............S",
			"..........SSSS",
			"........cccccc",
			"......ccwccccc",
			".....ccwgggggg",
			"....cccggggggg",
			"....ccgggggggg",
			"...ccgggwwkggg",
			"...ccgggwkkggg",
			"...ccggggggggg",
			"...cccgggGkkkk",
			"....ccgggggggg",
			"SSSSSSSSSSSSSS",
			".sssrssssyssss",
			"..SSSSSSSSSSSS",
			"....SSSSSSSSSS",
			".......g....gg",
			".......g.....g",
			".............g",
		],
	},
	"moth": {
		"pal": {"b": "6a5a88", "e": "ff3355", "w": "ffffff", "P": "4a2a8a", "p": "8a4ce0", "m": "e05ad0", "y": "ffe066"},
		"rows": [
			"...........b....",
			"............b...",
			"..PP.........b..",
			".PppPP.......bbb",
			"PpmmppPP....bewb",
			"PpmyymppPP...bbb",
			"PpmyyymppppPPbbb",
			"PpmyykympppppPbb",
			"PpmyyympppppppPb",
			"PpmmyymppppppPbb",
			".PpmmmppppppPPbb",
			"..PPpppppPPP..bb",
			"....PPPPP....bbb",
			".....PpmmpP...bb",
			"......PpmmpP..bb",
			".......PppP...bb",
			"........PP.....b",
			"...............b",
		],
	},
	"slug": {
		"pal": {"s": "c8d0e4", "S": "7a82a4", "w": "ffffff", "e": "202040", "m": "ff7aa8"},
		"rows": [
			"..www.........",
			"..wew.........",
			"..www.........",
			"...S..........",
			"....S.........",
			".....S........",
			"......S.......",
			".......Sssssss",
			".....Ssswwssss",
			"....Ssswssssss",
			"...Sssssssssss",
			"..SsssssssSkkk",
			"..SssssssssSmm",
			".SSssssssssSSS",
			"SSSsssssssssss",
			"SSSSSSSSSSSSSS",
			".SSSSSSSSSSSSS",
		],
	},
	"securi": {
		"pal": {"y": "ffc830", "Y": "c07820", "g": "9aa2ba", "G": "4e566c", "v": "ff3050", "V": "ffb0b0"},
		"rows": [
			"............y",
			"............G",
			"......GGGGGGG",
			".....Gyyyyyyy",
			".....GyGGGGGG",
			".....GyGvvvvv",
			".....GyGvVvvv",
			".....GyGGGGGG",
			".....Gyyyyyyy",
			"......GGGGGGG",
			"...........GG",
			".gg.YYYYYYYYY",
			"gGg.Yyyyyyyyy",
			"gGg.YyyGGGGGG",
			"gGg.YyyGGvGGG",
			"gGg.YyyGGGGGG",
			".g..Yyyyyyyyy",
			"....YYYYYYYYY",
			".....GGG.....",
			".....GGG.....",
			"....gggg.....",
		],
	},
	# --- crew portraits (16x16) ------------------------------------------
	"nova": {
		"pal": {"v": "5ac8ff", "h": "ff8a3c", "f": "f6c8a0", "F": "d8906c", "u": "3c6cd8", "w": "e0e8ff"},
		"rows": [
			"....hhhh",
			"..hhhhhh",
			".hhhhhhh",
			"vhhffhhh",
			"vhffffff",
			"vhfffkff",
			"vhfffkff",
			".hffffff",
			".hffffff",
			"..fffffk",
			"...Fffff",
			".....FFF",
			".uuuuwuu",
			"uuuuuwuu",
		],
	},
	"bolt": {
		"pal": {"a": "ff5050", "g": "a0a8c0", "G": "5a6278", "d": "1c2c40", "e": "60f0ff"},
		"rows": [
			".......a",
			".......G",
			"..gggggg",
			".gdddddd",
			".gdddddd",
			"Ggddeedd",
			"Ggddeedd",
			".gdddddd",
			".gddddee",
			".gdddddd",
			"..gggggg",
			"....GGGG",
			"..gggggg",
			".ggggggg",
		],
	},
	"ziggy": {
		"pal": {"h": "58c878", "l": "c8ff70", "p": "e060ff", "f": "b87a55", "F": "8a5438"},
		"rows": [
			"...hhhhh",
			".hhhlhhh",
			"hhhhhhhh",
			"hhhhhhhh",
			"hhfffffp",
			"hhffffff",
			"hhfffkff",
			"hhfffkff",
			".hffffff",
			".hffffff",
			"..ffffkk",
			"...Fffff",
			"....FFFF",
			"..pppppp",
		],
	},
}

static var _cache := {}


static func get_tex(id: String) -> ImageTexture:
	if not _cache.has(id):
		var d: Dictionary = DEFS[id]
		_cache[id] = build(d.rows, d.pal)
	return _cache[id]


static func build(half_rows: Array, palette: Dictionary) -> ImageTexture:
	var half_w := 0
	for r in half_rows:
		half_w = maxi(half_w, r.length())
	var img := Image.create(half_w * 2 + 2, half_rows.size() + 2, false, Image.FORMAT_RGBA8)
	for y in half_rows.size():
		var half: String = half_rows[y]
		half = half.lpad(half_w, ".")
		var row := half + _reverse(half)
		for x in row.length():
			var ch := row[x]
			if ch == "k":
				img.set_pixel(x + 1, y + 1, OUTLINE)
			elif palette.has(ch):
				img.set_pixel(x + 1, y + 1, Color(palette[ch]))
	add_outline(img)
	return ImageTexture.create_from_image(img)


static func _reverse(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s[i]
	return out


static func add_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var marks: Array[Vector2i] = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in dirs:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and img.get_pixelv(n).a > 0.0:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixelv(m, OUTLINE)


# --- the boss is drawn with code instead of text ----------------------------

## OVERMIND.EXE: a haunted CRT monitor with one big eye. angry = phase 2 look.
static func overmind(angry: bool) -> ImageTexture:
	var img := Image.create(60, 54, false, Image.FORMAT_RGBA8)
	var case_c := Color("7a6aa8")
	var hi := Color("a898d8")
	var lo := Color("4a3a78")
	# dangling cables (behind everything)
	var xs := [8, 16, 42, 50]
	for k in 4:
		for y in range(34, 53):
			var x := int(xs[k] + sin((y - 34) * 0.35 + k) * (2 + k % 2))
			_fill(img, x, y, 2, 1, Color("3a3450") if k % 2 == 0 else Color("584a78"))
	# monitor case with bevel
	_fill(img, 3, 2, 54, 38, case_c)
	_fill(img, 3, 2, 54, 1, hi)
	_fill(img, 3, 2, 1, 38, hi)
	_fill(img, 3, 39, 54, 1, lo)
	_fill(img, 56, 2, 1, 38, lo)
	# screen with scanlines
	var scr := Color("240808") if angry else Color("0c2418")
	var scan := Color("3a1010") if angry else Color("12301f")
	_fill(img, 8, 6, 44, 28, scr)
	for y in range(6, 34, 2):
		_fill(img, 8, y, 44, 1, scan)
	# the eye
	var cx := 30
	var cy := 20
	_ellipse(img, cx, cy, 16, 9, Color("e8f0e0"))
	if angry:
		for v in [Vector2i(-13, 2), Vector2i(-12, 3), Vector2i(12, -2), Vector2i(13, -1), Vector2i(-11, -3), Vector2i(11, 4)]:
			img.set_pixel(cx + v.x, cy + v.y, Color("ff5060"))
	var iris := Color("ff3040") if angry else Color("40e080")
	var iris_dk := Color("901020") if angry else Color("1a8048")
	_ellipse(img, cx, cy, 7, 7, iris_dk)
	_ellipse(img, cx, cy, 6, 6, iris)
	if angry:
		_ellipse(img, cx, cy, 1, 5, Color("0a0a10"))
	else:
		_ellipse(img, cx, cy, 3, 3, Color("0a0a10"))
	_fill(img, cx - 4, cy - 4, 2, 2, Color.WHITE)
	if angry:
		# furious V-shaped eyelid
		for x in range(cx - 17, cx + 18):
			var lid := cy - 3 - int(abs(x - cx) * 0.4)
			for y in range(6, lid):
				img.set_pixel(x, y, scr)
			img.set_pixel(x, lid, Color("ff3040"))
	# bezel lights + label
	_fill(img, 42, 35, 2, 2, Color("ff4060"))
	_fill(img, 46, 35, 2, 2, Color("ffd23c"))
	_fill(img, 50, 35, 2, 2, Color("60ff90"))
	_fill(img, 9, 36, 18, 1, lo)
	# stand
	_fill(img, 24, 40, 12, 5, lo)
	_fill(img, 16, 45, 28, 4, case_c)
	_fill(img, 16, 45, 28, 1, hi)
	add_outline(img)
	return ImageTexture.create_from_image(img)


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / (rx + 0.5)
			var dy := float(y - cy) / (ry + 0.5)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)
