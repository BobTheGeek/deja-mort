class_name SimVerbs
extends RefCounted

## The one availability function. The wheel, the solver's candidate generator and
## the interactions checklist all call this, so they can never disagree.


static func verb_ids(world: SimWorld) -> PackedStringArray:
	var out := PackedStringArray()
	for v in world.content.verbs:
		out.append(str((v as Dictionary).get("id", "")))
	return out


## Every verb id, available or not — the wheel needs the faded slots too.
## Every reason the sim can give for a verb being unavailable. The wheel keeps
## the words; a test fails the build when a key here has none.
const BLOCKERS: PackedStringArray = [
	"held", "held_missing", "subject", "actor.hands_free", "actor.holding",
	"actor.hidden", "actor.vulnerable", "actor.has_status", "actor.lacks_status",
	"target_actor", "container", "hazard", "zone", "range",
]


## Why this verb is not available on this target — a key from BLOCKERS, or "" if
## it is available, or "" when no rule is about this thing at all. The absence of
## a rule is not a reason; inventing one would be worse than saying nothing.
##
## Rules whose *target* side does not fit are skipped: "toggle" has nothing to do
## with a rug, and the rug is not the problem.
static func blocker(world: SimWorld, actor: SimActor, verb: String, target: Variant) -> String:
	var resolved: Dictionary = world._resolve_target(target)
	if resolved.is_empty():
		return ""
	var ctx := world._context(verb, resolved, actor)
	var best := ""
	var furthest := -1
	for rule in world.rules.rules:
		if rule.verb != verb or rule.trigger != "verb":
			continue
		var why := rule.why_not(ctx)
		if why.is_empty():
			return ""
		var rank := BLOCKERS.find(why)
		if rank > furthest:
			furthest = rank
			best = why
	return best if furthest >= 0 else ""


static func availability(world: SimWorld, actor: SimActor, target: Variant) -> Dictionary:
	var out := {}
	for verb in verb_ids(world):
		out[verb] = _for_verb(world, actor, verb, target)
	return out


static func is_available(world: SimWorld, actor: SimActor, verb: String, target: Variant) -> bool:
	return bool(_for_verb(world, actor, verb, target)["available"])


static func matching_rules(world: SimWorld, actor: SimActor, verb: String, target: Variant) -> Array[SimRule]:
	var resolved: Dictionary = world._resolve_target(target)
	if resolved.is_empty():
		return [] as Array[SimRule]
	var ctx := world._context(verb, resolved, actor)
	var out: Array[SimRule] = []
	for r in world.rules.matches(ctx):
		if r.trigger == "verb":
			out.append(r)
	return world.rules.choosable(out)


## Every match for this verb, before shadowing is applied. Only the lint wants
## this; everything else wants the choosable set above.
static func all_matching_rules(world: SimWorld, actor: SimActor, verb: String, target: Variant) -> Array[SimRule]:
	var resolved: Dictionary = world._resolve_target(target)
	if resolved.is_empty():
		return [] as Array[SimRule]
	var ctx := world._context(verb, resolved, actor)
	var out: Array[SimRule] = []
	for r in world.rules.matches(ctx):
		if r.trigger == "verb":
			out.append(r)
	return out


static func _for_verb(world: SimWorld, actor: SimActor, verb: String, target: Variant) -> Dictionary:
	var found := matching_rules(world, actor, verb, target)
	if found.is_empty():
		return {"available": false, "rule_id": "", "duration_s": 0.0, "rule_ids": PackedStringArray()}
	var ids := PackedStringArray()
	for r in found:
		ids.append(r.id)
	return {
		"available": true,
		"rule_id": found[0].id,
		"duration_s": found[0].duration_s,
		"rule_ids": ids,
	}


## Every (verb, object) pair the rule table allows in this room's start state.
## This is the denominator of the completion checklist.
static func valid_pairs(world: SimWorld) -> Array:
	var out: Array = []
	for obj in world.objects.all():
		for verb in verb_ids(world):
			if not _pair_reachable(world, verb, obj):
				continue
			out.append({"verb": verb, "object": obj.id})
	return out


