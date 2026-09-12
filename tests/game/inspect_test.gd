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
