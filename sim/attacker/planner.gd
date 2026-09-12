class_name SimAttackerPlanner
extends RefCounted

## Goal-oriented planner. Goal stack is locate -> reach -> neutralise. It costs
## every way of satisfying the current goal in seconds and takes the cheapest,
## which is what picks the entry when a room has more than one.

const GOAL_LEAVE := "leave"
const GOAL_NEUTRALISE := "neutralise"
const GOAL_REACH := "reach"
const GOAL_LOCATE := "locate"


static func goal(world: SimWorld, att: SimAttacker) -> String:
	if _should_leave(world, att):
		return GOAL_LEAVE
	if att.perception.target_visible or att.perception.has_last_known:
		return GOAL_NEUTRALISE
	if att.perception.has_investigate:
		return GOAL_REACH
	return GOAL_LOCATE


static func next_action(world: SimWorld, att: SimAttacker) -> Dictionary:
	var plan := plan_for(world, att)
	return plan[0] if not plan.is_empty() else {}


## Returns the whole plan, cheapest first step first. The caller executes one
## action and replans, so a changed world never runs a stale plan.
static func plan_for(world: SimWorld, att: SimAttacker) -> Array:
	if not att.alive or att.left or att.is_incapacitated():
		return []
	var current := goal(world, att)
	var terminal := _terminal_action(world, att, current)
	if terminal.is_empty():
		return []
	if att.inside:
		return [terminal]
	var approach := _cheapest_entry_plan(world, att, terminal)
	return approach


# --- goals -------------------------------------------------------------------

static func _should_leave(world: SimWorld, att: SimAttacker) -> bool:
	if world.fired_timers.has("help_arrives"):
		return true
	if att.profile.patience_s < 0.0:
		return false
	return att.inside and att.search_elapsed_s >= att.profile.patience_s


static func _terminal_action(world: SimWorld, att: SimAttacker, current: String) -> Dictionary:
	match current:
		GOAL_LEAVE:
			return SimAttackerActions.make(SimAttackerActions.LEAVE, {
				"goal_cell": world.inside_cell_of(world.objects.by_id(att.entry_id)),
				"target_id": att.entry_id,
				"duration_s": world.system("attacker.leave_s"),
			})
		GOAL_NEUTRALISE:
			return _attack_or_approach(world, att)
		GOAL_REACH:
			var cell := _nearest_standable(world, att, att.perception.investigate_target)
			if cell == SimEvent.NO_CELL:
				att.perception.clear_investigation()
				return _search_action(world, att)
			return SimAttackerActions.make(SimAttackerActions.INVESTIGATE, {
				"goal_cell": cell,
				"duration_s": world.system("attacker.investigate_s"),
			})
		_:
			return _search_action(world, att)


static func _attack_or_approach(world: SimWorld, att: SimAttacker) -> Dictionary:
	var player := world.player
	var aim: Vector2i = att.perception.last_known_pos
	if att.perception.target_visible:
		aim = player.pos
	if att.perception.target_visible and _in_attack_range(world, att, player.pos):
		return SimAttackerActions.make(SimAttackerActions.ATTACK, {
			"duration_s": att.profile.attack_duration_s,
		})
	var stand := _attack_stand_cell(world, att, aim)
	if stand == SimEvent.NO_CELL:
		att.perception.has_last_known = false
		return _search_action(world, att)
	if stand == att.pos:
		# He is where he wanted to be and still cannot see anyone: drop the lead.
		att.perception.has_last_known = false
		return _search_action(world, att)
	var id := SimAttackerActions.ATTACK if att.perception.target_visible else SimAttackerActions.MOVE_TO
	return SimAttackerActions.make(id, {
		"goal_cell": stand,
		"duration_s": att.profile.attack_duration_s if id == SimAttackerActions.ATTACK else 0.0,
	})


static func _search_action(world: SimWorld, att: SimAttacker) -> Dictionary:
	var spots := att.memory.ranked_spots(world, att.searched)
	var duration := att.profile.search_duration_s
	if not bool(world.room_state.get("lit", true)) and not att.profile.has_flashlight:
		duration *= float(world.system("attacker.dark_search_multiplier"))
	for spot in spots:
		var stand := _nearest_reachable(world, att, world.reach_cells(spot, spot.origin()))
		if stand == SimEvent.NO_CELL:
			continue
		return SimAttackerActions.make(SimAttackerActions.SEARCH, {
			"goal_cell": stand, "target_id": spot.id, "duration_s": duration,
		})
	# A spot he cannot walk to may just be behind a cheap door.
	var forced := _breach_blocking_door(world, att, spots)
	if not forced.is_empty():
		return forced
	# Nothing left to search: sweep the zones so patience still burns down.
	for zone in world.grid.zone_names():
		var centre := _nearest_standable(world, att, world.grid.zone_center(zone))
		if centre == SimEvent.NO_CELL or centre == att.pos:
			continue
		return SimAttackerActions.make(SimAttackerActions.MOVE_TO, {"goal_cell": centre})
	return SimAttackerActions.make(SimAttackerActions.MOVE_TO, {
		"goal_cell": att.pos, "duration_s": world.system("attacker.idle_s"),
	})


