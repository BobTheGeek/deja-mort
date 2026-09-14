class_name SimWorld
extends RefCounted

## Room state and the 10 Hz clock. The intent API at the bottom is the only way
## in. Nothing here is a Node, and nothing here holds a tuning literal.

const PHASE_PRE_ARRIVAL := "pre_arrival"
const PHASE_ARRIVAL := "arrival"
const PHASE_OVER := "over"

var content: SimContent = null
var grid: SimGrid = null
var objects: SimObjectStore = null
var hazards: SimHazardField = null
var events: SimEventBus = null
var rules: SimRuleTable = null
var rng: SimRng = null
var player: SimPlayer = null

var room: Dictionary = {}
var room_state: Dictionary = {}
var systems: Dictionary = {}
var tick: int = 0

var attacker: SimAttacker = null
var phase: String = PHASE_PRE_ARRIVAL
var fired_timers: PackedStringArray = []
var ending: String = ""
var ending_tick: int = -1
var player_pos_at_arrival: Vector2i = SimEvent.NO_CELL
var player_hidden_at_arrival: String = ""

var discoveries: PackedStringArray = []
var interactions: Array = []        # [{verb, object}] in order, deduplicated
var collected: PackedStringArray = []

var _tick_hz: int = 10
var _dt: float = 0.1
var _timers: Array = []
var _other_actors: Array[SimActor] = []
var _interaction_seen: Dictionary = {}


static func create(room_data: Dictionary, c: SimContent, seeded: SimRng) -> SimWorld:
	var w := SimWorld.new()
	w.content = c
	w.rng = seeded
	w.room = room_data
	w.systems = c.merged_systems(room_data.get("systems", {}))
	w._tick_hz = int(w.system("tick_hz"))
	w._dt = 1.0 / float(w._tick_hz)
	w.grid = SimGrid.from_room(room_data.get("grid", {}), room_data.get("zones", {}), room_data.get("marker_zones", []))
	w.objects = SimObjectStore.from_json(room_data.get("objects", []))
	w.hazards = SimHazardField.new()
	w.events = SimEventBus.new()
	w.rules = SimRuleTable.from_json(c.rules)
	w.room_state = {
		"lit": bool(room_data.get("lit", true)),
		"timer_s": float(room_data.get("timer_s", 0.0)),
		"exits_locked": bool(room_data.get("exits_locked", true)),
	}
	var start: Array = room_data.get("player_start", [0, 0])
	w.player = SimPlayer.new()
	w.player.configure(
		"player",
		Vector2i(int(start[0]), int(start[1])),
		float(w.system("player.walk_speed")),
		int(w.system("player.durability")),
		w.vulnerable_statuses(),
	)
	w._spawn_attacker(str(room_data.get("attacker", "")), room_data.get("prior_loops", []))
	return w


## The attacker exists from tick 0 but waits outside until the timer runs out.
func _spawn_attacker(attacker_id: String, prior_loops: Array) -> void:
	if attacker_id.is_empty():
		return
	var profile := SimAttackerProfile.load_by_id(attacker_id)
	if profile == null:
		push_error("SimWorld: no attacker profile '%s'" % attacker_id)
		return
	var entry_id: String = profile.entries[0] if profile.entries.size() > 0 else ""
	var entry := objects.by_id(entry_id)
	attacker = SimAttacker.create(
		profile,
		entry.origin() if entry != null else Vector2i.ZERO,
		vulnerable_statuses(),
		prior_loops,
	)
	attacker.entry_id = entry_id
	attacker.hazard_path_cost = float(system("hazard_path_cost"))
	add_actor(attacker)


# --- tuning access -----------------------------------------------------------

