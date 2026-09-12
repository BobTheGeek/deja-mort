class_name SaveData
extends RefCounted

## Per-room progress in user://. Only knowledge persists between loops, and this
## is where it lives. Schema versioned; migrations go in _migrate.

const PATH := "user://deja_mort_save.json"
const SCHEMA := 1

var data: Dictionary = {}


static func load_or_new() -> SaveData:
	var save := SaveData.new()
	save.data = {"schema": SCHEMA, "rooms": {}, "settings": {}}
	if not FileAccess.file_exists(PATH):
		return save
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK:
		push_error("SaveData: %s does not parse; starting fresh" % PATH)
		return save
	save.data = save._migrate(json.data)
	return save


func _migrate(loaded: Dictionary) -> Dictionary:
	var version := int(loaded.get("schema", 0))
	if version == SCHEMA:
		return loaded
	# No older schema has shipped yet. When one has, migrate it here rather than
	# silently discarding a player's notebook.
	push_warning("SaveData: schema %d is not %d, starting fresh" % [version, SCHEMA])
	return {"schema": SCHEMA, "rooms": {}, "settings": {}}


func room(room_id: String) -> Dictionary:
	var rooms: Dictionary = data["rooms"]
	if not rooms.has(room_id):
		rooms[room_id] = {
			"stars": 0,
			"endings_found": [],
			"interactions_done": [],
			"discoveries": [],
			"deaths": [],
			"collectible": [],
			"loops_total": 0,
			"best_loop_count": 0,
			"notebook": [],
			"attacker_notes": [],
		}
	return rooms[room_id]


## Folds one finished loop into the room's record.
func record_loop(room_id: String, world: SimWorld, report: Dictionary, loop_index: int) -> void:
	var entry := room(room_id)
	entry["loops_total"] = int(entry["loops_total"]) + 1
	entry["stars"] = maxi(int(entry["stars"]), int(report["stars"]))

	var completion: Dictionary = report["completion"]
	_union(entry, "discoveries", completion["discoveries"])
	_union(entry, "deaths", completion["deaths"])
	_union(entry, "collectible", completion["collectible"])
	for pair in world.interactions:
		_add_unique(entry["interactions_done"], "%s|%s" % [pair["verb"], pair["object"]])
	if not world.ending.is_empty():
		_add_unique(entry["endings_found"], world.ending)

	for note in SimOutcome.attacker_observations(world):
		_add_unique(entry["attacker_notes"], note)

	var line := str(report["notebook"])
	if not line.is_empty():
		(entry["notebook"] as Array).append({"loop": loop_index, "line": line})

	if bool(report["won"]):
		var best := int(entry["best_loop_count"])
		entry["best_loop_count"] = loop_index if best == 0 else mini(best, loop_index)


func _union(entry: Dictionary, key: String, values: Variant) -> void:
	for v in (values as Array):
		_add_unique(entry[key], v)


static func _add_unique(list: Array, value: Variant) -> void:
	if not list.has(value):
		list.append(value)


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: cannot write %s" % PATH)
		return
	file.store_string(JSON.stringify(data, "  ", true))
	file.close()


func path() -> String:
	return ProjectSettings.globalize_path(PATH)
