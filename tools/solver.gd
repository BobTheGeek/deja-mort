class_name SimSolver
extends RefCounted

## The solver, as a plain object so both tools/solve.gd and tools/verify_all.gd
## drive the same code. Mode A verifies authored solutions, Mode B explores,
## Mode C enumerates the ways to die.

const DEFAULT_SEED := 1

var max_actions := 6
var max_states := 20000
var beam := 12
var quiet := false
var verbose := true

var room_path := ""
var room: Dictionary = {}
var content: SimContent = null
var errors: PackedStringArray = []


func load_room(path: String, shared: SimContent = null) -> bool:
	content = shared if shared != null else SimContent.load_from()
	if not content.errors.is_empty():
		errors.append_array(content.errors)
		return false
	room_path = _res_path(path)
	var json := JSON.new()
	if not FileAccess.file_exists(room_path):
		errors.append("no such room: %s" % room_path)
		return false
	if json.parse(FileAccess.get_file_as_string(room_path)) != OK:
		errors.append("%s: %s" % [room_path, json.get_error_message()])
		return false
	room = json.data
	return true


func say(line: String) -> void:
	if verbose:
		print(line)


func _res_path(raw: String) -> String:
	return raw if raw.begins_with("res://") else "res://" + raw.trim_prefix("./")


func _world(seed_value: int = DEFAULT_SEED) -> SimWorld:
	return SimWorld.create(room.duplicate(true), content, SimRng.new(seed_value))


# --- Mode A: verify the authored solutions -----------------------------------

func mode_a() -> Dictionary:
	say("== MODE A — authored solutions ==")
	var solutions: Array = room.get("authored_solutions", [])
	var results: Array = []
	var all_ok := true
	for entry in solutions:
		var declared_ending := str(entry.get("ending", ""))
		var declared_stars := int(entry.get("stars", 0))
		var run := run_actions(entry.get("actions", []))
		var world: SimWorld = run["world"]
		var report := SimOutcome.evaluate(world, 1)
		var passed: bool = report["ending"] == declared_ending and int(report["stars"]) == declared_stars
		all_ok = all_ok and passed
		say("  %-16s %-8s ending=%-8s stars=%d  declared=%s/%d  t=%.1fs  tightness=%.1fs%s" % [
			entry.get("id", "?"), "PASS" if passed else "FAIL",
			report["ending"], int(report["stars"]),
			declared_ending, declared_stars, float(report["time_s"]),
			_tightness(float(run["busy_s"])),
			"" if run["rejected"].is_empty() else "  rejected=%s" % [run["rejected"]],
		])
		if not passed and not quiet:
			for line in world.events.to_lines().slice(maxi(0, world.events.to_lines().size() - 12)):
				say("      " + line)
		results.append({
			"id": entry.get("id", ""),
			"declared_ending": declared_ending,
			"declared_stars": declared_stars,
			"ending": report["ending"],
			"stars": report["stars"],
			"time_s": report["time_s"],
			"tightness_s": _tightness(float(run["busy_s"])),
			"action_count": (entry.get("actions", []) as Array).size(),
			"rejected": run["rejected"],
			"notebook": report["notebook"],
			"passed": passed,
		})
	say("  %d/%d authored solutions verified" % [count_passed(results), results.size()])
	say("")
	return {"ok": all_ok, "solutions": results}


func count_passed(results: Array) -> int:
	var n := 0
	for r in results:
		if bool(r["passed"]):
			n += 1
	return n


