extends GdUnitTestSuite

## The wheel must never ask which rule you meant. For any
## (verb, object, object-state, held item) at most one rule may be choosable.
##
## Written before the implementation. Expected to fail until `shadows` exists.

const F := preload("res://tests/support/sim_fixture.gd")
const EXCEPTIONS := "res://content/lint_exceptions.json"


# --- the mechanism -----------------------------------------------------------

func test_a_rule_carries_what_it_shadows() -> void:
	var table := F.world().rules
	assert_array(Array(table.by_id("push_heavy").shadows)).contains(["push"])
	assert_array(Array(table.by_id("tip_first").shadows)).contains(["push_heavy", "push"])
	assert_array(Array(table.by_id("push").shadows)).is_empty()


func test_shadowing_drops_the_general_rule() -> void:
	var table := F.world().rules
	var matches: Array[SimRule] = [table.by_id("push_heavy"), table.by_id("push")]
	var choosable := table.choosable(matches)
	assert_int(choosable.size()).is_equal(1)
	assert_str(choosable[0].id).is_equal("push_heavy")


## A shadows B, B shadows C, all three match: only A survives, even though the
## rule that removed C is itself removed.
func test_shadowing_resolves_a_chain_in_one_pass() -> void:
	var table := F.world().rules
	var matches: Array[SimRule] = [
		table.by_id("tip_first"), table.by_id("push_heavy"), table.by_id("push"),
	]
	var choosable := table.choosable(matches)
	assert_int(choosable.size()).is_equal(1)
	assert_str(choosable[0].id).is_equal("tip_first")


func test_rules_that_do_not_shadow_each_other_both_survive() -> void:
	var table := F.world().rules
	var matches: Array[SimRule] = [table.by_id("toggle_lock"), table.by_id("toggle_chain")]
	assert_int(table.choosable(matches).size()).is_equal(2)


func test_every_declared_shadow_names_a_rule_that_exists() -> void:
	var table := F.world().rules
	var ids := Array(table.ids())
	var broken := PackedStringArray()
	for rule in table.rules:
		for victim in rule.shadows:
			if not ids.has(str(victim)):
				broken.append("%s shadows unknown rule %s" % [rule.id, victim])
	assert_array(Array(broken)).override_failure_message(
		"shadow list has a typo: %s" % [broken]).is_empty()


func test_a_rule_never_shadows_itself() -> void:
	for rule in F.world().rules.rules:
		assert_bool(Array(rule.shadows).has(rule.id)) \
			.override_failure_message("%s shadows itself" % rule.id).is_false()


# --- the sweep ---------------------------------------------------------------

func test_the_sweep_finds_the_front_door_before_it_is_fixed() -> void:
	var found := SimVerbs.ambiguous_pairs(F.world())
	var pairs := PackedStringArray()
	for entry in found:
		pairs.append("%s|%s" % [entry["verb"], entry["object"]])
	assert_array(Array(pairs)).contains(["toggle|front_door"])


## Everything except the pairs we have written down and explained.
func test_room_one_has_no_undeclared_ambiguity() -> void:
	var allowed := _exceptions()
	var offenders := PackedStringArray()
	for entry in SimVerbs.ambiguous_pairs(F.world()):
		var key := "%s|%s" % [entry["verb"], entry["object"]]
		if allowed.has(key):
			continue
		offenders.append("%s %s" % [key, entry["rules"]])
	assert_array(Array(offenders)).override_failure_message(
		"undeclared overlap — the wheel would have to ask: %s" % [offenders]).is_empty()


## Every exception must still be real. One that has been fixed is a stale excuse.
func test_no_exception_outlives_its_reason() -> void:
	var live := PackedStringArray()
	for entry in SimVerbs.ambiguous_pairs(F.world()):
		live.append("%s|%s" % [entry["verb"], entry["object"]])
	var stale := PackedStringArray()
	for key in _exceptions():
		if not live.has(key):
			stale.append(key)
	assert_array(Array(stale)).override_failure_message(
		"these exceptions no longer overlap and should be deleted: %s" % [stale]).is_empty()


# --- what the wheel is handed ------------------------------------------------

func test_the_wheel_is_offered_at_most_one_rule_per_verb() -> void:
	var world := F.world()
	var allowed := _exceptions()
	var offenders := PackedStringArray()
	for obj in world.objects.all():
		var slots := SimVerbs.availability(world, world.player, obj.id)
		for verb in slots:
			var ids: PackedStringArray = slots[verb].get("rule_ids", PackedStringArray())
			if ids.size() <= 1 or allowed.has("%s|%s" % [verb, obj.id]):
				continue
			offenders.append("%s on %s offers %s" % [verb, obj.id, ids])
	assert_array(Array(offenders)).override_failure_message(
		"the wheel would have to ask: %s" % [offenders]).is_empty()


func _exceptions() -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(EXCEPTIONS):
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(EXCEPTIONS)) != OK:
		return out
	for entry in (json.data as Dictionary).get("ambiguous_pairs", []):
		out.append("%s|%s" % [entry["verb"], entry["object"]])
	return out
