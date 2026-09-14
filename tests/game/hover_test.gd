extends GdUnitTestSuite

## From the fifth playtest: "the layout of the room is too cluttered making it
## hard to see things. Often I can't tell what I am looking at. It took me a
## while to find the actual kitchen counter and the drawer."
##
## Thirty-nine objects in a twelve-by-ten room, drawn from a pack whose pieces
## are deliberately simple, seen from across the room. The room is not going to
## get less crowded — every visible thing is interactable by design — so the
## answer is to say what is under the pointer: a ring on the floor beneath it
## and its name at the cursor.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	renderer.sync(world, 0.1, 0.0)
	return renderer


# --- the ring ----------------------------------------------------------------

func test_nothing_is_ringed_until_something_is_pointed_at() -> void:
	var renderer := _rendered(F.world())
	assert_bool(renderer.highlight_visible()).is_false()


func test_pointing_at_something_rings_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("fridge")
	renderer.sync(world, 0.1, 0.0)
	assert_bool(renderer.highlight_visible()).override_failure_message(
		"nothing marks what the pointer is over").is_true()
	var ring := renderer.highlight_rect()
	var fridge := world.objects.by_id("fridge")
	assert_float(ring.get_center().distance_to(Vector2(
		float(fridge.origin().x) + 0.5, float(fridge.origin().y) + 0.5))) \
		.override_failure_message("the ring is not on the thing it is about").is_less(0.6)


func test_a_two_square_thing_gets_a_two_square_ring() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("couch")
	renderer.sync(world, 0.1, 0.0)
	var ring := renderer.highlight_rect()
	assert_float(maxf(ring.size.x, ring.size.y)).override_failure_message(
		"the couch is two squares long and its ring is %s" % [ring.size]).is_greater(1.5)


func test_pointing_away_takes_it_off_again() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("fridge")
	renderer.sync(world, 0.1, 0.0)
	renderer.highlight("")
	renderer.sync(world, 0.1, 0.0)
	assert_bool(renderer.highlight_visible()).override_failure_message(
		"the ring stayed behind after the pointer moved off").is_false()


## The ring is the accent, like everything else that says "this one".
func test_the_ring_is_a_brand_colour() -> void:
	var v := _visuals()
	assert_object(v.colour("object.highlight_color")).is_equal(Brand.ACCENT)


# --- the name ----------------------------------------------------------------

func test_the_hud_names_what_the_pointer_is_over() -> void:
	var world := F.world()
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(_visuals())
	hud.show_hover(world.objects.by_id("counter_drawer").name, Vector2(400.0, 300.0))
	assert_str(hud.hover_text()).override_failure_message(
		"the pointer is over the drawer and nothing says so").is_equal("Counter drawer")


func test_the_name_follows_the_pointer_and_stays_on_screen() -> void:
	var v := _visuals()
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(v)
	hud.show_hover("Kitchen counter", Vector2(400.0, 300.0))
	var near := hud.hover_rect()
	assert_float(near.position.distance_to(Vector2(400.0, 300.0))).override_failure_message(
		"the label is nowhere near the pointer").is_less(120.0)
	# Hard against the right edge, it has to come back inside.
	hud.show_hover("Kitchen counter", Vector2(v.number("ui.design_width") - 4.0, 300.0))
	assert_float(hud.hover_rect().end.x).override_failure_message(
		"the label ran off the edge of the screen").is_less_equal(v.number("ui.design_width"))


func test_pointing_at_nothing_says_nothing() -> void:
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(_visuals())
	hud.show_hover("Fridge", Vector2(400.0, 300.0))
	hud.show_hover("", Vector2(400.0, 300.0))
	assert_str(hud.hover_text()).is_empty()


## A wheel is open: the pointer is choosing a verb, not pointing at the room.
func test_the_name_goes_away_while_a_panel_is_up() -> void:
	var world := F.world()
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(_visuals())
	hud.show_hover("Fridge", Vector2(400.0, 300.0))
	hud.sync(world, 1, true)
	assert_str(hud.hover_text()).override_failure_message(
		"the room is still labelling itself behind an open panel").is_empty()


func test_the_game_wires_the_pointer_to_both() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	for call in ["_renderer.highlight(", "_hud.show_hover("]:
		assert_str(source).override_failure_message(
			"main.gd never calls %s" % call).contains(call)


## A ring on the floor is hidden by the very thing it points at — the counter
## drawer sits on its own square and covers it completely.
func test_the_ring_sits_above_the_thing_not_under_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("counter_drawer")
	renderer.sync(world, 0.1, 0.0)
	var ring := renderer.highlight_node()
	var bounds := renderer.object_bounds("counter_drawer")
	assert_float(ring.position.y).override_failure_message(
		"the ring is at y=%.2f and the drawer's top is at %.2f" % [ring.position.y, bounds.end.y]) \
		.is_greater_equal(bounds.end.y)
