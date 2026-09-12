extends GdUnitTestSuite

## Same room + same intents + same seed = the same event log, every time.
## Any failure here is a P0 bug: the solver and every room test depend on it.

const F := preload("res://tests/support/sim_fixture.gd")


func _scripted_loop(seed_value: int) -> SimWorld:
	var w := F.world("room_01_studio", seed_value)
	F.act(w, "toggle", "sink", "toggle_wet_source")
	F.act(w, "grab", "toaster")
	F.act(w, "toggle", "light_switch")
	F.goto(w, Vector2i(5, 4))
	w.step_seconds(60.0)
	F.act(w, "throw", Vector2i(3, 2), "throw_conductive_into_wet")
	w.step_seconds(5.0)
	return w


func test_the_same_seed_produces_the_same_event_log() -> void:
	var a := _scripted_loop(1)
	var b := _scripted_loop(1)
	assert_int(a.events.to_lines().size()).is_greater(20)
	assert_array(Array(a.events.to_lines())).is_equal(Array(b.events.to_lines()))


func test_the_same_seed_produces_the_same_state_hash() -> void:
	var a := _scripted_loop(1)
	var b := _scripted_loop(1)
	assert_int(a.snapshot_hash()).is_equal(b.snapshot_hash())


func test_the_state_hash_moves_when_the_state_does() -> void:
	var w := F.world()
	var before := w.snapshot_hash()
	F.act(w, "toggle", "light_switch")
	assert_int(w.snapshot_hash()).is_not_equal(before)


func test_pathing_and_spread_do_not_drift_over_a_long_run() -> void:
	var a := F.world("room_01_studio", 7)
	var b := F.world("room_01_studio", 7)
	for w in [a, b]:
		F.act(w, "toggle", "sink", "toggle_wet_source")
		w.step_seconds(float(w.room["timer_s"]))
	assert_array(a.hazards.cells("wet")).is_equal(b.hazards.cells("wet"))
	assert_int(a.snapshot_hash()).is_equal(b.snapshot_hash())
