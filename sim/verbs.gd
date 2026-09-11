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
