extends SceneTree

## Reads a session recording and says what happened.
##
##   godot --headless -s tools/session_report.gd              # the newest one
##   godot --headless -s tools/session_report.gd -- <path>    # a named one
##   godot --headless -s tools/session_report.gd -- --list
##
## The counts are the point, and so are the two lines that mean something went
## wrong: taps that resolved to nothing, and the same refusal over and over.

const DIR := "user://logs"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and str(args[0]) == "--list":
		for name in _sessions():
			print("%s/%s" % [DIR, name])
		quit()
		return
	var path := str(args[0]) if args.size() > 0 else _newest()
	if path.is_empty():
		printerr("session_report: no logs in %s" % ProjectSettings.globalize_path(DIR))
		quit(1)
		return
	if not FileAccess.file_exists(path):
		printerr("session_report: cannot read %s" % path)
		quit(1)
		return
	_report(path)
	quit()


func _sessions() -> PackedStringArray:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return PackedStringArray()
	var out := PackedStringArray()
	for name in dir.get_files():
		if str(name).ends_with(".jsonl"):
			out.append(str(name))
	out.sort()
	return out


func _newest() -> String:
	var names := _sessions()
	return "%s/%s" % [DIR, names[names.size() - 1]] if names.size() > 0 else ""


func _report(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	var records := SessionLog.parse(lines)
	var summary := SessionLog.summarise(records)
	print("session: %s" % ProjectSettings.globalize_path(path))
	print("  %d record(s), %d loop(s)" % [records.size(), summary["loops"]])
	print("  taps %d (%d resolved to nothing) · walks %d" % [
		summary["taps"], summary["taps_on_nothing"], summary["walks"]])
	print("  actions %d — %d done, %d refused" % [
		summary["intents"], summary["accepted"], summary["refused"]])
	print("  endings: %s" % [", ".join(PackedStringArray(summary["endings"])) if not (summary["endings"] as Array).is_empty() else "none"])

	var verbs: Dictionary = summary["verbs"]
	if not verbs.is_empty():
		var pairs: Array = []
		for verb in verbs:
			pairs.append([str(verb), int(verbs[verb])])
		pairs.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		var parts := PackedStringArray()
		for pair in pairs:
			parts.append("%s %d" % [pair[0], pair[1]])
		print("  verbs: %s" % ", ".join(parts))

	var touched: Array = summary["objects_touched"]
	print("  objects acted on (%d): %s" % [touched.size(), ", ".join(PackedStringArray(touched))])

	var repeated: Array = summary["repeated_refusals"]
	if not repeated.is_empty():
		print("  FIGHTING THE GAME — the same refusal, repeatedly:")
		for entry in repeated:
			print("    %s x%d" % [(entry as Dictionary)["what"], int((entry as Dictionary)["times"])])
	if int(summary["taps_on_nothing"]) > 0:
		print("  taps that hit nothing at all:")
		for raw in records:
			var record: Dictionary = raw
			if str(record.get("kind", "")) == "click" and str(record.get("picked", "")).is_empty():
				print("    t=%.1f loop %d  screen %s -> cell %s" % [
					float(record.get("t", 0.0)), int(record.get("loop", 0)),
					record.get("screen", []), record.get("cell", [])])

	print("  per loop:")
	var loops: Dictionary = {}
	for raw in records:
		var record: Dictionary = raw
		var loop := int(record.get("loop", 0))
		if not loops.has(loop):
			loops[loop] = {"taps": 0, "intents": 0, "refused": 0, "ending": "-", "t": 0.0}
		var entry: Dictionary = loops[loop]
		entry["t"] = maxf(float(entry["t"]), float(record.get("t", 0.0)))
		match str(record.get("kind", "")):
			"click":
				entry["taps"] = int(entry["taps"]) + 1
			"intent":
				entry["intents"] = int(entry["intents"]) + 1
				if not bool(record.get("accepted", false)):
					entry["refused"] = int(entry["refused"]) + 1
			"loop_ended":
				entry["ending"] = str(record.get("ending", "-"))
	for loop in loops:
		var entry: Dictionary = loops[loop]
		print("    loop %-3d %3d taps  %3d actions  %2d refused  ending %s" % [
			loop, entry["taps"], entry["intents"], entry["refused"], entry["ending"]])
