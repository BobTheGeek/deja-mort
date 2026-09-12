extends GdUnitTestSuite

## The notebook, rebuilt from Claude Design's turn-1 spec (docs/ui/SPEC.md).
## Bob: "reads fine, though it needs a design pass." It was a grey box with
## three plain buttons and a RichTextLabel.
##
## It is auto-written, never typed, and it is the only narrator this game has:
## what you have looked at, what you have learned about him, and how you have
## died. The conceit is a case file, not a paper notebook — no ruled lines, no
## handwriting, nothing cosy. Something cold that records what happened to you,
## repeatedly, without comment.
##
## Their design has a fourth tab, Achievements. This game has no achievements,
## so it is in docs/BACKLOG.md rather than invented here, and this suite holds
## the notebook to the three tabs that are real.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _entry(overrides: Dictionary = {}) -> Dictionary:
	var entry := {
		"endings_found": [], "interactions_done": [], "discoveries": [], "deaths": [],
		"collectible": [], "notebook": [], "attacker_notes": [],
	}
	for key in overrides:
		entry[key] = overrides[key]
	return entry


func _open(world: SimWorld, entry: Dictionary, v: GameVisuals = null) -> Notebook:
	var book: Notebook = auto_free(Notebook.new())
	book.setup(v if v != null else _visuals())
	book.show_for(world, entry)
	book.advance(1.0)
	return book


# --- the table ---------------------------------------------------------------

