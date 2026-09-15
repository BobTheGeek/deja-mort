class_name SimRule
extends RefCounted

## One row of content/rules.json. Behaviour lives in data; this only matches.

var id: String = ""
var verb: String = ""
var internal: bool = false          # fired by the world, never shown on the wheel
var held_tags: Array = []
var held_conditions: Dictionary = {}
var target_kind: String = "object"  # object | cell | actor | any
var subject_tags: Array = []
var subject_conditions: Dictionary = {}
var reach: String = "adjacent"      # adjacent | none
var trigger: String = "verb"        # verb (wheel) | follow_up (auto) | manual
var subject_adjacent: bool = false
## Rules this one outranks. When both match, this is what the player meant, so
## the wheel never has to ask. A specific rule sitting above a general one is
## the rule table working, not ambiguity.
var shadows: PackedStringArray = []
var requires_container_open: bool = false
var target_actor_conditions: Dictionary = {}
var target_tags: Array = []
var target_conditions: Dictionary = {}
var target_cell_hazard: String = ""
var target_cell_no_hazard: String = ""
var actor_conditions: Dictionary = {}
var range_check: Dictionary = {}
var zone: String = ""
var duration_s: float = 0.0
var noise: float = 0.0
var effects: Array = []
var discovery: String = ""


static func from_json(data: Dictionary) -> SimRule:
	var r := SimRule.new()
	r.id = str(data.get("id", ""))
	r.verb = str(data.get("verb", ""))
	r.internal = bool(data.get("internal", false))
	r.held_tags = data.get("held_tags", [])
	r.held_conditions = data.get("held_conditions", {})
	r.target_tags = data.get("target_tags", [])
	r.target_conditions = data.get("target_conditions", {})
	r.subject_tags = data.get("subject_tags", [])
	r.subject_conditions = data.get("subject_conditions", {})
	r.reach = str(data.get("reach", "adjacent"))
	r.trigger = str(data.get("trigger", "verb"))
	r.subject_adjacent = bool(data.get("subject_adjacent", false))
	for victim in data.get("shadows", []):
		r.shadows.append(str(victim))
	r.requires_container_open = bool(data.get("requires_container_open", false))
	r.target_actor_conditions = data.get("target_actor_conditions", {})
	r.actor_conditions = data.get("actor_conditions", {})
	r.range_check = data.get("range_check", {})
	r.zone = str(data.get("zone", ""))
	r.duration_s = float(data.get("duration_s", 0.0))
	r.noise = float(data.get("noise", 0.0))
	r.effects = data.get("effects", [])
	r.discovery = str(data.get("discovery", ""))
	var target_block: Dictionary = data.get("target", {})
	r.target_kind = str(target_block.get("kind", "object"))
	r.target_cell_hazard = str(target_block.get("cell_hazard", ""))
	r.target_cell_no_hazard = str(target_block.get("cell_no_hazard", ""))
	return r


## Which gate stopped this rule, or "" when it matched. Same order as matches(),
## because the first gate to fail is the honest answer. The key is machine-
## readable on purpose: the sim does not own the words.
func why_not(ctx: SimRuleContext) -> String:
	if ctx.verb != verb:
		return "verb"
	if not _target_kind_ok(ctx):
		return "target_kind"
	if not _held_ok(ctx):
		return "held_missing" if ctx.held == null else "held"
	if not _target_tags_ok(ctx):
		# Not what this rule is about. Nobody needs telling a rug has no switch.
		return "target"
	if not _target_conditions_ok(ctx):
		# About this thing, and this thing is in the wrong state: a flat phone,
		# a shut cupboard. That is a reason, and it has words.
		return "target_state"
	if not _subject_ok(ctx):
		return "subject"
	if not _actor_ok(ctx):
		return "actor." + _failing_actor_condition(ctx)
	if not _target_actor_ok(ctx):
		return "target_actor"
	if not _container_ok(ctx):
		return "container"
	if not _hazard_ok(ctx):
		return "hazard"
	if not _zone_ok(ctx):
		return "zone"
	if not _range_ok(ctx):
		return "range"
	return ""


func _failing_actor_condition(ctx: SimRuleContext) -> String:
	for key in actor_conditions:
		var one := {}
		one[key] = actor_conditions[key]
		var probe := SimRule.new()
		probe.actor_conditions = one
		if not probe._actor_ok(ctx):
			return str(key)
	return "conditions"


func matches(ctx: SimRuleContext) -> bool:
	if ctx.verb != verb:
		return false
	if not _target_kind_ok(ctx):
		return false
	if not _held_ok(ctx):
		return false
	if not _target_ok(ctx):
		return false
	if not _subject_ok(ctx):
		return false
	if not _actor_ok(ctx):
		return false
	if not _target_actor_ok(ctx):
		return false
	if not _container_ok(ctx):
		return false
	if not _hazard_ok(ctx):
		return false
	if not _zone_ok(ctx):
		return false
	if not _range_ok(ctx):
		return false
	return true


func _target_kind_ok(ctx: SimRuleContext) -> bool:
	match target_kind:
		"object":
			return ctx.target != null
		"cell":
			return ctx.target == null and ctx.cell != SimEvent.NO_CELL
		"actor":
			return ctx.target_actor != null
		_:
			return true


func _held_ok(ctx: SimRuleContext) -> bool:
	if held_tags.is_empty() and held_conditions.is_empty():
		return true
	if ctx.held == null:
		return false
	if not ctx.held.has_all_tags(held_tags):
		return false
	return _conditions_ok(ctx.held.state, held_conditions)


func _target_ok(ctx: SimRuleContext) -> bool:
	return _target_tags_ok(ctx) and _target_conditions_ok(ctx)


