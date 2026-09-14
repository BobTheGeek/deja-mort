extends GdUnitTestSuite

## A recording of a play session, so a playtest report can be read rather than
## guessed at.
##
## Bob's last two reports were "some things I clicked had no action" and "the
## deaths counter looked like the old one". The first took a probe to reproduce
## and the second is still unresolved. Both would have been one line in a log.
##
## What it records is what the player did and what the game did back: every tap
## with what it resolved to, every intent with whether the sim accepted it, every
## event off the bus, and how each loop ended. It decides nothing and it is off
## unless the build says otherwise.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _log() -> SessionLog:
	var log := SessionLog.new()
	log.start("res://__test_session.jsonl")
	return log


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://__test_session.jsonl"))


# --- writing -----------------------------------------------------------------

func test_every_record_is_one_line_of_json() -> void:
	var log := _log()
	log.click(Vector2(100, 200), Vector2i(2, 1), "toaster")
	log.intent("grab", "toaster", "grab_small", true)
	log.close()
	var lines := log.read_back()
	assert_int(lines.size()).is_equal(2)
	for line in lines:
		var parsed := JSON.new()
		assert_int(parsed.parse(str(line))).override_failure_message(
			"not JSON: %s" % line).is_equal(OK)


func test_a_tap_records_what_it_resolved_to() -> void:
	var log := _log()
	log.click(Vector2(100, 200), Vector2i(2, 1), "toaster")
	log.close()
	var record: Dictionary = log.records()[0]
	assert_str(str(record["kind"])).is_equal("click")
	assert_str(str(record["picked"])).is_equal("toaster")
	# JSON has one number type, so these come back as floats.
	assert_int(int((record["cell"] as Array)[0])).is_equal(2)
	assert_int(int((record["cell"] as Array)[1])).is_equal(1)
	assert_int(int((record["screen"] as Array)[0])).is_equal(100)
	assert_int(int((record["screen"] as Array)[1])).is_equal(200)


## The interesting taps are the ones that resolved to nothing at all.
func test_a_tap_that_found_nothing_says_so() -> void:
	var log := _log()
	log.click(Vector2(10, 10), Vector2i(6, 5), "")
	log.close()
	assert_str(str(log.records()[0]["picked"])).is_empty()


func test_an_intent_records_whether_the_sim_took_it() -> void:
	var log := _log()
	log.intent("grab", "glass_jar", "", false)
	log.close()
	var record: Dictionary = log.records()[0]
	assert_bool(bool(record["accepted"])).is_false()
	assert_str(str(record["verb"])).is_equal("grab")


func test_events_off_the_bus_are_recorded() -> void:
	var world := F.world()
	var log := _log()
	log.listen(world)
	assert_bool(F.act(world, "inspect", "fridge")).is_true()
	log.close()
	var kinds := PackedStringArray()
	for entry in log.records():
		kinds.append(str((entry as Dictionary)["kind"]))
	assert_bool(kinds.has("event")).override_failure_message(
		"nothing from the event bus reached the log").is_true()


func test_a_loop_records_how_it_ended() -> void:
	var log := _log()
	log.loop_started(3)
	log.loop_ended("loss", 2, 75.0)
	log.close()
	var last: Dictionary = log.records()[1]
	assert_str(str(last["ending"])).is_equal("loss")
	assert_int(int(last["loop"])).is_equal(3)


# --- reading it back ---------------------------------------------------------

## The point of the log is the summary, which is what I read.
func test_the_summary_counts_what_happened() -> void:
	var records: Array = [
		{"kind": "loop_started", "loop": 1, "t": 0.0},
		{"kind": "click", "loop": 1, "picked": "toaster", "cell": [2, 1]},
		{"kind": "intent", "loop": 1, "verb": "grab", "target": "toaster", "accepted": true},
		{"kind": "click", "loop": 1, "picked": "", "cell": [6, 5]},
		{"kind": "intent", "loop": 1, "verb": "throw", "target": "toaster", "accepted": false},
		{"kind": "intent", "loop": 1, "verb": "throw", "target": "toaster", "accepted": false},
		{"kind": "loop_ended", "loop": 1, "ending": "loss", "stars": 0, "time_s": 75.0},
	]
	var summary := SessionLog.summarise(records)
	assert_int(int(summary["loops"])).is_equal(1)
	assert_int(int(summary["taps"])).is_equal(2)
	assert_int(int(summary["taps_on_nothing"])).override_failure_message(
		"a tap that resolved to nothing is the one worth counting").is_equal(1)
	assert_int(int(summary["refused"])).is_equal(2)
	assert_array(summary["endings"]).is_equal(["loss"])


## The same refusal over and over is a player fighting the game.
func test_the_summary_names_a_refusal_that_keeps_happening() -> void:
	var records: Array = []
	for i in 4:
		records.append({"kind": "intent", "loop": 1, "verb": "grab", "target": "glass_jar",
			"accepted": false})
	var repeated: Array = SessionLog.summarise(records)["repeated_refusals"]
	assert_int(repeated.size()).is_greater(0)
	assert_str(str((repeated[0] as Dictionary)["what"])).contains("glass_jar")
	assert_int(int((repeated[0] as Dictionary)["times"])).is_equal(4)


