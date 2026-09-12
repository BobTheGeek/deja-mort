class_name SimEffects
extends RefCounted

## Applies a rule's `effects` list. Every branch here is on an op name from the
## JSON, never on an object id.


static func apply_rule(rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if rule.noise > 0.0:
		world.emit(SimEvent.TYPE_NOISE, {
			"cell": ctx.actor.pos, "loudness": rule.noise,
			"actor": ctx.actor.id, "rule_id": rule.id,
		})
	var before: int = world.events.log_all().size()
	for effect in rule.effects:
		apply_one(effect as Dictionary, rule, ctx)
	# A rule that changed nothing did not discover anything either — this is what
	# stops a follow-up rule with no cells to act on from logging a discovery.
	var changed: bool = world.events.log_all().size() > before
	if not rule.discovery.is_empty() and changed:
		world.record_discovery(rule.discovery, rule.id)


static func apply_one(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if not _guard_ok(effect, ctx):
		return
	var op := str(effect.get("op", ""))
	match op:
		"set":
			_op_set(effect, rule, ctx)
		"grab":
			_op_grab(effect, rule, ctx)
		"drop":
			_op_drop(effect, rule, ctx)
		"place_in":
			_op_place_in(effect, rule, ctx)
		"consume_held":
			_op_consume_held(effect, rule, ctx)
		"throw_held":
			_op_throw_held(effect, rule, ctx)
		"move":
			_op_move(effect, rule, ctx)
		"tip":
			_op_tip(effect, rule, ctx)
		"break":
			_op_break(effect, rule, ctx)
		"hazard":
			_op_hazard(effect, rule, ctx)
		"clear_hazard":
			_op_clear_hazard(effect, rule, ctx)
		"start_spread":
			_op_start_spread(effect, rule, ctx)
		"stop_spread":
			world.hazards.stop_spread(str(effect.get("layer", "")))
		"add_gas":
			world.hazards.add_gas(world.grid.zone_of(ctx.target_cell()), _fraction(effect, ctx))
		"noise":
			world.emit(SimEvent.TYPE_NOISE, {
				"cell": _first_cell(effect, ctx), "loudness": float(effect.get("loudness", 0.0)),
				"actor": ctx.actor.id, "rule_id": rule.id,
			})
		"light":
			world.emit(SimEvent.TYPE_LIGHT, {
				"cell": _first_cell(effect, ctx), "light": float(effect.get("value", 1.0)),
				"object": ctx.target.id if ctx.target != null else "", "rule_id": rule.id,
			})
		"status":
			_op_status(effect, rule, ctx)
		"damage":
			_op_damage(effect, rule, ctx)
		"hide_actor":
			_op_hide_actor(effect, rule, ctx)
		"unhide_actor":
			_op_unhide_actor(effect, rule, ctx)
		"start_timer":
			_op_start_timer(effect, rule, ctx)
		"discovery":
			world.record_discovery(str(effect.get("id", "")), rule.id)
		"collect":
			_op_collect(effect, rule, ctx)
		"reveal":
			_op_reveal(effect, rule, ctx)
		_:
			push_error("SimEffects: unknown op '%s' in rule '%s'" % [op, rule.id])


## Optional per-effect guard so one rule can carry a conditional step without a
## second rule id: {"requires_state": {"on": "target", "conditions": {...}}}.
static func _guard_ok(effect: Dictionary, ctx: SimRuleContext) -> bool:
	if not effect.has("requires_state"):
		return true
	var spec: Dictionary = effect["requires_state"]
	var obj := resolve_object(ctx, str(spec.get("on", "target")))
	if obj == null:
		return false
	return SimRule._conditions_ok(obj.state, spec.get("conditions", {}))


# --- object references -------------------------------------------------------

static func resolve_object(ctx: SimRuleContext, ref: String) -> SimObject:
	match ref:
		"target":
			return ctx.target
		"held":
			return ctx.held
		"subject":
			return ctx.subject
		_:
			return null


static func resolve_value(ctx: SimRuleContext, path: String) -> Variant:
	var parts := path.split(".")
	if parts.size() != 2:
		return null
	var obj := resolve_object(ctx, parts[0])
	if obj == null:
		return null
	if parts[1] == "id":
		return obj.id
	return obj.get_state(parts[1], null)


static func resolve_cells(ctx: SimRuleContext, where: String) -> Array[Vector2i]:
	var world: Object = ctx.world
	var out: Array[Vector2i] = []
	if where.begins_with("connected:"):
		return world.hazards.connected(where.substr(10), ctx.target_cell())
	if where.begins_with("area:"):
		var radius := int(where.substr(5))
		var centre := ctx.target_cell()
		for y in range(centre.y - radius, centre.y + radius + 1):
			for x in range(centre.x - radius, centre.x + radius + 1):
				var c := Vector2i(x, y)
				if world.grid.is_floor(c):
					out.append(c)
		return out
	match where:
		"target_cell":
			out.append(ctx.target_cell())
		"actor_cell":
			out.append(ctx.actor.pos)
		"object_cells":
			if ctx.target != null:
				out.append_array(ctx.target.cells)
		"subject_cells":
			if ctx.subject != null:
				out.append_array(ctx.subject.cells)
		"held_cells":
			if ctx.held != null:
				out.append_array(ctx.held.cells)
		"zone":
			out.append_array(world.grid.zone_cells(world.grid.zone_of(ctx.target_cell())))
		"tips_onto":
			if ctx.target != null:
				for pair in ctx.target.prop("tips", {}).get("onto", []):
					out.append(Vector2i(int(pair[0]), int(pair[1])))
		"cord_line_chokepoints":
			out.append_array(_cord_chokepoints(ctx))
		_:
			out.append(ctx.target_cell())
	return out


static func _cord_chokepoints(ctx: SimRuleContext) -> Array[Vector2i]:
	var world: Object = ctx.world
	var out: Array[Vector2i] = []
	var obj := ctx.subject if ctx.subject != null else ctx.target
	if obj == null:
		return out
	var outlet: Variant = obj.prop("outlet", null)
	if outlet == null:
		return out
	var from := Vector2i(int(outlet[0]), int(outlet[1]))
	for c in world.grid.line(from, obj.origin()):
		if out.has(c):
			continue
		if world.grid.in_zone("chokepoint", c):
			out.append(c)
			continue
		for other in world.objects.at_cell(c):
			if other.has_tag("chokepoint"):
				out.append(c)
				break
	return out


static func _first_cell(effect: Dictionary, ctx: SimRuleContext) -> Vector2i:
	var cells := resolve_cells(ctx, str(effect.get("where", "target_cell")))
	return cells[0] if not cells.is_empty() else ctx.target_cell()


static func _fraction(effect: Dictionary, ctx: SimRuleContext) -> float:
	if effect.has("fraction_system"):
		return float(ctx.world.system(str(effect["fraction_system"])))
	return float(effect.get("fraction", 0.0))


static func _seconds(effect: Dictionary, ctx: SimRuleContext) -> float:
	if effect.has("for_system"):
		return float(ctx.world.system(str(effect["for_system"])))
	return float(effect.get("for_s", -1.0))


# --- ops ---------------------------------------------------------------------

static func _op_set(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var key := str(effect.get("key", ""))
	var on := str(effect.get("on", "target"))
	var value: Variant = effect.get("value", null)
	if effect.has("value_from"):
		value = resolve_value(ctx, str(effect["value_from"]))
	if on == "room":
		var before: Variant = world.room_state.get(key, null)
		if bool(effect.get("toggle", false)):
			value = not bool(before)
		world.set_room_state(key, value, rule.id)
		return
	var obj := resolve_object(ctx, on)
	if obj == null:
		return
	if bool(effect.get("toggle", false)):
		value = not bool(obj.get_state(key, false))
	obj.set_state(key, value)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": obj.origin(), "object": obj.id, "rule_id": rule.id,
		"meta": {"key": key, "value": value},
	})


static func _op_grab(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.target == null:
		return
	world.objects.take_from_container(ctx.target.id)
	ctx.target.on = ""
	ctx.actor.holding = ctx.target.id
	var into_hand: Array[Vector2i] = [ctx.actor.pos]
	world.objects.move_to(ctx.target, into_hand)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": ctx.actor.pos, "object": ctx.target.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"held": true},
	})


