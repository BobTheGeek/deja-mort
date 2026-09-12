class_name GameMain
extends Node3D

## The only place presentation and simulation meet. It owns a SimWorld, steps it
## at the sim's own tick rate, hands the renderer state to draw, and turns clicks
## into intents. It never decides an outcome: every ending comes from the sim.

const ROOM_PATH := "res://content/rooms/%s.json"

@export var room_id: String = "room_01_studio"

var world: SimWorld = null
var content: SimContent = null
var visuals: GameVisuals = null
var loop_index: int = 1

var _renderer: RoomRenderer = null
var _camera: IsoCamera = null
var _wheel: ActionWheel = null
var _hud: GameHud = null
var _vignette: ColorRect = null
var _notebook: Notebook = null
var _win: WinScreen = null
var _save: SaveData = null
var _audio: AudioDirector = null

var _accumulator: float = 0.0
var _tick_seconds: float = 0.1
var _reset_at: float = -1.0
var _elapsed: float = 0.0
var _cycle: Dictionary = {}   # cell key -> which overlapping object to offer next
var _finished: bool = false


func _ready() -> void:
	content = SimContent.load_from()
	visuals = GameVisuals.load_table()
	_save = SaveData.load_or_new()
	if not content.errors.is_empty():
		for e in content.errors:
			push_error("content: %s" % e)
		return
	_build_nodes()
	_start_loop()


func _build_nodes() -> void:
	_renderer = RoomRenderer.new()
	_renderer.name = "RoomRenderer"
	add_child(_renderer)

	_camera = IsoCamera.new()
	_camera.name = "IsoCamera"
	_camera.current = true
	add_child(_camera)

	_audio = AudioDirector.new()
	_audio.name = "AudioDirector"
	add_child(_audio)
	_audio.setup()

	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material()
	layer.add_child(_vignette)

	_hud = GameHud.new()
	_hud.name = "Hud"
	layer.add_child(_hud)
	_hud.setup(visuals)

	_wheel = ActionWheel.new()
	_wheel.name = "Wheel"
	layer.add_child(_wheel)

	_notebook = Notebook.new()
	_notebook.name = "Notebook"
	layer.add_child(_notebook)
	_notebook.setup(visuals)

	_win = WinScreen.new()
	_win.name = "WinScreen"
	layer.add_child(_win)
	_win.setup(visuals)
	_win.replay_pressed.connect(_on_replay)


func _vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.85;
uniform float softness = 0.45;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(softness, 0.85, d) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, v);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", visuals.number("vignette.strength", 0.85))
	material.set_shader_parameter("softness", visuals.number("vignette.softness", 0.45))
	return material


# --- the loop ----------------------------------------------------------------

func _start_loop() -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(ROOM_PATH % room_id)) != OK:
		push_error("cannot read room %s" % room_id)
		return
	# A fresh seed per loop: the room resets completely, only knowledge persists.
	world = SimWorld.create(json.data, content, SimRng.new(loop_index))
	world.events.subscribe(_on_sim_event)
	_audio.listen(world)
	_tick_seconds = 1.0 / float(world.system("tick_hz"))
	_accumulator = 0.0
	_reset_at = -1.0
	_cycle.clear()

	_finished = false
	_camera.setup(visuals, world.grid.width, world.grid.height)
	_renderer.build(world, visuals)
	_wheel.setup(visuals, world)
	if not _wheel.chosen.is_connected(_on_verb_chosen):
		_wheel.chosen.connect(_on_verb_chosen)
	_wheel.close()


func _process(delta: float) -> void:
	if world == null:
		return
	_elapsed += delta

	if _reset_at >= 0.0:
		if _elapsed >= _reset_at:
			loop_index += 1
			_start_loop()
		_renderer.sync(world, delta)
		_hud.sync(world, loop_index, false)
		return

	# Any panel open = sim paused. Thinking is free; doing costs seconds.
	if not _is_paused() and world.ending.is_empty():
		_accumulator += delta
		while _accumulator >= _tick_seconds:
			_accumulator -= _tick_seconds
			world.step()
			if not world.ending.is_empty():
				break

	if not _is_paused():
		_audio.tick_metronome(world)
	_renderer.sync(world, delta)
	_hud.sync(world, loop_index, _win.is_open() or _notebook.is_open())


func _is_paused() -> bool:
	return _wheel.is_open() or _notebook.is_open() or _win.is_open()


func _on_sim_event(event: SimEvent) -> void:
	if event.type == SimEvent.TYPE_DEATH and event.actor == world.player.id:
		_hud.flash("DEAD")
	elif event.type == SimEvent.TYPE_ENDING:
		_finish_loop(str(event.meta.get("ending", "")))


## One place where a finished loop is banked. The sim decided the ending; this
## only records it and chooses what the player sees next.
func _finish_loop(ending: String) -> void:
	if _finished:
		return
	_finished = true
	_wheel.close()
	var report := SimOutcome.evaluate(world, loop_index)
	_save.record_loop(room_id, world, report, loop_index)
	_save.save()
	if SimOutcome.won(ending):
		_win.show_result(report, _save.room(room_id), loop_index)
		return
	_schedule_reset()


func _on_replay() -> void:
	loop_index += 1
	_start_loop()


## Death to control in under a second, from data. Slow deaths kill "one more try".
func _schedule_reset() -> void:
	if _reset_at >= 0.0:
		return
	_wheel.close()
	_reset_at = _elapsed + visuals.number("loop.death_reset_s", 0.55)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if world == null or _reset_at >= 0.0:
		return
	if _win.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		_wheel.close()
		_notebook.hide_book()
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_TAB:
		_notebook.toggle(world, _save.room(room_id))
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_wheel.close()
		return
	if click.button_index != MOUSE_BUTTON_LEFT or _is_paused():
		return
	_click_world(click.position)


func _click_world(screen_point: Vector2) -> void:
	var cell := _camera.cell_under(screen_point)
	if not world.grid.in_bounds(cell):
		return
	var target: Variant = _pick_target(cell)
	if target != null:
		_wheel.open_at(world, target, screen_point)
		return
	world.walk_to(cell)


## Objects stack on a cell — a toaster sits on a drawer. Clicking the same cell
## again offers the next one rather than always picking the first.
func _pick_target(cell: Vector2i) -> Variant:
	var here := world.objects.at_cell(cell)
	if here.is_empty():
		return null
	var key := "%d,%d" % [cell.x, cell.y]
	var index := int(_cycle.get(key, -1)) + 1
	if index >= here.size():
		index = 0
	_cycle[key] = index
	return here[index].id


func _on_verb_chosen(verb: String, target: Variant, rule_id: String) -> void:
	_wheel.close()
	if world.ending.is_empty():
		world.verb_on(verb, target, rule_id)
