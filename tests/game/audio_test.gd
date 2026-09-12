extends GdUnitTestSuite

## The attacker has to be findable by ear. That means every cue the map names
## must exist, and his footsteps must fire while yours stay silent.

const F := preload("res://tests/support/sim_fixture.gd")


func _director() -> AudioDirector:
	var director: AudioDirector = auto_free(AudioDirector.new())
	director.setup()
	return director


func _event(type: String, fields: Dictionary) -> SimEvent:
	return SimEvent.make(0, type, fields)


func test_the_map_loads_and_names_only_cues_that_exist() -> void:
	var director := _director()
	assert_dict(director.map).is_not_empty()
	var cues: Dictionary = director.map["cues"]
	assert_int(cues.size()).is_greater(5)
	for rule in director.map["events"]:
		assert_bool(cues.has(str((rule as Dictionary).get("cue", "")))) \
			.override_failure_message("event rule names a cue that does not exist: %s" % [rule]).is_true()
	# `cue` is deliberately absent — the clock is silent until the last ten
	# seconds. Whichever cues the metronome does name must exist.
	var metronome: Dictionary = director.map["metronome"]
	for key in ["cue", "urgent_cue"]:
		if not metronome.has(key):
			continue
		assert_bool(cues.has(str(metronome[key]))) \
			.override_failure_message("metronome.%s names a cue that does not exist" % key).is_true()
	assert_bool(metronome.has("urgent_cue")).is_true()


func test_every_cue_synthesises_to_real_audio() -> void:
	var director := _director()
	for name in (director.map["cues"] as Dictionary):
		var stream: AudioStreamWAV = director._streams[name]
		assert_object(stream).override_failure_message("cue %s did not synthesise" % name).is_not_null()
		assert_int(stream.data.size()).override_failure_message("cue %s is silent" % name).is_greater(0)


func test_his_footsteps_make_a_sound_and_yours_do_not() -> void:
	var director := _director()
	var his := director._match(_event(SimEvent.TYPE_ACTOR_MOVE, {"actor": "tenant_knife", "cell": Vector2i(1, 2)}))
	assert_str(str(his.get("cue", ""))).is_equal("footstep")
	var mine := director._match(_event(SimEvent.TYPE_ACTOR_MOVE, {"actor": "player", "cell": Vector2i(6, 5)}))
	assert_dict(mine).is_empty()


func test_the_information_bearing_cues_all_match() -> void:
	var director := _director()
	var cases := {
		"door": _event(SimEvent.TYPE_TIMER, {"meta": {"arrival": true}}),
		"breach": _event(SimEvent.TYPE_STATE_CHANGE, {"meta": {"breached": true}}),
		"search": _event(SimEvent.TYPE_INTERACTION, {"meta": {"searched": "closet"}}),
		"spark": _event(SimEvent.TYPE_HAZARD_SPAWN, {"meta": {"layer": "shock"}}),
		"death": _event(SimEvent.TYPE_DEATH, {"actor": "player"}),
	}
	for expected in cases:
		assert_str(str(director._match(cases[expected]).get("cue", ""))) \
			.override_failure_message("no cue for %s" % expected).is_equal(expected)


func test_a_louder_noise_picks_a_louder_cue() -> void:
	var director := _director()
	var quiet := director._match(_event(SimEvent.TYPE_NOISE, {"loudness": 1.0, "cell": Vector2i.ZERO}))
	var loud := director._match(_event(SimEvent.TYPE_NOISE, {"loudness": 6.0, "cell": Vector2i.ZERO}))
	assert_str(str(quiet.get("cue", ""))).is_not_equal(str(loud.get("cue", "")))


func test_a_real_loop_makes_noise() -> void:
	var director := _director()
	var w := F.world()
	director.listen(w)
	F.act(w, "toggle", "sink", "toggle_wet_source")
	w.step_seconds(w.timer_remaining_s() + 10.0)
	assert_int(director.played).override_failure_message("a whole loop was silent").is_greater(10)
