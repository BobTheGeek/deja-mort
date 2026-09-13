extends GdUnitTestSuite

## Landscape on a phone, and a thumb that can actually hit the wheel.
##
## The aspect ratio needed nothing — a room floating in black is the one layout
## that does not care, and 4:3 through 21:9 were checked on screen. What mobile
## really needs is three other things: a locked orientation, a UI big enough for
## a finger, and a HUD that stays out from under the notch.
##
## The size problem, in numbers: the wheel's slot is 88 units on a 1080-tall
## canvas. On an iPhone 16 Pro in landscape that is about 32 points against
## Apple's 44, and on a Pixel about 32dp against Google's 48. Two thirds of what
## a thumb needs.
##
## The scale is derived from the screen's own DPI, not a magic number, and it
## applies on a handheld only. A Steam Deck is a desktop OS driven by sticks,
## trackpads and a mouse; it does not get a phone's thumb allowance.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")

## Real devices, landscape, with the DPI each one reports.
const DEVICES := [
	{"name": "iPhone 16 Pro", "px": Vector2i(2556, 1179), "dpi": 460, "handheld": true},
	{"name": "Pixel 8", "px": Vector2i(2400, 1080), "dpi": 428, "handheld": true},
	{"name": "iPad Pro 11", "px": Vector2i(2388, 1668), "dpi": 264, "handheld": true},
	{"name": "Steam Deck", "px": Vector2i(1280, 800), "dpi": 215, "handheld": false},
	{"name": "desktop 1080p", "px": Vector2i(1920, 1080), "dpi": 96, "handheld": false},
]


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


# --- orientation -------------------------------------------------------------

func test_a_phone_is_held_the_long_way() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_str(project).override_failure_message(
		"nothing locks the orientation, so a phone will hand us a 9:19.5 frame") \
		.contains("window/handheld/orientation=\"landscape\"")


# --- thumb size --------------------------------------------------------------

func test_every_handheld_gets_a_slot_a_thumb_can_hit() -> void:
	var v := _visuals()
	var slot := v.number("wheel.slot_size")
	var wanted := v.number("ui.min_touch_mm")
	var small := PackedStringArray()
	for device in DEVICES:
		if not bool(device["handheld"]):
			continue
		var factor := UiScale.factor(device["px"], int(device["dpi"]), true, v)
		var mm := UiScale.millimetres(slot * factor * UiScale.canvas_scale(device["px"], v),
			int(device["dpi"]))
		if mm < wanted - 0.05:
			small.append("%s: %.1fmm at x%.2f" % [device["name"], mm, factor])
	assert_array(Array(small)).override_failure_message(
		"slots smaller than %.1fmm: %s" % [wanted, small]).is_empty()


func test_a_mouse_gets_the_ui_at_the_size_it_was_designed() -> void:
	var v := _visuals()
	for device in DEVICES:
		if bool(device["handheld"]):
			continue
		assert_float(UiScale.factor(device["px"], int(device["dpi"]), false, v)) \
			.override_failure_message("%s had its UI blown up for a thumb it does not use"
				% device["name"]).is_equal_approx(1.0, 0.001)


## A tablet is already big enough. Scaling it up would only cost room.
func test_a_tablet_is_left_alone() -> void:
	var v := _visuals()
	assert_float(UiScale.factor(Vector2i(2388, 1668), 264, true, v)).override_failure_message(
		"an 11-inch iPad does not need a thumb allowance").is_equal_approx(1.0, 0.001)


func test_the_scale_is_bounded_so_a_daft_dpi_cannot_swallow_the_screen() -> void:
	var v := _visuals()
	assert_float(UiScale.factor(Vector2i(2400, 1080), 2000, true, v)).is_less_equal(
		v.number("ui.max_touch_scale"))


# --- the notch ---------------------------------------------------------------

