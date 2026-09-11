class_name SimObject
extends RefCounted

## Objects are tags + state + props. No method here ever branches on `id`.

const RESERVED_KEYS: PackedStringArray = [
	"id", "name", "tags", "footprint", "on", "state", "inspect", "contains",
]

var id: String = ""
var name: String = ""
var tags: PackedStringArray = []
var cells: Array[Vector2i] = []
var default_cells: Array[Vector2i] = []
var state: Dictionary = {}
var on: String = ""
var contains: PackedStringArray = []
var inspect: String = ""
var props: Dictionary = {}

var _tag_set: Dictionary = {}


static func from_json(data: Dictionary) -> SimObject:
	var o := SimObject.new()
	o.id = str(data.get("id", ""))
	o.name = str(data.get("name", o.id))
	for t in data.get("tags", []):
		o.tags.append(str(t))
		o._tag_set[str(t)] = true
	for pair in data.get("footprint", []):
		o.cells.append(Vector2i(int(pair[0]), int(pair[1])))
	o.default_cells = o.cells.duplicate()
	o.state = (data.get("state", {}) as Dictionary).duplicate(true)
	o.on = str(data.get("on", ""))
	for c in data.get("contains", []):
		o.contains.append(str(c))
	o.inspect = str(data.get("inspect", ""))
	for key in data:
		if not RESERVED_KEYS.has(key):
			o.props[key] = data[key]
	return o


func has_tag(tag: String) -> bool:
	return _tag_set.has(tag)


func has_all_tags(required: Variant) -> bool:
	for t in required:
		if not _tag_set.has(str(t)):
			return false
	return true


func has_any_tag(options: Variant) -> bool:
	for t in options:
		if _tag_set.has(str(t)):
			return true
	return false


func add_tag(tag: String) -> void:
	if not _tag_set.has(tag):
		tags.append(tag)
		_tag_set[tag] = true


func remove_tag(tag: String) -> void:
	if _tag_set.has(tag):
		_tag_set.erase(tag)
		var idx := tags.find(tag)
		if idx >= 0:
			tags.remove_at(idx)


func get_state(key: String, fallback: Variant = null) -> Variant:
	return state.get(key, fallback)


func set_state(key: String, value: Variant) -> void:
	state[key] = value


func prop(key: String, fallback: Variant = null) -> Variant:
	return props.get(key, fallback)


func origin() -> Vector2i:
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)


func occupies(cell: Vector2i) -> bool:
	return cells.has(cell)


func is_moved() -> bool:
	return cells != default_cells


## Objects the actor can stand on (rugs) do not take occupancy.
func blocks_movement() -> bool:
	return not bool(prop("walk_over", false)) and not has_tag("carryable")


func blocks_sight() -> bool:
	return has_tag("blocks-sight")


## Reach connectivity: 4 by default, 8 for things reached across a counter.
func reach_connectivity() -> int:
	return int(prop("reach", 4))


func reset_to_default() -> void:
	cells = default_cells.duplicate()
