extends Node2D
## BATTLE SCREEN
## Flow: intro -> [choose commands for each crew member -> everyone acts in
## speed order] -> repeat -> victory / defeat / flee.
## Every sound goes through the Audio autoload by cue name (see audio.gd).
##
## HP meters ROLL like in Earthbound: when someone takes "mortal damage" their
## meter keeps ticking down, and they only go KO when it reaches 0. Heal them
## before it gets there and they survive!

signal finished
signal _menu_done(result: int)
signal _msg_done

const PixelFont := preload("res://scripts/pixel_font.gd")
const Sprites := preload("res://scripts/sprites.gd")
const Data := preload("res://scripts/data.gd")
const BG_SHADER := preload("res://shaders/battle_bg.gdshader")
const SPRITE_SHADER := preload("res://shaders/battle_sprite.gdshader")

const TEXT_SPEED := 55.0  # characters per second
const MSG_HOLD := 0.9     # seconds a finished message stays up
const ROLL_DOWN := 18.0   # HP per second the meter rolls down
const ROLL_UP := 45.0
const COMMANDS := ["BASH", "TECH", "ITEM", "GUARD", "RUN"]
const TOP_BOX := Rect2(4, 4, 312, 28)
const CARD_Y := 130
const CARD_W := 100
const CARD_H := 46

const BOX_BG := Color(0.04, 0.03, 0.1, 0.94)
const WHITE := Color("f0f0ff")
const DIM := Color("7a7a9a")
const YELLOW := Color("ffe066")
const RED := Color("ff4466")
const GREEN := Color("66ff99")
const CYAN := Color("66ddff")
const ORANGE := Color("ff8844")
const PINK := Color("ff88ff")

const BG_STYLES := {
	"standard_a": {"pattern": 0, "speed": 1.0, "cols": [Color("0c0620"), Color("2a1050"), Color("1e6a8a"), Color("6040a0")]},
	"standard_b": {"pattern": 1, "speed": 1.0, "cols": [Color("06121c"), Color("0f3a4a"), Color("2a8a6a"), Color("184060")]},
	"boss": {"pattern": 2, "speed": 1.0, "cols": [Color("100010"), Color("3a0a40"), Color("0a5040"), Color("5a1a70")]},
	"boss_phase2": {"pattern": 2, "speed": 1.7, "cols": [Color("1a0000"), Color("600010"), Color("a02010"), Color("401030")]},
}

static var auto_battle := false  # F7: the crew picks their own commands

var kind := "standard"  # "standard" or "boss"

var party: Array = []
var enemies: Array = []
var inventory := {}
var result := ""
var wiped := false
var phase2 := false
var danger := false

# message box
var msg_lines := PackedStringArray()
var msg_len := 0
var msg_shown := 0.0
var msg_hold := 0.0
var msg_waiting := false
var prompt := ""

# menus
var menu := {}
var active := -1
var target_mode := ""
var targets: Array = []
var target_i := 0
var _abort_pick := false
var _cmd_memory := {}

# effects
var t := 0.0
var shake := 0.0
var flash_col := Color(1, 1, 1, 0)
var bg_intensity := 0.0
var floaters: Array = []
var particles: Array = []
var beams: Array = []
var rings: Array = []

# BASH timing mini-game (empty when not running)
const TIMING_BOX := Rect2(40, 94, 240, 30)
const TRACK_X := 48.0
const TRACK_W := 224.0
var timing := {}
signal _timing_done(grade: Dictionary)

var bg: ColorRect
var ui: Node2D


func _ready() -> void:
	Audio.hud_y = 36
	bg = ColorRect.new()
	bg.position = Vector2(-8, -8)
	bg.size = Vector2(336, 196)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	add_child(bg)
	_setup_party()
	_setup_enemies()
	ui = Node2D.new()
	ui.draw.connect(_draw_ui)
	add_child(ui)
	if kind == "boss":
		_apply_bg("boss")
	else:
		_apply_bg(["standard_a", "standard_b"].pick_random())


func _setup_party() -> void:
	for i in Data.PARTY.size():
		var p: Dictionary = Data.PARTY[i]
		party.append({
			"idx": i, "id": p.id, "name": p.name, "bash": p.bash, "techs": p.techs,
			"max_hp": p.hp, "hp": p.hp, "hp_disp": float(p.hp), "max_en": p.en, "en": p.en,
			"atk": p.atk, "def": p.def, "spd": p.spd, "timing": p.timing,
			"ko": false, "guard": false, "shield": 0, "stun": 0,
			"portrait": Sprites.get_tex(p.id), "raise": 0.0, "bounce": 0.0, "hurt": 0.0,
		})
	for id in Data.ITEM_ORDER:
		inventory[id] = Data.ITEMS[id].count


func _setup_enemies() -> void:
	var ids: Array = ["overmind"] if kind == "boss" else Data.ENCOUNTERS.pick_random()
	var counts := {}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	var seen := {}
	var n := ids.size()
	for i in n:
		var id: String = ids[i]
		var d: Dictionary = Data.ENEMIES[id]
		var nm: String = d.name
		if counts[id] > 1:
			seen[id] = seen.get(id, 0) + 1
			nm += " " + "ABC"[seen[id] - 1]
		var is_boss: bool = d.get("boss", false)
		var tex: ImageTexture = Sprites.overmind(false) if is_boss else Sprites.get_tex(id)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height())
		var mat := ShaderMaterial.new()
		mat.shader = SPRITE_SHADER
		s.material = mat
		var base := Vector2(roundf(160.0 + (i - (n - 1) / 2.0) * 88.0), 118.0 if is_boss else 116.0)
		var sc := 1.0 if is_boss else 2.0  # small enemies are drawn at 2x, Earthbound-style
		s.scale = Vector2(sc, sc)
		s.position = base
		add_child(s)
		enemies.append({
			"id": id, "name": nm, "max_hp": d.hp, "hp": d.hp, "hp_disp": float(d.hp),
			"atk": d.atk, "def": d.def, "spd": d.spd, "exp": d.exp, "boss": is_boss,
			"node": s, "base": base, "dead": false, "stun": 0, "lunge": 0.0, "hurt": 0.0,
			"phase": randf() * TAU, "h": tex.get_height() * sc,
		})


func _apply_bg(style: String) -> void:
	var st: Dictionary = BG_STYLES[style]
	var mat: ShaderMaterial = bg.material
	for k in 4:
		mat.set_shader_parameter("col_" + "abcd"[k], st.cols[k])
	mat.set_shader_parameter("pattern", st.pattern)
	mat.set_shader_parameter("speed", st.speed)


# =============================================================================
# MAIN FLOW
# =============================================================================

