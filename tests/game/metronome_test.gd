extends GdUnitTestSuite

## The countdown is silent until the last ten seconds, then it ticks.
##
## This is a change of intent, not a bug fix: docs/01 section 14 and docs/06
## both describe a tick running under the whole loop with a swell at the end.
## Bob asked for silence underneath instead, so the swell arrives out of nothing.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _director() -> AudioDirector:
	var director: AudioDirector = auto_free(AudioDirector.new())
	director.setup()
	return director


## Runs the clock down to `remaining` seconds and counts what the metronome plays.
func _ticks_over(seconds_remaining_from: float, seconds_remaining_to: float) -> int:
	var world := F.world()
	var director := _director()
	world.step_seconds(world.timer_remaining_s() - seconds_remaining_from)
	var before := director.played
	var window := seconds_remaining_from - seconds_remaining_to
	for _i in world.ticks(window):
		world.step()
		director.tick_metronome(world)
	return director.played - before


func test_the_countdown_is_silent_while_there_is_time() -> void:
	assert_int(_ticks_over(60.0, 20.0)).override_failure_message(
		"the clock should not tick with a minute left").is_equal(0)


func test_it_starts_ticking_in_the_last_ten_seconds() -> void:
	assert_int(_ticks_over(9.0, 1.0)).override_failure_message(
		"the last ten seconds should tick").is_greater(0)


func test_the_first_tick_lands_promptly_once_it_starts() -> void:
	var world := F.world()
	var director := _director()
	var urgent_at := float(director.map["metronome"]["urgent_below_s"])
	world.step_seconds(world.timer_remaining_s() - urgent_at + 0.1)
	var before := director.played
	for _i in world.ticks(1.0):
		world.step()
		director.tick_metronome(world)
	assert_int(director.played - before).override_failure_message(
		"crossing into the last ten seconds should be heard at once").is_greater(0)


func test_the_map_no_longer_names_a_resting_tick() -> void:
	var metronome: Dictionary = _director().map["metronome"]
	assert_bool(metronome.has("cue")).override_failure_message(
		"a resting cue means the clock ticks all loop").is_false()
	assert_str(str(metronome.get("urgent_cue", ""))).is_not_empty()


func test_nothing_ticks_once_the_loop_is_over() -> void:
	var world := F.world()
	var director := _director()
	world.step_seconds(world.timer_remaining_s() - 5.0)
	world.kill_actor(world.player, "test", "test")
	world.step()
	var before := director.played
	for _i in world.ticks(3.0):
		director.tick_metronome(world)
	assert_int(director.played - before).override_failure_message(
		"the clock kept ticking after the loop ended").is_equal(0)
