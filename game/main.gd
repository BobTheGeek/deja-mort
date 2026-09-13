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
var _banner_at: float = 0.0
var _elapsed: float = 0.0
var _target := ClickTarget.new()
var _log := SessionLog.new()
var _finished: bool = false

## Held by the title screen while the door is still opening: the room is built
## behind the door, and its timer must not start until the cut.
var held: bool = false


func _ready() -> void:
	content = SimContent.load_from()
	visuals = GameVisuals.load_table()
	_save = SaveData.load_or_new()
	if not content.errors.is_empty():
		for e in content.errors:
			push_error("content: %s" % e)
		return
	_start_log()
	_size_window()
	# Before anything is built: a phone needs the UI bigger than the design and
	# out from under its own notch, and both are read from the device.
	UiScale.apply(get_window(), visuals)
	get_window().size_changed.connect(_on_window_resized)
	_build_nodes()
	_start_loop()


## The UI is drawn at 1920x1080 and stretched to the window, so a small window
## renders all of it small. Desktop only, and only the window it opens with —
## resizing after that is the player's business.
func _size_window() -> void:
	if OS.has_feature("mobile"):
		return
	var window := get_window()
	if window == null:
		return
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	var wanted := UiScale.window_size(screen.size, visuals)
	if wanted == window.size:
		return
	window.size = wanted
	window.position = screen.position + (screen.size - wanted) / 2


## A recording of the session, for reading a playtest rather than guessing at
## one. Debug builds only.
func _start_log() -> void:
	if not SessionLog.wanted(visuals, OS.is_debug_build()):
		return
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [now["year"], now["month"], now["day"],
		now["hour"], now["minute"], now["second"]]
	if _log.start(SessionLog.path_for(stamp)):
		print("session log: %s" % ProjectSettings.globalize_path(_log.path()))


func _exit_tree() -> void:
	_log.close()


## A window that moves to another screen can change DPI under us.
func _on_window_resized() -> void:
	UiScale.apply(get_window(), visuals)


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

	# The wheel's pause vignette goes below the HUD: it is there to dim the room,
	# not the timer the player is racing.
	_wheel = ActionWheel.new()
	_wheel.name = "Wheel"
	layer.add_child(_wheel.backdrop())

	_hud = GameHud.new()
	_hud.name = "Hud"
	layer.add_child(_hud)
	_hud.setup(visuals)
	_hud.notebook_pressed.connect(_on_notebook_pressed)

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
uniform float grain = 0.035;
// docs/06: vignette and slight grain, so it reads as a diorama and not a render.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(softness, 0.85, d) * strength;
	float g = (hash(FRAGCOORD.xy) - 0.5) * grain;
	COLOR = vec4(vec3(max(g, 0.0)), clamp(v + abs(g), 0.0, 1.0));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", visuals.number("vignette.strength", 0.85))
	material.set_shader_parameter("softness", visuals.number("vignette.softness", 0.45))
	material.set_shader_parameter("grain", visuals.number("vignette.grain", 0.035))
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
	_log.loop_started(loop_index)
	_log.listen(world)
	_audio.listen(world)
	_tick_seconds = 1.0 / float(world.system("tick_hz"))
	_accumulator = 0.0
	_reset_at = -1.0
	_target.reset()

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
		_renderer.sync(world, delta, _accumulator / _tick_seconds)
		_hud.advance(delta)
		# The word LOSS across the middle of the beat is the thing that made a
		# death feel like a spreadsheet. Let it play; name it at the end.
		_hud.sync(world, loop_index, _elapsed < _banner_at)
		return

	# Any panel open = sim paused. Thinking is free; doing costs seconds.
	if not _is_paused() and world.ending.is_empty():
		_accumulator += delta
		while _accumulator >= _tick_seconds:
			_accumulator -= _tick_seconds
			world.step()
			if not world.ending.is_empty():
				break

	_log.advance(delta)
	_wheel.advance(delta)
	_notebook.advance(delta)
	_win.advance(delta)
	if not _is_paused():
		_audio.tick_metronome(world)
	_renderer.sync(world, delta, _accumulator / _tick_seconds)
	_hud.advance(delta)
	_hud.sync(world, loop_index, _win.is_open() or _notebook.is_open())


func _is_paused() -> bool:
	return held or _wheel.is_open() or _notebook.is_open() or _win.is_open()