## Any shut `flimsy` door he can stand next to is a barrier, not a wall. Cost
## comes from the profile, so a stronger attacker opens it faster.
static func _breach_blocking_door(world: SimWorld, att: SimAttacker, spots: Array[SimObject]) -> Dictionary:
	if spots.is_empty():
		return {}
	for door in world.objects.with_tag("flimsy"):
		var gate := str(door.prop("passable_state", ""))
		if gate.is_empty() or bool(door.get_state(gate, false)):
			continue
		var stand := _nearest_reachable(world, att, world.reach_cells(door, door.origin()))
		if stand == SimEvent.NO_CELL:
			continue
		return SimAttackerActions.make(SimAttackerActions.BREACH_FLIMSY, {
			"goal_cell": stand, "target_id": door.id,
			"duration_s": att.profile.breach_cost("flimsy_door", 0.0),
			"noise": world.system("attacker.breach_noise.flimsy"),
		})
	return {}


# --- getting inside ----------------------------------------------------------

## Costs every entry end to end and returns the cheapest plan. With one entry
## this is a single branch; with several it is what `switch_entry` means.
static func _cheapest_entry_plan(world: SimWorld, att: SimAttacker, terminal: Dictionary) -> Array:
	var best: Array = []
	var best_cost := INF
	for entry_id in att.profile.entries:
		var entry := world.objects.by_id(entry_id)
		if entry == null:
			continue
		var steps := _barrier_steps(world, att, entry)
		var cost := 0.0
		for s in steps:
			cost += float(s["duration_s"])
		cost += float(world.system("attacker.enter_s"))
		var inside_cell := world.inside_cell_of(entry)
		var goal_cell: Vector2i = terminal["goal_cell"]
		if goal_cell != SimEvent.NO_CELL:
			var route := world.grid.path(inside_cell, goal_cell, Callable(world, "blocked"), Callable(att, "path_extra_cost"))
			if route.is_empty() and inside_cell != goal_cell:
				cost += float(world.system("attacker.unreachable_penalty"))
			else:
				cost += float(route.size()) / maxf(att.walk_speed, 0.001)
		if cost >= best_cost:
			continue
		best_cost = cost
		steps.append(SimAttackerActions.make(SimAttackerActions.ENTER, {
			"target_id": entry_id, "duration_s": world.system("attacker.enter_s"),
		}))
		steps.append(terminal)
		best = steps
	return best


static func _barrier_steps(world: SimWorld, att: SimAttacker, entry: SimObject) -> Array:
	var steps: Array = []
	if bool(entry.get_state("locked", false)):
		steps.append(SimAttackerActions.make(SimAttackerActions.BREACH_LOCK, {
			"target_id": entry.id, "target_cell": entry.origin(),
			"duration_s": att.profile.breach_cost("locked", 0.0),
			"noise": world.system("attacker.breach_noise.locked"),
		}))
	if bool(entry.get_state("chained", false)):
		steps.append(SimAttackerActions.make(SimAttackerActions.BREACH_CHAIN, {
			"target_id": entry.id,
			"duration_s": att.profile.breach_cost("chained", 0.0),
			"noise": world.system("attacker.breach_noise.chained"),
		}))
	var brace_id := str(entry.get_state("braced_by", ""))
	if not brace_id.is_empty() and brace_id != "<null>":
		var brace := world.objects.by_id(brace_id)
		var key := "braced_heavy" if brace != null and brace.has_tag("heavy") else "braced_light"
		steps.append(SimAttackerActions.make(SimAttackerActions.BREACH_BRACE, {
			"target_id": entry.id,
			"duration_s": att.profile.breach_cost(key, 0.0),
			"noise": world.system("attacker.breach_noise.braced"),
		}))
	return steps


# --- geometry helpers --------------------------------------------------------

static func _in_attack_range(world: SimWorld, att: SimAttacker, cell: Vector2i) -> bool:
	if world.grid.distance(att.pos, cell) > att.profile.attack_range:
		return false
	if att.profile.attack_range <= 1:
		return true
	return world.grid.has_los(att.pos, cell, Callable(world, "blocks_sight"))


static func _attack_stand_cell(world: SimWorld, att: SimAttacker, aim: Vector2i) -> Vector2i:
	if aim == SimEvent.NO_CELL:
		return SimEvent.NO_CELL
	if _in_attack_range(world, att, aim) and world.walkable(att.pos):
		return att.pos
	var candidates: Array[Vector2i] = []
	if world.walkable(aim):
		candidates.append(aim)
	for n in world.grid.neighbours(aim, 4):
		if world.walkable(n):
			candidates.append(n)
	return _nearest_reachable(world, att, candidates)


static func _nearest_standable(world: SimWorld, att: SimAttacker, cell: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	if world.walkable(cell):
		candidates.append(cell)
	for n in world.grid.neighbours(cell, 4):
		if world.walkable(n):
			candidates.append(n)
	return _nearest_reachable(world, att, candidates)


## Deterministic: shortest route, ties broken row-major.
static func _nearest_reachable(world: SimWorld, att: SimAttacker, candidates: Array[Vector2i]) -> Vector2i:
	var ordered := candidates.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var best := SimEvent.NO_CELL
	var best_len := INF
	for c in ordered:
		if c == att.pos:
			return c
		var route := world.grid.path(att.pos, c, Callable(world, "blocked"), Callable(att, "path_extra_cost"))
		if route.is_empty():
			continue
		if float(route.size()) < best_len:
			best_len = float(route.size())
			best = c
	return best
