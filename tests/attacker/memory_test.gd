extends GdUnitTestSuite

## `notice` and `full` are implemented now and unit tested now; only `none` is
## wired into Room 1. Memory never names a room or an object.

const F := preload("res://tests/support/sim_fixture.gd")


func _with_memory(mode: String, prior_loops: Array = []) -> SimWorld:
	var room := F.room_data()
	room["prior_loops"] = prior_loops
	var w := SimWorld.create(room, F.content(), SimRng.new(1))
	w.attacker.profile.memory = mode
	w.attacker.memory.configure(w.attacker.profile, prior_loops)
	return w


func test_none_forgets_everything() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_NONE)
	F.goto(w, Vector2i(3, 3))
	F.act(w, "push", "rug", "push")
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_array(Array(w.attacker.memory.search_order)) \
		.is_equal(Array(w.attacker.profile.search_order))
	assert_int(w.attacker.memory.avoid_cells.size()).is_equal(0)


func test_notice_looks_near_whatever_has_been_moved() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_NOTICE)
	assert_str(w.attacker.memory.search_order[0]).is_equal("closet")
	F.goto(w, Vector2i(3, 2))
	F.act(w, "push", "fridge", "push_heavy")
	w.attacker.memory.on_arrival(w, w.attacker)
	# The fridge now sits two cells from nothing that hides a person, so the
	# order is unchanged — but the machinery ran and produced a full ordering.
	assert_int(w.attacker.memory.search_order.size()) \
		.is_equal(w.attacker.profile.search_order.size())


func test_notice_promotes_a_hiding_spot_next_to_something_that_moved() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_NOTICE)
	var basket := w.objects.by_id("laundry_basket")
	w.objects.translate(basket, Vector2i(-1, 0))
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_str(w.attacker.memory.search_order[0]).is_equal("behind_furniture")


func test_notice_stays_out_from_under_a_leaning_shelf() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_NOTICE)
	F.goto(w, Vector2i(1, 7))
	F.act(w, "push", "bookshelf", "tip_first")
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_float(w.attacker.memory.extra_path_cost(Vector2i(1, 3))).is_greater(0.0)
	assert_float(w.attacker.memory.extra_path_cost(Vector2i(1, 4))).is_greater(0.0)


func test_full_searches_where_you_hid_last_time_first() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_FULL, [
		{"hidden_in": "bathtub", "trap_cells": [], "death_cause": "", "player_pos_at_arrival": [0, 0]},
	])
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_str(w.attacker.memory.search_order[0]).is_equal("bathroom")


func test_full_avoids_the_cell_that_killed_him() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_FULL, [
		{"hidden_in": "", "trap_cells": [[1, 3]], "death_cause": "slippery", "player_pos_at_arrival": [0, 0]},
	])
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_float(w.attacker.memory.extra_path_cost(Vector2i(1, 3))).is_greater(0.0)


func test_full_avoids_water_after_being_electrocuted() -> void:
	var w := _with_memory(SimAttackerMemory.MODE_FULL, [
		{"hidden_in": "", "trap_cells": [], "death_cause": "shock", "player_pos_at_arrival": [0, 0]},
	])
	F.act(w, "toggle", "sink", "toggle_wet_source")
	w.step_seconds(40.0)
	w.attacker.memory.on_arrival(w, w.attacker)
	assert_int(w.attacker.memory.avoid_cells.size()).is_greater(0)
	assert_float(w.attacker.memory.extra_path_cost(w.hazards.cells("wet")[0])).is_greater(0.0)


func test_a_loop_record_is_what_the_next_loop_reads() -> void:
	var w := F.world()
	F.act(w, "hide", "closet")
	w.step_seconds(w.timer_remaining_s())
	var record := SimAttackerMemory.record_loop(w)
	assert_str(str(record["hidden_in"])).is_equal("closet")
	assert_array(Array(record.keys())).contains(["trap_cells", "death_cause", "player_pos_at_arrival"])
