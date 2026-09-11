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
const SOLVER := "res://tools/solve.gd"


func _initialize() -> void:
	var rooms := _list_rooms()
	print("verify_all: %d room(s) in %s" % [rooms.size(), ROOMS_DIR])

	if rooms.is_empty():
		print("verify_all: no rooms to verify — OK")
		quit(0)
		return

	if not ResourceLoader.exists(SOLVER) and not FileAccess.file_exists(SOLVER):
		printerr("verify_all: FAIL — %d room(s) present but %s does not exist." % [rooms.size(), SOLVER])
		printerr("verify_all: rooms must not ship unverified. Solver arrives in M2.")
		quit(1)
		return

	var failures := 0
	for room_path in rooms:
		if not _verify_room(room_path):
			failures += 1

	if failures > 0:
		printerr("verify_all: FAIL — %d of %d room(s) failed verification." % [failures, rooms.size()])
		quit(1)
		return

	print("verify_all: OK — %d room(s) verified." % rooms.size())
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


## Mode A verification. Implemented in M2 alongside tools/solve.gd.
func _verify_room(room_path: String) -> bool:
	printerr("verify_all: %s — solver Mode A not implemented yet (M2)." % room_path)
	return false