static func _op_drop(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.held == null:
		return
	var cells := resolve_cells(ctx, str(effect.get("where", "target_cell")))
	var landing: Vector2i = cells[0] if not cells.is_empty() else ctx.actor.pos
	world.objects.move_to(ctx.held, [landing] as Array[Vector2i])
	ctx.actor.holding = ""
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": landing, "object": ctx.held.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"held": false},
	})


static func _op_place_in(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.held == null or ctx.target == null:
		return
	world.objects.put_in_container(ctx.target, ctx.held.id)
	world.objects.move_to(ctx.held, ctx.target.cells.duplicate())
	ctx.actor.holding = ""
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": ctx.target.origin(), "object": ctx.held.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"in": ctx.target.id},
	})


static func _op_consume_held(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.held == null:
		return
	ctx.held.set_state("consumed", true)
	world.objects.move_to(ctx.held, [] as Array[Vector2i])
	ctx.actor.holding = ""
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": ctx.actor.pos, "object": ctx.held.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"consumed": true},
	})


static func _op_throw_held(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.held == null:
		return
	var landing := ctx.target_cell()
	world.objects.move_to(ctx.held, [landing] as Array[Vector2i])
	ctx.actor.holding = ""
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": landing, "object": ctx.held.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"thrown": true},
	})