func test_the_table_carries_every_number_the_notebook_reads() -> void:
	var v := _visuals()
	var missing := PackedStringArray()
	for key in Notebook.REQUIRED_KEYS:
		if v.get_value("notebook." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing notebook keys: %s" % [missing]).is_empty()


func test_the_achievements_tab_is_not_quietly_here() -> void:
	var book := _open(F.world(), _entry())
	for tab in book.tabs():
		assert_str(str(tab).to_lower()).override_failure_message(
			"an Achievements tab with no achievements behind it").is_not_equal("achievements")


# --- the tabs ----------------------------------------------------------------

func test_three_tabs_each_carrying_its_own_count() -> void:
	var world := F.world()
	assert_bool(F.act(world, "inspect", "fridge")).is_true()
	assert_bool(F.act(world, "inspect", "toaster")).is_true()
	var entry := _entry({
		"interactions_done": ["inspect|fridge", "inspect|toaster"],
		"attacker_notes": ["He tries the handle first."],
		"notebook": [{"loop": 2, "line": "The toaster was not plugged in."}],
	})
	var book := _open(world, entry)
	assert_array(Array(book.tabs())).is_equal(["Room", "Attacker", "Deaths"])
	assert_int(book.tab_count("Room")).is_equal(2)
	assert_int(book.tab_count("Attacker")).is_equal(1)
	assert_int(book.tab_count("Deaths")).is_equal(1)


func test_a_tab_is_big_enough_to_tap() -> void:
	var v := _visuals()
	var book := _open(F.world(), _entry(), v)
	for tab in book.tabs():
		var box := book.tab_rect(str(tab))
		assert_float(box.size.y).override_failure_message(
			"the %s tab is %.0f tall, under the touch minimum" % [tab, box.size.y]) \
			.is_greater_equal(v.number("wheel.min_touch_target"))


func test_tapping_a_tab_changes_the_page() -> void:
	var world := F.world()
	var entry := _entry({"attacker_notes": ["He tries the handle first."]})
	var book := _open(world, entry)
	assert_str(book.active_tab()).is_equal("Room")
	assert_bool(book.press_at(book.tab_rect("Attacker").get_center())).is_true()
	assert_str(book.active_tab()).is_equal("Attacker")
	assert_str(str(book.lines()[0])).contains("handle")


func test_the_selected_tab_is_the_accent_and_the_others_are_not() -> void:
	var v := _visuals()
	var book := _open(F.world(), _entry(), v)
	assert_object(book.tab_colour("Room")).is_equal(v.colour("notebook.tab_selected_color"))
	assert_object(book.tab_colour("Deaths")).is_not_equal(v.colour("notebook.tab_selected_color"))


# --- what is on each page ----------------------------------------------------

func test_the_room_page_is_what_you_have_looked_at() -> void:
	var world := F.world()
	assert_bool(F.act(world, "inspect", "fridge")).is_true()
	var book := _open(world, _entry({"interactions_done": ["inspect|fridge", "grab|lighter"]}))
	var fridge := world.objects.by_id("fridge")
	var entries := book.entries()
	assert_int(entries.size()).override_failure_message(
		"grabbing something is not looking at it; only inspect writes a page").is_equal(1)
	var first: Dictionary = entries[0]
	assert_str(str(first["name"])).is_equal(fridge.name)
	assert_str(str(first["line"])).is_equal(fridge.inspect)
	assert_str(str(first["tags"]).to_lower()).contains("heavy")


func test_deaths_are_numbered_in_the_order_they_happened() -> void:
	var book := _open(F.world(), _entry({"notebook": [
		{"loop": 2, "line": "He found you under the bed."},
		{"loop": 3, "line": "The oil was still on your own side of the room."},
	]}))
	book.press_at(book.tab_rect("Deaths").get_center())
	var lines := book.lines()
	assert_str(str(lines[0])).contains("1")
	assert_str(str(lines[0])).contains("under the bed")
	assert_str(str(lines[1])).contains("2")


func test_an_empty_page_says_something_rather_than_nothing() -> void:
	var book := _open(F.world(), _entry())
	for tab in book.tabs():
		book.press_at(book.tab_rect(str(tab)).get_center())
		assert_str(book.empty_line()).override_failure_message(
			"the %s tab is blank with no explanation" % tab).is_not_empty()


# --- scrolling ---------------------------------------------------------------

func test_a_long_list_scrolls_and_says_how_much_is_left() -> void:
	var world := F.world()
	var done := PackedStringArray()
	for obj in world.objects.all():
		F.act(world, "inspect", obj.id)
		done.append("inspect|%s" % obj.id)
	var book := _open(world, _entry({"interactions_done": Array(done)}))
	assert_int(book.entries().size()).is_greater(20)
	assert_int(book.more_below()).override_failure_message(
		"thirty-nine entries all fit in a 720px panel?").is_greater(0)
	var was := book.scroll_offset()
	book.scroll_by(200.0)
	assert_float(book.scroll_offset()).is_greater(was)
	book.scroll_by(100000.0)
	assert_int(book.more_below()).override_failure_message(
		"scrolled to the end and it still claims there is more").is_equal(0)
	assert_float(book.scroll_offset()).override_failure_message(
		"the list scrolled clean off its own end").is_less(book.content_height())


func test_a_short_list_does_not_pretend_to_scroll() -> void:
	var world := F.world()
	assert_bool(F.act(world, "inspect", "fridge")).is_true()
	var book := _open(world, _entry({"interactions_done": ["inspect|fridge"]}))
	assert_int(book.more_below()).is_equal(0)
	book.scroll_by(500.0)
	assert_float(book.scroll_offset()).override_failure_message(
		"a one-entry page scrolled").is_equal_approx(0.0, 0.001)


func test_switching_tabs_goes_back_to_the_top() -> void:
	var world := F.world()
	var done := PackedStringArray()
	for obj in world.objects.all():
		F.act(world, "inspect", obj.id)
		done.append("inspect|%s" % obj.id)
	var book := _open(world, _entry({"interactions_done": Array(done)}))
	book.scroll_by(300.0)
	book.press_at(book.tab_rect("Deaths").get_center())
	assert_float(book.scroll_offset()).is_equal_approx(0.0, 0.001)


# --- the panel ---------------------------------------------------------------

func test_the_panel_is_on_screen_and_out_of_the_safe_area() -> void:
	var v := _visuals()
	v.safe = {"left": 90.0, "top": 30.0, "right": 90.0, "bottom": 40.0}
	var book := _open(F.world(), _entry(), v)
	var box := book.panel_rect()
	assert_float(box.position.x).is_greater_equal(90.0)
	assert_float(box.end.x).is_less_equal(v.number("ui.design_width") - 90.0)
	assert_float(box.end.y).override_failure_message(
		"the panel runs under the home bar").is_less_equal(v.number("ui.design_height") - 40.0)


func test_there_is_a_way_out_that_is_not_a_keyboard() -> void:
	var world := F.world()
	var book := _open(world, _entry())
	assert_float(book.close_rect().size.x).is_greater_equal(
		_visuals().number("wheel.min_touch_target"))
	assert_bool(book.press_at(book.close_rect().get_center())).is_true()
	assert_bool(book.is_open()).override_failure_message(
		"pressing close left the notebook open").is_false()


func test_a_tap_on_the_page_does_not_close_it() -> void:
	var book := _open(F.world(), _entry())
	book.press_at(book.panel_rect().get_center())
	assert_bool(book.is_open()).is_true()