## Issues each intent at its earliest tick, or when the previous one finishes.
func run_actions(actions: Array, seed_value: int = DEFAULT_SEED, max_s: float = -1.0, abort_on_reject: bool = false) -> Dictionary:
	var world := _world(seed_value)
	var cap: float = max_s if max_s > 0.0 else float(room.get("max_loop_s", 300))
	var guard := world.ticks(cap)
	var rejected: Array = []
	var next := 0
	var busy_ticks := 0
	while world.ending.is_empty() and world.tick < guard:
		if next < actions.size() and world.player.action == null:
			var step: Dictionary = actions[next]
			if world.time_s() + 0.0001 >= _due(step):
				if not _issue(world, step):
					rejected.append("%s@%.1f" % [step.get("intent", "?"), _due(step)])
					if abort_on_reject:
						return {"world": world, "rejected": rejected, "issued": next, "busy_s": 0.0}
				next += 1
		if world.player.action != null:
			busy_ticks += 1
		world.step()
	return {"world": world, "rejected": rejected, "issued": next,
		"busy_s": float(busy_ticks) / float(world.system("tick_hz"))}


## When an intent becomes issuable. `t` is absolute; `t_after_arrival` is measured
## from the countdown hitting zero, so tuning timer_s does not silently break
## every action that is a reaction to him walking in.
func _due(step: Dictionary) -> float:
	if step.has("t_after_arrival"):
		return float(room.get("timer_s", 0)) + float(step["t_after_arrival"])
	return float(step.get("t", 0))


func _issue(world: SimWorld, step: Dictionary) -> bool:
	var args: Array = step.get("args", [])
	match str(step.get("intent", "")):
		"walk_to":
			return world.walk_to(Vector2i(int(args[0]), int(args[1])))
		"wait":
			return world.wait(float(args[0]))
		"verb_on":
			var target: Variant = args[1]
			if target is Array:
				target = Vector2i(int(target[0]), int(target[1]))
			var rule_id := str(args[2]) if args.size() > 2 else ""
			return world.verb_on(str(args[0]), target, rule_id)
	return false


## Seconds of the countdown the solution did not need: the timer minus the time
## the player actually spent walking and acting. Waiting is free.
func _tightness(busy_s: float) -> float:
	return float(room.get("timer_s", 0)) - busy_s


# --- Mode B: explore ---------------------------------------------------------

## Beam search over intent sequences. Candidates come from tags, so the same
## generator works on any room. Budget is explicit and what it drops is logged.
func mode_b(authored: Array) -> Dictionary:
	say("== MODE B — explore ==")
	var candidates := _candidates()
	say("  %d candidate intents, depth %d, beam %d" % [candidates.size(), max_actions, beam])
	var wins: Array = []
	var seen_states := {}
	var seen_wins := {}
	var frontier: Array = [[]]
	var runs := 0
	var truncated := false

	for depth in max_actions:
		var scored: Array = []
		for prefix in frontier:
			for cand in candidates:
				if runs >= max_states:
					truncated = true
					break
				var sequence: Array = prefix.duplicate()
				sequence.append(cand)
				var run := run_actions(sequence, DEFAULT_SEED, -1.0, true)
				runs += 1
				var world: SimWorld = run["world"]
				if not run["rejected"].is_empty():
					continue
				var key := world.snapshot_hash()
				if seen_states.has(key):
					continue
				seen_states[key] = true
				if SimOutcome.won(world.ending) and world.player.alive:
					var win_key := _sequence_key(sequence)
					if not seen_wins.has(win_key):
						seen_wins[win_key] = true
						wins.append(_win_record(sequence, world, authored))
					continue
				scored.append({"sequence": sequence, "score": _heuristic(world)})
			if truncated:
				break
		if truncated or scored.is_empty():
			break
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"]))
		frontier = []
		for entry in scored.slice(0, beam):
			frontier.append(entry["sequence"])

	var improvised: Array = []
	for w in wins:
		if not bool(w["matches_authored"]):
			improvised.append(w)
	say("  %d simulated sequences, %d distinct wins, %d improvised" % [runs, wins.size(), improvised.size()])
	if truncated:
		say("  NOTE: budget reached after %d runs — coverage is partial, raise --max-states" % runs)
	for w in wins:
		say("    %-10s %-9s stars=%d t=%5.1fs  %s%s" % [
			w["ending"], "AUTHORED" if bool(w["matches_authored"]) else "IMPROVISED",
			int(w["stars"]), float(w["time_s"]), w["label"],
			"" if w["discoveries"].is_empty() else "  %s" % [w["discoveries"]],
		])
	var missed := PackedStringArray()
	for entry in authored:
		var declared := str(entry.get("declared_ending", entry.get("ending", "")))
		var seen_ending := false
		for w in wins:
			if str(w["ending"]) == declared:
				seen_ending = true
		if not seen_ending and not missed.has(declared):
			missed.append(declared)
	if not missed.is_empty():
		say("  NOT rediscovered within budget: %s" % [missed])
	say("")
	return {"runs": runs, "truncated": truncated, "wins": wins,
		"improvised": improvised.size(), "not_rediscovered": Array(missed)}