static func _op_move(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var obj := resolve_object(ctx, str(effect.get("on", "target")))
	if obj == null:
		return
	var tiles := int(effect.get("tiles", 1))
	var delta := _direction(effect, ctx) * tiles
	var moved: Array[Vector2i] = []
	for c in obj.cells:
		var n := c + delta
		if not world.grid.is_floor(n):
			return
		moved.append(n)
	for n in moved:
		for other in world.objects.at_cell(n):
			if other != obj and other.blocks_movement():
				return
	world.objects.move_to(obj, moved)
	ctx.subject = obj
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": obj.origin(), "object": obj.id, "actor": ctx.actor.id,
		"rule_id": rule.id, "meta": {"moved": true},
	})


static func _direction(effect: Dictionary, ctx: SimRuleContext) -> Vector2i:
	var named := str(effect.get("dir", "away_from_actor"))
	match named:
		"N": return Vector2i(0, -1)
		"E": return Vector2i(1, 0)
		"S": return Vector2i(0, 1)
		"W": return Vector2i(-1, 0)
		"away_from_actor":
			var d: Vector2i = ctx.target_cell() - ctx.actor.pos
			if absi(d.x) >= absi(d.y):
				return Vector2i(signi(d.x), 0)
			return Vector2i(0, signi(d.y))
		_:
			return Vector2i.ZERO


static func _op_tip(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.target == null:
		return
	var stage := str(effect.get("stage", "lean"))
	ctx.target.set_state("tipped" if stage == "fall" else "leaning", true)
	if stage == "fall":
		ctx.target.set_state("leaning", false)
		var onto := resolve_cells(ctx, "tips_onto")
		world.objects.move_to(ctx.target, onto)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": ctx.target.origin(), "object": ctx.target.id,
		"rule_id": rule.id, "meta": {"tip": stage},
	})


static func _op_break(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var obj := resolve_object(ctx, str(effect.get("on", "target")))
	if obj == null:
		return
	obj.set_state("broken", true)
	for t in obj.prop("break_adds_tags", []):
		obj.add_tag(str(t))
	for t in obj.prop("break_removes_tags", []):
		obj.remove_tag(str(t))
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": obj.origin(), "object": obj.id, "rule_id": rule.id,
		"meta": {"broken": true},
	})


