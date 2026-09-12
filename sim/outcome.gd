class_name SimOutcome
extends RefCounted

## Endings, death causes, the star rubric, the completion sets, and the one
## notebook line a loop earns. All of it reads state and data — no room is named.

const ENDING_EVADE := "evade"
const ENDING_DISABLE := "disable"
const ENDING_KILL := "kill"
const ENDING_ESCAPE := "escape"
const ENDING_LOSS := "loss"

const WIN_ENDINGS: PackedStringArray = [ENDING_EVADE, ENDING_DISABLE, ENDING_KILL, ENDING_ESCAPE]


## Called once per tick by SimWorld. Empty string means the loop continues.
static func detect_ending(world: SimWorld) -> String:
	if not world.player.alive:
		return ENDING_LOSS
	var att := world.attacker
	if att != null:
		if not att.alive:
			return ENDING_KILL
		if att.left:
			return ENDING_EVADE
		if att.is_incapacitated() and att.incapacitated_since >= 0:
			var held := world.tick - att.incapacitated_since
			if held >= world.ticks(float(world.system("disable_hold_s"))):
				return ENDING_DISABLE
	if not bool(world.room_state.get("exits_locked", true)):
		for exit_obj in world.objects.with_tag("exit"):
			if exit_obj.occupies(world.player.pos):
				return ENDING_ESCAPE
	if world.time_s() >= float(world.room.get("max_loop_s", INF)):
		# Safety cap, resolved exactly as the spec states it.
		if att == null or att.left:
			return ENDING_EVADE
		if att.is_incapacitated():
			return ENDING_DISABLE
		return ENDING_LOSS
	return ""


static func won(ending: String) -> bool:
	return WIN_ENDINGS.has(ending)


## The full report for one loop.
static func evaluate(world: SimWorld, loop_index: int = 1) -> Dictionary:
	var ending := world.ending
	var cause := death_key(world)
	var context := build_context(world, ending, loop_index)
	var stars := 0
	if won(ending):
		stars = 1
		if _passes(world, "two", context):
			stars = 2
		if _passes(world, "three", context):
			stars = 3
	return {
		"ending": ending,
		"won": won(ending),
		"stars": stars,
		"death_cause": cause,
		"time_s": world.time_s(),
		"loop_index": loop_index,
		"completion": completion(world),
		"notebook": notebook_line(world, ending, cause),
		"context": context,
	}


## Rubric predicates see a flat dotted namespace.
static func build_context(world: SimWorld, ending: String, loop_index: int) -> Dictionary:
	var att := world.attacker
	return {
		"ending": ending,
		"won": won(ending),
		"player.never_seen": world.player.never_seen,
		"player.dead": not world.player.alive,
		"player.damage_taken": world.player.damage_taken,
		"player.seen_count": world.player.seen_count,
		"player.death_cause": world.player.death_cause,
		"attacker.dead": att != null and not att.alive,
		"attacker.left": att != null and att.left,
		"attacker.death_cause": att.death_cause if att != null else "",
		"attacker.vulnerable": att != null and att.is_vulnerable(),
		"loop.index": loop_index,
		"loop.damage_taken": world.player.damage_taken,
		"loop.time_s": world.time_s(),
		"loop.discoveries": world.discoveries.size(),
	}


static func _passes(world: SimWorld, tier: String, context: Dictionary) -> bool:
	var rubric: Dictionary = world.room.get("rubric", {})
	var source := str(rubric.get(tier, ""))
	if source.is_empty():
		source = str(_defaults(world).get(tier, ""))
	if source.is_empty():
		return false
	return SimPredicate.evaluate(source, context)


static func _defaults(world: SimWorld) -> Dictionary:
	var path := "res://content/rubric_defaults.json"
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data


# --- death causes ------------------------------------------------------------

## A composed key: what killed you, and where or how you were caught. This is
## what the "Ways to die" checklist counts.
static func death_key(world: SimWorld) -> String:
	if world.player.alive:
		return ""
	var cause := world.player.death_cause
	var context := _death_context(world)
	return cause if context.is_empty() else "%s@%s" % [cause, context]


static func _death_context(world: SimWorld) -> String:
	var player := world.player
	if not player.found_in.is_empty():
		return player.found_in
	if not player.hidden_in.is_empty():
		var spot := world.objects.by_id(player.hidden_in)
		if spot != null:
			return str(spot.prop("category", spot.id))
	for name in player.status_names():
		if world.vulnerable_statuses().has(name) or name == "exposed":
			return name
	if player.has_status("exposed"):
		return "exposed"
	# Prefixed so a zone called `bed` never collides with a hiding spot whose
	# category is also `bed`.
	var zone := world.grid.zone_of(player.pos)
	return "zone_" + zone if not zone.is_empty() else "open"


# --- completion --------------------------------------------------------------