## Tag-driven candidate set: barriers, hazard sources, signals, hiding places.
## Nothing here names an object.
func _candidates() -> Array:
	var world := _world()
	var out: Array = []
	var seen := {}

	var add := func(intent: String, args: Array) -> void:
		var key := "%s|%s" % [intent, args]
		if not seen.has(key):
			seen[key] = true
			out.append({"t": 0, "intent": intent, "args": args})

	for obj in world.objects.all():
		if obj.has_tag("entry"):
			add.call("verb_on", ["toggle", obj.id, "toggle_lock"])
			add.call("verb_on", ["toggle", obj.id, "toggle_chain"])
		if obj.has_tag("movable") and (obj.has_tag("blocks-door") or obj.has_tag("tippable") or obj.has_tag("hides-object")):
			add.call("verb_on", ["push", obj.id])
			add.call("verb_on", ["push", obj.id])
		if obj.has_tag("light-switch") or obj.has_tag("wet-source") or obj.has_tag("gas-source") or obj.has_tag("lure"):
			add.call("verb_on", ["toggle", obj.id])
		if obj.has_tag("hides-player"):
			add.call("verb_on", ["hide", obj.id])
		if obj.has_tag("container") and obj.has_tag("openable") and _holds_interesting(world, obj):
			add.call("verb_on", ["open", obj.id])
		if obj.has_tag("carryable") and _is_interesting(obj):
			add.call("verb_on", ["grab", obj.id])
	# Waiting is an action. Fractions of the room's own countdown, so a room with
	# a different timer gets its own set without anyone editing this.
	for fraction in [0.25, 0.5, 0.75, 0.95]:
		add.call("wait", [snappedf(float(world.room_state["timer_s"]) * fraction, 0.5)])

	for obj in world.objects.all():
		if obj.has_tag("conductive") and obj.has_tag("plug-in"):
			for cell in world.grid.zone_cells(str(world.system("wet.zone", "kitchen"))):
				if world.walkable(cell):
					add.call("verb_on", ["throw", [cell.x, cell.y], "throw_conductive_into_wet"])
					break
		if obj.has_tag("pourable"):
			var entry_cell := world.inside_cell_of(_first_entry(world))
			if entry_cell != SimEvent.NO_CELL:
				add.call("verb_on", ["use-held-on", [entry_cell.x, entry_cell.y + 1], "pour_slippery"])
		if obj.has_tag("ignites"):
			for flammable in world.objects.with_tag("flammable"):
				add.call("verb_on", ["use-held-on", flammable.id, "ignite_flammable"])
				break
		if obj.has_tag("charger"):
			for phone in world.objects.with_tag("phone"):
				add.call("verb_on", ["use-held-on", phone.id, "charge_phone"])
				add.call("verb_on", ["toggle", phone.id, "call_help"])
	return out


func _first_entry(world: SimWorld) -> SimObject:
	var entries := world.objects.with_tag("entry")
	return entries[0] if not entries.is_empty() else null


const INTERESTING_TAGS: PackedStringArray = [
	"conductive", "pourable", "ignites", "aerosol", "charger", "weapon-improvised", "throwable",
]


func _is_interesting(obj: SimObject) -> bool:
	return obj.has_any_tag(INTERESTING_TAGS)


