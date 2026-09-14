extends SceneTree

## Schema and reference validation for content JSON.
##
##   godot --headless -s tools/lint_room.gd                 # lint every room
##   godot --headless -s tools/lint_room.gd -- content/rooms/room_01_studio.json
##
## Checks that exist now (M0): every content file parses as JSON; rooms carry the
## required top-level keys; every tag used by an object exists in content/tags.json;
## every containment reference points at a real object id.
## Rule/verb/effect validation lands with the rule table in M1.

const ROOMS_DIR := "res://content/rooms"
const TAGS_FILE := "res://content/tags.json"
const EXCEPTIONS_FILE := "res://content/lint_exceptions.json"

const REQUIRED_ROOM_KEYS := [
	"schema_version", "id", "title", "timer_s", "grid", "zones", "attacker", "objects",
]

var _errors: PackedStringArray = []
var _warnings: PackedStringArray = []


func _initialize() -> void:
	var targets := _targets()
	print("lint: %d room file(s)" % targets.size())

	var known_tags := _load_known_tags()

	for path in targets:
		_lint_room(path, known_tags)
		_lint_layout(path)
		_lint_ambiguity(path)

	for w in _warnings:
		print("lint: WARN %s" % w)
	for e in _errors:
		printerr("lint: ERROR %s" % e)

	if _errors.is_empty():
		print("lint: OK — %d error(s), %d warning(s)." % [0, _warnings.size()])
		quit(0)
	else:
		printerr("lint: FAIL — %d error(s), %d warning(s)." % [_errors.size(), _warnings.size()])
		quit(1)


## Furniture placement, against the standard in docs/08-room-layout.md. Bob has
## reported the same class of problem three playtests running — a fridge in front
## of the stove, cabinets showing their backs, a lamp marooned mid-floor — and
## none of it was decided. It accumulated. This is where it stops accumulating.
##
## A room may declare `layout_exceptions: {"<id>": "<reason>"}`. The check still
## runs and still reports; a declared exception does not fail the build. A
## violation is either fixed or it is a decision somebody wrote down.
func _lint_layout(path: String) -> void:
	var room: Variant = _read_json(path)
	if not (room is Dictionary):
		return
	var grid: Dictionary = (room as Dictionary).get("grid", {})
	var cells: Array = grid.get("cells", [])
	if cells.is_empty():
		return
	var excused: Dictionary = (room as Dictionary).get("layout_exceptions", {})
	# Per square: who blocks it. Something you can walk over or pick up does not.
	var blockers := {}
	for raw_obj in (room as Dictionary).get("objects", []):
		var o: Dictionary = raw_obj
		var o_tags: Array = o.get("tags", [])
		if bool(o.get("walk_over", false)) or o_tags.has("carryable"):
			continue
		for c in o.get("footprint", []):
			blockers["%d,%d" % [int(c[0]), int(c[1])]] = str(o.get("id", ""))

	for raw in (room as Dictionary).get("objects", []):
		var obj: Dictionary = raw
		var oid := str(obj.get("id", ""))
		var tags: Array = obj.get("tags", [])
		var footprint: Array = obj.get("footprint", [])
		if footprint.is_empty():
			continue
		var fixture := tags.has("fixture")
		var carryable := tags.has("carryable")

		if fixture and not _touches_a_wall(footprint, cells):
			_layout_issue(path, excused, oid, "fixture-off-wall",
				"is a fixture and touches no wall")

		# Only a drawn model has a front. A chain, a switch, a towel in a basket
		# do not, and asking which way they face is asking nothing.
		var drawn := not str(obj.get("mesh", "")).is_empty()
		var front := _front_of(obj)
		var ahead := Vector2i(int(footprint[0][0]) + front.x, int(footprint[0][1]) + front.y)
		var key := "%d,%d" % [ahead.x, ahead.y]
		if drawn and _is_wall(ahead, cells):
			_layout_issue(path, excused, oid, "faces-a-wall",
				"faces %s, which is a wall" % [front])
		# You stand at a cupboard, a sink, a cooker. You do not stand at a
		# television — a coffee table in front of one is a living room, not a
		# fault — so this asks only of the things you operate at arm's length.
		var operated := tags.has("openable") or tags.has("container") \
			or tags.has("wet-source") or tags.has("gas-source")
		if drawn and fixture and operated and blockers.has(key) \
				and not excused.has(str(blockers[key])):
			_layout_issue(path, excused, oid, "no-room-to-use",
				"opens onto '%s' with nowhere to stand" % blockers[key])

		if not carryable and not fixture and not _touches_a_wall(footprint, cells) \
				and not _touches_furniture(oid, footprint, blockers):
			_warnings.append("%s: object '%s' is marooned — it touches neither a wall nor "
				% [path, oid] + "any other furniture")


func _layout_issue(path: String, excused: Dictionary, oid: String, code: String,
		detail: String) -> void:
	var line := "%s: object '%s' %s [%s]" % [path, oid, detail, code]
	if excused.has(oid):
		_warnings.append("%s — declared: %s" % [line, excused[oid]])
	else:
		_errors.append(line)


## Kenney's furniture faces +Z at yaw 0; see docs/08-room-layout.md.
func _front_of(obj: Dictionary) -> Vector2i:
	var yaw := int(round(float(obj.get("mesh_yaw", 0.0)))) % 360
	match yaw:
		90: return Vector2i(1, 0)
		180: return Vector2i(0, -1)
		270: return Vector2i(-1, 0)
		_: return Vector2i(0, 1)


