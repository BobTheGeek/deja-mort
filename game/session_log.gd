class_name SessionLog
extends RefCounted

## A recording of a play session: every tap with what it resolved to, every
## intent with whether the sim accepted it, every event off the bus, and how each
## loop ended. One JSON object per line, so it can be read with a grep or by
## tools/session_report.gd.
##
## It decides nothing and changes nothing. It exists because a playtest report is
## a memory of what happened and a log is what happened — "some things I clicked
## had no action" took a probe to reproduce and would have been one line here.
##
## Off in a shipped build: nobody's play session gets written to their disk
## unless they are running the thing from source.

const DIR := "user://logs"

var _file: FileAccess = null
var _path := ""
var _loop := 0
var _elapsed := 0.0


## Debug builds only, and only while the table says so.
static func wanted(visuals: GameVisuals, debug_build: bool) -> bool:
	return debug_build and visuals.flag("log.session", false)


## `stamp` keeps one session per file; the game passes the wall clock, which is
## the one place a time of day is allowed in this project.
static func path_for(stamp: String) -> String:
	return "%s/session-%s.jsonl" % [DIR, stamp]


func start(path: String) -> bool:
	_path = path
	if path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(DIR)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("SessionLog: cannot write %s" % path)
		return false
	return true


func close() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func path() -> String:
	return _path


func advance(delta: float) -> void:
	_elapsed += delta


# --- what gets written -------------------------------------------------------

func click(screen: Vector2, cell: Vector2i, picked: String) -> void:
	_write({
		"kind": "click",
		"screen": [int(screen.x), int(screen.y)],
		"cell": [cell.x, cell.y],
		"picked": picked,
	})


func intent(verb: String, target: Variant, rule_id: String, accepted: bool) -> void:
	_write({
		"kind": "intent", "verb": verb, "target": str(target), "rule": rule_id,
		"accepted": accepted,
	})


func walk(cell: Vector2i, accepted: bool) -> void:
	_write({"kind": "walk", "cell": [cell.x, cell.y], "accepted": accepted})


func loop_started(loop_index: int) -> void:
	_loop = loop_index
	_write({"kind": "loop_started"})


func loop_ended(ending: String, stars: int, time_s: float) -> void:
	_write({"kind": "loop_ended", "ending": ending, "stars": stars, "time_s": time_s})


func panel(name: String, open: bool) -> void:
	_write({"kind": "panel", "panel": name, "open": open})


func listen(world: SimWorld) -> void:
	world.events.subscribe(_on_event)


func _on_event(event: SimEvent) -> void:
	_write({
		"kind": "event", "type": event.type, "actor": event.actor, "object": event.object,
		"rule": event.rule_id, "cell": [event.cell.x, event.cell.y], "meta": event.meta,
	})


func _write(record: Dictionary) -> void:
	if _file == null:
		return
	record["t"] = snappedf(_elapsed, 0.01)
	record["loop"] = _loop
	_file.store_line(JSON.stringify(record))


# --- reading it back ---------------------------------------------------------

func read_back() -> PackedStringArray:
	if not FileAccess.file_exists(_path):
		return PackedStringArray()
	return FileAccess.get_file_as_string(_path).strip_edges().split("\n", false)


func records() -> Array:
	return parse(read_back())


static func parse(lines: PackedStringArray) -> Array:
	var out: Array = []
	for line in lines:
		var json := JSON.new()
		if json.parse(str(line)) == OK and json.data is Dictionary:
			out.append(json.data)
	return out


## What I actually read. Counts first, then the two things that mean something
## went wrong: taps that resolved to nothing, and the same refusal over and over.
static func summarise(records: Array) -> Dictionary:
	var taps := 0
	var nothing := 0
	var notebook := 0
	var refused := 0
	var accepted := 0
	var walks := 0
	var endings := PackedStringArray()
	var loops: Dictionary = {}
	var verbs: Dictionary = {}
	var refusals: Dictionary = {}
	var touched: Dictionary = {}
	for raw in records:
		var record: Dictionary = raw
		loops[int(record.get("loop", 0))] = true
		match str(record.get("kind", "")):
			"click":
				taps += 1
				if str(record.get("picked", "")).is_empty():
					# Provisional: the walk that follows, if it happened, cancels it.
					# A tap on bare floor that walks him there is the game working.
					nothing += 1
			"walk":
				walks += 1
				if bool(record.get("accepted", false)) and nothing > 0:
					nothing -= 1
			"intent":
				var verb := str(record.get("verb", ""))
				verbs[verb] = int(verbs.get(verb, 0)) + 1
				if bool(record.get("accepted", false)):
					accepted += 1
					touched[str(record.get("target", ""))] = true
				else:
					refused += 1
					var key := "%s on %s" % [verb, record.get("target", "")]
					refusals[key] = int(refusals.get(key, 0)) + 1
			"loop_ended":
				endings.append(str(record.get("ending", "")))
			"panel":
				if bool(record.get("open", false)):
					notebook += 1
	var repeated: Array = []
	for key in refusals:
		if int(refusals[key]) >= 3:
			repeated.append({"what": key, "times": int(refusals[key])})
	repeated.sort_custom(func(a, b): return int(a["times"]) > int(b["times"]))
	return {
		"loops": maxi(loops.size(), endings.size()),
		"taps": taps,
		"taps_on_nothing": nothing,
		"notebook_opens": notebook,
		"walks": walks,
		"intents": accepted + refused,
		"accepted": accepted,
		"refused": refused,
		"verbs": verbs,
		"objects_touched": touched.keys(),
		"endings": Array(endings),
		"repeated_refusals": repeated,
	}
