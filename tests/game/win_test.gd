extends GdUnitTestSuite

## The win screen, rebuilt from Claude Design's turn-1 spec (docs/ui/SPEC.md).
##
## The endings row is the whole pitch: four discs, the ones you have found lit
## and named, the ones you have not as unnamed silhouettes. It says "there are
## three other ways out of this room" without a word of copy, which is the one
## thing the old screen — a paragraph of text — could not do.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _report(overrides: Dictionary = {}) -> Dictionary:
	var report := {
		"ending": SimOutcome.ENDING_DISABLE,
		"stars": 2,
		"time_s": 77.6,
		"notebook": "The toaster had been waiting for this.",
		"completion": {
			"interactions_possible": 38,
			"discoveries_possible": ["a", "b", "c", "d", "e", "f", "g", "h", "i"],
		},
	}
	for key in overrides:
		report[key] = overrides[key]
	return report


func _entry(overrides: Dictionary = {}) -> Dictionary:
	var entry := {
		"endings_found": [SimOutcome.ENDING_DISABLE],
		"interactions_done": [], "discoveries": ["a", "b", "c"], "deaths": ["x", "y"],
		"collectible": [], "notebook": [], "attacker_notes": [],
	}
	for key in overrides:
		entry[key] = overrides[key]
	return entry


func _shown(report: Dictionary = {}, entry: Dictionary = {}, loop_index := 8,
		v: GameVisuals = null) -> WinScreen:
	var screen: WinScreen = auto_free(WinScreen.new())
	screen.setup(v if v != null else _visuals())
	screen.show_result(report if not report.is_empty() else _report(),
		entry if not entry.is_empty() else _entry(), loop_index)
	screen.advance(5.0)
	return screen


# --- the table ---------------------------------------------------------------