func _holds_interesting(world: SimWorld, container: SimObject) -> bool:
	for id in container.contains:
		var item := world.objects.by_id(id)
		if item != null and _is_interesting(item):
			return true
	return false


## Hazards armed, seconds of barrier bought, and how well hidden — the three
## things that actually decide a loop.
func _heuristic(world: SimWorld) -> float:
	var score := 0.0
	for layer in ["slippery", "shock", "burning", "trip", "wet"]:
		score += float(world.hazards.count(layer))
	for entry in world.objects.with_tag("entry"):
		for barrier in world.barriers_for(entry):
			if bool(barrier.get_state("locked", false)):
				score += 4.0
			if bool(barrier.get_state("chained", false)):
				score += 4.0
		if not str(entry.get_state("braced_by", "")).is_empty():
			score += 10.0
	if world.player.is_hidden():
		score += 8.0
	if not bool(world.room_state.get("lit", true)):
		score += 5.0
	score += 3.0 * float(world.discoveries.size())
	if world.player.never_seen:
		score += 5.0
	return score


func _sequence_key(sequence: Array) -> String:
	var parts := PackedStringArray()
	for step in sequence:
		parts.append("%s%s" % [step["intent"], step["args"]])
	parts.sort()
	return "|".join(parts)


func _win_record(sequence: Array, world: SimWorld, authored: Array) -> Dictionary:
	var report := SimOutcome.evaluate(world, 1)
	var labels := PackedStringArray()
	for step in sequence:
		labels.append(_label(step))
	return {
		"ending": report["ending"],
		"stars": report["stars"],
		"time_s": report["time_s"],
		"actions": sequence,
		"label": " -> ".join(labels),
		"discoveries": Array(world.discoveries),
		"matches_authored": _matches_authored(sequence, world, authored),
	}


func _label(step: Dictionary) -> String:
	var args: Array = step.get("args", [])
	if str(step["intent"]) == "walk_to":
		return "walk%s" % [args]
	if str(step["intent"]) == "wait":
		return "wait %ss" % args[0]
	if args.size() >= 2:
		return "%s %s" % [args[0], args[1]]
	return str(step["intent"])


## Authored means every step of this win already appears in an authored solution
## that reached the same ending. Anything else is a find for the designer.
func _matches_authored(sequence: Array, world: SimWorld, authored: Array) -> bool:
	var used := _pair_set(sequence)
	for entry in authored:
		if str(entry.get("ending", "")) != world.ending:
			continue
		var known := _pair_set(entry.get("actions", []))
		var covered := true
		for pair in used:
			if not known.has(pair):
				covered = false
				break
		if covered:
			return true
	return false


func _pair_set(actions: Array) -> Dictionary:
	var out := {}
	for step in actions:
		var args: Array = step.get("args", [])
		if str(step.get("intent", "")) != "verb_on" or args.size() < 2:
			continue
		out["%s|%s" % [args[0], args[1]]] = true
	return out


# --- Mode C: ways to die -----------------------------------------------------

## Enumerates reachable death causes by building scenarios from tags. The list is
## derived, not hand-written, so a new room gets its own checklist for free.
func mode_c() -> Dictionary:
	say("== MODE C — ways to die ==")
	var scenarios := _death_scenarios()
	var found: Array = []
	var seen := {}
	var trace: Array = []
	for scenario in scenarios:
		var run := run_actions(scenario["actions"])
		var world: SimWorld = run["world"]
		var key := SimOutcome.death_key(world)
		trace.append("    %-28s -> %-22s %s" % [
			scenario["id"], key if not key.is_empty() else world.ending,
			"" if run["rejected"].is_empty() else "rejected=%s" % [run["rejected"]],
		])
		if world.player.alive:
			continue
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		found.append({
			"cause": key,
			"scenario": scenario["id"],
			"time_s": world.time_s(),
			"notebook": SimOutcome.notebook_line(world, world.ending, key),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["cause"]) < str(b["cause"]))
	say("  %d scenarios tried, %d distinct death causes" % [scenarios.size(), found.size()])
	if not quiet:
		for line in trace:
			say(line)
	for d in found:
		say("    %-24s via %-22s %s" % [d["cause"], d["scenario"], d["notebook"]])
	say("")
	return {"scenarios": scenarios.size(), "causes": found}


