class_name WinScreen
extends Control

## Stars, loops, time survived, the endings row with silhouettes for the ones you
## have not found, completion, and the ways-to-die count. The empty slots are the
## pitch: they tell you something better exists without a word of text.

signal replay_pressed()

const ENDINGS: PackedStringArray = [
	SimOutcome.ENDING_EVADE, SimOutcome.ENDING_DISABLE,
	SimOutcome.ENDING_KILL, SimOutcome.ENDING_ESCAPE,
]

var visuals: GameVisuals = null

var _panel: PanelContainer = null
var _body: RichTextLabel = null


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	visible = false

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.add_theme_stylebox_override("panel", visuals.panel_style())
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -210
	_panel.offset_bottom = 210
	add_child(_panel)

	var column := VBoxContainer.new()
	_panel.add_child(column)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.custom_minimum_size = Vector2(580, 330)
	column.add_child(_body)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)

	var replay := Button.new()
	replay.text = "Replay"
	replay.focus_mode = Control.FOCUS_NONE
	replay.pressed.connect(func() -> void: hide_screen(); replay_pressed.emit())
	buttons.add_child(replay)

	var next := Button.new()
	next.text = "Next Room"
	next.disabled = true
	next.tooltip_text = "Rooms 2-4 are M5."
	buttons.add_child(next)


func show_result(report: Dictionary, entry: Dictionary, loop_index: int) -> void:
	_body.text = _compose(report, entry, loop_index)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func hide_screen() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible


func _compose(report: Dictionary, entry: Dictionary, loop_index: int) -> String:
	var completion: Dictionary = report["completion"]
	var stars := int(report["stars"])
	var found: Array = entry.get("endings_found", [])

	var row := PackedStringArray()
	for ending in ENDINGS:
		row.append("%s %s" % ["■" if found.has(ending) else "□", ending.capitalize()])

	var interactions := int(completion["interactions_possible"])
	var done: int = (entry.get("interactions_done", []) as Array).size()
	var discoveries: int = (entry.get("discoveries", []) as Array).size()
	var possible_discoveries: int = (completion["discoveries_possible"] as Array).size()
	var percent := 0.0
	var total := float(interactions + possible_discoveries)
	if total > 0.0:
		percent = 100.0 * float(done + discoveries) / total

	return "\n".join(PackedStringArray([
		"[center][font_size=48]%s[/font_size][/center]" % _stars(stars),
		"[center][b]%s[/b][/center]" % str(report["ending"]).to_upper(),
		"",
		"Deaths: %d    Time survived: %.1fs" % [maxi(loop_index - 1, 0), float(report["time_s"])],
		"",
		"[b]Endings[/b]   %s" % " ".join(row),
		"",
		"Interactions  %d / %d" % [done, interactions],
		"Discoveries   %d / %d" % [discoveries, possible_discoveries],
		"Ways to die   %d" % (entry.get("deaths", []) as Array).size(),
		"Collectible   %s" % ("found" if not (entry.get("collectible", []) as Array).is_empty() else "not found"),
		"",
		"[b]Completion %.0f%%[/b]" % percent,
		"",
		"[i]%s[/i]" % str(report["notebook"]),
	]))


static func _stars(earned: int) -> String:
	var out := ""
	for i in 3:
		out += "★" if i < earned else "☆"
	return out
