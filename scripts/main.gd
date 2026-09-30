extends Node2D
## Switches between the title screen and battles, with a swirly transition.
##
## Command-line shortcuts (handy for testing):
##   godot --path . -- --auto-standard   start a standard battle on auto-pilot
##   godot --path . -- --auto-boss       start the boss battle on auto-pilot

const Title := preload("res://scripts/title.gd")
const Battle := preload("res://scripts/battle.gd")
const SWIRL := preload("res://shaders/swirl.gdshader")

var screen: Node
var wipe: ColorRect


func _enter_tree() -> void:
	_setup_input()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	wipe = ColorRect.new()
	wipe.size = Vector2(320, 180)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SWIRL
	wipe.material = mat
	layer.add_child(wipe)
	_set_wipe(0.0)
	var args := OS.get_cmdline_user_args()
	if "--auto-boss" in args or "--auto-standard" in args:
		Battle.auto_battle = true
		_start_battle("boss" if "--auto-boss" in args else "standard")
	else:
		_show_title()


func _show_title() -> void:
	var title := Title.new()
	_swap(title)
	title.start_battle.connect(_start_battle)
	Audio.play_music("title_loop", 0.5)


func _start_battle(kind: String) -> void:
	Audio.stop_music(0.2)
	Audio.play_sfx("encounter")
	await _animate_wipe(0.0, 1.0, 0.9)
	var battle := Battle.new()
	battle.kind = kind
	_swap(battle)
	battle.finished.connect(_end_battle)
	await _animate_wipe(1.0, 0.0, 0.45)
	battle.begin()


func _end_battle() -> void:
	Audio.stop_music(0.6)
	await _animate_wipe(0.0, 1.0, 0.6)
	_show_title()
	await _animate_wipe(1.0, 0.0, 0.45)


func _swap(node: Node) -> void:
	if screen:
		screen.queue_free()
	screen = node
	add_child(node)


func _set_wipe(v: float) -> void:
	(wipe.material as ShaderMaterial).set_shader_parameter("progress", v)
	wipe.visible = v > 0.0


func _animate_wipe(from: float, to: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_wipe, from, to, dur)
	await tw.finished


func _setup_input() -> void:
	var keys := {
		"up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D],
		"confirm": [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER],
		"cancel": [KEY_X, KEY_ESCAPE, KEY_BACKSPACE],
	}
	var pads := {
		"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
		"confirm": JOY_BUTTON_A, "cancel": JOY_BUTTON_B,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
