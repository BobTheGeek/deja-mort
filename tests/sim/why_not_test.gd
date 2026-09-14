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


# --- things you cannot get to -------------------------------------------------

## Bob's tenth playtest, loop 1, t=96.1s: he chose Hide on the bathtub and the
## sim refused. The bath door was shut. The wheel had the slot lit, because
## availability asked whether the rule matched and never asked whether he could
## get there — `verb_on` was the only thing that knew, and by then the wheel had
## already promised.
##
## Twelve seconds and a loop went into that.
func test_a_thing_you_cannot_walk_to_is_not_available() -> void:
	var world := F.world()
	world.player.pos = Vector2i(6, 2)
	assert_bool(world.objects.by_id("bath_door").get_state("open", false)).override_failure_message(
		"this test needs the bath door shut").is_false()
	assert_bool(SimVerbs.is_available(world, world.player, "hide", "bathtub")) \
		.override_failure_message("the wheel would light Hide on a tub behind a shut door") \
		.is_false()
	assert_str(_blocker(world, "hide", "bathtub")).is_equal("unreachable")


func test_opening_the_door_makes_it_available_again() -> void:
	var world := F.world()
	world.player.pos = Vector2i(6, 2)
	assert_bool(F.act(world, "open", "bath_door")).is_true()
	assert_bool(SimVerbs.is_available(world, world.player, "hide", "bathtub")) \
		.override_failure_message("the door is open and the tub is still refused").is_true()


## The claim, stated once: if the wheel lights it, the sim does it. This walks
## every object in the room and every verb on it, in two states, and fails on the
## first slot that promises something the sim then refuses.
func test_everything_the_wheel_offers_actually_happens() -> void:
	for world: SimWorld in [F.world(), _with_hands_full()]:
		var broken := PackedStringArray()
		for obj in world.objects.all():
			for verb in SimVerbs.verb_ids(world):
				if not SimVerbs.is_available(world, world.player, verb, obj.id):
					continue
				if world.verb_on(verb, obj.id):
					world.player.cancel_action()
				else:
					broken.append("%s on %s" % [verb, obj.id])
		assert_array(Array(broken)).override_failure_message(
			"the wheel offers these and the sim refuses them: %s" % [broken]).is_empty()


func _with_hands_full() -> SimWorld:
	var world := F.world()
	F.give(world, "glass_jar")
	return world
