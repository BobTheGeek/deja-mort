class_name SimObjectStore
extends RefCounted

## Objects in declaration order, plus a cell index kept in step with moves.

var _order: Array[SimObject] = []
var _by_id: Dictionary = {}
var _by_cell: Dictionary = {}   # Vector2i -> Array[SimObject]


static func from_json(objects: Array) -> SimObjectStore:
	var s := SimObjectStore.new()
	for raw in objects:
		s.add(SimObject.from_json(raw as Dictionary))
	return s


func add(obj: SimObject) -> void:
	_order.append(obj)
	_by_id[obj.id] = obj
	_index(obj)


func by_id(id: String) -> SimObject:
	return _by_id.get(id, null)


func has(id: String) -> bool:
	return _by_id.has(id)


func all() -> Array[SimObject]:
	return _order.duplicate()


func with_tag(tag: String) -> Array[SimObject]:
	var out: Array[SimObject] = []
	for o in _order:
		if o.has_tag(tag):
			out.append(o)
	return out


func at_cell(cell: Vector2i) -> Array[SimObject]:
	var found: Variant = _by_cell.get(cell, null)
	if found == null:
		return [] as Array[SimObject]
	return (found as Array).duplicate()


## Container that currently holds `id`, or null.
func container_of(id: String) -> SimObject:
	for o in _order:
		if o.contains.has(id):
			return o
	return null


## An object is on the floor when nothing contains it and nothing supports it.
func is_loose(obj: SimObject) -> bool:
	return obj.on.is_empty() and container_of(obj.id) == null


func move_to(obj: SimObject, new_cells: Array[Vector2i]) -> void:
	_deindex(obj)
	obj.cells = new_cells.duplicate()
	_index(obj)


func translate(obj: SimObject, delta: Vector2i) -> void:
	var moved: Array[Vector2i] = []
	for c in obj.cells:
		moved.append(c + delta)
	move_to(obj, moved)


func take_from_container(id: String) -> void:
	var c := container_of(id)
	if c != null:
		var idx := c.contains.find(id)
		if idx >= 0:
			c.contains.remove_at(idx)


func put_in_container(container: SimObject, id: String) -> void:
	take_from_container(id)
	if not container.contains.has(id):
		container.contains.append(id)


func _index(obj: SimObject) -> void:
	for c in obj.cells:
		if not _by_cell.has(c):
			_by_cell[c] = [] as Array[SimObject]
		(_by_cell[c] as Array).append(obj)


func _deindex(obj: SimObject) -> void:
	for c in obj.cells:
		if _by_cell.has(c):
			(_by_cell[c] as Array).erase(obj)