## A pair counts if any rule for that verb could ever match this object, judged
## on tags alone — start state must not hide a pair the player can reach later.
static func _pair_reachable(world: SimWorld, verb: String, obj: SimObject) -> bool:
	for rule in world.rules.rules:
		if rule.trigger != "verb" or rule.verb != verb:
			continue
		if rule.target_kind == "actor":
			continue
		if rule.target_kind == "cell":
			# A cell-targeted rule (throw, drop, pour) is an interaction with the
			# object in your hands, so the pair is (verb, held object).
			if obj.has_tag("carryable") and obj.has_all_tags(rule.held_tags):
				return true
			continue
		if not obj.has_all_tags(rule.target_tags):
			continue
		if not rule.held_tags.is_empty() and not _room_has_holdable(world, rule.held_tags):
			continue
		return true
	return false


static func _room_has_holdable(world: SimWorld, required: Array) -> bool:
	for o in world.objects.all():
		if o.has_tag("carryable") and o.has_all_tags(required):
			return true
	return false


# --- ambiguity sweep ---------------------------------------------------------

## Every (verb, object, object-state, held item) where more than one rule is
## choosable. The wheel cannot pick between those without asking the player which
## rule they meant, which is a content bug wearing a UI costume.
##
## Sweeps a scratch copy of the room, so the caller's world is untouched.
## `apply_shadows = false` reports the raw overlap, which is how the lint shows
## what declared shadowing is buying.
static func ambiguous_pairs(world: SimWorld, apply_shadows: bool = true, max_state_keys: int = 4) -> Array:
	var scratch := SimWorld.create(world.room.duplicate(true), world.content, SimRng.new(0))
	var held_options: Array = [""]
	for obj in scratch.objects.all():
		if obj.has_tag("carryable"):
			held_options.append(obj.id)

	var found: Dictionary = {}
	for obj in scratch.objects.all():
		var keys := _condition_keys(scratch, obj, max_state_keys)
		var original: Dictionary = obj.state.duplicate(true)
		for combo in _state_combinations(scratch, keys):
			for key in combo:
				if combo[key] == null:
					obj.state.erase(key)
				else:
					obj.state[key] = combo[key]
			for held in held_options:
				scratch.player.holding = held
				for verb in verb_ids(scratch):
					var hits := all_matching_rules(scratch, scratch.player, verb, obj.id)
					if apply_shadows:
						hits = scratch.rules.choosable(hits)
					if hits.size() < 2:
						continue
					var ids := PackedStringArray()
					for rule in hits:
						ids.append(rule.id)
					var key := "%s|%s|%s" % [verb, obj.id, ids]
					if not found.has(key):
						found[key] = {
							"verb": verb, "object": obj.id, "rules": ids,
							"state": combo.duplicate(), "held": held,
						}
			scratch.player.holding = ""
		obj.state = original

	var ordered := found.keys()
	ordered.sort()
	var out: Array = []
	for key in ordered:
		out.append(found[key])
	return out


## State keys any wheel rule tests on this object.
static func _condition_keys(world: SimWorld, obj: SimObject, limit: int) -> PackedStringArray:
	var keys := PackedStringArray()
	for rule in world.rules.rules:
		if rule.trigger != "verb" or not obj.has_all_tags(rule.target_tags):
			continue
		for key in rule.target_conditions:
			if not keys.has(key):
				keys.append(key)
	keys.sort()
	return keys.slice(0, limit)


## Every assignment over those keys, from the literal values rules use plus absent.
static func _state_combinations(world: SimWorld, keys: PackedStringArray) -> Array:
	var out: Array = [{}]
	for key in keys:
		var values: Array = [null]
		for rule in world.rules.rules:
			var want: Variant = rule.target_conditions.get(key, null)
			if want == null or want is Dictionary or values.has(want):
				continue
			values.append(want)
		var grown: Array = []
		for base in out:
			for value in values:
				var next: Dictionary = (base as Dictionary).duplicate()
				next[key] = value
				grown.append(next)
		out = grown
	return out
