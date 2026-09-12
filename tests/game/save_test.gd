extends GdUnitTestSuite

## Between loops, only knowledge persists. This is that knowledge.

const F := preload("res://tests/support/sim_fixture.gd")


func _finished_world() -> SimWorld:
	var w := F.world()
	F.act(w, "inspect", "toaster")
	F.act(w, "hide", "closet")
	var guard := w.ticks(float(w.room.get("max_loop_s", 300)))
	while w.ending.is_empty() and w.tick < guard:
		w.step()
	return w


func test_a_new_room_entry_starts_empty() -> void:
	var save := SaveData.new()
	save.data = {"schema": SaveData.SCHEMA, "rooms": {}, "settings": {}}
	var entry := save.room("room_01_studio")
	assert_int(int(entry["loops_total"])).is_equal(0)
	assert_int(int(entry["stars"])).is_equal(0)
	assert_array(entry["notebook"]).is_empty()


func test_a_loop_is_folded_into_the_record() -> void:
	var save := SaveData.new()
	save.data = {"schema": SaveData.SCHEMA, "rooms": {}, "settings": {}}
	var w := _finished_world()
	save.record_loop("room_01_studio", w, SimOutcome.evaluate(w, 1), 1)
	var entry := save.room("room_01_studio")
	assert_int(int(entry["loops_total"])).is_equal(1)
	assert_array(entry["interactions_done"]).contains(["inspect|toaster"])
	assert_array(entry["deaths"]).is_not_empty()
	assert_array(entry["notebook"]).is_not_empty()
	assert_array(entry["attacker_notes"]).is_not_empty()


func test_two_loops_union_rather_than_overwrite() -> void:
	var save := SaveData.new()
	save.data = {"schema": SaveData.SCHEMA, "rooms": {}, "settings": {}}
	for loop in [1, 2]:
		var w := _finished_world()
		save.record_loop("room_01_studio", w, SimOutcome.evaluate(w, loop), loop)
	var entry := save.room("room_01_studio")
	assert_int(int(entry["loops_total"])).is_equal(2)
	assert_int((entry["notebook"] as Array).size()).is_equal(2)
	# The same death twice is still one way to die.
	assert_int((entry["deaths"] as Array).size()).is_equal(1)


func test_stars_only_ever_go_up() -> void:
	var save := SaveData.new()
	save.data = {"schema": SaveData.SCHEMA, "rooms": {}, "settings": {}}
	var w := _finished_world()
	save.record_loop("room_01_studio", w, {"stars": 3, "won": true, "time_s": 1.0,
		"notebook": "", "completion": {"discoveries": [], "deaths": [], "collectible": []}}, 4)
	save.record_loop("room_01_studio", w, {"stars": 1, "won": true, "time_s": 1.0,
		"notebook": "", "completion": {"discoveries": [], "deaths": [], "collectible": []}}, 9)
	var entry := save.room("room_01_studio")
	assert_int(int(entry["stars"])).is_equal(3)
	assert_int(int(entry["best_loop_count"])).is_equal(4)


func test_an_unknown_schema_does_not_crash_the_game() -> void:
	var save := SaveData.new()
	var migrated := save._migrate({"schema": 99, "rooms": {"x": {}}})
	assert_int(int(migrated["schema"])).is_equal(SaveData.SCHEMA)
	assert_dict(migrated["rooms"]).is_empty()