static func completion(world: SimWorld) -> Dictionary:
	var possible_pairs: int = SimVerbs.valid_pairs(world).size()
	var possible_disc := possible_discoveries(world)
	var deaths := PackedStringArray()
	for e in world.events.of_type(SimEvent.TYPE_DEATH):
		if e.actor == world.player.id:
			var key := death_key(world)
			if not key.is_empty() and not deaths.has(key):
				deaths.append(key)
	var endings := PackedStringArray()
	for e in world.events.of_type(SimEvent.TYPE_ENDING):
		var value := str(e.meta.get("ending", ""))
		if not value.is_empty() and not endings.has(value):
			endings.append(value)
	return {
		"interactions": world.interactions.size(),
		"interactions_possible": possible_pairs,
		"discoveries": Array(world.discoveries),
		"discoveries_possible": Array(possible_disc),
		"deaths": Array(deaths),
		"endings": Array(endings),
		"collectible": Array(world.collected),
		"percent": _percent(world, possible_pairs, possible_disc.size()),
	}


## Every discovery this room's objects could ever fire, computed from the rule
## table at load. The `???` entries on the dossier come from here.
static func possible_discoveries(world: SimWorld) -> PackedStringArray:
	var out := PackedStringArray()
	for rule in world.rules.rules:
		if rule.discovery.is_empty() or out.has(rule.discovery):
			continue
		if _rule_is_possible(world, rule):
			out.append(rule.discovery)
	return out


static func _rule_is_possible(world: SimWorld, rule: SimRule) -> bool:
	if not _tags_exist(world, rule.held_tags, true):
		return false
	if not _tags_exist(world, rule.subject_tags, false):
		return false
	if rule.target_kind == "object" and not _tags_exist(world, rule.target_tags, false):
		return false
	return true


static func _tags_exist(world: SimWorld, required: Array, must_carry: bool) -> bool:
	if required.is_empty():
		return true
	for obj in world.objects.all():
		if must_carry and not obj.has_tag("carryable"):
			continue
		if obj.has_all_tags(required):
			return true
	return false


static func _percent(world: SimWorld, pairs_possible: int, discoveries_possible: int) -> float:
	var done := float(world.interactions.size() + world.discoveries.size() + world.collected.size())
	var total := float(pairs_possible + discoveries_possible + _collectibles(world))
	if total <= 0.0:
		return 0.0
	return 100.0 * done / total


static func _collectibles(world: SimWorld) -> int:
	return world.objects.with_tag("collectible").size()


# --- notebook ----------------------------------------------------------------

static func notebook_line(world: SimWorld, ending: String, cause: String) -> String:
	var templates := _templates()
	var keys := PackedStringArray()
	if not cause.is_empty():
		keys.append("death." + cause)
		keys.append("death." + cause.get_slice("@", 0))
		keys.append("death.default")
	else:
		keys.append("ending." + ending)
		keys.append("ending.default")
	for key in keys:
		if templates.has(key):
			return _fill(str(templates[key]), world, ending, cause)
	return ""


static func _fill(template: String, world: SimWorld, ending: String, cause: String) -> String:
	var out := template
	out = out.replace("{where}", cause.get_slice("@", 1) if cause.contains("@") else "")
	out = out.replace("{cause}", cause.get_slice("@", 0))
	out = out.replace("{ending}", ending)
	out = out.replace("{time}", "%.0f" % world.time_s())
	return out


## What the loop showed you about him, in his own order. Derived from the event
## log through templates — no room and no attacker profile is named here.
static func attacker_observations(world: SimWorld) -> PackedStringArray:
	var templates := _templates()
	var out := PackedStringArray()
	var add := func(key: String, fields: Dictionary) -> void:
		if not templates.has(key):
			return
		var line := str(templates[key])
		for field in fields:
			line = line.replace("{%s}" % field, str(fields[field]))
		if not out.has(line):
			out.append(line)

	var attacker_id := world.attacker.id if world.attacker != null else ""
	if attacker_id.is_empty():
		return out
	for e in world.events.log_all():
		if e.actor != attacker_id:
			continue
		match e.type:
			SimEvent.TYPE_ACTOR_MOVE:
				if e.meta.has("entered"):
					add.call("attacker.entered", {"what": _name_of(world, e.object)})
			SimEvent.TYPE_STATE_CHANGE:
				if e.meta.has("breached"):
					add.call("attacker.breached", {"what": _name_of(world, e.object)})
			SimEvent.TYPE_INTERACTION:
				if e.meta.has("searched"):
					add.call("attacker.searched", {"what": _name_of(world, str(e.meta["searched"]))})
			SimEvent.TYPE_ACTOR_STATUS:
				if e.meta.has("left"):
					add.call("attacker.left", {})
				elif e.meta.has("found"):
					add.call("attacker.found", {"what": _name_of(world, e.object)})
	return out


static func _name_of(world: SimWorld, object_id: String) -> String:
	var obj := world.objects.by_id(object_id)
	return obj.name.to_lower() if obj != null else object_id


static func _templates() -> Dictionary:
	var path := "res://content/notebook_templates.json"
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data
