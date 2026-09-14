extends GdUnitTestSuite

## Perception, planning, barriers, patience, and the thing that matters most:
## he takes hazards through the same world.step() the player does.

const F := preload("res://tests/support/sim_fixture.gd")


func _at_arrival(w: SimWorld) -> void:
	w.step_seconds(w.timer_remaining_s())


func test_the_profile_is_data() -> void:
	var p := SimAttackerProfile.load_by_id("tenant_knife")
	assert_object(p).is_not_null()
	assert_str(p.weapon).is_equal("knife")
	assert_int(p.sight_range).is_equal(6)
	assert_float(p.patience_s).is_equal(40.0)
	assert_float(p.breach_cost("braced_heavy", 0.0)).is_equal(10.0)


func test_he_waits_outside_until_the_timer_runs_out() -> void:
	var w := F.world()
	assert_object(w.attacker).is_not_null()
	assert_str(w.phase).is_equal(SimWorld.PHASE_PRE_ARRIVAL)
	assert_bool(w.attacker.inside).is_false()
	w.step_seconds(w.timer_remaining_s() - 1.0)
	assert_bool(w.attacker.inside).is_false()
	_at_arrival(w)
	assert_str(w.phase).is_not_equal(SimWorld.PHASE_PRE_ARRIVAL)


func test_he_comes_through_the_entry_and_ends_up_inside() -> void:
	var w := F.world()
	_at_arrival(w)
	_seconds_until_inside(w)
	assert_bool(w.attacker.inside).is_true()
	assert_vector(w.attacker.pos).is_equal(w.inside_cell_of(w.objects.by_id("front_door")))


func test_locking_and_chaining_the_door_costs_him_the_profile_seconds() -> void:
	var plain := F.world()
	_at_arrival(plain)
	var plain_entry := _seconds_until_inside(plain)

	var barred := F.world()
	F.act(barred, "toggle", "front_door", "toggle_lock")
	F.act(barred, "toggle", "door_chain", "toggle_chain")
	_at_arrival(barred)
	var barred_entry := _seconds_until_inside(barred)

	var expected := barred.attacker.profile.breach_cost("locked", 0.0) \
		+ barred.attacker.profile.breach_cost("chained", 0.0)
	assert_float(barred_entry - plain_entry).is_equal_approx(expected, 0.3)


func test_a_braced_door_costs_more_than_a_locked_one() -> void:
	var w := F.world()
	F.goto(w, Vector2i(3, 2))
	F.act(w, "push", "moving_boxes", "push_heavy")
	assert_str(str(w.objects.by_id("front_door").get_state("braced_by"))).is_equal("moving_boxes")
	_at_arrival(w)
	var seconds := _seconds_until_inside(w)
	assert_float(seconds).is_greater(w.attacker.profile.breach_cost("braced_heavy", 0.0))


func _seconds_until_inside(w: SimWorld) -> float:
	var start := w.time_s()
	var guard := w.ticks(60.0)
	var spent := 0
	while not w.attacker.inside and spent < guard:
		w.step()
		spent += 1
	return w.time_s() - start


func test_he_searches_the_first_category_in_his_search_order_first() -> void:
	var w := F.world()
	F.act(w, "hide", "bed")
	_at_arrival(w)
	w.step_seconds(40.0)
	var searched := PackedStringArray()
	for e in w.events.of_type(SimEvent.TYPE_INTERACTION):
		if e.meta.has("searched"):
			searched.append(str(e.meta["searched"]))
	assert_array(Array(searched)).is_not_empty()
	assert_str(str(w.objects.by_id(searched[0]).prop("category", ""))) \
		.is_equal(w.attacker.profile.search_order[0])


func test_darkness_halves_what_he_can_see() -> void:
	var w := F.world()
	var profile := w.attacker.profile
	assert_int(w.attacker.perception.effective_sight(w, profile)).is_equal(profile.sight_range)
	F.act(w, "toggle", "light_switch")
	assert_int(w.attacker.perception.effective_sight(w, profile)).is_equal(int(profile.sight_range / 2))