func system(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = systems
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			if fallback == null:
				push_error("SimWorld: missing systems key '%s'" % path)
			return fallback
	return node


func vulnerable_statuses() -> PackedStringArray:
	var out := PackedStringArray()
	for s in system("vulnerable_statuses", []):
		out.append(str(s))
	return out


func ticks(seconds: float) -> int:
	return int(round(seconds * float(_tick_hz)))


func time_s() -> float:
	return float(tick) * _dt


func timer_remaining_s() -> float:
	return maxf(0.0, float(room_state.get("timer_s", 0.0)) - time_s())


# --- space -------------------------------------------------------------------

func walkable(cell: Vector2i) -> bool:
	if not grid.in_bounds(cell):
		return false
	var passable := grid.cell_type(cell) == SimGrid.FLOOR
	for obj in objects.at_cell(cell):
		var gate := str(obj.prop("passable_state", ""))
		if not gate.is_empty():
			if bool(obj.get_state(gate, false)):
				passable = true
			else:
				return false
		elif obj.blocks_movement():
			return false
	return passable


func blocked(cell: Vector2i) -> bool:
	return not walkable(cell)


func blocks_sight(cell: Vector2i) -> bool:
	if grid.cell_type(cell) == SimGrid.WALL:
		for obj in objects.at_cell(cell):
			if not str(obj.prop("passable_state", "")).is_empty() and bool(obj.get_state(str(obj.prop("passable_state", "")), false)):
				return false
		return true
	for obj in objects.at_cell(cell):
		if obj.blocks_sight():
			return true
	return false


func actors() -> Array[SimActor]:
	var out: Array[SimActor] = [player]
	out.append_array(_other_actors)
	return out


func add_actor(a: SimActor) -> void:
	_other_actors.append(a)


func actor_by_id(id: String) -> SimActor:
	for a in actors():
		if a.id == id:
			return a
	return null


## The walkable cell an entry opens onto. Doors sit on wall cells, so this is the
## first walkable neighbour, row-major for determinism.
func inside_cell_of(entry: SimObject) -> Vector2i:
	if entry == null:
		return SimEvent.NO_CELL
	var candidates: Array[Vector2i] = []
	for c in entry.cells:
		for n in grid.neighbours(c, 4):
			if grid.cell_type(n) == SimGrid.FLOOR and not candidates.has(n):
				candidates.append(n)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for c in candidates:
		if walkable(c):
			return c
	return candidates[0] if not candidates.is_empty() else SimEvent.NO_CELL


## An entry plus everything guarding it. A lock is part of a door; a chain is its
## own thing on the frame. Both cost him seconds, and neither needs the entry to
## carry state that is not really about the entry.
func barriers_for(entry: SimObject) -> Array[SimObject]:
	var out: Array[SimObject] = []
	if entry == null:
		return out
	out.append(entry)
	for obj in objects.all():
		if str(obj.prop("guards", "")) == entry.id:
			out.append(obj)
	return out


func death_cause_for_weapon(weapon: String) -> String:
	var map: Dictionary = system("attacker.weapon_death_cause", {})
	return str(map.get(weapon, weapon))


func actor_at(cell: Vector2i) -> SimActor:
	for a in actors():
		if a.alive and a.pos == cell:
			return a
	return null


# --- event helpers -----------------------------------------------------------

func emit(type: String, fields: Dictionary = {}) -> SimEvent:
	var e := SimEvent.make(tick, type, fields)
	events.emit_event(e)
	return e


func record_discovery(id: String, rule_id: String) -> void:
	if id.is_empty() or discoveries.has(id):
		return
	discoveries.append(id)
	emit(SimEvent.TYPE_DISCOVERY, {"rule_id": rule_id, "meta": {"id": id}})


func record_interaction(verb: String, object_id: String, rule_id: String) -> void:
	var key := "%s|%s" % [verb, object_id]
	if not _interaction_seen.has(key):
		_interaction_seen[key] = true
		interactions.append({"verb": verb, "object": object_id})
	emit(SimEvent.TYPE_INTERACTION, {
		"object": object_id, "actor": player.id, "rule_id": rule_id,
		"meta": {"verb": verb},
	})


func set_room_state(key: String, value: Variant, rule_id: String) -> void:
	room_state[key] = value
	emit(SimEvent.TYPE_STATE_CHANGE, {"rule_id": rule_id, "meta": {"room": key, "value": value}})


func collect(item: SimObject, rule_id: String) -> void:
	if collected.has(item.id):
		return
	collected.append(item.id)
	player.collect(item.id)
	emit(SimEvent.TYPE_INTERACTION, {
		"object": item.id, "actor": player.id, "rule_id": rule_id,
		"meta": {"collected": item.id},
	})


func apply_status(a: SimActor, name: String, seconds: float, rule_id: String) -> void:
	if name.is_empty() or not a.alive:
		return
	var until: int = tick + ticks(seconds) if seconds >= 0.0 else tick + ticks(float(system("forever_s")))
	var was := a.has_status(name)
	a.apply_status_until(name, until)
	if not was:
		a.status_since[name] = tick
	emit(SimEvent.TYPE_ACTOR_STATUS, {
		"cell": a.pos, "actor": a.id, "rule_id": rule_id,
		"meta": {"effect": name, "until": until},
	})


func damage_actor(a: SimActor, amount: int, cause: String, rule_id: String) -> void:
	if not a.alive:
		return
	a.durability -= amount
	emit(SimEvent.TYPE_ATTACK, {
		"cell": a.pos, "actor": a.id, "rule_id": rule_id,
		"meta": {"amount": amount, "cause": cause, "durability": a.durability},
	})
	if a.id == player.id:
		player.damage_taken += amount
	if a.durability <= 0:
		kill_actor(a, cause, rule_id)


func kill_actor(a: SimActor, cause: String, rule_id: String) -> void:
	if not a.alive:
		return
	a.alive = false
	a.death_cause = cause
	a.cancel_action()
	emit(SimEvent.TYPE_DEATH, {
		"cell": a.pos, "actor": a.id, "rule_id": rule_id, "meta": {"cause": cause},
	})


func start_timer(name: String, seconds: float, on_fire: Array, rule_id: String, bound: Dictionary) -> void:
	for t in _timers:
		if t["name"] == name:
			return
	_timers.append({
		"name": name, "fire_tick": tick + ticks(seconds),
		"on_fire": on_fire, "rule_id": rule_id, "bound": bound,
	})
	emit(SimEvent.TYPE_TIMER, {
		"rule_id": rule_id, "meta": {"timer": name, "starts": tick, "fires": tick + ticks(seconds)},
	})


func timer_remaining(name: String) -> float:
	for t in _timers:
		if t["name"] == name:
			return float(int(t["fire_tick"]) - tick) * _dt
	return -1.0


# --- the intent API ----------------------------------------------------------

func walk_to(cell: Vector2i) -> bool:
	if not player.alive or not walkable(cell):
		return false
	var route := _path_to(cell)
	if route.is_empty() and player.pos != cell:
		return false
	var act := SimAction.new()
	act.kind = SimAction.KIND_WALK
	act.target_cell = cell
	act.issued_tick = tick
	act.phase = SimAction.PHASE_WALKING
	player.cancel_action()
	player.path = route
	player.action = act
	return true


func verb_on(verb: String, target: Variant, rule_id: String = "") -> bool:
	if not player.alive:
		return false
	var resolved := _resolve_target(target)
	if resolved.is_empty():
		return false
	var ctx := _context(verb, resolved)
	var rule := rules.first_match(ctx, rule_id)
	if rule == null or rule.trigger != "verb":
		return false
	var route: Array[Vector2i] = []
	if rule.reach == "adjacent":
		var spots := reach_cells(resolved["object"], resolved["cell"])
		if spots.is_empty():
			return false
		if not spots.has(player.pos):
			route = _path_to_any(spots)
			if route.is_empty():
				return false
	var act := SimAction.new()
	act.kind = SimAction.KIND_VERB
	act.verb = verb
	act.rule_id = rule.id
	act.target_id = str(resolved["id"])
	act.target_cell = resolved["cell"]
	act.duration_ticks = ticks(rule.duration_s)
	act.issued_tick = tick
	act.phase = SimAction.PHASE_WALKING
	player.cancel_action()
	player.path = route
	player.action = act
	return true


func wait(seconds: float) -> bool:
	if not player.alive:
		return false
	var act := SimAction.new()
	act.kind = SimAction.KIND_WAIT
	act.duration_ticks = ticks(seconds)
	act.issued_tick = tick
	act.phase = SimAction.PHASE_WALKING
	player.cancel_action()
	player.action = act
	return true


func idle() -> bool:
	return player.action == null


# --- stepping ----------------------------------------------------------------

func step() -> void:
	tick += 1
	_step_timers()
	_step_actor(player)
	_step_attacker()
	_carry_held()
	_step_object_systems()
	_step_hazard_spread()
	_step_hazards_on_actors()
	_check_outcome()


func step_seconds(seconds: float) -> void:
	for _i in ticks(seconds):
		step()


## Steps until the player's queued action finishes, or the cap is hit.
func step_until_idle(max_seconds: float = 60.0) -> void:
	var limit := ticks(max_seconds)
	var spent := 0
	while player.action != null and spent < limit:
		step()
		spent += 1


func _step_timers() -> void:
	var fired: Array = []
	for t in _timers:
		if tick >= int(t["fire_tick"]):
			fired.append(t)
	for t in fired:
		_timers.erase(t)
		if not fired_timers.has(str(t["name"])):
			fired_timers.append(str(t["name"]))
		emit(SimEvent.TYPE_TIMER, {"rule_id": t["rule_id"], "meta": {"timer": t["name"], "fired": true}})
		var on_fire: Array = t["on_fire"]
		if on_fire.is_empty():
			continue
		var bound: Dictionary = t["bound"]
		var ctx := SimRuleContext.new()
		ctx.world = self
		ctx.actor = player
		ctx.target = objects.by_id(str(bound.get("target", "")))
		ctx.held = objects.by_id(str(bound.get("held", "")))
		ctx.cell = ctx.target.origin() if ctx.target != null else SimEvent.NO_CELL
		var rule := rules.by_id(str(t["rule_id"]))
		for effect in on_fire:
			SimEffects.apply_one(effect as Dictionary, rule, ctx)


func _step_actor(a: SimActor) -> void:
	if a.action == null or not a.alive:
		return
	var act: SimAction = a.action
	if act.phase == SimAction.PHASE_WALKING:
		if _immobilised(a):
			return
		if a.path.is_empty():
			_begin_perform(a, act)
		else:
			a.walk_progress += a.walk_speed * _dt
			while a.walk_progress >= 1.0 and not a.path.is_empty():
				a.walk_progress -= 1.0
				var next: Vector2i = a.path.pop_front()
				if blocked(next):
					a.path.clear()
					break
				a.facing = next - a.pos
				a.pos = next
				emit(SimEvent.TYPE_ACTOR_MOVE, {"cell": a.pos, "actor": a.id})
			if a.path.is_empty():
				_begin_perform(a, act)
			else:
				# The leg being walked now, not the one just finished. Writing it
				# after the step meant the figure was drawn walking into the next
				# cell while facing the last one — a sideways slide on every turn,
				# which is most of what he does.
				a.facing = a.path[0] - a.pos
	if a.action != null and act.phase == SimAction.PHASE_PERFORMING and tick >= act.ends_tick:
		_complete(a, act)


## On the floor is on the floor. The same list applies to the player and to him.
func _immobilised(a: SimActor) -> bool:
	for name in system("immobilising_statuses", []):
		if a.has_status(str(name)):
			return true
	return false


func _begin_perform(a: SimActor, act: SimAction) -> void:
	if act.kind == SimAction.KIND_WALK:
		act.phase = SimAction.PHASE_DONE
		a.action = null
		return
	_turn_towards(a, act)
	act.phase = SimAction.PHASE_PERFORMING
	act.ends_tick = tick + act.duration_ticks


## You look at what you are doing. `facing` used to be written only while
## walking, so it kept whichever way the last step went, and for anything you
## were already standing next to nothing wrote it at all. His perception is
## entitled to know which way someone is turned, so this is sim state.
func _turn_towards(a: SimActor, act: SimAction) -> void:
	var cell := _aim_cell(a, act)
	if cell == SimEvent.NO_CELL or cell == a.pos:
		return
	var delta := cell - a.pos
	a.facing = Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) \
		else Vector2i(0, signi(delta.y))


