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
var _choice_box: VBoxContainer = null
var _backdrop: ColorRect = null
var _centre := Vector2.ZERO


func setup(table: GameVisuals, world: SimWorld) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	visible = false

	# Dimming the room is how the pause reads. Wheel open = sim stopped.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(
		visuals.colour("wheel.backdrop_color", Color.BLACK),
		visuals.number("wheel.backdrop_alpha", 0.45),
	)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.size = get_viewport_rect().size
	add_child(_backdrop)

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

	_choice_box = VBoxContainer.new()
	_choice_box.visible = false
	add_child(_choice_box)


func is_open() -> bool:
	return visible


func open_at(world: SimWorld, target: Variant, screen_point: Vector2) -> void:
	_target = target
	_centre = screen_point
	_layout()
	_refresh(world)
	_hide_choices()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_choices()
	_target = null


func target() -> Variant:
	return _target


func _layout() -> void:
	var radius := visuals.number("wheel.radius", 104.0)
	var slot_size := visuals.number("wheel.slot_size", 78.0)
	var centre_size := visuals.number("wheel.center_size", 92.0)
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
	_choice_box.position = _centre + Vector2(radius + slot_size * 0.5, -slot_size)


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


func _on_slot_pressed(verb: String) -> void:
	var button: Button = _slots[verb]
	var rule_ids: PackedStringArray = button.get_meta("rule_ids", PackedStringArray())
	if rule_ids.size() <= 1:
		var rule_id := rule_ids[0] if rule_ids.size() == 1 else ""
		chosen.emit(verb, _target, rule_id)
		return
	# More than one rule matches this verb on this target — locking a door and
	# chaining it are both `toggle`. Ask rather than silently picking the first.
	_show_choices(verb, rule_ids)


func _show_choices(verb: String, rule_ids: PackedStringArray) -> void:
	_hide_choices()
	for rule_id in rule_ids:
		var button := Button.new()
		button.text = rule_id.replace("_", " ")
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: chosen.emit(verb, _target, rule_id))
		_choice_box.add_child(button)
	_choice_box.visible = true


func _hide_choices() -> void:
	for child in _choice_box.get_children():
		child.queue_free()
	_choice_box.visible = false