func begin() -> void:
	Audio.play_set("boss" if kind == "boss" else "battle")
	for e in enemies:
		e.node.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	for e in enemies:
		tw.tween_property(e.node, "modulate:a", 1.0, 0.5)
	await _wait(0.3)
	if kind == "boss":
		Audio.play_sfx("boss_roar")
		shake = 5.0
		_flash(Color(0.4, 1, 0.6, 0.5))
		await say("OVERMIND.EXE HAS BOOTED UP!")
		await say("IT WANTS TO DELETE YOUR ENTIRE CREW.")
	else:
		await say(_intro_text())
	await _battle_loop()


func _battle_loop() -> void:
	while true:
		var cmds = await _choose_commands()
		if _battle_over():
			break
		if cmds is String:
			if await _try_run():
				return
			cmds = []
			cmds.resize(party.size())
		await _execute_round(cmds)
		if _battle_over():
			break
		_end_round()
	if _all_enemies_dead():
		await _win()
	else:
		await _lose()


## Checks the crew directly rather than trusting `wiped`: when everyone hits 0
## in the same frame, the flag isn't set until after menus have been cancelled,
## and a round where nobody can act would otherwise loop forever.
func _battle_over() -> bool:
	return wiped or _all_enemies_dead() or _alive_party().is_empty()


func _all_enemies_dead() -> bool:
	return enemies.all(func(e): return e.dead)


func _alive_enemies() -> Array:
	return enemies.filter(func(e): return not e.dead)


func _alive_party() -> Array:
	return party.filter(func(m): return not m.ko)


# =============================================================================
# CHOOSING COMMANDS
# =============================================================================

func _choose_commands() -> Variant:
	var cmds := []
	cmds.resize(party.size())
	var i := 0
	while i < party.size():
		if _battle_over():
			break
		if party[i].ko:
			i += 1
			continue
		active = i
		_abort_pick = false
		var c = await _pick_command(i, cmds)
		if c == null:  # cancelled: step back to the previous crew member
			var j := i - 1
			while j >= 0 and party[j].ko:
				j -= 1
			if j >= 0:
				for k in range(j, party.size()):
					cmds[k] = null
				i = j
			continue
		if c is String:
			active = -1
			return c
		cmds[i] = c
		i += 1
	active = -1
	_abort_pick = false
	return cmds


func _pick_command(i: int, cmds: Array) -> Variant:
	var m: Dictionary = party[i]
	if auto_battle:
		await _wait(0.35)
		return _auto_command(m)
	var start: int = _cmd_memory.get(i, 0)
	while true:
		if _abort_pick:
			return {"type": "none"}
		prompt = "%s: WHAT'S THE PLAN?" % m.name
		var c := await _ask_menu("command", COMMANDS, [], [], start)
		if c < 0:
			return {"type": "none"} if _abort_pick else null
		_cmd_memory[i] = c
		start = c
		match c:
			0:
				var tg = await _pick_target("enemy")
				if tg is Dictionary:
					return {"type": "bash", "actor": m, "target": tg}
			1:
				var r = await _pick_tech(m)
				if r is Dictionary:
					return r
			2:
				var r = await _pick_item(m, cmds)
				if r is Dictionary:
					return r
			3:
				return {"type": "guard", "actor": m}
			4:
				return "run"
	return null


func _pick_tech(m: Dictionary) -> Variant:
	var names := []
	var ok := []
	var descs := []
	for id in m.techs:
		var td: Dictionary = Data.TECHS[id]
		names.append(td.name.rpad(14) + str(td.cost).lpad(2) + "EN")
		ok.append(m.en >= td.cost)
		descs.append(td.desc)
	var start := 0
	while true:
		prompt = "%s - TECH" % m.name
		var c := await _ask_menu("list", names, ok, descs, start)
		if c < 0:
			return null
		start = c
		var td: Dictionary = Data.TECHS[m.techs[c]]
		var tg = await _pick_target(td.target)
		if tg != null:
			return {"type": "tech", "actor": m, "id": m.techs[c], "target": tg}
	return null


func _pick_item(m: Dictionary, cmds: Array) -> Variant:
	var names := []
	var ok := []
	var descs := []
	for id in Data.ITEM_ORDER:
		var left := _items_left(id, cmds)
		names.append(Data.ITEMS[id].name.rpad(15) + "x%d" % left)
		ok.append(left > 0)
		descs.append(Data.ITEMS[id].desc)
	var start := 0
	while true:
		prompt = "%s - ITEMS" % m.name
		var c := await _ask_menu("list", names, ok, descs, start)
		if c < 0:
			return null
		start = c
		var id: String = Data.ITEM_ORDER[c]
		var tg = await _pick_target(Data.ITEMS[id].target)
		if tg != null:
			return {"type": "item", "actor": m, "id": id, "target": tg}
	return null


## Items still in the bag after the commands already queued this round.
func _items_left(id: String, cmds: Array) -> int:
	var n: int = inventory[id]
	for c in cmds:
		if c is Dictionary and c.type == "item" and c.id == id:
			n -= 1
	return n


## Returns a party/enemy Dictionary, "all" for group targets, or null if cancelled.
func _pick_target(tt: String) -> Variant:
	var pool: Array
	match tt:
		"enemy":
			pool = _alive_enemies()
		"ally":
			pool = _alive_party()
		"ally_ko":
			pool = party.filter(func(m): return m.ko)
		_:
			return "all"
	if pool.is_empty():
		Audio.play_sfx("menu_error")
		return null
	if _abort_pick:
		return null
	target_mode = "enemy" if tt == "enemy" else "ally"
	targets = pool
	target_i = 0
	if target_mode == "ally" and active >= 0:
		target_i = maxi(0, pool.find(party[active]))
	var r: int = await _menu_done
	target_mode = ""
	if r < 0:
		return null
	return targets[r]


func _ask_menu(type: String, options: Array, enabled: Array, descs: Array, start := 0) -> int:
	if _abort_pick:
		return -1
	menu = {"type": type, "options": options, "enabled": enabled, "descs": descs,
		"index": clampi(start, 0, options.size() - 1)}
	var r: int = await _menu_done
	menu = {}
	return r


## Cancel whatever menu is open (someone got KO'd, or the battle ended).
func _abort() -> void:
	_abort_pick = true
	if not menu.is_empty() or target_mode != "":
		_menu_done.emit(-1)


func _auto_command(m: Dictionary) -> Dictionary:
	var foes := _alive_enemies()
	var hurt: Array = party.filter(func(p): return not p.ko and p.hp < p.max_hp * 0.4)
	var downed: Array = party.filter(func(p): return p.ko)
	for id in m.techs:
		var td: Dictionary = Data.TECHS[id]
		if m.en < td.cost:
			continue
		if td.effect == "revive" and not downed.is_empty():
			return {"type": "tech", "actor": m, "id": id, "target": downed[0]}
		if td.effect == "heal" and not hurt.is_empty():
			return {"type": "tech", "actor": m, "id": id, "target": hurt[0]}
	if randf() < 0.45:
		var opts := []
		for id in m.techs:
			var td: Dictionary = Data.TECHS[id]
			if m.en < td.cost:
				continue
			if td.effect in ["damage", "magic"] or (td.effect == "shield" and party.all(func(p): return p.shield == 0)):
				opts.append(id)
		if not opts.is_empty():
			var id: String = opts.pick_random()
			var td: Dictionary = Data.TECHS[id]
			var tg = "all" if td.target.begins_with("all") else foes.pick_random()
			return {"type": "tech", "actor": m, "id": id, "target": tg}
	if randf() < 0.1:
		return {"type": "guard", "actor": m}
	return {"type": "bash", "actor": m, "target": foes.pick_random()}