## The part of the target you are actually next to — a two-cell couch is faced
## at the end you are standing beside, not at its origin corner.
func _aim_cell(a: SimActor, act: SimAction) -> Vector2i:
	var resolved := _resolve_target(act.target_id if not act.target_id.is_empty() else act.target_cell)
	if resolved.is_empty():
		return act.target_cell
	var obj: SimObject = resolved["object"]
	if obj == null or obj.cells.is_empty():
		return resolved["cell"]
	var best: Vector2i = obj.cells[0]
	for c in obj.cells:
		if grid.distance(c, a.pos) < grid.distance(best, a.pos):
			best = c
	return best


func _complete(a: SimActor, act: SimAction) -> void:
	a.action = null
	act.phase = SimAction.PHASE_DONE
	if act.kind == SimAction.KIND_ATTACKER:
		SimAttackerActions.complete(self, a as SimAttacker, act.meta)
		return
	if act.kind != SimAction.KIND_VERB:
		return
	var resolved := _resolve_target(act.target_id if not act.target_id.is_empty() else act.target_cell)
	if resolved.is_empty():
		return
	var ctx := _context(act.verb, resolved, a)
	var rule := rules.by_id(act.rule_id)
	if rule == null or not rule.matches(ctx):
		return
	if a.is_hidden() and rule.verb != "hide":
		fire_manual("unhide", a)
	ctx.subject = ctx.held
	SimEffects.apply_rule(rule, ctx)
	if ctx.target != null:
		record_interaction(act.verb, ctx.target.id, rule.id)
	_run_follow_ups(ctx)


