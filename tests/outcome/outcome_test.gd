extends GdUnitTestSuite

## Endings, death causes, the rubric language, completion, and the notebook.

const F := preload("res://tests/support/sim_fixture.gd")


func _run_to_end(w: SimWorld) -> Dictionary:
	var guard := w.ticks(float(w.room.get("max_loop_s", 300)))
	while w.ending.is_empty() and w.tick < guard:
		w.step()
	return SimOutcome.evaluate(w)


# --- endings -----------------------------------------------------------------

func test_a_dead_player_is_a_loss_not_a_win() -> void:
	var w := F.world()
	var report := _run_to_end(w)
	assert_str(str(report["ending"])).is_equal(SimOutcome.ENDING_LOSS)
	assert_bool(bool(report["won"])).is_false()
	assert_int(int(report["stars"])).is_equal(0)


func test_a_dead_attacker_is_a_kill() -> void:
	var w := F.world()
	w.step_seconds(w.timer_remaining_s())
	w.step_seconds(float(w.system("attacker.enter_s")) + 0.5)
	w.kill_actor(w.attacker, "shock", "test")
	w.step()
	assert_str(w.ending).is_equal(SimOutcome.ENDING_KILL)


func test_leaving_is_an_evade() -> void:
	var w := F.world()
	F.act(w, "hide", "bathtub")
	w.start_timer("help_arrives", 1.0, [], "test", {})
	w.step_seconds(w.timer_remaining_s())
	w.step_seconds(30.0)
	assert_str(w.ending).is_equal(SimOutcome.ENDING_EVADE)


func test_holding_him_down_long_enough_is_a_disable() -> void:
	var w := F.world()
	F.act(w, "hide", "bathtub")
	w.step_seconds(w.timer_remaining_s())
	w.step_seconds(3.0)
	w.apply_status(w.attacker, "pinned", 999.0, "test")
	w.step_seconds(float(w.system("disable_hold_s")) + 1.0)
	assert_str(w.ending).is_equal(SimOutcome.ENDING_DISABLE)


func test_an_ending_is_emitted_once() -> void:
	var w := F.world()
	_run_to_end(w)
	w.step_seconds(5.0)
	assert_int(w.events.of_type(SimEvent.TYPE_ENDING).size()).is_equal(1)


# --- death causes ------------------------------------------------------------

func test_a_death_cause_says_where_he_found_you() -> void:
	var w := F.world()
	F.act(w, "hide", "closet")
	_run_to_end(w)
	assert_str(SimOutcome.death_key(w)).is_equal("stabbed@closet")


func test_a_hazard_death_needs_no_context() -> void:
	var w := F.world()
	w.hazards.spawn("shock", w.player.pos, w.tick + w.ticks(3.0))
	w.step()
	assert_str(SimOutcome.death_key(w)).is_equal("shock@electrocuted")


# --- rubric ------------------------------------------------------------------

func test_the_predicate_language_reads_dotted_paths() -> void:
	var context := {"ending": "kill", "attacker.death_cause": "shock", "player.never_seen": true,
		"loop.index": 3, "loop.damage_taken": 0}
	assert_bool(SimPredicate.evaluate("attacker.death_cause == 'shock' && player.never_seen", context)).is_true()
	assert_bool(SimPredicate.evaluate("attacker.death_cause == 'fire'", context)).is_false()
	assert_bool(SimPredicate.evaluate("loop.index <= 6", context)).is_true()
	assert_bool(SimPredicate.evaluate("loop.index > 6", context)).is_false()
	assert_bool(SimPredicate.evaluate("ending != 'evade'", context)).is_true()
	assert_bool(SimPredicate.evaluate("!player.never_seen", context)).is_false()
	assert_bool(SimPredicate.evaluate("(ending == 'evade' || ending == 'kill') && loop.damage_taken == 0", context)).is_true()


func test_a_missing_variable_is_false_not_a_crash() -> void:
	assert_bool(SimPredicate.evaluate("nothing.here == 'x'", {})).is_false()
	assert_bool(SimPredicate.evaluate("nothing.here", {})).is_false()


func test_the_room_rubric_overrides_the_default() -> void:
	var w := F.world()
	assert_str(str((w.room["rubric"] as Dictionary)["two"])).is_equal("ending != 'evade'")
	var context := SimOutcome.build_context(w, SimOutcome.ENDING_EVADE, 1)
	assert_bool(SimPredicate.evaluate(str(w.room["rubric"]["two"]), context)).is_false()


# --- completion --------------------------------------------------------------

func test_completion_counts_what_the_room_can_offer() -> void:
	var w := F.world()
	F.act(w, "inspect", "toaster")
	F.act(w, "toggle", "sink", "toggle_wet_source")
	var done := SimOutcome.completion(w)
	assert_int(int(done["interactions"])).is_equal(2)
	assert_int(int(done["interactions_possible"])).is_greater(60)
	assert_array(Array(done["discoveries_possible"])).contains(["water_and_current", "brace_door", "lights_out"])
	assert_float(float(done["percent"])).is_greater(0.0)


func test_discoveries_are_recorded_once() -> void:
	var w := F.world()
	F.goto(w, Vector2i(3, 2))
	F.act(w, "push", "fridge", "push_heavy")
	assert_array(Array(w.discoveries)).contains(["brace_door"])
	assert_int(w.discoveries.size()).is_equal(1)


# --- notebook ----------------------------------------------------------------

func test_the_notebook_writes_the_line_for_this_death() -> void:
	var w := F.world()
	F.act(w, "hide", "closet")
	_run_to_end(w)
	assert_str(SimOutcome.notebook_line(w, w.ending, SimOutcome.death_key(w))) \
		.is_equal("Hid in the closet. He looked in the closet.")


func test_an_unknown_death_still_gets_a_line() -> void:
	var w := F.world()
	w.kill_actor(w.player, "defenestrated", "test")
	var line := SimOutcome.notebook_line(w, SimOutcome.ENDING_LOSS, SimOutcome.death_key(w))
	assert_str(line).is_not_empty()
	assert_str(line).contains("defenestrated")
