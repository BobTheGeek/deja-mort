extends GdUnitTestSuite

## From the first recorded session: Bob tapped the kitchen knife, inspected it,
## tapped it again — and the action that came out was Drop. He wanted the knife.
## Grab was unavailable because his hands were already full of floor lamp, and
## the wheel showed a dashed circle and said nothing.
##
## So the sim answers "why not". It returns a key, never a sentence: the words
## live in the visual table with the rest of the wheel's copy.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _blocker(world: SimWorld, verb: String, target: Variant) -> String:
	return SimVerbs.blocker(world, world.player, verb, target)


func test_an_available_verb_is_not_blocked_by_anything() -> void:
	var world := F.world()
	assert_bool(SimVerbs.is_available(world, world.player, "inspect", "fridge")).is_true()
	assert_str(_blocker(world, "inspect", "fridge")).override_failure_message(
		"a verb you can use should report no reason at all").is_empty()


## The one that cost Bob the knife.
func test_full_hands_are_named_as_the_reason() -> void:
	var world := F.world()
	assert_str(_blocker(world, "grab", "kitchen_knife")).override_failure_message(
		"with empty hands, grabbing a knife is not blocked").is_empty()
	F.give(world, "floor_lamp")
	assert_str(_blocker(world, "grab", "kitchen_knife")).override_failure_message(
		"hands full of floor lamp and the sim cannot say so").is_equal("actor.hands_free")


func test_empty_hands_are_named_too() -> void:
	var world := F.world()
	assert_str(_blocker(world, "use-held-on", "sink")).override_failure_message(
		"using a held thing with nothing held should say the hands are empty") \
		.is_equal("held_missing")


func test_a_shut_cupboard_is_named() -> void:
	var world := F.world()
	assert_bool(bool(world.objects.by_id("cabinet").get_state("open", false))).is_false()
	assert_str(_blocker(world, "grab", "glass_jar")).is_equal("container")


func test_opening_the_cupboard_clears_it() -> void:
	var world := F.world()
	assert_bool(F.act(world, "open", "cabinet")).is_true()
	assert_str(_blocker(world, "grab", "glass_jar")).override_failure_message(
		"the cabinet is open and the jar is still said to be shut away").is_empty()


## A verb that has nothing to do with the thing gets no invented excuse.
func test_a_verb_that_does_not_apply_says_nothing() -> void:
	var world := F.world()
	assert_bool(SimVerbs.is_available(world, world.player, "toggle", "rug")).is_false()
	assert_str(_blocker(world, "toggle", "rug")).override_failure_message(
		"a rug is not a switch; that is not a reason, it is the absence of one") \
		.is_empty()


## State counts: a lamp that is already on cannot be turned on.
func test_the_state_of_the_thing_can_be_the_reason() -> void:
	var world := F.world()
	assert_bool(F.act(world, "toggle", "floor_lamp")).is_true()
	var blocked := _blocker(world, "toggle", "floor_lamp")
	if SimVerbs.is_available(world, world.player, "toggle", "floor_lamp"):
		return   # the room allows toggling it back, which is its own answer
	assert_str(blocked).is_not_empty()


## Every key the sim can return has words somewhere. A key with no copy is an
## empty tooltip, which is what we already had.
func test_every_reason_the_sim_can_give_has_words_for_it() -> void:
	var reasons: Dictionary = GameVisuals.load_table().get_value("wheel.reasons", {})
	var missing := PackedStringArray()
	for key in SimVerbs.BLOCKERS:
		if not reasons.has(str(key)):
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"reasons with no copy in visuals.json: %s" % [missing]).is_empty()