## Fires every internal `follow_up` rule that matches the state just created.
func _run_follow_ups(source: SimRuleContext) -> void:
	if source.subject == null:
		return
	for rule in rules.rules:
		if rule.trigger != "follow_up":
			continue
		var candidates: Array = [null]
		candidates.append_array(objects.all())
		for candidate in candidates:
			var ctx := SimRuleContext.new()
			ctx.world = self
			ctx.verb = rule.verb
			ctx.actor = source.actor
			ctx.held = source.held
			ctx.subject = source.subject
			ctx.target = candidate
			ctx.cell = candidate.origin() if candidate != null else source.subject.origin()
			if rule.matches(ctx):
				SimEffects.apply_rule(rule, ctx)
				break


## Runs a `manual` internal rule by verb, e.g. leaving a hiding spot.
func fire_manual(verb: String, a: SimActor) -> bool:
	for rule in rules.rules:
		if rule.trigger != "manual" or rule.verb != verb:
			continue
		var ctx := SimRuleContext.new()
		ctx.world = self
		ctx.verb = verb
		ctx.actor = a
		ctx.cell = a.pos
		if rule.matches(ctx):
			SimEffects.apply_rule(rule, ctx)
			return true
	return false


## Sustained, tag-driven behaviour: gas filling a zone, lures making noise, fire
## catching on whatever it touches. Driven by tags, never by object id.
## Arrival, perception, planning, then the same walk/perform machinery the player
## uses. He is stepped here, between the player and the hazards, so a trap laid
## this tick catches him on the same tick it would catch you.
func _step_attacker() -> void:
	if attacker == null:
		return
	if phase == PHASE_PRE_ARRIVAL:
		if timer_remaining_s() > 0.0:
			return
		phase = PHASE_ARRIVAL
		player_pos_at_arrival = player.pos
		player_hidden_at_arrival = player.hidden_in
		attacker.memory.on_arrival(self, attacker)
		emit(SimEvent.TYPE_TIMER, {"cell": attacker.pos, "actor": attacker.id, "meta": {"arrival": true}})
	if not attacker.alive or attacker.left:
		return
	attacker.perception.observe(self, attacker, attacker.profile)
	if attacker.is_incapacitated():
		if attacker.incapacitated_since < 0:
			attacker.incapacitated_since = tick
		attacker.cancel_action()
		return
	attacker.incapacitated_since = -1
	if attacker.inside and not attacker.perception.target_visible:
		attacker.search_elapsed_s += _dt
	# Replan on new perception: a plan made while blind must not outlive the moment
	# he spots you. Only a change counts, or he would restart the same plan forever.
	if attacker.perception.consume_change() and attacker.action != null \
			and str(attacker.action.verb) != SimAttackerActions.ATTACK:
		attacker.cancel_action()
	if attacker.action == null:
		var next_action := SimAttackerPlanner.next_action(self, attacker)
		if not next_action.is_empty():
			SimAttackerActions.begin(self, attacker, next_action)
	_step_actor(attacker)