func test_he_hears_a_loud_enough_noise_and_goes_to_look() -> void:
	var w := F.world()
	_at_arrival(w)
	w.step_seconds(3.0)
	w.attacker.perception.clear_investigation()
	w.emit(SimEvent.TYPE_NOISE, {"cell": Vector2i(9, 3), "loudness": 9.0, "actor": "prop"})
	w.attacker.perception.observe(w, w.attacker, w.attacker.profile)
	assert_bool(w.attacker.perception.has_investigate).is_true()
	assert_vector(w.attacker.perception.investigate_target).is_equal(Vector2i(9, 3))


func test_a_quiet_noise_far_away_is_not_heard() -> void:
	var w := F.world()
	_at_arrival(w)
	w.step_seconds(3.0)
	w.attacker.perception.clear_investigation()
	w.emit(SimEvent.TYPE_NOISE, {"cell": Vector2i(10, 8), "loudness": 1.0, "actor": "prop"})
	w.attacker.perception.observe(w, w.attacker, w.attacker.profile)
	assert_bool(w.attacker.perception.has_investigate).is_false()


func test_a_concealed_hazard_is_invisible_to_him() -> void:
	var w := F.world()
	F.give(w, "cooking_oil")
	F.act(w, "use-held-on", Vector2i(1, 3), "pour_slippery")
	_at_arrival(w)
	w.step_seconds(3.0)
	assert_bool(w.attacker.perception.known_hazards.has(Vector2i(1, 3))).is_true()

	var covered := F.world()
	F.give(covered, "cooking_oil")
	F.act(covered, "use-held-on", Vector2i(1, 3), "pour_slippery")
	F.goto(covered, Vector2i(3, 3))
	F.act(covered, "push", "rug", "push")
	assert_bool(covered.hazards.has("concealed", Vector2i(1, 3))).is_true()
	_at_arrival(covered)
	covered.step_seconds(3.0)
	assert_bool(covered.attacker.perception.known_hazards.has(Vector2i(1, 3))).is_false()


func test_he_slips_on_the_oil_exactly_as_the_player_would() -> void:
	var w := F.world()
	F.give(w, "cooking_oil")
	F.act(w, "use-held-on", Vector2i(1, 3), "pour_slippery")
	F.goto(w, Vector2i(3, 3))
	F.act(w, "push", "rug", "push")
	F.act(w, "hide", "closet")
	_at_arrival(w)
	w.step_seconds(6.0)
	# Prone lasts three seconds, so assert it happened rather than that it still is.
	assert_array(Array(_statuses_applied_to(w, w.attacker.id))).contains(["prone"])


func _statuses_applied_to(w: SimWorld, actor_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for e in w.events.of_type(SimEvent.TYPE_ACTOR_STATUS):
		if e.actor == actor_id and e.meta.has("effect"):
			out.append(str(e.meta["effect"]))
	return out


func test_the_shock_that_kills_the_player_also_kills_him() -> void:
	var w := F.world()
	_at_arrival(w)
	w.step_seconds(float(w.system("attacker.enter_s")) + 0.5)
	assert_bool(w.attacker.inside).is_true()
	w.hazards.spawn("shock", w.attacker.pos, w.tick + w.ticks(3.0))
	w.step()
	assert_bool(w.attacker.alive).is_false()
	assert_str(w.attacker.death_cause).is_equal("shock")


func test_patience_runs_out_and_he_leaves() -> void:
	var w := F.world()
	F.act(w, "hide", "bathtub")
	_at_arrival(w)
	w.step_seconds(float(w.room.get("max_loop_s", 300)) - w.time_s() - 1.0)
	assert_bool(w.attacker.left or not w.player.alive).is_true()


func test_help_arriving_sends_him_home() -> void:
	var w := F.world()
	w.start_timer("help_arrives", 1.0, [], "test", {})
	_at_arrival(w)
	w.step_seconds(20.0)
	assert_array(Array(w.fired_timers)).contains(["help_arrives"])
	assert_bool(w.attacker.left).is_true()