func _death_scenarios() -> Array:
	var world := _world()
	var out: Array = []
	var step := func(intent: String, args: Array) -> Dictionary:
		return {"t": 0, "intent": intent, "args": args}

	var arrival := float(world.room_state["timer_s"])

	out.append({"id": "stand_still", "actions": []})

	for spot in world.objects.with_tag("hides-player"):
		var actions := _reach_prefix(world, spot)
		if spot.has_tag("openable"):
			actions.append(step.call("verb_on", ["open", spot.id]))
		actions.append(step.call("verb_on", ["hide", spot.id]))
		out.append({"id": "hide_in_" + spot.id, "actions": actions})

	for oil in world.objects.with_tag("slippery-source"):
		if not oil.has_tag("carryable"):
			continue
		var cell := world.inside_cell_of(_first_entry(world))
		var actions := _acquire(world, oil)
		actions.append(step.call("verb_on", ["use-held-on", [cell.x, cell.y], "pour_slippery"]))
		actions.append(step.call("walk_to", [cell.x + 1, cell.y + 1]))
		# Step onto it as he arrives, so the three prone seconds are the ones
		# that matter.
		actions.append({"t": arrival - 1.0, "intent": "walk_to", "args": [cell.x, cell.y]})
		out.append({"id": "slip_on_" + oil.id, "actions": actions})

	for igniter in world.objects.with_tag("ignites"):
		if not igniter.has_tag("carryable"):
			continue
		for fuel in world.objects.with_tag("flammable"):
			var standing := _standable_cell(world, fuel)
			if standing == SimEvent.NO_CELL:
				continue
			var actions := _acquire(world, igniter)
			actions.append(step.call("verb_on", ["use-held-on", fuel.id, "ignite_flammable"]))
			actions.append(step.call("walk_to", [standing.x, standing.y]))
			out.append({"id": "burn_with_" + fuel.id, "actions": actions})
			break

	for burner in world.objects.with_tag("gas-source"):
		for spray in world.objects.with_tag("aerosol"):
			var actions := _reach_prefix(world, spray)
			actions.append(step.call("verb_on", ["toggle", burner.id, "toggle_gas_source"]))
			actions.append(step.call("verb_on", ["toggle", burner.id, "toggle_stove_ignite"]))
			actions.append_array(_acquire(world, spray))
			# Blinded lasts four seconds, so it has to happen as the door opens.
			actions.append({"t": arrival + 1.0, "intent": "verb_on",
				"args": ["use-held-on", [burner.origin().x, burner.origin().y], "aerosol_flash"]})
			out.append({"id": "blind_self_" + spray.id, "actions": actions})
			break
		var gas: Array = [step.call("verb_on", ["toggle", burner.id, "toggle_gas_source"]),
			step.call("wait", [float(world.system("gas.fill_s")) + 2.0]),
			step.call("verb_on", ["toggle", burner.id, "toggle_stove_ignite"])]
		out.append({"id": "gas_" + burner.id, "actions": gas})

	for tap in world.objects.with_tag("wet-source"):
		for appliance in world.objects.with_tag("conductive"):
			if not appliance.has_tag("plug-in") or not appliance.has_tag("carryable"):
				continue
			var wet_cell := _wet_source_cell(world, tap)
			if wet_cell == SimEvent.NO_CELL:
				continue
			var actions: Array = [step.call("verb_on", ["toggle", tap.id, "toggle_wet_source"])]
			actions.append_array(_acquire(world, appliance))
			actions.append(step.call("wait", [60.0]))
			actions.append(step.call("walk_to", [wet_cell.x, wet_cell.y]))
			actions.append(step.call("verb_on", ["throw", [wet_cell.x, wet_cell.y], "throw_conductive_into_wet"]))
			out.append({"id": "electrocute_self_" + appliance.id, "actions": actions})
			break

	for weapon in world.objects.with_tag("weapon-improvised"):
		var entry_cell := world.inside_cell_of(_first_entry(world))
		var actions := _acquire(world, weapon)
		actions.append({"t": arrival - 10.0, "intent": "walk_to",
			"args": [entry_cell.x, entry_cell.y + 1]})
		actions.append({"t": arrival + 2.1, "intent": "verb_on",
			"args": ["use-held-on", world.attacker.id if world.attacker != null else "", "strike_exposed"]})
		out.append({"id": "charge_with_" + weapon.id, "actions": actions})
		break

	for phone in world.objects.with_tag("phone"):
		var host := world.objects.container_of(phone.id)
		var stand := _standable_cell(world, host if host != null else phone)
		if stand == SimEvent.NO_CELL:
			continue
		out.append({"id": "caught_at_" + phone.id, "actions": [
			step.call("walk_to", [stand.x, stand.y]),
		]})
	return out