static func _op_hazard(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var layer := str(effect.get("layer", ""))
	var seconds := _seconds(effect, ctx)
	var until: int = SimHazardField.FOREVER if seconds < 0.0 else world.tick + world.ticks(seconds)
	var spawned: Array[Vector2i] = []
	for c in resolve_cells(ctx, str(effect.get("where", "target_cell"))):
		if world.hazards.spawn(layer, c, until):
			spawned.append(c)
	if spawned.is_empty():
		return
	world.emit(SimEvent.TYPE_HAZARD_SPAWN, {
		"cell": spawned[0], "rule_id": rule.id, "actor": ctx.actor.id,
		"meta": {"layer": layer, "cells": spawned.size(), "until": until},
	})


static func _op_clear_hazard(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var layer := str(effect.get("layer", ""))
	for c in resolve_cells(ctx, str(effect.get("where", "target_cell"))):
		world.hazards.clear(layer, c)


static func _op_start_spread(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var layer := str(effect.get("layer", ""))
	var source := resolve_object(ctx, str(effect.get("source", "target")))
	if source == null:
		return
	var source_cells: Array[Vector2i] = []
	for c in source.cells:
		for n in world.grid.neighbours(c, 4):
			if world.walkable(n) and not source_cells.has(n):
				source_cells.append(n)
	var zone_name := str(effect.get("zone", ""))
	if zone_name.is_empty() and effect.has("zone_system"):
		zone_name = str(world.system(str(effect["zone_system"]), ""))
	if zone_name.is_empty():
		zone_name = world.grid.zone_of(source.origin())
	var rate := float(world.system(str(effect.get("rate_system", ""))))
	world.hazards.start_spread(layer, source_cells, world.grid.zone_cells(zone_name), rate)
	world.emit(SimEvent.TYPE_HAZARD_SPAWN, {
		"cell": source.origin(), "object": source.id, "rule_id": rule.id,
		"meta": {"layer": layer, "spread": "started", "zone": zone_name},
	})


static func _op_status(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var seconds := _seconds(effect, ctx)
	var name := str(effect.get("effect", ""))
	for a in _status_targets(effect, ctx):
		world.apply_status(a, name, seconds, rule.id)


static func _status_targets(effect: Dictionary, ctx: SimRuleContext) -> Array:
	var world: Object = ctx.world
	var who := str(effect.get("who", "target_actor"))
	match who:
		"actor":
			return [ctx.actor]
		"target_actor":
			return [ctx.target_actor] if ctx.target_actor != null else []
		"actors_in_cells":
			var cells := resolve_cells(ctx, str(effect.get("where", "target_cell")))
			var out: Array = []
			for a in world.actors():
				if cells.has(a.pos):
					out.append(a)
			return out
		_:
			return []


static func _op_damage(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var amount := int(effect.get("amount", 1))
	for a in _status_targets(effect, ctx):
		world.damage_actor(a, amount, str(effect.get("cause", rule.id)), rule.id)


static func _op_hide_actor(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.target == null:
		return
	ctx.actor.hidden_in = ctx.target.id
	var spots: Variant = ctx.target.prop("hide_cells", null)
	if spots != null and (spots as Array).size() > 0:
		ctx.actor.pos = Vector2i(int(spots[0][0]), int(spots[0][1]))
	world.emit(SimEvent.TYPE_ACTOR_STATUS, {
		"cell": ctx.actor.pos, "actor": ctx.actor.id, "object": ctx.target.id,
		"rule_id": rule.id, "meta": {"hidden": true},
	})


static func _op_unhide_actor(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.actor.hidden_in.is_empty():
		return
	var was := ctx.actor.hidden_in
	ctx.actor.hidden_in = ""
	world.emit(SimEvent.TYPE_ACTOR_STATUS, {
		"cell": ctx.actor.pos, "actor": ctx.actor.id, "object": was,
		"rule_id": rule.id, "meta": {"hidden": false},
	})


static func _op_start_timer(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var name := str(effect.get("name", ""))
	if effect.has("name_from"):
		name = "%s:%s" % [name, resolve_value(ctx, str(effect["name_from"]))]
	var seconds := _seconds(effect, ctx)
	var on_fire: Array = effect.get("on_fire", [])
	var bound := {}
	if ctx.target != null:
		bound["target"] = ctx.target.id
	if ctx.held != null:
		bound["held"] = ctx.held.id
	world.start_timer(name, seconds, on_fire, rule.id, bound)


static func _op_collect(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	var source := resolve_object(ctx, str(effect.get("from", "target")))
	if source == null:
		return
	for id in source.contains:
		var item: SimObject = world.objects.by_id(id)
		if item != null and item.has_tag("collectible"):
			world.collect(item, rule.id)


static func _op_reveal(effect: Dictionary, rule: SimRule, ctx: SimRuleContext) -> void:
	var world: Object = ctx.world
	if ctx.target == null:
		return
	var seen := int(ctx.target.get_state("inspected", 0)) + 1
	ctx.target.set_state("inspected", seen)
	world.emit(SimEvent.TYPE_STATE_CHANGE, {
		"cell": ctx.target.origin(), "object": ctx.target.id, "actor": ctx.actor.id,
		"rule_id": rule.id,
		"meta": {"inspected": seen, "text": ctx.target.inspect, "tags": ", ".join(ctx.target.tags)},
	})