func test_the_safe_area_becomes_insets_in_canvas_units() -> void:
	# A phone in landscape: the island eats the left edge, the home bar the bottom.
	var insets := UiScale.insets(Rect2i(132, 0, 2424, 1131), Vector2i(2556, 1179), Vector2(1920, 886))
	assert_float(float(insets["left"])).is_equal_approx(132.0 * 1920.0 / 2556.0, 0.5)
	assert_float(float(insets["bottom"])).is_greater(0.0)
	assert_float(float(insets["top"])).is_equal_approx(0.0, 0.001)
	assert_float(float(insets["right"])).is_equal_approx(0.0, 0.001)


func test_no_notch_means_no_insets() -> void:
	var insets := UiScale.insets(Rect2i(0, 0, 1920, 1080), Vector2i(1920, 1080), Vector2(1920, 1080))
	for edge in ["left", "top", "right", "bottom"]:
		assert_float(float(insets[edge])).override_failure_message(
			"%s inset invented on a screen with nothing in the way" % edge).is_equal_approx(0.0, 0.001)


func test_the_hud_moves_out_from_under_the_island() -> void:
	var v := _visuals()
	v.safe = {"left": 99.0, "top": 0.0, "right": 0.0, "bottom": 40.0}
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(v)
	assert_float(hud.lines_position().x).override_failure_message(
		"the loop counter sits under the notch").is_greater_equal(v.number("hud.margin_x") + 99.0)
	assert_float(hud.inspect_rect().end.y).override_failure_message(
		"the inspect line runs under the home bar") \
		.is_less_equal(v.number("ui.design_height") - 40.0)


func test_the_wheel_clamps_inside_the_safe_area_too() -> void:
	var v := _visuals()
	v.safe = {"left": 99.0, "top": 0.0, "right": 0.0, "bottom": 40.0}
	var world := F.world()
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(v, world)
	wheel.open_at(world, "fridge", Vector2(4, 4))
	wheel.advance(1.0)
	var box := wheel.occupied_rect()
	assert_float(box.position.x).override_failure_message(
		"the wheel opened under the notch").is_greater_equal(v.number("wheel.edge_margin") + 99.0 - 0.5)
	assert_float(box.end.y).override_failure_message(
		"the wheel's caption runs under the home bar") \
		.is_less_equal(v.number("ui.design_height") - 40.0 + 0.5)


# --- how big the window opens ------------------------------------------------

## The UI is drawn at 1920x1080 and the canvas stretches to the window, so a
## 1152-wide window renders every number at 60% of itself. That is how a tally
## of 3px scratches next to a 20px label reads as "the old plain text label with
## nothing beside it", which is what Bob saw.
func test_the_window_opens_as_big_as_the_screen_sensibly_allows() -> void:
	var v := _visuals()
	var base := Vector2(v.number("ui.design_width"), v.number("ui.design_height"))
	# A big desktop: the design's own size, and no larger.
	assert_vector(UiScale.window_size(Vector2i(3456, 2160), v)).is_equal(Vector2i(1920, 1080))
	# A laptop: as much of it as the fraction allows, still 16:9.
	var laptop := UiScale.window_size(Vector2i(1512, 982), v)
	assert_bool(laptop.x <= int(1512.0 * v.number("ui.window_screen_fraction"))) \
		.override_failure_message("the window is wider than the screen allows: %s" % laptop).is_true()
	assert_float(float(laptop.x) / float(laptop.y)).override_failure_message(
		"the window opened at a different shape from the canvas").is_equal_approx(
			base.x / base.y, 0.02)
	assert_int(laptop.x).override_failure_message(
		"a window this small renders the UI at less than half size").is_greater(1100)


func test_the_game_sizes_its_own_window() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_str(source).override_failure_message(
		"nothing sizes the window, so it opens at whatever project.godot last said") \
		.contains("UiScale.window_size")


## A desktop window has no notch. macOS reports a display safe area that is the
## screen minus the menu bar, which has nothing to do with a window inside it —
## taking it pushed the title menu 70px down, into the room strip.
func test_a_desktop_window_takes_no_safe_area_insets() -> void:
	var source := FileAccess.get_file_as_string("res://game/ui_scale.gd")
	assert_str(source).override_failure_message(
		"the safe area is applied without asking whether this is a handheld") \
		.contains("if handheld else _none()")
