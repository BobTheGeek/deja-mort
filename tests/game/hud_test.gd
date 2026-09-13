extends GdUnitTestSuite

## The HUD, rebuilt from Claude Design's turn-1 spec (docs/ui/SPEC.md).
##
## What it has to carry is unchanged — the timer, how many times you have died,
## what is in your hands, whether you are hidden, what the room just told you,
## and how the loop ended. What changes is that it now says those things the way
## the spec says them: a tally scratched on a wall rather than "Death 3", a bar
## that drains under the timer in the last ten seconds, a chip that breathes
## while you are hidden, and a way into the notebook that a phone can reach.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _hud(v: GameVisuals = null) -> GameHud:
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(v if v != null else _visuals())
	return hud


func _synced(loop_index: int = 1, panel_open := false) -> Array:
	var world := F.world()
	var hud := _hud()
	hud.sync(world, loop_index, panel_open)
	return [hud, world]


# --- the table ---------------------------------------------------------------

func test_the_table_carries_every_number_the_hud_reads() -> void:
	var v := _visuals()
	var missing := PackedStringArray()
	for key in GameHud.REQUIRED_KEYS:
		if v.get_value("hud." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing hud keys: %s" % [missing]).is_empty()


# --- the tally ---------------------------------------------------------------

## "Death 3" is a score. Three scratches on a wall is a fact about you.
func test_the_loop_counter_is_scratched_not_printed() -> void:
	for deaths in [0, 1, 4, 7, 13]:
		var pair := _synced(deaths + 1)
		var hud: GameHud = pair[0]
		assert_int(hud.tally_strokes().size()).override_failure_message(
			"%d deaths drew %d strokes" % [deaths, hud.tally_strokes().size()]).is_equal(deaths)


## Groups of five, the fifth struck through the other four.
func test_the_fifth_stroke_of_a_group_lies_across_it() -> void:
	var pair := _synced(12)   # eleven deaths: two full groups and one
	var strokes: Array = pair[0].tally_strokes()
	var diagonal := 0
	for i in strokes.size():
		if bool((strokes[i] as Dictionary)["diagonal"]):
			diagonal += 1
			assert_int((i + 1) % 5).override_failure_message(
				"stroke %d is diagonal and is not a fifth" % (i + 1)).is_equal(0)
	assert_int(diagonal).override_failure_message(
		"eleven deaths should be two struck-through groups").is_equal(2)


## Past a certain point the strokes stop being countable and the numeral is the
## truth. Drawing ninety of them would be a wall of noise.
func test_a_long_run_collapses_to_a_number() -> void:
	var pair := _synced(41)
	var hud: GameHud = pair[0]
	assert_int(hud.tally_strokes().size()).override_failure_message(
		"forty deaths drew forty strokes across the screen").is_less_equal(5)
	assert_str(hud.loop_label()).override_failure_message(
		"the count is not written down anywhere").contains("40")


func test_the_tally_starts_inside_the_margin_and_the_safe_area() -> void:
	var v := _visuals()
	v.safe = {"left": 60.0, "top": 20.0, "right": 0.0, "bottom": 0.0}
	var hud := _hud(v)
	hud.sync(F.world(), 4)
	var first: Dictionary = hud.tally_strokes()[0]
	assert_float((first["from"] as Vector2).x).override_failure_message(
		"the tally is under the notch").is_greater_equal(v.number("hud.margin_x") + 60.0)


# --- the timer ---------------------------------------------------------------

func test_the_last_ten_seconds_turn_the_timer_and_drain_a_bar() -> void:
	var world := F.world()
	var hud := _hud()
	hud.sync(world, 1)
	assert_bool(hud.urgent_bar_rect().size.x > 0.0).override_failure_message(
		"a bar is draining with 75 seconds left").is_false()
	world.step_seconds(world.timer_remaining_s() - 5.0)
	hud.sync(world, 1)
	var bar := hud.urgent_bar_rect()
	var v := _visuals()
	var expected := v.number("hud.urgent_bar_width_max") * 5.0 / v.number("hud.urgent_below_s")
	assert_float(bar.size.x).override_failure_message(
		"five seconds left and the bar is %.0f wide, not %.0f" % [bar.size.x, expected]) \
		.is_equal_approx(expected, 2.0)
	assert_object(hud.timer_colour()).is_equal(v.colour("hud.urgent_color"))


func test_the_timer_is_the_calm_colour_when_there_is_time() -> void:
	var pair := _synced()
	assert_object(pair[0].timer_colour()).is_equal(_visuals().colour("hud.timer_color"))


# --- what is in your hands ---------------------------------------------------

func test_holding_sits_on_the_right_and_says_nothing_when_empty() -> void:
	var world := F.world()
	var hud := _hud()
	hud.sync(world, 1)
	assert_str(hud.holding_value()).override_failure_message(
		"empty hands should read as empty, not as a dash nobody asked for").is_empty()
	F.give(world, "lighter")
	hud.sync(world, 1)
	assert_str(hud.holding_value()).is_equal(world.objects.by_id("lighter").name)
	var box := hud.holding_rect()
	var v := _visuals()
	assert_float(box.end.x).override_failure_message(
		"holding is not right-aligned to the margin").is_equal_approx(
			v.number("ui.design_width") - v.number("hud.margin_x"), 1.0)


func test_the_hidden_chip_only_exists_while_you_are_hidden() -> void:
	var world := F.world()
	var hud := _hud()
	hud.sync(world, 1)
	assert_bool(hud.hidden_visible()).is_false()
	assert_bool(F.act(world, "hide", "closet")).override_failure_message(
		"could not get into the closet to test the chip").is_true()
	hud.sync(world, 1)
	assert_bool(hud.hidden_visible()).override_failure_message(
		"hidden in the closet and the HUD says nothing").is_true()
	assert_str(hud.hidden_text()).contains(world.objects.by_id("closet").name)


## Being hidden is a fragile state and the spec has it breathe. A value in the
## table that nothing reads is a promise nobody keeps.
func test_the_hidden_chip_breathes() -> void:
	var world := F.world()
	var hud := _hud()
	assert_bool(F.act(world, "hide", "closet")).is_true()
	hud.sync(world, 1)
	var first := hud.hidden_alpha()
	hud.advance(_visuals().number("hud.hidden_breathe_period_s") * 0.5)
	assert_float(hud.hidden_alpha()).override_failure_message(
		"the chip is not breathing: %.3f both times" % first).is_not_equal(first)


# --- the way into the notebook -----------------------------------------------

func test_there_is_a_way_into_the_notebook_a_phone_can_reach() -> void:
	var v := _visuals()
	var hud := _hud(v)
	var box := hud.notebook_button_rect()
	assert_float(box.size.x).override_failure_message(
		"the notebook button is under the touch minimum").is_greater_equal(
			v.number("ui.min_touch_mm") * 0.0 + v.number("wheel.min_touch_target"))
	assert_float(box.end.x).is_less_equal(v.number("ui.design_width") - v.number("hud.notebook_button_right") + 1.0)
	assert_float(box.end.y).is_less_equal(v.number("ui.design_height") - v.number("hud.notebook_button_bottom") + 1.0)


func test_pressing_it_asks_for_the_notebook() -> void:
	var hud := _hud()
	var watcher := monitor_signals(hud)
	hud.press_at(hud.notebook_button_rect().get_center())
	await assert_signal(watcher).is_emitted("notebook_pressed")


func test_a_tap_somewhere_else_is_not_the_notebook() -> void:
	var hud := _hud()
	assert_bool(hud.press_at(Vector2(20.0, 20.0))).override_failure_message(
		"the HUD swallowed a tap meant for the room").is_false()


## It must not sit on top of a two-line inspect line.
func test_the_button_clears_the_inspect_line() -> void:
	var world := F.world()
	var hud := _hud()
	var fridge := world.objects.by_id("fridge")
	hud.show_inspect(fridge.name, fridge.inspect)
	assert_bool(hud.notebook_button_rect().intersects(hud.inspect_rect())).override_failure_message(
		"the notebook button is sitting on the inspect line").is_false()


# --- paused ------------------------------------------------------------------

## Thinking is free, and the HUD should look like the clock has stopped.
func test_a_panel_open_stops_the_clock_and_says_so() -> void:
	var pair := _synced(3, true)
	var hud: GameHud = pair[0]
	assert_bool(hud.paused_look()).is_true()
	assert_float(hud.timer_alpha()).is_equal_approx(
		_visuals().number("hud.paused_timer_alpha"), 0.001)
	assert_bool(hud.tally_strokes().is_empty()).override_failure_message(
		"the tally is still up while a panel is open").is_true()


func test_normally_the_hud_is_all_there() -> void:
	var pair := _synced(3)
	var hud: GameHud = pair[0]
	assert_bool(hud.paused_look()).is_false()
	assert_float(hud.timer_alpha()).is_equal_approx(1.0, 0.001)
	assert_int(hud.tally_strokes().size()).is_equal(2)


## The button and the Tab key are the same action, and the room must not also
## get the tap that opened the notebook.
func test_the_game_routes_the_button_before_the_room() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_str(source).override_failure_message(
		"nothing connects the notebook button").contains("notebook_pressed.connect")
	var press := source.find("_hud.press_at(click.position)")
	var click := source.find("_click_world(click.position)")
	assert_int(press).override_failure_message("the button is never offered the tap").is_greater(-1)
	assert_int(press).override_failure_message(
		"the room gets the tap before the HUD does").is_less(click)


# --- the banner ---------------------------------------------------------------

## From Bob's third playtest: "after I died the LOSS overlay stayed up even once
## the new round started."
##
## The banner was a string that got set when the loop ended and never unset. The
## next loop has no ending, so nothing wrote over it, and it sat across a room
## whose timer was already running again.
func test_the_ending_is_named_while_the_loop_is_over() -> void:
	var world := F.world()
	var hud := _hud()
	hud.sync(world, 1)
	assert_str(hud.banner_text()).override_failure_message(
		"a banner before anything has ended").is_empty()
	world.kill_actor(world.player, "stabbed", "test")
	world.step()
	assert_str(world.ending).override_failure_message(
		"this test needs the loop to have ended").is_not_empty()
	hud.sync(world, 1)
	assert_str(hud.banner_text()).is_equal("LOSS")


func test_the_next_loop_starts_with_a_clean_screen() -> void:
	var over := F.world()
	over.kill_actor(over.player, "stabbed", "test")
	over.step()
	var hud := _hud()
	hud.sync(over, 1)
	assert_str(hud.banner_text()).is_not_empty()
	# A fresh loop: same HUD, new world, nothing has ended.
	hud.sync(F.world(), 2)
	assert_str(hud.banner_text()).override_failure_message(
		"LOSS is still across a room whose timer is running again").is_empty()


## The death beat flashes DEAD before the sim has named an ending; that must
## clear itself too.
func test_a_flash_clears_when_the_loop_moves_on() -> void:
	var hud := _hud()
	hud.flash("DEAD")
	assert_str(hud.banner_text()).is_equal("DEAD")
	hud.sync(F.world(), 2)
	assert_str(hud.banner_text()).is_empty()


## The beat flashes DEAD before the ending is named. Clearing on every frame of
## a finished loop would wipe it.
func test_the_death_flash_survives_the_beat() -> void:
	var world := F.world()
	world.kill_actor(world.player, "stabbed", "test")
	world.step()
	var hud := _hud()
	hud.flash("DEAD")
	hud.sync(world, 1, true)     # the banner is suppressed early in the beat
	assert_str(hud.banner_text()).override_failure_message(
		"DEAD was wiped before anyone could read it").is_equal("DEAD")
	hud.sync(world, 1, false)    # and the ending is named at the end of it
	assert_str(hud.banner_text()).is_equal("LOSS")