## Whatever an actor is holding travels with them. Without this you can "pick up"
## a lamp, walk to the other side of the room, and leave it exactly where it was.
func _carry_held() -> void:
	for a in actors():
		if a.holding.is_empty():
			continue
		var held := objects.by_id(a.holding)
		if held == null:
			continue
		if held.cells.size() == 1 and held.cells[0] == a.pos:
			continue
		var carried: Array[Vector2i] = [a.pos]
		objects.move_to(held, carried)


func _check_outcome() -> void:
	if not ending.is_empty():
		return
	var found := SimOutcome.detect_ending(self)
	if found.is_empty():
		return
	ending = found
	ending_tick = tick
	phase = PHASE_OVER
	emit(SimEvent.TYPE_ENDING, {
		"actor": player.id, "meta": {"ending": ending, "time_s": time_s()},
	})


func _step_object_systems() -> void:
	var gas_fill_s := float(system("gas.fill_s"))
	var lure_interval := ticks(float(system("lure.interval_s")))
	for obj in objects.all():
		if obj.has_tag("gas-source") and bool(obj.get_state("on", false)) and not bool(obj.get_state("lit", false)):
			hazards.add_gas(grid.zone_of(obj.origin()), _dt / gas_fill_s)
		if obj.has_tag("lure") and bool(obj.get_state("on", false)):
			if lure_interval > 0 and tick % lure_interval == 0:
				emit(SimEvent.TYPE_NOISE, {
					"cell": obj.origin(), "object": obj.id,
					"loudness": float(obj.prop("lure_noise", system("lure.loudness"))),
					"meta": {"sustained": true},
				})
		if obj.has_tag("flammable") and not bool(obj.get_state("burning", false)):
			for c in obj.cells:
				if hazards.has("burning", c) or hazards.has("hot", c):
					obj.set_state("burning", true)
					for cc in obj.cells:
						hazards.spawn("burning", cc, SimHazardField.FOREVER)
					emit(SimEvent.TYPE_HAZARD_SPAWN, {
						"cell": obj.origin(), "object": obj.id,
						"meta": {"layer": "burning", "caught": true},
					})
					break