# =============================================================================
# RESOLVING A ROUND
# =============================================================================

func _execute_round(cmds: Array) -> void:
	var acts := []
	for i in party.size():
		var m: Dictionary = party[i]
		if m.ko or cmds[i] == null or cmds[i].type == "none":
			continue
		var c: Dictionary = cmds[i]
		if c.type == "guard":
			m.guard = true
			c.spd = 999.0
		else:
			c.spd = m.spd + randf() * 5.0
		acts.append(c)
	for e in _alive_enemies():
		acts.append({"type": "enemy", "actor": e, "spd": e.spd + randf() * 5.0})
	acts.sort_custom(func(a, b): return a.spd > b.spd)
	for act in acts:
		if _battle_over():
			return
		await _perform(act)
		await _check_phase2()


func _end_round() -> void:
	for m in party:
		m.guard = false
		if m.shield > 0:
			m.shield -= 1


func _perform(act: Dictionary) -> void:
	var a: Dictionary = act.actor
	if act.type == "enemy":
		await _enemy_act(a)
		return
	if a.ko:
		return
	if a.stun > 0:
		a.stun -= 1
		await say("%s IS STUNNED AND CAN'T MOVE!" % a.name)
		return
	match act.type:
		"guard":
			a.en = mini(a.max_en, a.en + 2)
			Audio.play_sfx("guard")
			await say("%s IS BRACING FOR IMPACT. (+2 EN)" % a.name)
		"bash":
			await _do_bash(a, act.target)
		"tech":
			await _do_tech(a, act.id, act.target)
		"item":
			await _do_item(a, act.id, act.target)


func _do_bash(a: Dictionary, target: Dictionary) -> void:
	var e = _retarget(target)
	if e == null:
		return
	await _card_hop(a)
	await say(a.bash.format({"a": a.name, "t": e.name}), 0.2)
	var grade := await _timing_minigame(a)
	if e.dead:  # e.g. the F2 shortcut fired mid-swing
		return
	Audio.play_sfx("attack_swing")
	if grade.is_empty():
		Audio.play_sfx("miss")
		_floater(_enemy_center(e), "MISS", DIM)
		await say("JUST MISSED!")
		return
	var dmg := _calc_damage(a.atk, e.def, grade.mult)
	if grade.id == "perfect":
		Audio.play_sfx("critical_hit")
		_flash(Color(1, 1, 1, 0.85))
		shake = 5.0
		_floater(Vector2(160, 52), "SMAAAASH!!", YELLOW, 2)
	else:
		Audio.play_sfx("attack_hit")
	_hurt_enemy(e, dmg)
	await say("%d HP OF DAMAGE TO %s!" % [dmg, e.name])
	if e.hp <= 0:
		await _kill_enemy(e)


## Deltarune-style timing bar: a marker slides across and the player presses
## confirm as it crosses the target zone. Returns the grade it earned from
## Data.TIMING_GRADES, or {} for a miss (never pressed).
func _timing_minigame(a: Dictionary) -> Dictionary:
	var zone := randf_range(0.55, 0.85)
	timing = {"x": 0.0, "zone": zone, "speed": a.timing / 1.1, "done": false, "grade": {}, "stop": 2.0}
	if auto_battle:
		# pick a grade, then stop the marker somewhere inside that grade's band
		var grades: Array = Data.TIMING_GRADES
		var g := _weighted(grades, "auto")
		var i := grades.find(g)
		var lo: float = 0.0 if i == 0 else grades[i - 1].px + 1
		var hi: float = minf(g.px, 60.0)
		timing.stop = zone - randf_range(lo, maxf(lo, hi)) / TRACK_W
	Audio.play_sfx("timing_start")
	var grade: Dictionary = await _timing_done
	await _wait(0.45)
	timing = {}
	return grade


func _resolve_timing(pressed: bool) -> void:
	var grade := {}
	if pressed:
		var px := absf(timing.x - timing.zone) * TRACK_W
		for g in Data.TIMING_GRADES:
			if px <= g.px:
				grade = g
				break
	timing.done = true
	timing.grade = grade
	Audio.play_sfx("timing_" + grade.get("id", "miss"))
	_timing_done.emit(grade)


func _update_timing(delta: float) -> void:
	if timing.is_empty() or timing.done:
		return
	timing.x += timing.speed * delta
	if timing.x >= timing.stop:
		timing.x = timing.stop
		_resolve_timing(true)
	elif timing.x >= 1.0:
		timing.x = 1.0
		_resolve_timing(false)


func _do_tech(a: Dictionary, id: String, target) -> void:
	var td: Dictionary = Data.TECHS[id]
	if a.en < td.cost:
		Audio.play_sfx("menu_error")
		await say("%s TRIED %s... BUT RAN OUT OF EN!" % [a.name, td.name])
		return
	a.en -= td.cost
	await _card_hop(a)
	await say("%s USES %s!" % [a.name, td.name], 0.3)
	Audio.play_sfx(td.sfx)
	await _apply_effect(a, td, target)


func _do_item(a: Dictionary, id: String, target) -> void:
	var d: Dictionary = Data.ITEMS[id]
	if inventory[id] <= 0:
		await say("%s REACHED FOR A %s... BUT THERE ARE NONE LEFT!" % [a.name, d.name])
		return
	inventory[id] -= 1
	Audio.play_sfx("item_use")
	await say("%s USES THE %s!" % [a.name, d.name], 0.3)
	if d.has("sfx"):
		Audio.play_sfx(d.sfx)
	await _apply_effect(a, d, target)