func test_a_quiet_session_reports_nothing_alarming() -> void:
	var summary := SessionLog.summarise([
		{"kind": "click", "loop": 1, "picked": "toaster", "cell": [2, 1]},
		{"kind": "intent", "loop": 1, "verb": "grab", "target": "toaster", "accepted": true},
	])
	assert_int(int(summary["taps_on_nothing"])).is_equal(0)
	assert_array(summary["repeated_refusals"]).is_empty()


# --- when it is on -----------------------------------------------------------

func test_it_is_on_for_a_debug_build_and_off_for_a_shipped_one() -> void:
	var v := GameVisuals.load_table()
	assert_bool(v.flag("log.session", false)).override_failure_message(
		"the log is switched off in data, so a playtest records nothing").is_true()
	assert_bool(SessionLog.wanted(v, false)).override_failure_message(
		"a shipped build should not be writing a log of the player's session").is_false()
	assert_bool(SessionLog.wanted(v, true)).is_true()


func test_the_game_records_a_session() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	for call in ["SessionLog", "_log.click(", "_log.intent("]:
		assert_str(source).override_failure_message(
			"main.gd never calls %s" % call).contains(call)


## The first real session flagged three "taps that hit nothing". All three were
## taps on bare floor that walked the player there — which is the game working.
## A tap only means something went wrong when it did not even move him.
func test_a_tap_on_bare_floor_that_walks_is_not_a_failure() -> void:
	var summary := SessionLog.summarise([
		{"kind": "click", "loop": 1, "picked": "", "cell": [5, 4], "t": 1.0},
		{"kind": "walk", "loop": 1, "cell": [5, 4], "accepted": true, "t": 1.0},
	])
	assert_int(int(summary["taps_on_nothing"])).override_failure_message(
		"walking somewhere is what a tap on the floor is for").is_equal(0)
	assert_int(int(summary["walks"])).is_equal(1)


func test_a_tap_that_did_nothing_at_all_still_counts() -> void:
	var summary := SessionLog.summarise([
		{"kind": "click", "loop": 1, "picked": "", "cell": [5, 4], "t": 1.0},
		{"kind": "walk", "loop": 1, "cell": [5, 4], "accepted": false, "t": 1.0},
		{"kind": "click", "loop": 1, "picked": "", "cell": [0, 0], "t": 2.0},
	])
	assert_int(int(summary["taps_on_nothing"])).override_failure_message(
		"a tap that picked nothing and moved nobody is the one worth knowing about") \
		.is_equal(2)


## Whether the hint system gets opened at all is worth knowing.
func test_opening_a_panel_is_recorded() -> void:
	var log := _log()
	log.panel("notebook", true)
	log.close()
	var record: Dictionary = log.records()[0]
	assert_str(str(record["panel"])).is_equal("notebook")
	assert_bool(bool(record["open"])).is_true()


func test_the_summary_counts_panel_opens() -> void:
	var summary := SessionLog.summarise([
		{"kind": "panel", "loop": 1, "panel": "notebook", "open": true},
		{"kind": "panel", "loop": 1, "panel": "notebook", "open": false},
		{"kind": "panel", "loop": 2, "panel": "notebook", "open": true},
	])
	assert_int(int(summary["notebook_opens"])).is_equal(2)


func test_the_game_records_the_notebook_being_opened() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_str(source).override_failure_message(
		"nothing records whether the hint system is ever used").contains("_log.panel(")


## A tap whose ray missed is not a tap that did nothing: it can still open a
## wheel on the square, or on the door behind the wall it hit. Reading the tenth
## playtest, seven of the twenty-two "taps that picked nothing" had opened a
## wheel, which made the report exaggerate to my own face.
##
## So the record carries what the tap actually resolved to.
func test_a_tap_records_what_it_opened_on_not_just_what_the_ray_hit() -> void:
	var log := _log()
	log.click(Vector2(10, 10), Vector2i(0, 2), "", "front_door")
	log.close()
	var record: Dictionary = log.records()[0]
	assert_str(str(record["picked"])).is_empty()
	assert_str(str(record["opened_on"])).is_equal("front_door")


func test_only_a_tap_that_opened_nothing_and_walked_nowhere_counts_as_dead() -> void:
	var opened := SessionLog.summarise([
		{"kind": "click", "picked": "", "opened_on": "front_door", "loop": 1},
	])
	assert_int(int(opened["taps_on_nothing"])).override_failure_message(
		"a tap that opened a wheel was counted as a dead tap").is_equal(0)
	var dead := SessionLog.summarise([
		{"kind": "click", "picked": "", "opened_on": "", "loop": 1},
	])
	assert_int(int(dead["taps_on_nothing"])).is_equal(1)
