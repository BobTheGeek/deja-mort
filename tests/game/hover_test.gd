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

func test_nothing_is_outlined_until_something_is_pointed_at() -> void:
	var renderer := _rendered(F.world())
	assert_bool(renderer.highlight_visible()).is_false()


func test_pointing_at_something_outlines_it() -> void:
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


func test_a_two_square_thing_is_outlined_across_both() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("couch")
	renderer.sync(world, 0.1, 0.0)
	var drawn := renderer.highlight_rect()
	assert_float(maxf(drawn.size.x, drawn.size.y)).override_failure_message(
		"the couch is two squares long and its outline is %s" % [drawn.size]).is_greater(1.5)


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
func test_the_outline_colour_is_a_brand_token() -> void:
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


## The frame is gone. Bob: "it is too big and thick and still does not
## accurately tell me what I am going to interact with." An outline traces the
## object's own silhouette instead of drawing a box round its square, which at a
## counter run is a box round its neighbours too.
func test_the_outline_hugs_the_object_rather_than_boxing_its_square() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("counter_drawer")
	renderer.sync(world, 0.1, 0.0)
	var outline := renderer.highlight_node()
	assert_object(outline).is_not_null()
	assert_int(_meshes_in(outline)).override_failure_message(
		"the outline traces nothing").is_greater(0)
	# It is the object's own meshes, so it is the object's own shape.
	var mine := renderer.object_bounds("counter_drawer")
	var drawn := renderer.highlight_rect()
	assert_float(drawn.size.x).is_equal_approx(mine.size.x, 0.05)
	assert_float(drawn.size.y).is_equal_approx(mine.size.z, 0.05)


## A hairline, not a bar. One and a half pixels at the design canvas.
func test_the_outline_is_a_hairline() -> void:
	var v := _visuals()
	var renderer := _rendered(F.world())
	var metres_per_pixel := v.number("camera.size") / v.number("ui.design_height")
	assert_float(renderer.outline_thickness()).override_failure_message(
		"the outline is %.4f m, which is %.1f pixels" % [renderer.outline_thickness(),
			renderer.outline_thickness() / metres_per_pixel]) \
		.is_equal_approx(metres_per_pixel * v.number("object.highlight_pixels"), 0.0005)
	assert_float(v.number("object.highlight_pixels")).is_less_equal(2.0)


## Drawn inside out, so only the sliver past the real object shows.
func test_it_is_an_inverted_hull_and_not_a_coat_of_paint() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("fridge")
	renderer.sync(world, 0.1, 0.0)
	var copy := _first_mesh(renderer.highlight_node())
	var paint := copy.material_override as StandardMaterial3D
	assert_object(paint).is_not_null()
	assert_int(paint.cull_mode).override_failure_message(
		"front faces are not culled, so this paints over the object").is_equal(
			BaseMaterial3D.CULL_FRONT)
	assert_bool(paint.grow).is_true()
	assert_int(paint.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)


## BRAND.md forbids red outright. Bob asked for a thin red line; this is the same
## amber that marks a locked door and a refused action, at the same hairline.
func test_the_outline_is_the_accent_because_the_brand_has_no_red() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.highlight("fridge")
	renderer.sync(world, 0.1, 0.0)
	var paint := _first_mesh(renderer.highlight_node()).material_override as StandardMaterial3D
	assert_object(paint.albedo_color).is_equal(Brand.ACCENT)
	assert_bool(paint.albedo_color.r > paint.albedo_color.g \
		and paint.albedo_color.g > paint.albedo_color.b).override_failure_message(
			"the accent should read warm, not red").is_true()


func _meshes_in(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _meshes_in(child)
	return total


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