## Shared by techs and items.
func _apply_effect(a: Dictionary, d: Dictionary, target) -> void:
	match d.effect:
		"damage", "magic":
			var list: Array = _alive_enemies() if target is String else [_retarget(target)]
			if list.is_empty() or list[0] == null:
				return
			await _play_fx(d.fx, list)
			var stunned := []
			var total := 0
			for e in list:
				var dmg: int
				if d.effect == "damage":
					dmg = _calc_damage(a.atk, e.def, d.power)
				else:
					dmg = maxi(1, int(d.power * randf_range(0.85, 1.15)))
				total += dmg
				_hurt_enemy(e, dmg)
				if d.has("stun") and e.hp > 0 and randf() < d.stun:
					e.stun = 1
					stunned.append(e)
			Audio.play_sfx("attack_hit")
			if list.size() == 1:
				await say("%d HP OF DAMAGE TO %s!" % [total, list[0].name])
			else:
				await say("%d TOTAL DAMAGE ACROSS %d ENEMIES!" % [total, list.size()])
			for e in stunned:
				Audio.play_sfx("stun")
				await say("%s IS STUNNED!" % e.name)
			for e in list:
				if e.hp <= 0 and not e.dead:
					await _kill_enemy(e)
		"heal", "energy":
			var m: Dictionary = target
			if m.ko:
				await say("...BUT %s IS KNOCKED OUT. NO EFFECT." % m.name)
				return
			await _play_fx(d.fx, [m])
			var amt := int(d.power * randf_range(0.9, 1.1))
			if d.effect == "heal":
				var before: int = m.hp
				m.hp = mini(m.max_hp, m.hp + amt)
				Audio.play_sfx("heal")
				_floater(_card_center(m), "+%d" % (m.hp - before), GREEN)
				await say("%s RECOVERED %d HP!" % [m.name, m.hp - before])
			else:
				var before: int = m.en
				m.en = mini(m.max_en, m.en + amt)
				Audio.play_sfx("energy")
				_floater(_card_center(m), "+%d EN" % (m.en - before), CYAN)
				await say("%s RECOVERED %d EN!" % [m.name, m.en - before])
		"revive":
			var m: Dictionary = target
			if not m.ko:
				await say("...BUT %s IS ALREADY UP. NO EFFECT." % m.name)
				return
			await _play_fx(d.fx, [m])
			m.ko = false
			m.hp = maxi(1, int(m.max_hp * d.power))
			m.hp_disp = 0.0
			_floater(_card_center(m), "REVIVED", GREEN)
			await say("%s IS BACK ON THEIR FEET!" % m.name)
		"shield":
			var list := _alive_party()
			await _play_fx(d.fx, list)
			for m in list:
				m.shield = d.turns
			await say("A SHIELD WALL PROTECTS THE CREW!")
		"duck":
			_floater(Vector2(160, 70), "SQUEAK!", YELLOW, 2)
			await say("SQUEAK! ...NOTHING HAPPENED.")


func _enemy_act(e: Dictionary) -> void:
	if e.dead:
		return
	if e.stun > 0:
		e.stun -= 1
		await say("%s IS STUNNED AND CAN'T MOVE!" % e.name)
		return
	var moves: Array = Data.ENEMIES[e.id].moves
	if phase2 and e.boss:
		moves = Data.ENEMIES[e.id].moves_phase2
	var mv: Dictionary = _weighted(moves)
	var alive := _alive_party()
	if alive.is_empty():
		return
	var tgt: Dictionary = alive.pick_random()
	var text: String = mv.text.format({"e": e.name, "t": tgt.name})
	match mv.kind:
		"attack":
			await _enemy_lunge(e)
			Audio.play_sfx("enemy_attack")
			await say(text, 0.3)
			if randf() < 0.05:
				Audio.play_sfx("miss")
				await say("%s DODGED IT!" % tgt.name)
				return
			var dmg := _mitigate(tgt, _calc_damage(e.atk, tgt.def, mv.mult))
			_hurt_party(tgt, dmg)
			await say(_damage_text(tgt, dmg))
			if mv.has("stun") and tgt.hp > 0 and randf() < mv.stun:
				tgt.stun = 1
				Audio.play_sfx("stun")
				await say("%s IS STUNNED!" % tgt.name)
		"attack_all":
			await _enemy_lunge(e)
			Audio.play_sfx("enemy_attack")
			await say(text, 0.3)
			for m in alive:
				_hurt_party(m, _mitigate(m, _calc_damage(e.atk, m.def, mv.mult)))
			await say("THE WHOLE CREW TOOK DAMAGE!")
		"drain_en":
			await _enemy_lunge(e)
			Audio.play_sfx("drain")
			await say(text, 0.3)
			var amt: int = mini(tgt.en, mv.amount)
			tgt.en -= amt
			_floater(_card_center(tgt), "-%d EN" % amt, CYAN)
			await say("%s LOST %d EN!" % [tgt.name, amt])
		"heal_self":
			Audio.play_sfx("enemy_heal")
			e.hp = mini(e.max_hp, e.hp + mv.amount)
			_floater(_enemy_center(e), "+%d" % mv.amount, GREEN)
			await say(text)
		_:
			await say(text)


func _check_phase2() -> void:
	if kind != "boss" or phase2 or enemies.is_empty():
		return
	var b: Dictionary = enemies[0]
	if b.dead or b.hp > b.max_hp / 2:
		return
	phase2 = true
	Audio.play_sfx("boss_roar")
	_flash(Color(1, 0.2, 0.2, 0.9))
	shake = 6.0
	b.node.texture = Sprites.overmind(true)
	b.atk = int(b.atk * 1.25)
	b.spd += 4
	_apply_bg("boss_phase2")
	Audio.play_music("boss_phase2_loop", 1.5)
	await say("OVERMIND.EXE IS OVERCLOCKING!!")
	await say("ITS COOLING FANS ARE SCREAMING AT 9000 RPM!")


# =============================================================================
# ENDINGS
# =============================================================================

func _try_run() -> bool:
	await say("THE CREW TRIES TO SLIP AWAY...", 0.5)
	if kind == "boss":
		Audio.play_sfx("run_fail")
		await say("OVERMIND.EXE LOCKED THE AIRLOCKS! NO ESCAPE!")
		return false
	if randf() < 0.6:
		result = "flee"
		Audio.set_danger(false)
		Audio.play_sfx("run_away")
		Audio.play_music("flee")
		var tw := create_tween().set_parallel()
		for e in enemies:
			tw.tween_property(e.node, "modulate:a", 0.0, 0.4)
		await say("THE CREW BLASTED OFF TO SAFETY!")
		await say("PRESS Z TO RETURN TO THE TITLE.", 4.0 if auto_battle else -1.0)
		finished.emit()
		return true
	Audio.play_sfx("run_fail")
	await say("...BUT THE ENEMIES CUT THEM OFF!")
	return false


func _win() -> void:
	result = "win"
	Audio.set_danger(false)
	Audio.play_music("victory", 0.0, "victory_loop")
	for k in 60:
		particles.append({"p": Vector2(randf_range(0, 320), randf_range(-60, 0)), "v": Vector2(randf_range(-15, 15), randf_range(25, 55)),
			"life": 4.0, "col": [YELLOW, PINK, CYAN, GREEN].pick_random(), "size": 2, "g": 0.0})
	await say("YOU WON!")
	var xp := 0
	for e in enemies:
		xp += e.exp
	await say("THE CREW EARNED %d EXP." % xp)
	var lucky: Dictionary = _alive_party().pick_random()
	await say(Data.VICTORY_FLUFF.pick_random().format({"a": lucky.name}))
	await say("PRESS Z TO RETURN TO THE TITLE.", 4.0 if auto_battle else -1.0)
	finished.emit()


