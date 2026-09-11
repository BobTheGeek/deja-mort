class_name SimRuleTable
extends RefCounted

## Loading and matching. Declaration order in rules.json is the tie-break, so
## specific rules are authored above general ones.

var rules: Array[SimRule] = []
var _by_id: Dictionary = {}


static func from_json(data: Variant) -> SimRuleTable:
	var t := SimRuleTable.new()
	if data is Array:
		for raw in data:
			var rule := SimRule.from_json(raw as Dictionary)
			t.rules.append(rule)
			t._by_id[rule.id] = rule
	return t


func by_id(id: String) -> SimRule:
	return _by_id.get(id, null)


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in rules:
		out.append(r.id)
	return out


func matches(ctx: SimRuleContext) -> Array[SimRule]:
	var out: Array[SimRule] = []
	for r in rules:
		if r.matches(ctx):
			out.append(r)
	return out


func first_match(ctx: SimRuleContext, rule_id: String = "") -> SimRule:
	for r in rules:
		if not rule_id.is_empty() and r.id != rule_id:
			continue
		if r.matches(ctx):
			return r
	return null