## Opens whatever shut door stands between the player and `obj`. Entry doors are
## left alone — opening the front door for him is not a scenario, it is a gift.
func _reach_prefix(world: SimWorld, obj: SimObject) -> Array:
	var target := _standable_cell(world, obj)
	if target != SimEvent.NO_CELL and not world.grid.path(world.player.pos, target, Callable(world, "blocked")).is_empty():
		return []
	var actions: Array = []
	for door in world.objects.all():
		var gate := str(door.prop("passable_state", ""))
		if gate.is_empty() or door.has_tag("entry") or bool(door.get_state(gate, false)):
			continue
		actions.append({"t": 0, "intent": "verb_on", "args": ["open", door.id]})
	return actions


## Actions that put `item` in the player's hand, opening its container if needed.
func _acquire(world: SimWorld, item: SimObject) -> Array:
	var actions := _reach_prefix(world, item)
	var host := world.objects.container_of(item.id)
	if host != null and host.has_tag("openable"):
		actions.append({"t": 0, "intent": "verb_on", "args": ["open", host.id]})
	actions.append({"t": 0, "intent": "verb_on", "args": ["grab", item.id]})
	return actions


func _standable_cell(world: SimWorld, obj: SimObject) -> Vector2i:
	for c in obj.cells:
		if world.walkable(c):
			return c
	for c in obj.cells:
		for n in world.grid.neighbours(c, 4):
			if world.walkable(n):
				return n
	return SimEvent.NO_CELL


func _wet_source_cell(world: SimWorld, tap: SimObject) -> Vector2i:
	for c in tap.cells:
		for n in world.grid.neighbours(c, 4):
			if world.walkable(n):
				return n
	return SimEvent.NO_CELL


# --- report ------------------------------------------------------------------

func difficulty(report: Dictionary) -> Dictionary:
	var authored: Array = report.get("authored", [])
	var explore: Dictionary = report.get("explore", {})
	var wins: Array = explore.get("wins", [])
	var min_actions := -1
	var tightness := INF
	for w in wins:
		var n: int = (w["actions"] as Array).size()
		if min_actions < 0 or n < min_actions:
			min_actions = n
	for a in authored:
		tightness = minf(tightness, float(a["tightness_s"]))
	return {
		"solutions_found": wins.size(),
		"authored_passing": count_passed(authored),
		"min_actions_to_win": min_actions,
		"tightness_s": null if tightness == INF else tightness,
		"death_causes": (report.get("deaths", {}).get("causes", []) as Array).size(),
	}


func write_report(report: Dictionary) -> void:
	var path := room_path.replace(".json", ".solver.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("solve: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(report, "  ", true) + "\n")
	file.close()
	say("solver: wrote %s" % path)