func _lose() -> void:
	result = "lose"
	Audio.set_danger(false)
	Audio.play_music("defeat")
	var mat: ShaderMaterial = bg.material
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("gray", v), 0.0, 1.0, 1.5)
	await say("THE CREW WAS KNOCKED OUT...")
	await say("THEY WAKE UP BACK AT THE SPACE STATION. HOW EMBARRASSING.")
	await say("PRESS Z TO RETURN TO THE TITLE.", 4.0 if auto_battle else -1.0)
	finished.emit()


# =============================================================================
# HELPERS
# =============================================================================

func _calc_damage(atk: float, def: float, mult: float) -> int:
	var base := atk * mult - def * 0.5
	return maxi(1, roundi(base * randf_range(0.85, 1.15)))


func _mitigate(m: Dictionary, dmg: int) -> int:
	var d := float(dmg)
	if m.guard:
		d *= 0.5
	if m.shield > 0:
		d *= 0.6
	return maxi(1, roundi(d))


func _damage_text(m: Dictionary, dmg: int) -> String:
	if m.hp <= 0:
		return "%d HP OF MORTAL DAMAGE TO %s!!" % [dmg, m.name]
	return "%s TOOK %d DAMAGE!" % [m.name, dmg]


func _weighted(moves: Array, key := "w") -> Dictionary:
	var total := 0.0
	for mv in moves:
		total += mv[key]
	var r := randf() * total
	for mv in moves:
		r -= mv[key]
		if r <= 0.0:
			return mv
	return moves[-1]


func _retarget(e) -> Variant:
	if e is Dictionary and not e.dead:
		return e
	var alive := _alive_enemies()
	return null if alive.is_empty() else alive.pick_random()


func _hurt_enemy(e: Dictionary, dmg: int) -> void:
	e.hp = maxi(0, e.hp - dmg)
	e.hurt = 0.4
	_floater(_enemy_center(e) + Vector2(0, -6), str(dmg), WHITE)
	_burst(_enemy_center(e), WHITE, 8)


func _hurt_party(m: Dictionary, dmg: int) -> void:
	m.hp = maxi(0, m.hp - dmg)
	m.hurt = 0.4
	shake = maxf(shake, 3.0)
	_flash(Color(1, 0, 0, 0.25))
	Audio.play_sfx("player_hurt")
	_floater(_card_center(m) + Vector2(0, -14), str(dmg), RED)


func _kill_enemy(e: Dictionary) -> void:
	e.dead = true
	var mat: ShaderMaterial = e.node.material
	mat.set_shader_parameter("flash_color", Color("ff5080"))
	mat.set_shader_parameter("flash", 0.6)
	if e.boss:
		Audio.stop_music(0.8)
		Audio.play_sfx("boss_defeat")
		for k in 7:
			var h: float = e.h
			_burst(e.base + Vector2(randf_range(-26, 26), -randf_range(4, h)), [YELLOW, ORANGE, WHITE].pick_random(), 14)
			shake = 5.0
			_flash(Color(1, 1, 1, 0.5))
			await _wait(0.2)
	else:
		Audio.play_sfx("enemy_defeat")
	_burst(_enemy_center(e), YELLOW, 16)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 1.2 if e.boss else 0.7)
	if e.boss:
		await say("OVERMIND.EXE HAS STOPPED RESPONDING.")
	else:
		var lines := ["%s WAS DEFEATED!", "%s WAS SENT TO THE RECYCLE BIN!", "%s EXPLODED INTO CONFETTI!", "%s BLINKED OUT OF EXISTENCE!"]
		await say(lines.pick_random() % e.name)
	e.node.visible = false


func _intro_text() -> String:
	var nm: String = Data.ENEMIES[enemies[0].id].name
	if enemies.size() == 1:
		return "A %s ATTACKS!" % nm
	var lines := ["%s AND FRIENDS WARP IN!", "%s AND ITS GANG BLOCK THE CORRIDOR!", "A %s AND PALS PICK A FIGHT!"]
	return lines.pick_random() % nm


func _enemy_center(e: Dictionary) -> Vector2:
	return e.base + Vector2(0, -e.h / 2.0)


func _card_center(m: Dictionary) -> Vector2:
	return Vector2(7 + m.idx * 103 + CARD_W / 2, CARD_Y + CARD_H / 2)


func _pos_of(x: Dictionary) -> Vector2:
	return _enemy_center(x) if x.has("node") else _card_center(x)


func _wait(sec: float) -> void:
	var tw := create_tween()
	tw.tween_interval(sec)
	await tw.finished


func _card_hop(m: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): m.bounce = v, 0.0, -6.0, 0.08)
	tw.tween_method(func(v: float): m.bounce = v, -6.0, 0.0, 0.12)
	await tw.finished


func _enemy_lunge(e: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): e.lunge = v, 0.0, 1.0, 0.08)
	tw.tween_method(func(v: float): e.lunge = v, 1.0, 0.0, 0.15)
	await tw.finished


## Show a message with a typewriter effect. hold < 0 waits for the player.
func say(text: String, hold := MSG_HOLD) -> void:
	msg_lines = PixelFont.wrap(text.to_upper(), 50)
	msg_len = 0
	for l in msg_lines:
		msg_len += l.length()
	msg_shown = 0.0
	msg_hold = hold
	msg_waiting = true
	await _msg_done


# =============================================================================
# EFFECTS
# =============================================================================

