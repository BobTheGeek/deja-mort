extends GdUnitTestSuite

## Occupancy, reach, stepping, and hazards acting on actors.

const F := preload("res://tests/support/sim_fixture.gd")


func test_a_shut_door_blocks_and_an_open_one_does_not() -> void:
	var w := F.world()
	assert_bool(w.walkable(Vector2i(8, 2))).is_false()
	w.objects.by_id("bath_door").set_state("open", true)
	assert_bool(w.walkable(Vector2i(8, 2))).is_true()


func test_a_rug_is_walked_over_not_around() -> void:
	var w := F.world()
	assert_bool(w.walkable(Vector2i(2, 3))).is_true()
	assert_bool(w.walkable(Vector2i(2, 2))).is_false()


func test_counter_objects_are_reachable_diagonally() -> void:
	var w := F.world()
	assert_array(w.reach_cells(w.objects.by_id("counter_drawer"), Vector2i(2, 1))) \
		.contains([Vector2i(1, 2), Vector2i(3, 2)])


func test_walking_costs_time_at_the_authored_speed() -> void:
	var w := F.world()
	var start := w.player.pos
	assert_bool(w.walk_to(Vector2i(6, 8))).is_true()
	w.step_until_idle()
	assert_vector(w.player.pos).is_equal(Vector2i(6, 8))
	assert_float(w.time_s()).is_greater(0.0)
	assert_vector(start).is_not_equal(w.player.pos)


func test_an_intent_with_no_matching_rule_is_refused() -> void:
	var w := F.world()
	assert_bool(w.verb_on("hide", "toaster")).is_false()
	assert_bool(w.verb_on("grab", "fridge")).is_false()
	assert_bool(w.verb_on("nonsense", "toaster")).is_false()
	assert_object(w.player.action).is_null()


func test_the_loop_timer_counts_down() -> void:
	var w := F.world()
	assert_float(w.timer_remaining_s()).is_equal(90.0)
	w.step_seconds(10.0)
	assert_float(w.timer_remaining_s()).is_equal_approx(80.0, 0.001)


func test_oil_puts_an_actor_on_the_floor() -> void:
	var w := F.world()
	F.give(w, "cooking_oil")
	F.act(w, "use-held-on", Vector2i(4, 4), "pour_slippery")
	var mark := F.target_actor(w, Vector2i(4, 4))
	w.step()
	assert_bool(mark.has_status("prone")).is_true()
	assert_bool(mark.is_vulnerable()).is_true()


func test_standing_in_a_shocked_puddle_kills_the_player() -> void:
	var w := F.world()
	w.hazards.spawn("shock", w.player.pos, w.tick + w.ticks(3.0))
	w.step()
	assert_bool(w.player.alive).is_false()
	assert_str(w.player.death_cause).is_equal("shock")


func test_statuses_expire_on_their_own() -> void:
	var w := F.world()
	var mark := F.target_actor(w, Vector2i(6, 6))
	w.apply_status(mark, "stunned", 2.0, "test")
	assert_bool(mark.has_status("stunned")).is_true()
	w.step_seconds(3.0)
	assert_bool(mark.has_status("stunned")).is_false()


func test_the_wheel_reports_every_verb_available_or_not() -> void:
	var w := F.world()
	var slots := SimVerbs.availability(w, w.player, "toaster")
	assert_int(slots.size()).is_equal(SimVerbs.verb_ids(w).size())
	assert_bool(bool(slots["grab"]["available"])).is_true()
	assert_bool(bool(slots["hide"]["available"])).is_false()


func test_the_room_reports_its_valid_pair_count() -> void:
	var w := F.world()
	assert_int(SimVerbs.valid_pairs(w).size()).is_greater(60)


func test_interactions_are_recorded_once_each() -> void:
	var w := F.world()
	F.act(w, "inspect", "toaster")
	F.act(w, "inspect", "toaster")
	assert_int(w.interactions.size()).is_equal(1)


func test_the_collectible_needs_a_second_look() -> void:
	var w := F.world()
	F.act(w, "inspect", "toaster")
	assert_array(Array(w.collected)).is_empty()
	F.act(w, "inspect", "toaster")
	assert_array(Array(w.collected)).contains(["bubble_token"])