func _on_sim_event(event: SimEvent) -> void:
	# He swings before the screen says anything. The sim already resolved it; this
	# is the beat docs/06 asks for, staged from the cause it recorded.
	if event.type == SimEvent.TYPE_ATTACK:
		var beat := DeathBeat.resolve(visuals, world.room,
			world.death_cause_for_weapon(str(event.meta.get("weapon", ""))))
		_renderer.play_once(event.actor, str(beat.get("attacker_clip", "")), float(beat.get("hold_s", 2.0)))
	# Any event carrying words is a thing the room just told you. Inspect is the
	# only one so far, and keying on the words rather than on the verb means the
	# next rule that has something to say needs no code here.
	if event.meta.has("text"):
		var about := world.objects.by_id(event.object) if not event.object.is_empty() else null
		_hud.show_inspect(about.name if about != null else "", str(event.meta["text"]))
	if event.type == SimEvent.TYPE_DEATH and event.actor == world.player.id:
		var death := DeathBeat.resolve(visuals, world.room, str(event.meta.get("cause", "")))
		_renderer.flicker(float(death.get("light_flicker", 0.0)))
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
	_log.loop_ended(ending, int(report["stars"]), float(report["time_s"]))
	_save.record_loop(room_id, world, report, loop_index)
	_save.save()
	if SimOutcome.won(ending):
		_win.show_result(report, _save.room(room_id), loop_index)
		_log.panel("win", true)
		return
	_schedule_reset()


func _on_replay() -> void:
	loop_index += 1
	_start_loop()


## Long enough to watch him die, short enough to keep "one more try" — and a
## click cuts it short, so the beat never costs you a retry you did not want.
func _schedule_reset() -> void:
	if _reset_at >= 0.0:
		return
	_wheel.close()
	var beat := DeathBeat.resolve(visuals, world.room, world.player.death_cause)
	_reset_at = _elapsed + maxf(float(beat.get("hold_s", 2.0)),
		visuals.number("loop.death_reset_s", 0.55))
	_banner_at = _reset_at - visuals.number("death.banner_last_s", 0.7)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if _reset_at >= 0.0:
		if event.is_pressed():
			_reset_at = _elapsed
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
		_log.panel("notebook", _notebook.is_open())
		return
	if event is InputEventMouseMotion:
		_hud.hover_at((event as InputEventMouseMotion).position)
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
	# The notebook button is HUD, not room. A phone has no Tab key.
	if _hud.press_at(click.position):
		return
	_click_world(click.position)


func _on_notebook_pressed() -> void:
	_notebook.toggle(world, _save.room(room_id))
	_log.panel("notebook", _notebook.is_open())


## What the player meant. The ray goes at what is drawn first, because the floor
## square under the cursor is the wrong answer for anything tall: from this
## camera the middle of the fridge sits over the square behind it.
func _click_world(screen_point: Vector2) -> void:
	var picked := _pick_near(screen_point)
	var on_screen := world.objects.by_id(picked) if not picked.is_empty() else null
	var cell := on_screen.origin() if on_screen != null else _camera.cell_under(screen_point)
	if not world.grid.in_bounds(cell):
		return
	_log.click(screen_point, cell, picked)
	var target: Variant = _target.choose(world, cell, picked)
	if target != null:
		var at := _target.position_on(world, cell)
		_wheel.open_at(world, target, screen_point, int(at[0]), int(at[1]))
		return
	_log.walk(cell, world.walk_to(cell))


## What is under the tap, and failing that what is beside it. A finger is wider
## than a pixel and the smallest object in Room 1 is about 26 canvas px across,
## so a near miss looks again in a small ring rather than walking you somewhere.
func _pick_near(screen_point: Vector2) -> String:
	var hit := _renderer.pick(_camera.project_ray_origin(screen_point),
		_camera.project_ray_normal(screen_point))
	if not hit.is_empty():
		return hit
	for offset in ClickTarget.ring(visuals.number("object.pick_tolerance_px", 14.0)):
		var point := screen_point + offset
		hit = _renderer.pick(_camera.project_ray_origin(point), _camera.project_ray_normal(point))
		if not hit.is_empty():
			return hit
	return ""


## A refusal keeps the wheel open and says so. Closing silently was
## indistinguishable from a character who would not move.
func _on_verb_chosen(verb: String, target: Variant, rule_id: String) -> void:
	if not world.ending.is_empty():
		_wheel.close()
		return
	var accepted := world.verb_on(verb, target, rule_id)
	_log.intent(verb, target, rule_id, accepted)
	if accepted:
		_wheel.close()
		return
	_wheel.report_refused(verb)
