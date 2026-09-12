extends SceneTree

## Runs the solver over every room in content/rooms/ and fails the build if any
## authored solution no longer wins.
##
##   godot --headless -s tools/verify_all.gd
##
## M0: no rooms and no solver exist yet, so this reports zero rooms and exits 0.
## The moment a room lands without tools/solve.gd present this fails loudly —
## a green build must never mean "we skipped the solver".

const ROOMS_DIR := "res://content/rooms"
const SOLVER := "res://tools/solver.gd"


func _initialize() -> void:
	var rooms := _list_rooms()
	print("verify_all: %d room(s) in %s" % [rooms.size(), ROOMS_DIR])

	if rooms.is_empty():
		print("verify_all: no rooms to verify — OK")
		quit(0)
		return

	var solver_present := FileAccess.file_exists(SOLVER)
	var shared := SimContent.load_from()
	var failures := 0
	var unclaimed := 0
	for room_path in rooms:
		var claims: int = _authored_solution_count(room_path)
		if claims == 0:
			unclaimed += 1
			print("verify_all: %s — no authored_solutions yet, nothing to verify" % room_path)
			continue
		if not solver_present:
			# A room that claims to be solvable must be proved solvable. This is the
			# line that stops a green build from meaning "we skipped the solver".
			printerr("verify_all: FAIL — %s declares %d authored solution(s) but %s does not exist."
				% [room_path, claims, SOLVER])
			failures += 1
			continue
		if not _verify_room(room_path, shared):
			failures += 1

	if failures > 0:
		printerr("verify_all: FAIL — %d of %d room(s) failed verification." % [failures, rooms.size()])
		quit(1)
		return

	print("verify_all: OK — %d room(s), %d with authored solutions verified, %d not yet claimed."
		% [rooms.size(), rooms.size() - unclaimed, unclaimed])
	quit(0)


func _list_rooms() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		printerr("verify_all: cannot open %s" % ROOMS_DIR)
		return found
	for file_name in dir.get_files():
		if file_name.ends_with(".json") and not file_name.ends_with(".solver.json"):
			found.append("%s/%s" % [ROOMS_DIR, file_name])
	found.sort()
	return found


func _authored_solution_count(room_path: String) -> int:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(room_path)) != OK:
		printerr("verify_all: %s does not parse" % room_path)
		return 0
	var data: Variant = json.data
	if data is Dictionary:
		return (data.get("authored_solutions", []) as Array).size()
	return 0


## Mode A: every authored solution must still reach its declared ending and stars.
func _verify_room(room_path: String, shared: SimContent) -> bool:
	var solver := SimSolver.new()
	if not solver.load_room(room_path, shared):
		for e in solver.errors:
			printerr("verify_all: %s" % e)
		return false
	var result := solver.mode_a()
	return bool(result["ok"])
