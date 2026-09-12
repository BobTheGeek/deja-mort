extends GdUnitTestSuite

## Room 1 through the solver, as spec §14 asks for. Mode B is left to the CLI —
## it takes about eighty seconds, which does not belong in a unit suite.

const ROOM := "res://content/rooms/room_01_studio.json"
const REPORT := "res://content/rooms/room_01_studio.solver.json"


func _solver() -> SimSolver:
	var s := SimSolver.new()
	s.verbose = false
	assert_bool(s.load_room(ROOM)).is_true()
	return s


func test_every_authored_solution_still_wins() -> void:
	var result := _solver().mode_a()
	assert_bool(bool(result["ok"])).is_true()
	for entry in result["solutions"]:
		assert_bool(bool(entry["passed"])) \
			.override_failure_message("%s: got %s/%d, declared %s/%d" % [
				entry["id"], entry["ending"], int(entry["stars"]),
				entry["declared_ending"], int(entry["declared_stars"])]).is_true()


func test_the_three_endings_score_one_two_and_three_stars() -> void:
	var by_id := {}
	for entry in _solver().mode_a()["solutions"]:
		by_id[str(entry["id"])] = entry
	assert_int(int(by_id["evade_phone"]["stars"])).is_equal(1)
	assert_int(int(by_id["disable_shelf"]["stars"])).is_equal(2)
	assert_int(int(by_id["kill_toaster"]["stars"])).is_equal(3)
	assert_str(str(by_id["evade_phone"]["ending"])).is_equal("evade")
	assert_str(str(by_id["disable_shelf"]["ending"])).is_equal("disable")
	assert_str(str(by_id["kill_toaster"]["ending"])).is_equal("kill")


func test_mode_a_is_deterministic() -> void:
	var first := _solver().mode_a()
	var second := _solver().mode_a()
	assert_str(JSON.stringify(first, "", true)).is_equal(JSON.stringify(second, "", true))


func test_mode_c_reaches_at_least_ten_ways_to_die() -> void:
	var deaths := _solver().mode_c()
	assert_int((deaths["causes"] as Array).size()).is_greater_equal(10)


func test_mode_c_is_deterministic() -> void:
	assert_str(JSON.stringify(_solver().mode_c(), "", true)) \
		.is_equal(JSON.stringify(_solver().mode_c(), "", true))


## The committed report is the difficulty baseline. If a rule change moves the
## room, this fails and the report has to be regenerated in the same PR.
func test_the_committed_solver_report_still_matches_the_room() -> void:
	assert_bool(FileAccess.file_exists(REPORT)).is_true()
	var json := JSON.new()
	assert_int(json.parse(FileAccess.get_file_as_string(REPORT))).is_equal(OK)
	var committed: Dictionary = json.data
	var fresh: Array = _solver().mode_a()["solutions"]
	assert_int((committed["authored"] as Array).size()).is_equal(fresh.size())
	for i in fresh.size():
		var was: Dictionary = committed["authored"][i]
		var now: Dictionary = fresh[i]
		assert_str(str(now["id"])).is_equal(str(was["id"]))
		assert_str(str(now["ending"])).is_equal(str(was["ending"]))
		assert_int(int(now["stars"])).is_equal(int(was["stars"]))
		assert_float(float(now["tightness_s"])).is_equal_approx(float(was["tightness_s"]), 0.2)
