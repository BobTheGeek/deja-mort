extends GdUnitTestSuite

## The chain is a thing on the wall, not a mode of the door. Splitting it removes
## the last case where two rules match one (verb, object) and the wheel has to ask.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")
const EXCEPTIONS := "res://content/lint_exceptions.json"


# --- the content shape -------------------------------------------------------

func test_the_chain_is_its_own_object_guarding_the_entry() -> void:
	var w := F.world()
	var chain := w.objects.by_id("door_chain")
	assert_object(chain).override_failure_message("no door_chain object").is_not_null()
	assert_bool(chain.has_tag("chainable")).is_true()
	assert_str(str(chain.prop("guards", ""))).is_equal("front_door")


func test_the_door_keeps_its_lock_and_gives_up_its_chain() -> void:
	var door := F.world().objects.by_id("front_door")
	assert_bool(door.has_tag("lockable")).is_true()
	assert_bool(door.has_tag("chainable")) \
		.override_failure_message("the door still claims to be chainable").is_false()
	assert_object(door.get_state("chained", null)) \
		.override_failure_message("`chained` still lives on the door").is_null()


## A chain hangs on the wall beside a door. It is not an obstacle, and if it
## were, he could never come through at all.
func test_the_chain_does_not_block_the_doorway() -> void:
	var w := F.world()
	var door := w.objects.by_id("front_door")
	assert_bool(w.walkable(w.inside_cell_of(door))).is_true()
	door.set_state("open", true)
	assert_bool(w.walkable(door.origin())) \
		.override_failure_message("the chain made the doorway impassable").is_true()


# --- behaviour ---------------------------------------------------------------

func test_toggling_the_chain_chains_the_chain() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "door_chain", "toggle_chain")).is_true()
	assert_bool(bool(w.objects.by_id("door_chain").get_state("chained"))).is_true()


func test_the_door_and_the_chain_each_offer_exactly_one_rule() -> void:
	var w := F.world()
	for id in ["front_door", "door_chain"]:
		var slots := SimVerbs.availability(w, w.player, id)
		var ids: PackedStringArray = slots["toggle"].get("rule_ids", PackedStringArray())
		assert_int(ids.size()).override_failure_message(
			"toggle on %s still offers %s" % [id, ids]).is_equal(1)


func test_the_world_lists_every_barrier_on_an_entry() -> void:
	var w := F.world()
	var ids := PackedStringArray()
	for barrier in w.barriers_for(w.objects.by_id("front_door")):
		ids.append(barrier.id)
	assert_array(Array(ids)).contains(["front_door", "door_chain"])


# --- the attacker ------------------------------------------------------------

func test_he_plans_to_breach_a_chain_that_is_on() -> void:
	var w := F.world()
	F.act(w, "toggle", "door_chain", "toggle_chain")
	w.step_seconds(w.timer_remaining_s())
	var plan := SimAttackerPlanner.plan_for(w, w.attacker)
	var ids := PackedStringArray()
	for step in plan:
		ids.append(str(step["id"]))
	assert_array(Array(ids)).override_failure_message("plan was %s" % [ids]) \
		.contains([SimAttackerActions.BREACH_CHAIN])


func test_breaching_the_chain_clears_the_chain_not_the_door() -> void:
	var w := F.world()
	F.act(w, "toggle", "door_chain", "toggle_chain")
	w.step_seconds(w.timer_remaining_s())
	var guard := w.ticks(60.0)
	var spent := 0
	while not w.attacker.inside and spent < guard:
		w.step()
		spent += 1
	assert_bool(w.attacker.inside).is_true()
	assert_bool(bool(w.objects.by_id("door_chain").get_state("chained"))).is_false()


func test_the_chain_still_costs_him_the_profile_seconds() -> void:
	var plain := F.world()
	plain.step_seconds(plain.timer_remaining_s())
	var plain_entry := _seconds_until_inside(plain)

	var chained := F.world()
	F.act(chained, "toggle", "door_chain", "toggle_chain")
	chained.step_seconds(chained.timer_remaining_s())
	var chained_entry := _seconds_until_inside(chained)

	assert_float(chained_entry - plain_entry).is_equal_approx(
		chained.attacker.profile.breach_cost("chained", 0.0), 0.3)


func _seconds_until_inside(w: SimWorld) -> float:
	var start := w.time_s()
	var guard := w.ticks(60.0)
	var spent := 0
	while not w.attacker.inside and spent < guard:
		w.step()
		spent += 1
	return w.time_s() - start


# --- the whole point ---------------------------------------------------------

func test_room_one_has_no_ambiguity_left_at_all() -> void:
	var found := SimVerbs.ambiguous_pairs(F.world())
	var pairs := PackedStringArray()
	for entry in found:
		pairs.append("%s|%s %s" % [entry["verb"], entry["object"], entry["rules"]])
	assert_array(Array(pairs)).override_failure_message(
		"still ambiguous: %s" % [pairs]).is_empty()


func test_the_exception_that_excused_the_front_door_is_gone() -> void:
	var json := JSON.new()
	assert_int(json.parse(FileAccess.get_file_as_string(EXCEPTIONS))).is_equal(OK)
	assert_array((json.data as Dictionary).get("ambiguous_pairs", [])) \
		.override_failure_message("the lint is still excusing something").is_empty()


## With nothing left to disambiguate, the wheel has no reason to ask.
func test_the_wheel_no_longer_has_a_choice_list() -> void:
	var source := FileAccess.get_file_as_string("res://game/wheel.gd")
	assert_bool(source.contains("_show_choices")) \
		.override_failure_message("game/wheel.gd still has its 'which rule did you mean' list").is_false()
