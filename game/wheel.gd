class_name ActionWheel
extends Control

## Eight fixed slots plus Inspect in the middle. Slot order comes from
## content/verbs.json, availability from SimVerbs — the same function the solver
## uses — so a faded slot is the truth, not a guess.
##
## Opening the wheel pauses the sim. That is the whole time model: thinking is
## free, doing costs seconds.

signal chosen(verb: String, target: Variant, rule_id: String)
signal dismissed()

var visuals: GameVisuals = null

var _target: Variant = null
var _slots: Dictionary = {}        # verb -> Button
var _backdrop: ColorRect = null
var _caption: Label = null
var _centre := Vector2.ZERO
var _world: SimWorld = null


func setup(table: GameVisuals, world: SimWorld) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Dimming the room is how the pause reads. Wheel open = sim stopped.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(
		visuals.colour("wheel.backdrop_color", Color.BLACK),
		visuals.number("wheel.backdrop_alpha", 0.45),
	)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Up to five objects share a cell in Room 1. Without this the wheel is aimed
	# at something you cannot see it aiming at, and a refusal is indistinguishable
	# from a character who will not move.
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", int(visuals.number("wheel.caption_size", 20.0)))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	var angles: Dictionary = visuals.get_value("wheel.slot_angles_deg", {})
	for entry in world.content.verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var slot := str((entry as Dictionary).get("slot", ""))
		var label := str((entry as Dictionary).get("label", verb))
		var button := Button.new()
		button.text = label
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("verb", verb)
		button.set_meta("slot", slot)
		button.set_meta("angle", float(angles.get(slot, 0.0)))
		button.pressed.connect(_on_slot_pressed.bind(verb))
		add_child(button)
		_slots[verb] = button

	_fit_viewport()


## Built off the tree in tests, where there is no viewport to measure. Measuring
## first used to abort setup and take the slots and the caption down with it.
func _fit_viewport() -> void:
	var view := get_viewport()
	if view == null:
		return
	size = view.get_visible_rect().size
	if _backdrop != null:
		_backdrop.size = size
	if not view.size_changed.is_connected(_fit_viewport):
		view.size_changed.connect(_fit_viewport)


func is_open() -> bool:
	return visible


func open_at(world: SimWorld, target: Variant, screen_point: Vector2,
		index: int = 1, count: int = 1) -> void:
	_target = target
	_world = world
	_centre = screen_point
	_set_caption(_describe(world, target, index, count))
	_layout()
	_refresh(world)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target = null


func target() -> Variant:
	return _target


func target_label() -> String:
	return _caption.text if _caption != null else ""


## Says what is under the cursor, and which of the things under the cursor it is.
func _describe(world: SimWorld, target: Variant, index: int, count: int) -> String:
	var name := str(target)
	if target is String:
		var obj := world.objects.by_id(str(target))
		if obj != null:
			name = obj.name
	elif target is Vector2i:
		name = "Floor %s" % [target]
	if count > 1:
		return "%s   (%d of %d here — click again to cycle)" % [name, index, count]
	return name


## A refused action that closes the wheel and says nothing reads as a bug.
func report_refused(verb: String) -> void:
	if _caption == null:
		return
	_caption.text = "%s — can't do that from here" % verb.capitalize()
	_caption.add_theme_color_override("font_color", visuals.colour("wheel.refused_color", Color.RED))


func _set_caption(text: String) -> void:
	_caption.text = text
	_caption.add_theme_color_override("font_color", visuals.colour("wheel.caption_color", Color.WHITE))


func _layout() -> void:
	var radius := visuals.number("wheel.radius", 104.0)
	var slot_size := visuals.number("wheel.slot_size", 78.0)
	var centre_size := visuals.number("wheel.center_size", 92.0)
	var caption_width := 520.0
	_caption.size = Vector2(caption_width, 28.0)
	_caption.position = _centre + Vector2(-caption_width * 0.5, -radius - slot_size * 0.9)
	for verb in _slots:
		var button: Button = _slots[verb]
		var is_centre := str(button.get_meta("slot")) == "center"
		var box := Vector2(centre_size, centre_size) if is_centre else Vector2(slot_size, slot_size)
		button.size = box
		if is_centre:
			button.position = _centre - box * 0.5
			continue
		var angle := deg_to_rad(float(button.get_meta("angle")))
		var offset := Vector2(sin(angle), -cos(angle)) * radius
		button.position = _centre + offset - box * 0.5


## Availability for all nine verbs, available or not. The faded slots are the
## tutorial, so they stay on screen.
func _refresh(world: SimWorld) -> void:
	var available_alpha := visuals.number("wheel.available_alpha", 1.0)
	var faded_alpha := visuals.number("wheel.faded_alpha", 0.28)
	var table := SimVerbs.availability(world, world.player, _target)
	for verb in _slots:
		var button: Button = _slots[verb]
		var entry: Dictionary = table.get(verb, {})
		var usable := bool(entry.get("available", false))
		button.disabled = not usable
		button.modulate.a = available_alpha if usable else faded_alpha
		button.set_meta("rule_ids", entry.get("rule_ids", PackedStringArray()))
		var duration := float(entry.get("duration_s", 0.0))
		button.tooltip_text = "%s  %.1fs" % [verb, duration] if usable else "%s — no rule" % verb


## Exactly one rule is choosable per verb — content/lint_exceptions.json is empty
## and tools/lint_room.gd fails the build if that ever stops being true — so the
## wheel picks and goes. It never asks which rule you meant.
func _on_slot_pressed(verb: String) -> void:
	var rule_ids: PackedStringArray = _slots[verb].get_meta("rule_ids", PackedStringArray())
	chosen.emit(verb, _target, rule_ids[0] if rule_ids.size() == 1 else "")
