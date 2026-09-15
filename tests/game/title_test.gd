extends GdUnitTestSuite

## The title screen, from Claude Design's turn-1 spec and BRAND.md's opening
## beat: the clock mark ticks once, the wordmark appears, the tagline fades in,
## then the door opens into Room 1.
##
## The delivered lockup is placed, never re-set — the wordmark is Archivo with
## custom-drawn accents and setting it live would be a different wordmark. The
## beat gets the mark alone first and then cross-fades into the lockup files.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _title(save: SaveData = null) -> TitleScreen:
	var screen: TitleScreen = auto_free(TitleScreen.new())
	screen.setup(_visuals(), save if save != null else SaveData.new())
	return screen


func _at(seconds: float, save: SaveData = null) -> TitleScreen:
	var screen := _title(save)
	screen.advance(seconds)
	return screen


# --- the table ---------------------------------------------------------------

func test_the_table_carries_every_number_the_title_reads() -> void:
	var v := _visuals()
	var missing := PackedStringArray()
	for key in TitleScreen.REQUIRED_KEYS:
		if v.get_value("title." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing title keys: %s" % [missing]).is_empty()


func test_the_delivered_lockups_are_on_disk() -> void:
	var v := _visuals()
	for key in ["mark_file", "lockup_file", "lockup_tagline_file"]:
		var path := str(v.get_value("title." + key, ""))
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"%s is not there: %s" % [key, path]).is_true()


# --- the beat ----------------------------------------------------------------

func test_it_opens_on_the_mark_alone() -> void:
	var screen := _at(0.05)
	assert_bool(screen.mark_visible()).is_true()
	assert_float(screen.lockup_alpha()).override_failure_message(
		"the wordmark is on screen before its cue").is_equal_approx(0.0, 0.001)
	assert_float(screen.menu_alpha()).is_equal_approx(0.0, 0.001)


## The hands never move. It is 1:30 and it stays 1:30, so the tick is a scale.
func test_the_tick_is_a_pulse_and_not_a_hand_moving() -> void:
	var v := _visuals()
	var screen := _at(v.number("title.tick_at_s") + v.number("title.tick_duration_s") * 0.5)
	assert_float(screen.mark_scale()).override_failure_message(
		"nothing happened at the tick").is_less(1.0)
	assert_float(screen.mark_scale()).is_greater_equal(v.number("title.tick_scale_min") - 0.001)
	var after := _at(v.number("title.tick_at_s") + v.number("title.tick_duration_s") + 0.05)
	assert_float(after.mark_scale()).override_failure_message(
		"the mark never came back to full size").is_equal_approx(1.0, 0.001)


func test_the_mark_travels_to_where_the_lockup_puts_it() -> void:
	var v := _visuals()
	var start := _at(0.3).mark_rect()
	var landed := _at(v.number("title.wordmark_at_s") + v.number("title.mark_travel_s") + 0.05)
	assert_vector(landed.mark_rect().get_center()).override_failure_message(
		"the mark did not land on the lockup's own mark position") \
		.is_equal_approx(landed.lockup_mark_rect().get_center(), Vector2.ONE)
	assert_float(landed.mark_rect().size.x).is_equal_approx(landed.lockup_mark_rect().size.x, 1.0)
	assert_vector(start.get_center()).is_not_equal(landed.mark_rect().get_center())


func test_the_tagline_arrives_last() -> void:
	var v := _visuals()
	var before := _at(v.number("title.tagline_at_s") - 0.05)
	assert_float(before.tagline_alpha()).is_equal_approx(0.0, 0.001)
	assert_float(before.lockup_alpha()).override_failure_message(
		"the lockup should already be up before the tagline").is_greater(0.9)
	var after := _at(v.number("title.tagline_at_s") + v.number("title.tagline_fade_s") + 0.05)
	assert_float(after.tagline_alpha()).is_equal_approx(1.0, 0.001)


func test_the_menu_is_last_of_all() -> void:
	var v := _visuals()
	assert_float(_at(v.number("title.menu_at_s") - 0.05).menu_alpha()).is_equal_approx(0.0, 0.001)
	assert_float(_at(v.number("title.menu_at_s") + v.number("title.menu_fade_s") + 0.05).menu_alpha()) \
		.is_equal_approx(1.0, 0.001)


## Nobody watches an opening twice.
func test_any_input_skips_to_the_end() -> void:
	var screen := _at(0.2)
	screen.skip()
	assert_float(screen.menu_alpha()).is_equal_approx(1.0, 0.001)
	assert_float(screen.tagline_alpha()).is_equal_approx(1.0, 0.001)
	assert_bool(screen.is_idle()).is_true()