func _target_tags_ok(ctx: SimRuleContext) -> bool:
	if target_tags.is_empty() and target_conditions.is_empty():
		return true
	if ctx.target == null:
		return false
	return ctx.target.has_all_tags(target_tags)


func _target_conditions_ok(ctx: SimRuleContext) -> bool:
	if target_conditions.is_empty():
		return true
	if ctx.target == null:
		return false
	return _conditions_ok(ctx.target.state, target_conditions)


func _subject_ok(ctx: SimRuleContext) -> bool:
	if subject_tags.is_empty() and subject_conditions.is_empty():
		return true
	if ctx.subject == null:
		return false
	if not ctx.subject.has_all_tags(subject_tags):
		return false
	if subject_adjacent:
		if ctx.target == null:
			return false
		var grid: SimGrid = ctx.world.get("grid")
		var touching := false
		for a in ctx.subject.cells:
			for b in ctx.target.cells:
				if grid.is_adjacent(a, b, 4):
					touching = true
		if not touching:
			return false
	return _conditions_ok(ctx.subject.state, subject_conditions)


func _actor_ok(ctx: SimRuleContext) -> bool:
	for key in actor_conditions:
		var want: Variant = actor_conditions[key]
		match key:
			"hands_free":
				if ctx.actor.hands_free() != bool(want):
					return false
			"holding":
				if (not ctx.actor.holding.is_empty()) != bool(want):
					return false
			"hidden":
				if ctx.actor.is_hidden() != bool(want):
					return false
			"vulnerable":
				if ctx.actor.is_vulnerable() != bool(want):
					return false
			"has_status":
				if not ctx.actor.has_status(str(want)):
					return false
			"lacks_status":
				if ctx.actor.has_status(str(want)):
					return false
			_:
				return false
	return true


func _target_actor_ok(ctx: SimRuleContext) -> bool:
	if target_actor_conditions.is_empty():
		return true
	if ctx.target_actor == null:
		return false
	for key in target_actor_conditions:
		var want: Variant = target_actor_conditions[key]
		match key:
			"vulnerable":
				if ctx.target_actor.is_vulnerable() != bool(want):
					return false
			"alive":
				if ctx.target_actor.alive != bool(want):
					return false
			"has_status":
				if not ctx.target_actor.has_status(str(want)):
					return false
			_:
				return false
	return true


## Reaching into a shut container is not allowed. Generic: any `openable`
## container that currently holds the target must be `open`.
func _container_ok(ctx: SimRuleContext) -> bool:
	if not requires_container_open or ctx.target == null:
		return true
	var store: SimObjectStore = ctx.world.get("objects")
	var host := store.container_of(ctx.target.id)
	if host == null:
		return true
	if not host.has_tag("openable"):
		return true
	return bool(host.get_state("open", false))


func _hazard_ok(ctx: SimRuleContext) -> bool:
	if target_cell_hazard.is_empty() and target_cell_no_hazard.is_empty():
		return true
	if ctx.world == null:
		return false
	var hazards: SimHazardField = ctx.world.get("hazards")
	var cell: Vector2i = ctx.target_cell()
	if not target_cell_hazard.is_empty() and not hazards.has(target_cell_hazard, cell):
		return false
	if not target_cell_no_hazard.is_empty() and hazards.has(target_cell_no_hazard, cell):
		return false
	return true


func _zone_ok(ctx: SimRuleContext) -> bool:
	if zone.is_empty():
		return true
	var grid: SimGrid = ctx.world.get("grid")
	return grid.zone_of(ctx.target_cell()) == zone


func _range_ok(ctx: SimRuleContext) -> bool:
	if range_check.is_empty():
		return true
	var limit: Variant = _range_limit(ctx)
	if limit == null:
		return false
	var from: Vector2i = ctx.actor.pos
	if str(range_check.get("from", "actor")) == "held_outlet":
		if ctx.held == null:
			return false
		var outlet: Variant = ctx.held.prop("outlet", null)
		if outlet == null:
			return false
		from = Vector2i(int(outlet[0]), int(outlet[1]))
	var grid: SimGrid = ctx.world.get("grid")
	return grid.distance(from, ctx.target_cell()) <= int(limit)


func _range_limit(ctx: SimRuleContext) -> Variant:
	if range_check.has("max"):
		return range_check["max"]
	if range_check.has("max_prop") and ctx.held != null:
		return ctx.held.prop(str(range_check["max_prop"]), null)
	if range_check.has("max_system"):
		return ctx.world.system(str(range_check["max_system"]))
	return null


## Condition values support exact match plus a few comparison forms:
##   true / false / 5 / "closed"      exact
##   {"not": x}                        inequality
##   {"gte": 2} {"lte": 2} {"gt": } {"lt": }
##   {"exists": true}
static func _conditions_ok(state: Dictionary, conditions: Dictionary) -> bool:
	for key in conditions:
		var want: Variant = conditions[key]
		var have: Variant = state.get(key, null)
		if want is Dictionary:
			var spec: Dictionary = want
			if spec.has("exists"):
				if (have != null) != bool(spec["exists"]):
					return false
			if spec.has("not") and have == spec["not"]:
				return false
			if spec.has("gte") and (have == null or float(have) < float(spec["gte"])):
				return false
			if spec.has("lte") and (have == null or float(have) > float(spec["lte"])):
				return false
			if spec.has("gt") and (have == null or float(have) <= float(spec["gt"])):
				return false
			if spec.has("lt") and (have == null or float(have) >= float(spec["lt"])):
				return false
		elif have != want:
			return false
	return true