func _is_wall(cell: Vector2i, cells: Array) -> bool:
	if cell.y < 0 or cell.y >= cells.size():
		return true
	var row := str(cells[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"


func _touches_a_wall(footprint: Array, cells: Array) -> bool:
	for c in footprint:
		var cell := Vector2i(int(c[0]), int(c[1]))
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_wall(cell + step, cells):
				return true
	return false


func _touches_furniture(oid: String, footprint: Array, occupied: Dictionary) -> bool:
	for c in footprint:
		var cell := Vector2i(int(c[0]), int(c[1]))
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var key := "%d,%d" % [cell.x + step.x, cell.y + step.y]
			if occupied.has(key) and str(occupied[key]) != oid:
				return true
	return false


## The wheel must never have to ask which rule the player meant. Any
## (verb, object, state, held) that leaves two choosable rules is a content bug;
## a specific rule declaring `shadows` on a general one is not.
func _lint_ambiguity(path: String) -> void:
	var content := SimContent.load_from()
	if not content.errors.is_empty():
		for e in content.errors:
			_errors.append(e)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var world := SimWorld.create(json.data, content, SimRng.new(0))

	var raw := SimVerbs.ambiguous_pairs(world, false)
	var live := SimVerbs.ambiguous_pairs(world, true)
	print("lint: %s — %d overlapping (verb, object) pairs, %d resolved by declared shadowing, %d left"
		% [path.get_file(), raw.size(), raw.size() - live.size(), live.size()])

	var allowed := _allowed_pairs()
	var seen := {}
	for entry in live:
		var key: String = "%s|%s" % [entry["verb"], entry["object"]]
		seen[key] = true
		if allowed.has(key):
			print("lint:   allowed  %s %s — %s" % [key, entry["rules"], allowed[key]])
			continue
		_errors.append("%s: %s on '%s' leaves %s choosable; the wheel would have to ask. Declare `shadows` or split the object."
			% [path, entry["verb"], entry["object"], entry["rules"]])
	for key in allowed:
		if not seen.has(key):
			_errors.append("%s: lint_exceptions.json still excuses '%s' but it no longer overlaps — delete the entry."
				% [EXCEPTIONS_FILE, key])


func _allowed_pairs() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(EXCEPTIONS_FILE):
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(EXCEPTIONS_FILE)) != OK:
		_errors.append("%s does not parse" % EXCEPTIONS_FILE)
		return out
	for entry in (json.data as Dictionary).get("ambiguous_pairs", []):
		var spec: Dictionary = entry
		var reason := str(spec.get("reason", ""))
		if reason.is_empty():
			_errors.append("%s: an exception with no reason is not an exception" % EXCEPTIONS_FILE)
		out["%s|%s" % [spec.get("verb", ""), spec.get("object", "")]] = reason
	return out


func _targets() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var explicit := PackedStringArray()
		for a in args:
			explicit.append(a if a.begins_with("res://") else "res://" + a.trim_prefix("./"))
		return explicit

	var found := PackedStringArray()
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		_errors.append("cannot open %s" % ROOMS_DIR)
		return found
	for file_name in dir.get_files():
		if file_name.ends_with(".json") and not file_name.ends_with(".solver.json"):
			found.append("%s/%s" % [ROOMS_DIR, file_name])
	found.sort()
	return found


func _load_known_tags() -> Dictionary:
	var known := {}
	if not FileAccess.file_exists(TAGS_FILE):
		_warnings.append("%s not present yet — tag references unchecked." % TAGS_FILE)
		return known
	var data: Variant = _read_json(TAGS_FILE)
	if data == null:
		return known
	# tags.json may be a flat list or a {group: [tags]} map. Accept both.
	if data is Array:
		for t in data:
			known[t] = true
	elif data is Dictionary:
		for group in data:
			var entry: Variant = data[group]
			if entry is Array:
				for t in entry:
					known[t] = true
			else:
				known[group] = true
	return known


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_errors.append("%s does not exist" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		_errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _lint_room(path: String, known_tags: Dictionary) -> void:
	var room: Variant = _read_json(path)
	if room == null:
		return
	if not (room is Dictionary):
		_errors.append("%s: top level must be an object" % path)
		return

	for key in REQUIRED_ROOM_KEYS:
		if not room.has(key):
			_errors.append("%s: missing required key '%s'" % [path, key])

	var objects: Variant = room.get("objects", [])
	if not (objects is Array):
		_errors.append("%s: 'objects' must be an array" % path)
		return

	var ids := {}
	for obj in objects:
		if not (obj is Dictionary):
			_errors.append("%s: every object must be an object" % path)
			continue
		var oid: String = str(obj.get("id", ""))
		if oid.is_empty():
			_errors.append("%s: object with no 'id'" % path)
			continue
		if ids.has(oid):
			_errors.append("%s: duplicate object id '%s'" % [path, oid])
		ids[oid] = obj

	for oid in ids:
		var obj: Dictionary = ids[oid]
		var tags: Variant = obj.get("tags", [])
		if tags is Array:
			for t in tags:
				if not known_tags.is_empty() and not known_tags.has(t):
					_errors.append("%s: object '%s' uses unknown tag '%s'" % [path, oid, t])
		else:
			_errors.append("%s: object '%s' has non-array 'tags'" % [path, oid])

		for ref_key in ["contains"]:
			var refs: Variant = obj.get(ref_key, [])
			if refs is Array:
				for r in refs:
					if not ids.has(str(r)):
						_errors.append("%s: object '%s'.%s references unknown id '%s'" % [path, oid, ref_key, r])