# --- the menu ----------------------------------------------------------------

func test_three_rows_and_each_is_big_enough_to_tap() -> void:
	var screen := _at(9.0)
	assert_array(Array(screen.menu_items())).is_equal(["continue", "new", "settings"])
	for item in screen.menu_items():
		assert_float(screen.menu_rect(str(item)).size.y).override_failure_message(
			"the %s row is under the touch minimum" % item) \
			.is_greater_equal(_visuals().number("wheel.min_touch_target"))


func test_continue_says_where_you_were_and_is_dead_without_a_save() -> void:
	var screen := _at(9.0)
	assert_bool(screen.menu_enabled("continue")).override_failure_message(
		"nothing has been played, so there is nothing to continue").is_false()
	assert_str(screen.menu_sub("continue")).is_empty()

	var save := SaveData.new()
	save.data = {"schema": 1, "rooms": {"room_01_studio": {
		"stars": 2, "endings_found": ["disable"], "notebook": [{"loop": 2, "line": "x"}],
		"interactions_done": [], "discoveries": [], "deaths": [], "collectible": [],
		"attacker_notes": [], "loops_total": 8,
	}}, "settings": {}}
	var played := _at(9.0, save)
	assert_bool(played.menu_enabled("continue")).is_true()
	assert_str(played.menu_sub("continue")).override_failure_message(
		"Continue should say which room and how many deaths").contains("7")


## A run abandoned mid-loop still left a notebook behind.
func test_continue_works_off_a_notebook_alone() -> void:
	var save := SaveData.new()
	save.data = {"schema": 1, "rooms": {"room_01_studio": {"stars": 0, "endings_found": [],
		"notebook": [{"loop": 1, "line": "x"}], "interactions_done": [], "discoveries": [],
		"deaths": [], "collectible": [], "attacker_notes": [], "loops_total": 0}}, "settings": {}}
	assert_bool(_at(9.0, save).menu_enabled("continue")).is_true()


## Wiping a notebook is the one destructive thing on this screen.
func test_a_new_game_asks_before_it_wipes_anything() -> void:
	var save := SaveData.new()
	save.data = {"schema": 1, "rooms": {"room_01_studio": {"loops_total": 4, "stars": 1,
		"endings_found": [], "notebook": [], "interactions_done": [], "discoveries": [],
		"deaths": [], "collectible": [], "attacker_notes": []}}, "settings": {}}
	var screen := _at(9.0, save)
	var watcher := monitor_signals(screen)
	screen.press_at(screen.menu_rect("new").get_center())
	await assert_signal(watcher).is_not_emitted("start_requested", [true])
	assert_str(screen.menu_label("new").to_lower()).override_failure_message(
		"a tap on New wiped a notebook with no warning").contains("sure")
	screen.press_at(screen.menu_rect("new").get_center())
	await assert_signal(watcher).is_emitted("start_requested", [true])


func test_settings_is_visibly_not_ready() -> void:
	var screen := _at(9.0)
	assert_bool(screen.menu_enabled("settings")).is_false()
	var watcher := monitor_signals(screen)
	screen.press_at(screen.menu_rect("settings").get_center())
	await assert_signal(watcher).is_not_emitted("start_requested", [false])


# --- the room strip ----------------------------------------------------------

func test_the_strip_shows_the_rooms_that_exist_and_the_ones_that_do_not() -> void:
	var screen := _at(9.0)
	var cells := screen.room_cells()
	assert_int(cells.size()).is_equal(int(_visuals().number("title.room_slots", 4)))
	assert_bool(bool((cells[0] as Dictionary)["unlocked"])).override_failure_message(
		"Room 1 exists and should not be drawn as locked").is_true()
	assert_bool(bool((cells[cells.size() - 1] as Dictionary)["unlocked"])).override_failure_message(
		"a room that has not been built is not unlocked").is_false()


func test_a_locked_cell_is_the_same_skeleton_with_nothing_in_it() -> void:
	var cells := _at(9.0).room_cells()
	var locked: Dictionary = cells[cells.size() - 1]
	assert_int(int(locked["stars"])).is_equal(0)
	assert_array(locked["endings_found"]).is_empty()
	assert_str(str(locked["label"])).override_failure_message(
		"a locked cell still names its slot, so the shape of what is coming is visible") \
		.is_not_empty()