func _play_fx(fx: String, list: Array) -> void:
	match fx:
		"laser":
			for k in 3:
				for tg in list:
					var to := _pos_of(tg) + Vector2(randi_range(-4, 4), randi_range(-4, 4))
					var from := Vector2(randi_range(40, 280), 128)
					beams.append({"a": from, "b": to, "life": 0.12, "col": [RED, YELLOW, CYAN][k], "pts": PackedVector2Array()})
					_burst(to, YELLOW, 3)
				await _wait(0.1)
			await _wait(0.1)
		"burst":
			for tg in list:
				var p := _pos_of(tg)
				rings.append({"p": p, "r0": 2.0, "r1": 28.0, "life": 0.35, "max": 0.35, "col": YELLOW})
				_burst(p, ORANGE, 20)
			_flash(Color(1, 0.8, 0.4, 0.6))
			shake = 4.0
			await _wait(0.35)
		"zap":
			for k in 4:
				for tg in list:
					var to := _pos_of(tg)
					beams.append({"a": Vector2.ZERO, "b": Vector2.ZERO, "life": 0.08, "col": CYAN if k % 2 == 0 else WHITE,
						"pts": _jagged(Vector2(to.x + randi_range(-8, 8), 34), to)})
				await _wait(0.09)
			_flash(Color(0.6, 0.9, 1, 0.4))
		"shield":
			for m in list:
				var p := _pos_of(m)
				rings.append({"p": p, "r0": 34.0, "r1": 4.0, "life": 0.4, "max": 0.4, "col": CYAN})
				_sparkle(p, CYAN, 10)
			await _wait(0.45)
		"heal", "energy":
			for m in list:
				_sparkle(_pos_of(m), GREEN if fx == "heal" else CYAN, 16)
			await _wait(0.45)
		"stars":
			for k in 34:
				particles.append({"p": Vector2(randf_range(60, 340), randf_range(-60, 10)), "v": Vector2(-70, 170),
					"life": 1.0, "col": [WHITE, YELLOW, PINK].pick_random(), "size": 2, "g": 0.0})
			await _wait(0.6)
			for tg in list:
				_burst(_pos_of(tg), PINK, 12)
			_flash(Color(1, 0.7, 1, 0.5))
			await _wait(0.2)
		"spore":
			for m in list:
				var p := _pos_of(m)
				for k in 18:
					particles.append({"p": p + Vector2(randf_range(-40, 40), randf_range(-60, -30)), "v": Vector2(0, randf_range(35, 70)),
						"life": 0.8, "col": Color("c8ff70"), "size": 1, "g": 0.0})
				rings.append({"p": p, "r0": 4.0, "r1": 30.0, "life": 0.5, "max": 0.5, "col": Color("c8ff70")})
			await _wait(0.7)
		"grenade":
			for tg in list:
				var p := _pos_of(tg)
				_burst(p, ORANGE, 18)
				rings.append({"p": p, "r0": 2.0, "r1": 22.0, "life": 0.3, "max": 0.3, "col": ORANGE})
			_flash(Color(1, 0.6, 0.2, 0.7))
			shake = 5.0
			await _wait(0.4)
		_:
			await _wait(0.2)


func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		var p := a.lerp(b, f)
		if i > 0 and i < 6:
			p.x += randi_range(-5, 5)
		pts.append(p.round())
	return pts


func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var ang := randf() * TAU
		var spd := randf_range(40, 110)
		particles.append({"p": p, "v": Vector2(cos(ang), sin(ang)) * spd, "life": randf_range(0.25, 0.55),
			"col": col, "size": randi_range(1, 2), "g": 140.0})


