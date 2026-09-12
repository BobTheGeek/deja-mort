class_name Notebook
extends Control

## Auto-written, never typed. Three tabs: what is in the room, what he did, and
## how you died. It is the hint system and it is the only voice the game has.

const TAB_ROOM := "Room"
const TAB_ATTACKER := "Attacker"
const TAB_DEATHS := "Deaths"
const TABS: PackedStringArray = [TAB_ROOM, TAB_ATTACKER, TAB_DEATHS]

var visuals: GameVisuals = null

var _panel: PanelContainer = null
var _tab_row: HBoxContainer = null
var _body: RichTextLabel = null
var _active := TAB_ROOM


func setup(table: GameVisuals) -> void:
	visuals = table
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	visible = false

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.add_theme_stylebox_override("panel", visuals.panel_style())
	_panel.custom_minimum_size = Vector2(620, 460)
	_panel.offset_left = -310
	_panel.offset_right = 310
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	add_child(_panel)

	var column := VBoxContainer.new()
	_panel.add_child(column)

	_tab_row = HBoxContainer.new()
	column.add_child(_tab_row)
	for tab in TABS:
		var button := Button.new()
		button.text = tab
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _active = tab; _render())
		_tab_row.add_child(button)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.custom_minimum_size = Vector2(600, 400)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)


var _world: SimWorld = null
var _entry: Dictionary = {}


func show_for(world: SimWorld, entry: Dictionary) -> void:
	_world = world
	_entry = entry
	_render()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func hide_book() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible


func toggle(world: SimWorld, entry: Dictionary) -> void:
	if visible:
		hide_book()
	else:
		show_for(world, entry)


func _render() -> void:
	for button in _tab_row.get_children():
		(button as Button).modulate.a = 1.0 if (button as Button).text == _active else 0.5
	match _active:
		TAB_ATTACKER:
			_body.text = _lines_or_blank(_entry.get("attacker_notes", []), "Nothing observed yet.")
		TAB_DEATHS:
			var deaths := PackedStringArray()
			for record in _entry.get("notebook", []):
				deaths.append("[b]Death %d.[/b] %s" % [int(record["loop"]) - 1, record["line"]])
			_body.text = _lines_or_blank(Array(deaths), "No deaths yet. Give it time.")
		_:
			_body.text = _room_page()


## Objects you have looked at, with the tag hints Inspect revealed.
func _room_page() -> String:
	if _world == null:
		return "—"
	var seen := PackedStringArray()
	for done in _entry.get("interactions_done", []):
		var parts := str(done).split("|")
		if parts.size() != 2 or parts[0] != "inspect":
			continue
		var obj := _world.objects.by_id(parts[1])
		if obj == null:
			continue
		seen.append("[b]%s[/b]\n%s\n[i]%s[/i]\n" % [obj.name, obj.inspect, ", ".join(obj.tags)])
	return _lines_or_blank(Array(seen), "Nothing inspected yet.")


func _lines_or_blank(lines: Array, blank: String) -> String:
	if lines.is_empty():
		return blank
	var text := PackedStringArray()
	for line in lines:
		text.append(str(line))
	return "\n".join(text)