func test_an_unlocked_cell_carries_what_you_earned() -> void:
	var save := SaveData.new()
	save.data = {"schema": 1, "rooms": {"room_01_studio": {"stars": 2,
		"endings_found": ["disable", "kill"], "notebook": [], "interactions_done": [],
		"discoveries": [], "deaths": [], "collectible": [], "attacker_notes": [], "loops_total": 3}},
		"settings": {}}
	var first: Dictionary = _at(9.0, save).room_cells()[0]
	assert_int(int(first["stars"])).is_equal(2)
	assert_int((first["endings_found"] as Array).size()).is_equal(2)


# --- the door ----------------------------------------------------------------

func test_the_door_only_exists_on_the_way_out() -> void:
	var screen := _at(9.0)
	assert_float(screen.door_alpha()).override_failure_message(
		"the door is not the logo and does not sit on the title screen").is_equal_approx(0.0, 0.001)
	screen.begin_exit()
	screen.advance(_visuals().number("title.door_in_s") + 0.05)
	assert_float(screen.door_alpha()).is_equal_approx(1.0, 0.001)
	assert_float(screen.menu_alpha()).override_failure_message(
		"the menu is still up behind an opening door").is_less(0.2)


func test_the_leaf_swings_and_then_the_frame_rushes_past() -> void:
	var v := _visuals()
	var screen := _at(9.0)
	screen.begin_exit()
	screen.advance(v.number("title.door_open_at_s") + v.number("title.door_open_s") + 0.01)
	assert_float(screen.leaf_scale_x()).override_failure_message(
		"the door never opened").is_equal_approx(v.number("title.door_leaf_scale_x_to"), 0.02)
	assert_float(screen.room_alpha()).override_failure_message(
		"the room should be showing through the opening").is_greater(0.0)
	screen.advance(v.number("title.door_through_s") + 0.2)
	assert_float(screen.frame_scale()).is_greater(2.0)
	assert_bool(screen.exit_finished()).is_true()


func test_the_room_is_not_running_until_the_door_is_open() -> void:
	var v := _visuals()
	var screen := _at(9.0)
	assert_bool(screen.room_wanted()).override_failure_message(
		"the room is being built while the menu is still up").is_false()
	screen.begin_exit()
	screen.advance(v.number("title.door_open_at_s") + 0.01)
	assert_bool(screen.room_wanted()).override_failure_message(
		"nothing asked for the room, so there is nothing behind the door").is_true()


func test_the_game_boots_into_the_title() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_str(project).contains("run/main_scene=\"res://game/title.tscn\"")
	var source := FileAccess.get_file_as_string("res://game/boot.gd")
	assert_str(source).override_failure_message(
		"nothing brings the room in behind the door").contains("main.tscn")


## The room arrives behind the door rather than snapping on.
func test_the_room_fades_up_behind_the_door() -> void:
	var source := FileAccess.get_file_as_string("res://game/boot.gd")
	assert_str(source).override_failure_message(
		"nothing dims the room while the door is still shut").contains("room_alpha()")
	var v := _visuals()
	var screen := _at(9.0)
	screen.begin_exit()
	screen.advance(v.number("title.door_open_at_s") + v.number("title.door_open_s") * 0.5)
	var half := screen.room_alpha()
	assert_float(half).is_greater(0.0)
	assert_float(half).override_failure_message(
		"the room is at full brightness while the door is only half open").is_less(1.0)
	screen.advance(v.number("title.door_through_s") + 0.5)
	assert_float(screen.room_alpha()).is_equal_approx(1.0, 0.001)


## Bob, playing the title: the Continue / New Game / Settings block should be
## centred under the logo, with equal space between the tagline above and the
## room strip below — not pinned to the logo's left edge low on the screen.
func test_the_menu_is_centred_under_the_logo() -> void:
	var screen := _at(9.0)
	var axis := screen.lockup_rect().get_center().x
	for item in screen.menu_items():
		assert_float(screen.menu_rect(str(item)).get_center().x).override_failure_message(
			"the %s row is not on the logo's axis" % item).is_equal_approx(axis, 0.5)


func test_the_menu_has_equal_air_above_and_below() -> void:
	var screen := _at(9.0)
	var titles_bottom := screen.lockup_rect().end.y
	var strip_top := screen._strip_top()
	var block := screen.menu_rect("continue")
	var above := block.position.y - titles_bottom
	var below := strip_top - (block.position.y + screen._menu_block_height())
	assert_float(above).override_failure_message(
		"space above the menu (%.1f) does not match the space below it (%.1f)"
		% [above, below]).is_equal_approx(below, 1.0)
	assert_float(above).override_failure_message(
		"the menu is jammed against the tagline or the room strip").is_greater(10.0)