func _sparkle(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		particles.append({"p": p + Vector2(randf_range(-22, 22), randf_range(-6, 14)), "v": Vector2(0, randf_range(-45, -20)),
			"life": randf_range(0.5, 0.9), "col": col, "size": 1, "g": 0.0})


func _flash(c: Color) -> void:
	flash_col = c


func _floater(p: Vector2, text: String, col: Color, scale := 1) -> void:
	floaters.append({"text": text, "p": p, "vy": -32.0, "life": 1.1 if scale == 1 else 1.3, "col": col, "scale": scale})


# =============================================================================
# FRAME UPDATE + INPUT
# =============================================================================

func _process(delta: float) -> void:
	t += delta
	_update_message(delta)
	_update_party(delta)
	_update_enemies(delta)
	_update_fx(delta)
	_update_timing(delta)
	if shake > 0.0:
		position = Vector2(randi_range(-1, 1), randi_range(-1, 1)) * ceilf(shake)
		shake = move_toward(shake, 0.0, 14.0 * delta)
	else:
		position = Vector2.ZERO
	var target_int := 1.0 if danger else 0.0
	if phase2:
		target_int += 0.5
	bg_intensity = move_toward(bg_intensity, target_int, delta)
	(bg.material as ShaderMaterial).set_shader_parameter("intensity", bg_intensity)
	ui.queue_redraw()


func _update_message(delta: float) -> void:
	if not msg_waiting:
		return
	if msg_shown < msg_len:
		var before := int(msg_shown)
		msg_shown = minf(msg_len, msg_shown + TEXT_SPEED * delta)
		if int(msg_shown) / 3 != before / 3:
			Audio.play_sfx("text_blip", true)
	elif msg_hold >= 0.0:
		msg_hold -= delta
		if msg_hold <= 0.0:
			msg_waiting = false
			_msg_done.emit()


func _update_party(delta: float) -> void:
	for m in party:
		m.hurt = maxf(0.0, m.hurt - delta)
		m.raise = move_toward(m.raise, -6.0 if m.idx == active else 0.0, 60.0 * delta)
		if m.ko:
			continue
		# the rolling HP meter
		if m.hp_disp > m.hp:
			m.hp_disp = maxf(m.hp, m.hp_disp - ROLL_DOWN * delta)
		elif m.hp_disp < m.hp:
			m.hp_disp = minf(m.hp, m.hp_disp + ROLL_UP * delta)
		if m.hp <= 0 and m.hp_disp <= 0.0:
			m.ko = true
			m.guard = false
			m.shield = 0
			m.stun = 0
			Audio.play_sfx("party_ko")
			_floater(_card_center(m) + Vector2(0, -14), "KO", RED)
			if m.idx == active:
				_abort()
	if result == "" and not wiped and party.all(func(p): return p.ko):
		wiped = true
		_abort()
	var d := false
	for m in party:
		if not m.ko and m.hp <= m.max_hp * 0.3:
			d = true
	if result != "":
		d = false
	if d != danger:
		danger = d
		Audio.set_danger(d)


func _update_enemies(delta: float) -> void:
	for e in enemies:
		e.hurt = maxf(0.0, e.hurt - delta)
		e.hp_disp = move_toward(e.hp_disp, e.hp, 60.0 * delta)
		if not e.node.visible:
			continue
		var bob := roundf(sin(t * (1.5 if e.boss else 2.5) + e.phase) * 2.0)
		var sx := 0.0
		if e.hurt > 0.0:
			sx = 2.0 if int(e.hurt * 30.0) % 2 == 0 else -2.0
		e.node.position = e.base + Vector2(sx, bob + roundf(e.lunge * 8.0))
		if e.dead:
			continue
		var fl: float = e.lunge * 0.3
		if e.hurt > 0.0 and int(e.hurt * 20.0) % 2 == 0:
			fl = 1.0
		if target_mode == "enemy" and is_same(targets[target_i], e) and int(t * 8.0) % 2 == 0:
			fl = 0.35
		(e.node.material as ShaderMaterial).set_shader_parameter("flash", fl)


func _update_fx(delta: float) -> void:
	for p in particles:
		p.v.y += p.g * delta
		p.p += p.v * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0.0)
	for b in beams:
		b.life -= delta
	beams = beams.filter(func(b): return b.life > 0.0)
	for r in rings:
		r.life -= delta
	rings = rings.filter(func(r): return r.life > 0.0)
	for f in floaters:
		f.p.y += f.vy * delta
		f.vy = move_toward(f.vy, 0.0, 70.0 * delta)
		f.life -= delta
	floaters = floaters.filter(func(f): return f.life > 0.0)
	flash_col.a = move_toward(flash_col.a, 0.0, 3.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _debug_key(event.keycode):
			return
	if not timing.is_empty():
		if not timing.done and not auto_battle and event.is_action_pressed("confirm"):
			_resolve_timing(true)
		return
	if msg_waiting:
		if event.is_action_pressed("confirm"):
			if msg_shown < msg_len:
				msg_shown = msg_len
			elif msg_hold < 0.0:
				msg_waiting = false
				Audio.play_sfx("menu_select")
				_msg_done.emit()
			else:
				msg_hold = 0.0
		return
	if target_mode != "":
		var n := targets.size()
		if event.is_action_pressed("left", true) or event.is_action_pressed("up", true):
			target_i = (target_i - 1 + n) % n
			Audio.play_sfx("menu_move")
		elif event.is_action_pressed("right", true) or event.is_action_pressed("down", true):
			target_i = (target_i + 1) % n
			Audio.play_sfx("menu_move")
		elif event.is_action_pressed("confirm"):
			Audio.play_sfx("menu_select")
			_menu_done.emit(target_i)
		elif event.is_action_pressed("cancel"):
			Audio.play_sfx("menu_back")
			_menu_done.emit(-1)
		return
	if menu.is_empty():
		return
	var count: int = menu.options.size()
	var horizontal: bool = menu.type == "command"
	if event.is_action_pressed("left" if horizontal else "up", true):
		menu.index = (menu.index - 1 + count) % count
		Audio.play_sfx("menu_move")
	elif event.is_action_pressed("right" if horizontal else "down", true):
		menu.index = (menu.index + 1) % count
		Audio.play_sfx("menu_move")
	elif event.is_action_pressed("confirm"):
		if menu.enabled.is_empty() or menu.enabled[menu.index]:
			Audio.play_sfx("menu_select")
			_menu_done.emit(menu.index)
		else:
			Audio.play_sfx("menu_error")
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("menu_back")
		_menu_done.emit(-1)


## Test shortcuts so your composer can jump straight to any music moment.
func _debug_key(key: Key) -> bool:
	match key:
		KEY_F7:
			auto_battle = not auto_battle
			return true
		KEY_F6:
			if result == "":
				result = "quit"
				Audio.set_danger(false)
				finished.emit()
			return true
	if result != "":
		return false
	match key:
		KEY_F2:  # instant win
			for e in enemies:
				e.hp = 0
				e.dead = true
				e.node.visible = false
			_abort()
		KEY_F3:  # instant defeat
			for m in party:
				m.hp = 0
				m.hp_disp = 0.0
		KEY_F4:  # everyone to low HP (danger layer test)
			for m in party:
				if not m.ko:
					m.hp = maxi(1, int(m.max_hp * 0.15))
		KEY_F5:  # boss straight to phase 2 (after the next action)
			if kind == "boss" and not enemies[0].dead:
				enemies[0].hp = mini(enemies[0].hp, enemies[0].max_hp / 2)
		_:
			return false
	return true


# =============================================================================
# DRAWING
# =============================================================================

func _draw_ui() -> void:
	# enemy HP bars + stun stars
	for e in enemies:
		if e.dead:
			continue
		var w := 56 if e.boss else 40
		var x: float = e.base.x - w / 2
		var y: float = e.base.y + 3
		ui.draw_rect(Rect2(x - 1, y - 1, w + 2, 4), Color(0, 0, 0, 0.7))
		ui.draw_rect(Rect2(x, y, roundf(w * e.hp_disp / e.max_hp), 2), _hp_color(e.hp_disp / e.max_hp))
		if e.stun > 0:
			var top: float = e.node.position.y - e.h - 4
			for k in 3:
				var a := t * 5.0 + k * TAU / 3.0
				ui.draw_rect(Rect2(roundf(e.base.x + cos(a) * 10.0), roundf(top + sin(a) * 2.0), 2, 2), YELLOW)
	# effects
	for r in rings:
		var f: float = 1.0 - r.life / r.max
		ui.draw_arc(r.p, lerpf(r.r0, r.r1, f), 0.0, TAU, 24, r.col, 1.0)
	for b in beams:
		if b.pts.is_empty():
			ui.draw_line(b.a, b.b, b.col, 1.0)
		else:
			ui.draw_polyline(b.pts, b.col, 1.0)
	for p in particles:
		ui.draw_rect(Rect2(p.p.round(), Vector2(p.size, p.size)), p.col)
	_draw_top_box()
	_draw_list_menu()
	_draw_target_cursor()
	_draw_timing()
	for m in party:
		_draw_card(m)
	for f in floaters:
		if f.life < 0.25 and int(f.life * 20.0) % 2 == 0:
			continue
		var s: int = f.scale
		var w: int = PixelFont.width(f.text, s)
		PixelFont.draw(ui, Vector2(f.p.x - w / 2, f.p.y), f.text, f.col, s, Color(0, 0, 0, 1))
	if auto_battle:
		ui.draw_rect(Rect2(4, 33, 30, 9), Color(0, 0, 0, 0.6))
		PixelFont.draw(ui, Vector2(6, 34), "AUTO", CYAN)
	if flash_col.a > 0.0:
		ui.draw_rect(Rect2(-8, -8, 336, 196), flash_col)


func _draw_top_box() -> void:
	_box(TOP_BOX)
	var x := TOP_BOX.position.x + 6
	var y1 := TOP_BOX.position.y + 5
	var y2 := y1 + 10
	if target_mode != "":
		PixelFont.draw(ui, Vector2(x, y1), "WHO'S THE TARGET?", YELLOW)
		PixelFont.draw(ui, Vector2(x, y2), "▶ " + targets[target_i].name, WHITE)
	elif not menu.is_empty() and menu.type == "command":
		PixelFont.draw(ui, Vector2(x, y1), prompt, YELLOW)
		for i in menu.options.size():
			var ox: float = x + 4 + i * 60
			if i == menu.index:
				if int(t * 4.0) % 2 == 0:
					PixelFont.draw(ui, Vector2(ox, y2), "▶", YELLOW)
				PixelFont.draw(ui, Vector2(ox + 8, y2), menu.options[i], WHITE)
			else:
				PixelFont.draw(ui, Vector2(ox + 8, y2), menu.options[i], DIM)
	elif not menu.is_empty() and menu.type == "list":
		PixelFont.draw(ui, Vector2(x, y1), prompt, YELLOW)
		PixelFont.draw(ui, Vector2(x, y2), menu.descs[menu.index], WHITE)
	else:
		var remaining := int(msg_shown)
		for li in mini(msg_lines.size(), 2):
			var line: String = msg_lines[li]
			PixelFont.draw(ui, Vector2(x, y1 + li * 10), line.substr(0, clampi(remaining, 0, line.length())), WHITE)
			remaining -= line.length()
		if msg_waiting and msg_hold < 0.0 and msg_shown >= msg_len and int(t * 3.0) % 2 == 0:
			PixelFont.draw(ui, Vector2(TOP_BOX.end.x - 11, TOP_BOX.end.y - 9), "▼", YELLOW)


func _draw_list_menu() -> void:
	if menu.is_empty() or menu.type != "list":
		return
	var n: int = menu.options.size()
	var r := Rect2(4, 34, 136, 9 + n * 10)
	_box(r)
	for i in n:
		var y := r.position.y + 5 + i * 10
		var ok: bool = menu.enabled.is_empty() or menu.enabled[i]
		if i == menu.index and int(t * 4.0) % 2 == 0:
			PixelFont.draw(ui, Vector2(r.position.x + 5, y), "▶", YELLOW)
		PixelFont.draw(ui, Vector2(r.position.x + 13, y), menu.options[i], (WHITE if i == menu.index else Color("c0c0e0")) if ok else Color("50506a"))


func _draw_timing() -> void:
	if timing.is_empty():
		return
	var colors := {"perfect": YELLOW, "great": CYAN, "good": GREEN, "weak": ORANGE, "miss": DIM}
	var grade: Dictionary = timing.grade
	var gcol: Color = colors[grade.get("id", "miss")]
	_box(TIMING_BOX, gcol if timing.done else YELLOW)
	var label: String = grade.get("text", "MISS...") if timing.done else "PRESS Z IN THE ZONE!"
	PixelFont.draw(ui, TIMING_BOX.position + Vector2(6, 5), label, gcol if timing.done else WHITE)
	# the track, with the target zone drawn widest band first
	var ty := TIMING_BOX.position.y + 17
	ui.draw_rect(Rect2(TRACK_X, ty, TRACK_W, 7), Color(0, 0, 0, 0.75))
	var cx := roundf(TRACK_X + timing.zone * TRACK_W)
	var bands := {"good": Color("4a3a8a"), "great": Color("2a7aa0"), "perfect": YELLOW}
	# grades are listed narrowest-first, so draw them in reverse
	for i in range(Data.TIMING_GRADES.size() - 1, -1, -1):
		var g: Dictionary = Data.TIMING_GRADES[i]
		if bands.has(g.id):
			ui.draw_rect(Rect2(cx - g.px, ty, g.px * 2 + 1, 7), bands[g.id])
	# the moving marker
	var mx := roundf(TRACK_X + clampf(timing.x, 0.0, 1.0) * TRACK_W)
	var mcol := WHITE
	if timing.done and int(t * 12.0) % 2 == 0:
		mcol = gcol
	ui.draw_rect(Rect2(mx - 2, ty - 3, 4, 13), Color(0, 0, 0, 1))
	ui.draw_rect(Rect2(mx - 1, ty - 2, 2, 11), mcol)


func _draw_target_cursor() -> void:
	if target_mode == "":
		return
	var tg: Dictionary = targets[target_i]
	var p: Vector2
	if target_mode == "enemy":
		p = Vector2(tg.base.x, tg.node.position.y - tg.h - 8)
	else:
		p = Vector2(_card_center(tg).x, CARD_Y + tg.raise - 8)
	p.y += roundf(sin(t * 8.0) * 1.5)
	ui.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -1), p + Vector2(5, -1), p + Vector2(0, 5)]), Color(0, 0, 0, 1))
	ui.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(0, 4)]), YELLOW)