func _step_hazard_spread() -> void:
	var created: Dictionary = hazards.step(tick, _dt, Callable(self, "walkable"))
	for layer in created:
		var cells: Array = created[layer]
		emit(SimEvent.TYPE_HAZARD_SPAWN, {
			"cell": cells[0], "meta": {"layer": layer, "cells": cells.size(), "spread": true},
		})


func _step_hazards_on_actors() -> void:
	var effects: Dictionary = system("hazard_effects", {})
	for a in actors():
		if not a.alive:
			continue
		a.expire_statuses(tick)
		for layer in SimHazardField.LAYERS:
			if not hazards.has(layer, a.pos):
				a.hazard_since.erase(layer)
				continue
			if not a.hazard_since.has(layer):
				a.hazard_since[layer] = tick
			if not effects.has(layer):
				continue
			_apply_hazard_effect(a, layer, effects[layer] as Dictionary)
	_check_gas(effects)


func _apply_hazard_effect(a: SimActor, layer: String, spec: Dictionary) -> void:
	# You slip when you step on it, not for as long as you stand on it. Without
	# this an actor on an oiled cell is prone forever and can never leave.
	if bool(spec.get("on_enter_only", false)) and int(a.hazard_since.get(layer, -1)) != tick:
		return
	var guard := str(spec.get("unless_status", ""))
	if not guard.is_empty() and a.has_status(guard):
		return
	var status_name := str(spec.get("status", ""))
	if not status_name.is_empty() and not a.has_status(status_name):
		apply_status(a, status_name, float(system(str(spec.get("for_system", "")), 0.0)), "hazard:" + layer)
	if spec.has("damage") and _hazard_may_damage(a, layer, spec):
		a.hazard_last_damage[layer] = tick
		damage_actor(a, int(spec["damage"]), layer, "hazard:" + layer)
	var lethal_to: Array = spec.get("lethal_to", [])
	if not lethal_to.has(a.role):
		return
	if spec.has("lethal_after_system"):
		# Measured from when he stepped into it, not from the status, which is
		# re-applied every few seconds and would reset the clock forever.
		var since: int = int(a.hazard_since.get(layer, tick))
		if tick - since < ticks(float(system(str(spec["lethal_after_system"])))):
			return
	kill_actor(a, layer, "hazard:" + layer)


