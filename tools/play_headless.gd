extends SceneTree

## Pokes the sim from the command line. No scene, no Nodes.
##
##   godot --headless -s tools/play_headless.gd -- [room_id] [command]
##
## Commands: state (default) · pairs · flood · shock · all

const ROOMS := "res://content/rooms/%s.json"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var room_id := str(args[0]) if args.size() > 0 else "room_01_studio"
	var command := str(args[1]) if args.size() > 1 else "state"

	var content := SimContent.load_from()
	if not content.errors.is_empty():
		for e in content.errors:
			printerr("content: %s" % e)
		quit(1)
		return

	var path := ROOMS % room_id
	if not FileAccess.file_exists(path):
		printerr("no such room: %s" % path)
		quit(1)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		printerr("%s: %s" % [path, json.get_error_message()])
		quit(1)
		return

	var ok := true
	match command:
		"state":
			ok = _state(json.data, content)
		"pairs":
			ok = _pairs(json.data, content)
		"flood":
			ok = _flood(json.data, content)
		"shock":
			ok = _shock(json.data, content)
		"all":
			ok = _state(json.data, content) and _pairs(json.data, content) \
				and _flood(json.data, content) and _shock(json.data, content)
		_:
			printerr("unknown command: %s" % command)
			ok = false
	quit(0 if ok else 1)


func _world(room: Dictionary, content: SimContent, seed_value: int = 1) -> SimWorld:
	return SimWorld.create(room, content, SimRng.new(seed_value))


func _state(room: Dictionary, content: SimContent) -> bool:
	var w := _world(room, content)
	print("== %s (%s) ==" % [w.room.get("title", "?"), w.room.get("id", "?")])
	print("grid %dx%d  zones %s" % [w.grid.width, w.grid.height, w.grid.zone_names()])
	print("objects %d  rules %d  verbs %s" % [
		w.objects.all().size(), w.rules.rules.size(), SimVerbs.verb_ids(w),
	])
	print("player starts at %s, timer %.0fs, lit=%s" % [
		w.player.pos, w.room_state["timer_s"], w.room_state["lit"],
	])
	var walkable := 0
	for y in w.grid.height:
		for x in w.grid.width:
			if w.walkable(Vector2i(x, y)):
				walkable += 1
	print("walkable cells %d" % walkable)
	return true


func _pairs(room: Dictionary, content: SimContent) -> bool:
	var w := _world(room, content)
	var pairs := SimVerbs.valid_pairs(w)
	print("valid (verb, object) pairs in %s: %d" % [w.room.get("id", "?"), pairs.size()])
	var per_verb := {}
	for p in pairs:
		per_verb[p["verb"]] = int(per_verb.get(p["verb"], 0)) + 1
	var verbs := per_verb.keys()
	verbs.sort()
	for v in verbs:
		print("  %-12s %d" % [v, per_verb[v]])
	return true


func _flood(room: Dictionary, content: SimContent) -> bool:
	var w := _world(room, content)
	print("-- flood: toggle the sink, watch the kitchen --")
	w.verb_on("toggle", "sink", "toggle_wet_source")
	w.step_until_idle()
	var started := w.time_s()
	var kitchen := w.grid.zone_cells("kitchen")
	var floor_cells := 0
	for c in kitchen:
		if w.walkable(c):
			floor_cells += 1
	print("kitchen walkable floor cells: %d (tap on at t=%.1fs)" % [floor_cells, started])
	var full_at := -1.0
	for _i in w.ticks(60.0):
		w.step()
		if w.hazards.count("wet") >= floor_cells and full_at < 0.0:
			full_at = w.time_s()
		if w.tick % w.ticks(10.0) == 0:
			print("  t=%5.1fs wet cells %d" % [w.time_s(), w.hazards.count("wet")])
	print("kitchen fully wet at t=%.1fs (%.1fs after the tap)" % [full_at, full_at - started])
	print("wet cells: %s" % [w.hazards.cells("wet")])
	return full_at > 0.0


func _shock(room: Dictionary, content: SimContent) -> bool:
	var w := _world(room, content)
	print("-- shock: flood, then throw the plugged toaster into the water --")
	w.verb_on("toggle", "sink", "toggle_wet_source")
	w.step_until_idle()
	w.verb_on("grab", "toaster")
	w.step_until_idle()
	print("holding: %s (plugged=%s, outlet=%s, cord_range=%s)" % [
		w.player.holding,
		w.objects.by_id("toaster").get_state("plugged"),
		w.objects.by_id("toaster").prop("outlet"),
		w.objects.by_id("toaster").prop("cord_range"),
	])
	w.walk_to(Vector2i(5, 4))
	w.step_until_idle()
	w.step_seconds(60.0)
	print("player at %s, wet cells %d" % [w.player.pos, w.hazards.count("wet")])
	var thrown := w.verb_on("throw", Vector2i(3, 2), "throw_conductive_into_wet")
	print("throw accepted: %s" % thrown)
	w.step_until_idle()
	var shock := w.hazards.cells("shock")
	print("shock cells (%d): %s" % [shock.size(), shock])
	print("includes (1,2): %s" % shock.has(Vector2i(1, 2)))
	print("discoveries: %s" % [w.discoveries])
	return thrown and shock.has(Vector2i(1, 2))