func _draw_card(m: Dictionary) -> void:
	var x: float = 7.0 + m.idx * 103
	var y: float = CARD_Y + roundf(m.raise + m.bounce)
	if m.hurt > 0.0:
		x += 2.0 if int(m.hurt * 30.0) % 2 == 0 else -2.0
	var border := WHITE
	var doomed: bool = not m.ko and m.hp <= 0
	if m.idx == active:
		border = YELLOW
	if doomed and int(t * 6.0) % 2 == 0:
		border = RED
	if target_mode == "ally" and is_same(targets[target_i], m) and int(t * 8.0) % 2 == 0:
		border = YELLOW
	var fill := BOX_BG
	if m.hurt > 0.0:
		fill = Color(0.35, 0.05, 0.1, 0.95)
	elif m.ko:
		fill = Color(0.08, 0.06, 0.1, 0.94)
	_box(Rect2(x, y, CARD_W, CARD_H), border, fill)
	ui.draw_texture(m.portrait, Vector2(x + 4, y + 4), Color(0.4, 0.4, 0.5) if m.ko else Color.WHITE)
	PixelFont.draw(ui, Vector2(x + 26, y + 5), m.name, YELLOW if m.idx == active else WHITE)
	var tags := []
	if m.ko:
		tags.append(["KO", RED])
	else:
		if doomed:
			tags.append(["!!", RED])
		if m.guard:
			tags.append(["GRD", CYAN])
		if m.shield > 0:
			tags.append(["SHD", CYAN])
		if m.stun > 0:
			tags.append(["STN", YELLOW])
	for k in mini(tags.size(), 2):
		PixelFont.draw(ui, Vector2(x + 4, y + 26 + k * 9), tags[k][0], tags[k][1])
	var hp_s := str(int(ceilf(m.hp_disp)))
	PixelFont.draw(ui, Vector2(x + 26, y + 15), "HP", DIM)
	PixelFont.draw(ui, Vector2(x + 97 - PixelFont.width(hp_s), y + 15), hp_s, RED if doomed else WHITE)
	_bar(x + 26, y + 24, 70, m.hp_disp / m.max_hp, _hp_color(m.hp_disp / m.max_hp))
	var en_s := str(m.en)
	PixelFont.draw(ui, Vector2(x + 26, y + 30), "EN", DIM)
	PixelFont.draw(ui, Vector2(x + 97 - PixelFont.width(en_s), y + 30), en_s, WHITE)
	_bar(x + 26, y + 39, 70, float(m.en) / m.max_en, CYAN)


func _box(r: Rect2, border := WHITE, fill := BOX_BG) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	ui.draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), fill)
	ui.draw_rect(Rect2(x + 2, y, w - 4, 1), border)
	ui.draw_rect(Rect2(x + 2, y + h - 1, w - 4, 1), border)
	ui.draw_rect(Rect2(x, y + 2, 1, h - 4), border)
	ui.draw_rect(Rect2(x + w - 1, y + 2, 1, h - 4), border)
	for c in [Vector2(x + 1, y + 1), Vector2(x + w - 2, y + 1), Vector2(x + 1, y + h - 2), Vector2(x + w - 2, y + h - 2)]:
		ui.draw_rect(Rect2(c, Vector2.ONE), border)


func _bar(x: float, y: float, w: float, ratio: float, col: Color) -> void:
	ui.draw_rect(Rect2(x, y, w, 3), Color(0, 0, 0, 0.6))
	ui.draw_rect(Rect2(x, y, roundf(w * clampf(ratio, 0.0, 1.0)), 3), col)


func _hp_color(r: float) -> Color:
	if r > 0.5:
		return GREEN
	if r > 0.25:
		return YELLOW
	return RED
