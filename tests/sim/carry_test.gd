extends GdUnitTestSuite

## Picking something up should mean carrying it. From Bob's playtest: "When I
## chose to pickup or hold the lamp, it did not move with me. In other words, I
## did not actually pick it up."
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func test_a_held_object_comes_with_you() -> void:
	var w := F.world()
	assert_bool(F.act(w, "grab", "floor_lamp")).is_true()
	assert_str(w.player.holding).is_equal("floor_lamp")
	assert_bool(F.goto(w, Vector2i(6, 5))).is_true()
	assert_vector(w.objects.by_id("floor_lamp").origin()).override_failure_message(
		"the lamp stayed behind while the player walked off with it").is_equal(w.player.pos)


func test_it_keeps_up_the_whole_way() -> void:
	var w := F.world()
	F.act(w, "grab", "floor_lamp")
	w.walk_to(Vector2i(2, 7))
	for _i in w.ticks(4.0):
		w.step()
		assert_vector(w.objects.by_id("floor_lamp").origin()).override_failure_message(
			"the lamp fell behind mid-walk").is_equal(w.player.pos)
		if w.player.action == null:
			break


func test_putting_it_down_leaves_it_where_you_put_it() -> void:
	var w := F.world()
	F.act(w, "grab", "floor_lamp")
	F.goto(w, Vector2i(4, 6))
	assert_bool(F.act(w, "drop", Vector2i(4, 5), "drop")).is_true()
	assert_str(w.player.holding).is_empty()
	assert_vector(w.objects.by_id("floor_lamp").origin()).is_equal(Vector2i(4, 5))
	F.goto(w, Vector2i(6, 5))
	assert_vector(w.objects.by_id("floor_lamp").origin()).override_failure_message(
		"a dropped object followed the player anyway").is_equal(Vector2i(4, 5))


## The toaster is on a cord. Carrying it must not teleport its outlet.
func test_carrying_something_does_not_move_what_it_is_plugged_into() -> void:
	var w := F.world()
	var outlet: Variant = w.objects.by_id("toaster").prop("outlet")
	F.act(w, "grab", "toaster")
	F.goto(w, Vector2i(5, 4))
	assert_array(w.objects.by_id("toaster").prop("outlet")).is_equal(outlet)


## From Bob's third playtest: "I don't like how when I grab the lamp it follows
## me around the room. It does not look right. When something is picked up, it
## should just show that I have it and disappear from the screen until I put it
## back down or use it."
##
## That is a drawing decision, not a simulation one. The sim keeps carrying the
## object at the actor's cell — dropping it has to put it somewhere, throwing it
## has to throw it from somewhere, and the solver depends on both. What changes
## is that presentation stops drawing it.
func test_the_sim_still_knows_where_a_carried_thing_is() -> void:
	var world := F.world()
	F.give(world, "floor_lamp")
	assert_bool(F.goto(world, Vector2i(6, 8))).is_true()
	assert_array(world.objects.by_id("floor_lamp").cells).override_failure_message(
		"the sim lost track of what the player is holding").is_equal([world.player.pos])