## Roles, not ids: a hazard spec must work for any attacker profile.
func _hazard_may_damage(a: SimActor, layer: String, spec: Dictionary) -> bool:
	var damage_to: Array = spec.get("damage_to", [])
	if not damage_to.is_empty() and not damage_to.has(a.role):
		return false
	if not spec.has("damage_every_s"):
		return not a.hazard_last_damage.has(layer)
	var gap := ticks(float(spec["damage_every_s"]))
	return tick - int(a.hazard_last_damage.get(layer, -gap * 2)) >= gap


func _check_gas(effects: Dictionary) -> void:
	var spec: Dictionary = effects.get("gas_explosion", {})
	if spec.is_empty():
		return
	for zone in grid.zone_names():
		if grid.is_marker_zone(zone):
			continue
		if hazards.gas_level(zone) < float(spec.get("at_level", 1.0)):
			continue
		var ignited := false
		for cell in grid.zone_cells(zone):
			for layer in spec.get("ignited_by", []):
				if hazards.has(str(layer), cell):
					ignited = true
		if not ignited:
			continue
		emit(SimEvent.TYPE_HAZARD_SPAWN, {"meta": {"layer": "explosion", "zone": zone}})
		for a in actors():
			if a.alive and grid.zone_of(a.pos) == zone:
				kill_actor(a, "explosion", "gas_explosion")
		hazards.add_gas(zone, -1.0)


# --- targeting helpers -------------------------------------------------------

func _resolve_target(target: Variant) -> Dictionary:
	if target is String:
		var id := str(target)
		var obj := objects.by_id(id)
		if obj != null:
			return {"object": obj, "actor": null, "cell": obj.origin(), "id": id}
		var other := actor_by_id(id)
		if other != null:
			return {"object": null, "actor": other, "cell": other.pos, "id": id}
		return {}
	if target is Vector2i:
		return {"object": null, "actor": null, "cell": target, "id": ""}
	return {}


func _context(verb: String, resolved: Dictionary, a: SimActor = null) -> SimRuleContext:
	var who: SimActor = a if a != null else player
	var held: SimObject = objects.by_id(who.holding) if not who.holding.is_empty() else null
	return SimRuleContext.make(
		self, verb, who, resolved["object"], resolved["cell"], held, resolved["actor"]
	)


## Cells an actor may stand in to act on `obj` (or on a bare cell).
func reach_cells(obj: SimObject, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if obj == null:
		# A bare square is reached from itself or from anything touching it,
		# corners included. Four-connectivity left the cooker's own square with
		# no way to stand: a fridge one side, a counter the other, a wall behind
		# and boxes in front, and nothing could be poured or thrown onto it.
		if walkable(cell):
			out.append(cell)
		for n in grid.neighbours(cell, 8):
			if walkable(n) and not out.has(n):
				out.append(n)
		return out
	var connectivity := obj.reach_connectivity()
	for c in obj.cells:
		if walkable(c) and not out.has(c):
			out.append(c)
		for n in grid.neighbours(c, connectivity):
			if walkable(n) and not out.has(n):
				out.append(n)
	if out.is_empty():
		var host := objects.container_of(obj.id)
		if host != null:
			return reach_cells(host, host.origin())
	return out


func _path_to(cell: Vector2i) -> Array[Vector2i]:
	return grid.path(player.pos, cell, Callable(self, "blocked"))


func _path_to_any(cells: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var ordered := cells.duplicate()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for c in ordered:
		if c == player.pos:
			return [] as Array[Vector2i]
		var route := _path_to(c)
		if route.is_empty():
			continue
		if best.is_empty() or route.size() < best.size():
			best = route
	return best


# --- determinism -------------------------------------------------------------

func snapshot_hash() -> int:
	var parts := PackedStringArray()
	parts.append("t=%d lit=%s" % [tick, room_state.get("lit", true)])
	for o in objects.all():
		var keys := o.state.keys()
		keys.sort()
		var st := PackedStringArray()
		for k in keys:
			st.append("%s=%s" % [k, o.state[k]])
		parts.append("%s@%s[%s]" % [o.id, o.cells, ",".join(st)])
	for a in actors():
		parts.append("%s@%s h=%s hid=%s st=%s alive=%s" % [
			a.id, a.pos, a.holding, a.hidden_in, a.status_names(), a.alive,
		])
	for layer in SimHazardField.LAYERS:
		parts.append("%s:%s" % [layer, hazards.cells(layer)])
	return "\n".join(parts).hash()
