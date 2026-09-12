extends SceneTree

## CLI for the solver. All the work is in tools/solver.gd so verify_all runs the
## same code.
##
##   godot --headless -s tools/solve.gd -- content/rooms/room_01_studio.json
##   godot --headless -s tools/solve.gd -- <room.json> --mode a
##   godot --headless -s tools/solve.gd -- <room.json> --max-actions 6 --beam 12
##
## Modes: a = verify authored · b = explore · c = deaths · all (default).
## Mode `all` writes <room>.solver.json so difficulty drift shows up in diffs.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: solve.gd -- <room.json> [--mode a|b|c|all] [--max-actions N] [--max-states N] [--beam N] [--quiet]")
		quit(2)
		return

	var solver := SimSolver.new()
	var mode := "all"
	var i := 1
	while i < args.size():
		match str(args[i]):
			"--mode": mode = str(args[i + 1]); i += 2
			"--max-actions": solver.max_actions = int(args[i + 1]); i += 2
			"--max-states": solver.max_states = int(args[i + 1]); i += 2
			"--beam": solver.beam = int(args[i + 1]); i += 2
			"--quiet": solver.quiet = true; i += 1
			_: i += 1

	if not solver.load_room(str(args[0])):
		for e in solver.errors:
			printerr("solve: %s" % e)
		quit(1)
		return

	print("solver: %s (%s)" % [solver.room.get("id", "?"), solver.room_path])
	print("solver: seed=%d max_actions=%d max_states=%d beam=%d" % [
		SimSolver.DEFAULT_SEED, solver.max_actions, solver.max_states, solver.beam,
	])
	print("")

	var report := {
		"room": solver.room.get("id", ""),
		"seed": SimSolver.DEFAULT_SEED,
		"budget": {"max_actions": solver.max_actions, "max_states": solver.max_states, "beam": solver.beam},
	}
	var ok := true
	if mode == "a" or mode == "all":
		var a := solver.mode_a()
		report["authored"] = a["solutions"]
		ok = ok and bool(a["ok"])
	if mode == "b" or mode == "all":
		report["explore"] = solver.mode_b(solver.room.get("authored_solutions", []))
	if mode == "c" or mode == "all":
		report["deaths"] = solver.mode_c()
	report["difficulty"] = solver.difficulty(report)
	if mode == "all":
		solver.write_report(report)
	quit(0 if ok else 1)
