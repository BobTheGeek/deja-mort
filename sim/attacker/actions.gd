class_name SimAttackerActions
extends RefCounted

## The attacker's action library. Every cost comes from the profile or from
## systems.json; no branch here names a room or an object id.

const ENTER := "enter"
const BREACH_LOCK := "breach_lock"
const BREACH_CHAIN := "breach_chain"
const BREACH_BRACE := "breach_brace"
const BREACH_FLIMSY := "breach_flimsy"
const MOVE_TO := "move_to"
const INVESTIGATE := "investigate"
const SEARCH := "search"
const ATTACK := "attack"
const LEAVE := "leave"

const IDS: PackedStringArray = [
	ENTER, BREACH_LOCK, BREACH_CHAIN, BREACH_BRACE, BREACH_FLIMSY,
	MOVE_TO, INVESTIGATE, SEARCH, ATTACK, LEAVE,
]


static func make(id: String, fields: Dictionary = {}) -> Dictionary:
	var a := {
		"id": id,
		"goal_cell": fields.get("goal_cell", SimEvent.NO_CELL),
		"target_id": str(fields.get("target_id", "")),
		"duration_s": float(fields.get("duration_s", 0.0)),
		"noise": float(fields.get("noise", 0.0)),
	}
	return a


## Schedules the action: path there with the attacker's own cost view, then
## occupy the duration. Walking and performing go through world.step() exactly
## as the player's do.
static func begin(world: SimWorld, att: SimAttacker, action: Dictionary) -> bool:
	var act := SimAction.new()
	act.kind = SimAction.KIND_ATTACKER
	act.verb = str(action["id"])
	act.target_id = str(action["target_id"])
	act.target_cell = action["goal_cell"]
	act.duration_ticks = world.ticks(float(action["duration_s"]))
	act.issued_tick = world.tick
	act.phase = SimAction.PHASE_WALKING
	act.meta = action

	att.cancel_action()
	var goal: Vector2i = action["goal_cell"]
	if goal != SimEvent.NO_CELL and goal != att.pos:
		var route := path_for(world, att, att.pos, goal)
		if route.is_empty():
			return false
		att.path = route
	att.action = act
	return true


static func path_for(world: SimWorld, att: SimAttacker, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return world.grid.path(from, to, Callable(world, "blocked"), Callable(att, "path_extra_cost"))


static func complete(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var noise := float(action.get("noise", 0.0))
	if noise > 0.0:
		world.emit(SimEvent.TYPE_NOISE, {
			"cell": att.pos, "loudness": noise, "actor": att.id,
			"meta": {"action": action["id"]},
		})
	match str(action["id"]):
		ENTER:
			_enter(world, att, action)
		BREACH_LOCK:
			_set_barrier(world, att, action, "locked", false)
		BREACH_CHAIN:
			_set_barrier(world, att, action, "chained", false)
		BREACH_BRACE:
			_break_brace(world, att, action)
		BREACH_FLIMSY:
			_breach_flimsy(world, att, action)
		MOVE_TO:
			pass
		INVESTIGATE:
			att.perception.clear_investigation()
		SEARCH:
			_search(world, att, action)
		ATTACK:
			_attack(world, att, action)
		LEAVE:
			_leave(world, att, action)


static func _enter(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var entry := world.objects.by_id(str(action["target_id"]))
	if entry != null:
		entry.set_state("open", true)
	att.inside = true
	att.pos = world.inside_cell_of(entry)
	world.emit(SimEvent.TYPE_ACTOR_MOVE, {
		"cell": att.pos, "actor": att.id, "object": str(action["target_id"]),
		"meta": {"entered": true},
	})


static func _set_barrier(world: SimWorld, att: SimAttacker, action: Dictionary, key: String, value: bool) -> void:
	var entry := world.objects.by_id(str(action["target_id"]))
	if entry == null:
		return
	entry.set_state(key, value)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": entry.origin(), "object": entry.id, "actor": att.id,
		"meta": {key: value, "breached": true},
	})


static func _break_brace(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var entry := world.objects.by_id(str(action["target_id"]))
	if entry == null:
		return
	var brace := world.objects.by_id(str(entry.get_state("braced_by", "")))
	entry.set_state("braced_by", null)
	if brace != null:
		# Shoved clear of the doorway; if nowhere is free it just stops blocking.
		var pushed: Array[Vector2i] = []
		var away: Vector2i = brace.origin() - entry.origin()
		away = Vector2i(signi(away.x), signi(away.y))
		var ok := away != Vector2i.ZERO
		for c in brace.cells:
			var n := c + away
			if not world.grid.is_floor(n):
				ok = false
			pushed.append(n)
		if ok:
			world.objects.move_to(brace, pushed)
		brace.set_state("displaced", true)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": entry.origin(), "object": entry.id, "actor": att.id,
		"meta": {"braced_by": null, "breached": true},
	})


static func _breach_flimsy(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var door := world.objects.by_id(str(action["target_id"]))
	if door == null:
		return
	door.set_state("locked", false)
	door.set_state("open", true)
	door.set_state("broken", true)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": door.origin(), "object": door.id, "actor": att.id,
		"meta": {"open": true, "breached": true},
	})


static func _search(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var spot := world.objects.by_id(str(action["target_id"]))
	if spot == null:
		return
	att.searched[spot.id] = true
	world.emit(SimEvent.TYPE_INTERACTION, {
		"cell": spot.origin(), "object": spot.id, "actor": att.id,
		"meta": {"searched": spot.id},
	})
	if world.player.hidden_in != spot.id:
		return
	world.player.found_in = str(spot.prop("category", spot.id))
	world.player.hidden_in = ""
	att.perception.has_last_known = true
	att.perception.last_known_pos = world.player.pos
	world.emit(SimEvent.TYPE_ACTOR_STATUS, {
		"cell": world.player.pos, "actor": att.id, "object": spot.id,
		"meta": {"found": world.player.id},
	})


static func _attack(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	var player := world.player
	if not player.alive:
		return
	if world.grid.distance(att.pos, player.pos) > att.profile.attack_range:
		return
	world.emit(SimEvent.TYPE_ATTACK, {
		"cell": player.pos, "actor": att.id, "meta": {"weapon": att.profile.weapon},
	})
	world.kill_actor(player, world.death_cause_for_weapon(att.profile.weapon), att.id)


static func _leave(world: SimWorld, att: SimAttacker, action: Dictionary) -> void:
	att.left = true
	att.inside = false
	world.emit(SimEvent.TYPE_ACTOR_STATUS, {
		"cell": att.pos, "actor": att.id, "meta": {"left": true},
	})
