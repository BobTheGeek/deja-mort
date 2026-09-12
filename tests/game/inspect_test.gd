extends GdUnitTestSuite

## From Bob's playtest: "often when I click on Inspect nothing happens. I would
## expect to see some sort of dialogue or information about what I inspected,
## which of course is part of telling the story."
##
## Inspect always worked — it reveals tags, counts the look, and feeds the
## notebook. What it never did was say anything on screen, so the only verb
## whose whole product is words produced none.
##
## The words are already authored: all 39 objects in Room 1 carry `inspect`.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


# --- the content -------------------------------------------------------------

func test_every_object_in_the_room_has_something_to_say() -> void:
	var silent := PackedStringArray()
	for obj in F.world().objects.all():
		if obj.inspect.strip_edges().is_empty():
			silent.append(obj.id)
	assert_array(Array(silent)).override_failure_message(
		"inspect is the story; these objects have no text: %s" % [silent]).is_empty()


func test_the_sim_hands_the_text_to_presentation() -> void:
	var world := F.world()
	assert_bool(F.act(world, "inspect", "fridge")).is_true()
	var said := ""
	for event in world.events.log_all():
		if event.rule_id == "inspect" and event.meta.has("text"):
			said = str(event.meta["text"])
	assert_str(said).override_failure_message(
		"nothing on the bus carries the fridge's text").is_equal(world.objects.by_id("fridge").inspect)


# --- the screen --------------------------------------------------------------

func test_the_hud_shows_what_was_inspected() -> void:
	var world := F.world()
	var hud := _hud()
	var fridge := world.objects.by_id("fridge")
	hud.show_inspect(fridge.name, fridge.inspect)
	assert_str(hud.inspect_text()).override_failure_message(
		"the HUD says nothing after an inspect").contains(fridge.inspect)
	assert_str(hud.inspect_text()).override_failure_message(
		"say which object it is").contains(fridge.name)


func test_the_line_clears_itself_so_it_does_not_pile_up() -> void:
	var hud := _hud()
	hud.show_inspect("Fridge", "Humming.")
	hud.advance(hud.visuals.number("hud.inspect_hold_s", 4.0) + 0.2)
	assert_str(hud.inspect_text()).override_failure_message(
		"the inspect line never goes away").is_empty()


func test_it_stays_long_enough_to_read() -> void:
	var hold := GameVisuals.load_table().number("hud.inspect_hold_s", 0.0)
	assert_float(hold).override_failure_message(
		"an unreadable %.1fs is no better than saying nothing" % hold).is_greater(2.5)


# --- helpers -----------------------------------------------------------------

func _hud() -> GameHud:
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(GameVisuals.load_table())
	return hud


## The canvas is 1920x1080 now (docs/ui/SPEC.md). Numbers tuned for a 1152-wide
## window render at 60% of themselves on it, which is how a stretch change
## quietly shrinks a HUD nobody re-measured.
func test_the_hud_is_sized_for_the_canvas_it_is_drawn_on() -> void:
	var v := GameVisuals.load_table()
	var height := v.number("ui.design_height", 1080.0)
	assert_float(v.number("hud.timer_size")).override_failure_message(
		"the timer is the loudest thing on screen and it is %.0fpx on a %.0fpx canvas" % [
			v.number("hud.timer_size"), height]).is_greater_equal(height * 0.06)
	assert_float(v.number("hud.inspect_size")).override_failure_message(
		"the inspect line is unreadable at %.0fpx on a %.0fpx canvas" % [
			v.number("hud.inspect_size"), height]).is_greater_equal(24.0)


func test_the_inspect_line_sits_on_something_rather_than_on_the_room() -> void:
	var v := GameVisuals.load_table()
	assert_float(v.number("hud.inspect_fill_alpha")).override_failure_message(
		"white text straight onto a lit wall is the one contrast case the brief calls out") \
		.is_greater(0.5)
	assert_object(v.colour("hud.inspect_name_color")).is_equal(Brand.ACCENT)


## The panel is measured from the text, not grown by a layout pass that never
## runs. Get it wrong and it covers the room instead of sitting under it.
func test_the_inspect_panel_is_a_strip_at_the_bottom_not_a_curtain() -> void:
	var world := F.world()
	var hud := _hud()
	var v := GameVisuals.load_table()
	var frame := Vector2(v.number("ui.design_width"), v.number("ui.design_height"))
	var fridge := world.objects.by_id("fridge")
	hud.show_inspect(fridge.name, fridge.inspect)
	var box := hud.inspect_rect()
	assert_float(box.size.x).override_failure_message(
		"the panel is %.0f wide on a %.0f canvas" % [box.size.x, frame.x]) \
		.is_less_equal(v.number("hud.inspect_max_width") + 1.0)
	assert_float(box.size.y).override_failure_message(
		"the panel is %.0f tall; it holds one line of text" % box.size.y).is_less(frame.y * 0.2)
	assert_float(box.position.y).override_failure_message(
		"the panel starts at y=%.0f, nowhere near the bottom" % box.position.y) \
		.is_greater(frame.y * 0.6)
	assert_float(box.end.y).override_failure_message(
		"the panel runs off the bottom of the frame").is_less_equal(frame.y)