func test_the_table_carries_every_number_the_win_screen_reads() -> void:
	var v := _visuals()
	var missing := PackedStringArray()
	for key in WinScreen.REQUIRED_KEYS:
		if v.get_value("win." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing win keys: %s" % [missing]).is_empty()


func test_every_ending_has_an_icon_on_disk() -> void:
	var v := _visuals()
	var missing := PackedStringArray()
	for ending in WinScreen.ENDINGS:
		var path: String = v.get_value("win.ending_icon_path", "") % ending
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_array(Array(missing)).override_failure_message(
		"endings with no icon: %s" % [missing]).is_empty()


# --- stars and the headline --------------------------------------------------

func test_three_stars_are_always_drawn_and_only_some_are_earned() -> void:
	for earned in [1, 2, 3]:
		var screen := _shown(_report({"stars": earned}))
		var stars := screen.stars()
		assert_int(stars.size()).override_failure_message(
			"an unearned star still has to be on screen — it is the ask").is_equal(3)
		var lit := 0
		for star in stars:
			if bool((star as Dictionary)["earned"]):
				lit += 1
		assert_int(lit).is_equal(earned)


func test_the_headline_is_the_ending_you_got() -> void:
	assert_str(_shown().headline()).is_equal("DISABLE")


func test_the_run_line_carries_the_deaths_and_the_clock() -> void:
	var line := _shown(_report(), _entry(), 8).run_line()
	assert_str(line).contains("7")
	assert_str(line).contains("77.6")


# --- the endings row: the pitch ----------------------------------------------

func test_all_four_endings_are_shown_in_a_fixed_order() -> void:
	var cells := _shown().ending_cells()
	assert_int(cells.size()).is_equal(4)
	var order := PackedStringArray()
	for cell in cells:
		order.append(str((cell as Dictionary)["ending"]))
	assert_array(Array(order)).is_equal(
		[SimOutcome.ENDING_EVADE, SimOutcome.ENDING_DISABLE, SimOutcome.ENDING_KILL,
		SimOutcome.ENDING_ESCAPE])


func test_an_unfound_ending_is_a_silhouette_with_no_name() -> void:
	var cells := _shown().ending_cells()
	for cell in cells:
		var found := bool((cell as Dictionary)["found"])
		var label := str((cell as Dictionary)["label"])
		if found:
			assert_str(label).override_failure_message(
				"a found ending should be named").is_not_empty()
		else:
			assert_str(label).override_failure_message(
				"an unfound ending named itself and gave the puzzle away: '%s'" % label).is_empty()


func test_finding_one_lights_it_and_nothing_else() -> void:
	var cells := _shown(_report(), _entry({"endings_found": [SimOutcome.ENDING_KILL]})).ending_cells()
	var lit := PackedStringArray()
	for cell in cells:
		if bool((cell as Dictionary)["found"]):
			lit.append(str((cell as Dictionary)["ending"]))
	assert_array(Array(lit)).is_equal([SimOutcome.ENDING_KILL])


func test_each_disc_is_big_enough_to_read_across_a_room() -> void:
	var v := _visuals()
	for cell in _shown().ending_cells():
		assert_float((cell["rect"] as Rect2).size.x).is_equal_approx(
			v.number("win.ending_disc_size"), 1.0)


# --- the numbers -------------------------------------------------------------

func test_the_stats_are_the_four_the_spec_names() -> void:
	var stats := _shown().stats()
	var labels := PackedStringArray()
	for stat in stats:
		labels.append(str((stat as Dictionary)["label"]))
	assert_array(Array(labels)).is_equal(
		["INTERACTIONS", "DISCOVERIES", "WAYS TO DIE", "COLLECTIBLE"])


func test_the_numbers_come_from_the_run_not_from_thin_air() -> void:
	var stats := _shown(_report(), _entry({
		"interactions_done": ["inspect|fridge", "grab|lighter"], "discoveries": ["a"],
		"deaths": ["x", "y", "z"], "collectible": [],
	})).stats()
	assert_str(str((stats[0] as Dictionary)["value"])).is_equal("2 / 38")
	assert_str(str((stats[1] as Dictionary)["value"])).is_equal("1 / 9")
	assert_str(str((stats[2] as Dictionary)["value"])).is_equal("3")
	assert_str(str((stats[3] as Dictionary)["value"]).to_lower()).contains("not found")


func test_the_completion_bar_is_as_long_as_the_number_says() -> void:
	var screen := _shown(_report(), _entry({
		"interactions_done": [], "discoveries": [], "deaths": [], "collectible": [],
	}))
	assert_float(screen.completion_percent()).is_equal_approx(0.0, 0.01)
	assert_float(screen.completion_bar_rect().size.x).is_equal_approx(0.0, 0.01)
	var half := _shown(_report({"completion": {
		"interactions_possible": 10, "discoveries_possible": [],
	}}), _entry({"interactions_done": ["a|b", "c|d", "e|f", "g|h", "i|j"], "discoveries": [],
		"deaths": [], "collectible": []}))
	assert_float(half.completion_percent()).is_equal_approx(50.0, 0.01)
	assert_float(half.completion_bar_rect().size.x).is_equal_approx(
		half.completion_track_rect().size.x * 0.5, 1.0)


# --- the buttons -------------------------------------------------------------

func test_replay_is_a_button_a_thumb_can_hit_and_it_replays() -> void:
	var screen := _shown()
	var box := screen.button_rect("replay")
	assert_float(box.size.y).is_greater_equal(_visuals().number("wheel.min_touch_target"))
	var watcher := monitor_signals(screen)
	assert_bool(screen.press_at(box.get_center())).is_true()
	await assert_signal(watcher).is_emitted("replay_pressed")


func test_next_room_is_visibly_not_ready_and_does_nothing() -> void:
	var screen := _shown()
	assert_bool(screen.button_enabled("next")).override_failure_message(
		"Room 2 does not exist yet; the button must say so").is_false()
	var watcher := monitor_signals(screen)
	screen.press_at(screen.button_rect("next").get_center())
	await assert_signal(watcher).is_not_emitted("replay_pressed")
	assert_bool(screen.is_open()).is_true()


# --- the panel ---------------------------------------------------------------

func test_the_panel_stays_on_screen_and_out_of_the_safe_area() -> void:
	var v := _visuals()
	v.safe = {"left": 90.0, "top": 30.0, "right": 90.0, "bottom": 40.0}
	var screen := _shown({}, {}, 8, v)
	var box := screen.panel_rect()
	assert_float(box.position.x).is_greater_equal(90.0)
	assert_float(box.end.x).is_less_equal(v.number("ui.design_width") - 90.0)
	assert_float(box.end.y).override_failure_message(
		"the panel runs off the bottom: %s" % [box]).is_less_equal(v.number("ui.design_height") - 40.0)


## It arrives after the ending has been named, not on top of it.
func test_it_waits_for_the_banner_before_it_appears() -> void:
	var screen: WinScreen = auto_free(WinScreen.new())
	screen.setup(_visuals())
	screen.show_result(_report(), _entry(), 8)
	assert_float(screen.reveal()).override_failure_message(
		"the win screen landed on the same frame as the ending banner").is_equal_approx(0.0, 0.001)
	screen.advance(_visuals().number("win.open_delay_s") + _visuals().number("win.open_in_s") + 0.05)
	assert_float(screen.reveal()).is_equal_approx(1.0, 0.001)


## Both panels animate on real seconds while the sim is stopped, so something
## has to drive them.
func test_the_game_advances_the_panels() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	for call in ["_win.advance(delta)", "_notebook.advance(delta)"]:
		assert_str(source).override_failure_message(
			"nothing calls %s, so it will never finish opening" % call).contains(call)
