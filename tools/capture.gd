extends SceneTree

## Screenshots the running game, so a presentation change can carry evidence.
## CLAUDE.md asks for a screenshot in the PR; this is how one gets made.
##
##   godot --path . -s tools/capture.gd -- greybox 2.0
##   godot --path . -s tools/capture.gd -- wheel 1.0 --click 600,340
##
## Not headless: Godot's headless driver has no renderer, so this opens a window.

const SCENE := "res://game/main.tscn"
const OUT_DIR := "user://shots"

var _name := "shot"
var _capture_at := 1.5
var _clicks: Array = []
var _elapsed := 0.0
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_name = str(args[0])
	if args.size() > 1:
		_capture_at = float(args[1])
	var i := 2
	while i < args.size():
		if str(args[i]) == "--click" and i + 1 < args.size():
			var parts := str(args[i + 1]).split(",")
			_clicks.append({
				"at": _capture_at * 0.6,
				"point": Vector2(float(parts[0]), float(parts[1])),
				"cell": Vector2i(-1, -1),
				"done": false,
			})
			i += 2
		elif str(args[i]) == "--speed" and i + 1 < args.size():
			# Run the clock fast so a whole 75-second loop fits in a short capture.
			Engine.time_scale = float(args[i + 1])
			i += 2
		elif str(args[i]) == "--cell" and i + 1 < args.size():
			var coords := str(args[i + 1]).split(",")
			_clicks.append({
				"at": _capture_at * 0.6,
				"point": Vector2.ZERO,
				"cell": Vector2i(int(coords[0]), int(coords[1])),
				"done": false,
			})
			i += 2
		else:
			i += 1

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var packed: PackedScene = load(SCENE)
	if packed == null:
		printerr("capture: cannot load %s" % SCENE)
		quit(1)
		return
	get_root().add_child(packed.instantiate())


func _process(delta: float) -> bool:
	if _done:
		return true
	_elapsed += delta

	for click in _clicks:
		if bool(click["done"]) or _elapsed < float(click["at"]):
			continue
		click["done"] = true
		var point: Vector2 = click["point"]
		if click["cell"] != Vector2i(-1, -1):
			point = _cell_to_screen(click["cell"])
			if point == Vector2.ZERO:
				printerr("capture: cannot place cell %s on screen" % [click["cell"]])
				continue
		_send_click(point)

	if _elapsed < _capture_at:
		return false
	var image := get_root().get_texture().get_image()
	if image == null:
		printerr("capture: no framebuffer")
		return true
	var path := "%s/%s.png" % [OUT_DIR, _name]
	image.save_png(path)
	print("capture: %s  %dx%d  t=%.2fs" % [path, image.get_width(), image.get_height(), _elapsed])
	_report_state()
	_done = true
	return true


## A screenshot alone cannot prove the sim is doing anything. This can.
func _report_state() -> void:
	var main := get_root().get_child(get_root().get_child_count() - 1)
	var world: SimWorld = main.get("world")
	if world == null:
		printerr("capture: no world")
		return
	var attacker_at := "outside"
	if world.attacker != null and world.attacker.inside:
		attacker_at = str(world.attacker.pos)
	print("state: loop=%d timer=%.1fs player=%s holding=%s hidden=%s attacker=%s alive=%s ending=%s" % [
		main.get("loop_index"), world.timer_remaining_s(), world.player.pos,
		world.player.holding if not world.player.holding.is_empty() else "-",
		world.player.hidden_in if world.player.is_hidden() else "-",
		attacker_at, world.player.alive,
		world.ending if not world.ending.is_empty() else "-",
	])


## Clicking a grid cell is far steadier than clicking a pixel guess.
func _cell_to_screen(cell: Vector2i) -> Vector2:
	var main := get_root().get_child(get_root().get_child_count() - 1)
	var camera := main.find_child("IsoCamera", true, false) as Camera3D
	if camera == null:
		return Vector2.ZERO
	return camera.unproject_position(IsoCamera.cell_to_world(cell, 0.3))


func _send_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_root().push_input(event)
	print("capture: clicked %s at t=%.2fs" % [point, _elapsed])
