class_name GameVisuals
extends RefCounted

## Loads content/visuals.json. Everything game/ knows about how the room looks
## comes through here, so no look is ever hardcoded and no object is ever named.

const PATH := "res://content/visuals.json"

var data: Dictionary = {}


static func load_table() -> GameVisuals:
	var v := GameVisuals.new()
	if FileAccess.file_exists(PATH):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(PATH)) == OK:
			v.data = json.data
		else:
			push_error("GameVisuals: %s does not parse" % PATH)
	else:
		push_error("GameVisuals: %s missing" % PATH)
	return v


## Dotted lookup: get("camera.size").
func get_value(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = data
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return fallback
	return node


func number(path: String, fallback: float = 0.0) -> float:
	return float(get_value(path, fallback))


func flag(path: String, fallback: bool = false) -> bool:
	return bool(get_value(path, fallback))


func colour(path: String, fallback := Color(1, 0, 1)) -> Color:
	var raw: Variant = get_value(path, null)
	return to_colour(raw, fallback)


func colour_with_alpha(path: String, alpha_path: String, fallback := Color(1, 0, 1)) -> Color:
	var base := colour(path, fallback)
	return Color(base.r, base.g, base.b, number(alpha_path, 1.0))


static func to_colour(raw: Variant, fallback := Color(1, 0, 1)) -> Color:
	if raw is Array and (raw as Array).size() >= 3:
		return Color(float(raw[0]), float(raw[1]), float(raw[2]))
	return fallback


## One opaque panel style for every overlay, so nothing shows the room through it.
func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour("panel.color", Color(0.06, 0.06, 0.08))
	var border := int(number("panel.border_width", 2.0))
	style.set_border_width_all(border)
	style.border_color = colour("panel.border_color", Color(0.3, 0.3, 0.3))
	style.set_corner_radius_all(int(number("panel.corner_radius", 4.0)))
	var padding := int(number("panel.padding", 18.0))
	style.set_content_margin_all(padding)
	return style


## Merges the default object look with every `by_tag` entry this object matches.
## Later tags win on each key, and tag order comes from the JSON, so two objects
## with the same tags always resolve to the same look.
func object_look(tags: PackedStringArray) -> Dictionary:
	var look: Dictionary = (get_value("object.default", {}) as Dictionary).duplicate(true)
	var by_tag: Dictionary = get_value("object.by_tag", {})
	for tag in by_tag:
		if not tags.has(tag):
			continue
		for key in (by_tag[tag] as Dictionary):
			look[key] = by_tag[tag][key]
	return look


## State keys that are truthy on this object, applied over its base look.
func apply_state(look: Dictionary, state: Dictionary) -> Dictionary:
	var out := look.duplicate(true)
	var table: Dictionary = get_value("state_visual", {})
	for key in table:
		if not state.has(key) or not _truthy(state[key]):
			continue
		for field in (table[key] as Dictionary):
			out[field] = table[key][field]
	return out


static func _truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	if value is String:
		return not (value as String).is_empty()
	return value != null
