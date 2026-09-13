extends GdUnitTestSuite

## From Bob's playtest: "a number of the items I clicked on had no action. The
## wheel did not even appear."
##
## Clicks were resolved by intersecting the ray with the floor plane and asking
## which objects stood on that square. That works for a rug. It does not work for
## anything tall: from an isometric camera, the middle of the fridge projects
## onto the floor square *behind* the fridge. Eight of Room 1's twenty-three
## meshed objects could not be clicked on their own body at all — clicking the
## fridge selected the stove, and clicking the bookshelf, the closet, the doors,
## the lamp or the toilet selected nothing, so the game just walked there.
##
## It got worse when the furniture became real size, because the furniture got
## taller.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	renderer.sync(world, 1.0, 0.0)
	return renderer


## The camera's own basis, from the same angles IsoCamera uses. No viewport
## required, so this works on a renderer built off the scene tree.
func _camera_basis() -> Basis:
	var v := GameVisuals.load_table()
	var pivot: Node3D = auto_free(Node3D.new())
	pivot.rotation_degrees = Vector3(v.number("camera.pitch_deg", -35.264),
		v.number("camera.yaw_deg", 45.0), 0.0)
	return pivot.transform.basis


## Screen pixels per world unit: an orthographic camera of `size` covers that
## many world units over the canvas's height.
func _px_per_unit() -> float:
	var v := GameVisuals.load_table()
	return v.number("ui.design_height", 1080.0) / maxf(v.number("camera.size", 11.0), 0.001)


## A world point flattened onto the camera plane, in screen pixels.
func _project(point: Vector3) -> Vector2:
	var basis := _camera_basis()
	return Vector2(point.dot(basis.x), point.dot(basis.y)) * _px_per_unit()


func _ray_from_flat(flat: Vector2) -> Array:
	var basis := _camera_basis()
	var direction := -basis.z
	var units := flat / _px_per_unit()
	return [basis.x * units.x + basis.y * units.y - direction * 50.0, direction]


## The ray an orthographic camera casts through a world point, built from the
## same angles IsoCamera uses. No viewport required.
func _ray_through(point: Vector3) -> Array:
	var v := GameVisuals.load_table()
	var pivot: Node3D = auto_free(Node3D.new())
	pivot.rotation_degrees = Vector3(v.number("camera.pitch_deg", -35.264),
		v.number("camera.yaw_deg", 45.0), 0.0)
	var direction := -pivot.transform.basis.z
	return [point - direction * 50.0, direction]


## A grid of points over the object as drawn.
func _samples(box: AABB) -> Array:
	var out: Array = []
	for x in 3:
		for y in 3:
			for z in 3:
				out.append(box.position + Vector3(
					box.size.x * (0.15 + 0.35 * float(x)),
					box.size.y * (0.15 + 0.35 * float(y)),
					box.size.z * (0.15 + 0.35 * float(z))))
	return out


# --- the harness -------------------------------------------------------------

## Every object you can see, clickable where you can see it — measured the way
## a player meets it: in screen pixels, with everything else in the room in the
## way.
##
## The first version of this test sampled points inside each object's own volume
## and called an object broken when none of them picked it. That is the wrong
## question. The middle of the stove is behind the fridge; the *corner* of the
## stove is not, and a corner is enough to click. It reported two objects as
## unclickable that a player can hit perfectly well, and I repeated that as fact.
func test_every_drawn_object_has_somewhere_you_can_click_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var floor_px := GameVisuals.load_table().number("object.min_clickable_px", 400.0)
	var thin := PackedStringArray()
	var total := 0
	for obj in world.objects.all():
		var node := renderer.object_node(obj.id)
		if node == null or not node.visible:
			continue
		var box := renderer.object_bounds(obj.id)
		if box.size == Vector3.ZERO:
			continue
		total += 1
		var seen := _clickable_px(renderer, obj.id, box)
		if seen < floor_px:
			thin.append("%s: %.0f px" % [obj.id, seen])
	assert_int(total).override_failure_message("nothing was drawn to click").is_greater(20)
	assert_array(Array(thin)).override_failure_message(
		"objects with almost nowhere to click, at the 1920x1080 canvas:\n  %s"
		% "\n  ".join(thin)).is_empty()


## A thumb is not a pixel. The smallest thing in Room 1 is about 26 canvas px
## across, which is roughly ten points on a phone against Apple's forty-four.
func test_a_tap_that_lands_just_off_a_small_object_still_finds_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var tolerance := GameVisuals.load_table().number("object.pick_tolerance_px", 14.0)
	var centre := renderer.object_bounds("frying_pan").get_center()
	var found := false
	for offset in ClickTarget.ring(tolerance):
		# A ray parallel to the camera's, nudged sideways by a near miss.
		var ray := _ray_through(centre)
		var nudged: Vector3 = (ray[0] as Vector3) + Vector3(offset.x, 0.0, offset.y) * 0.02
		if renderer.pick(nudged, ray[1] as Vector3) == "frying_pan":
			found = true
	assert_bool(found).override_failure_message(
		"the ring of near misses is empty, so tolerance does nothing").is_true()
	assert_float(tolerance).override_failure_message(
		"no tap tolerance at all: a phone has to hit a 26px target exactly").is_greater(0.0)


func _clickable_px(renderer: RoomRenderer, id: String, box: AABB) -> float:
	# Walks the object's own screen rectangle at a coarse step and counts where
	# the pick comes back as this object. No viewport, so the projection is done
	# by hand from the same angles the camera uses.
	var step := 3.0
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in 8:
		var flat := _project(box.get_endpoint(i))
		lo = Vector2(minf(lo.x, flat.x), minf(lo.y, flat.y))
		hi = Vector2(maxf(hi.x, flat.x), maxf(hi.y, flat.y))
	var hits := 0
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var ray := _ray_from_flat(Vector2(x, y))
			if renderer.pick(ray[0] as Vector3, ray[1] as Vector3) == id:
				hits += 1
			x += step
		y += step
	return float(hits) * step * step


## The specific one Bob would have hit first.
func test_clicking_the_fridge_does_not_select_the_stove() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var ray := _ray_through(renderer.object_bounds("fridge").get_center())
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).is_equal("fridge")


func test_a_ray_into_the_void_picks_nothing() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var ray := _ray_through(Vector3(-40.0, 0.5, -40.0))
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).override_failure_message(
		"a click on empty space picked an object").is_empty()


## Something inside a shut drawer is not on screen, so it cannot be clicked.
func test_what_you_cannot_see_you_cannot_click() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(bool(world.objects.by_id("cabinet").get_state("open", false))) \
		.override_failure_message("this test needs a shut cabinet").is_false()
	var node := renderer.object_node("glass_jar")
	if node == null:
		return
	assert_bool(node.visible).override_failure_message(
		"an object inside a shut cabinet is being drawn").is_false()
	var ray := _ray_through(renderer.object_bounds("cabinet").get_center())
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).override_failure_message(
		"picked something that is inside a cupboard").is_equal("cabinet")


## Nearest first: the fridge is between the camera and the wall behind it.
func test_the_nearer_of_two_things_wins() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var front := renderer.object_bounds("couch").get_center()
	var ray := _ray_through(front)
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).is_equal("couch")


# --- what the game does with it ----------------------------------------------

func test_a_picked_object_wins_over_whatever_else_shares_its_square() -> void:
	var world := F.world()
	# The counter holds five things; the toaster is the one you can see.
	var here := world.objects.at_cell(Vector2i(2, 1))
	assert_int(here.size()).is_greater(2)
	var picker := ClickTarget.new()
	assert_str(str(picker.choose(world, Vector2i(2, 1), "toaster"))).override_failure_message(
		"the thing under the cursor lost to the first thing on the square").is_equal("toaster")


## Tapping the same square again still cycles, which is how you reach the four
## things you cannot see.
func test_tapping_the_same_square_still_cycles() -> void:
	var world := F.world()
	var picker := ClickTarget.new()
	var first: Variant = picker.choose(world, Vector2i(2, 1), "toaster")
	var second: Variant = picker.choose(world, Vector2i(2, 1), "toaster")
	assert_str(str(second)).override_failure_message(
		"the second tap on a stacked square offered the same object").is_not_equal(str(first))


func test_with_nothing_picked_it_falls_back_to_the_square() -> void:
	var world := F.world()
	var picker := ClickTarget.new()
	assert_str(str(picker.choose(world, Vector2i(2, 1), ""))).is_not_empty()
	assert_object(picker.choose(world, Vector2i(6, 5), "")).override_failure_message(
		"an empty square should offer nothing to act on").is_null()


# --- what you are holding ----------------------------------------------------

## Bob: a lamp that trails after you around the room does not look right. A
## point-and-click picks things up into your hands, not into your wake.
func test_what_you_are_holding_is_not_drawn_in_the_room() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(renderer.object_node("floor_lamp").visible).override_failure_message(
		"the lamp should be in the room before anyone picks it up").is_true()
	F.give(world, "floor_lamp")
	renderer.sync(world, 0.1, 0.0)
	assert_bool(renderer.object_node("floor_lamp").visible).override_failure_message(
		"the lamp is still standing in the room while the player holds it").is_false()


func test_and_it_cannot_be_clicked_while_you_hold_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var ray := _ray_through(renderer.object_bounds("floor_lamp").get_center())
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).is_equal("floor_lamp")
	F.give(world, "floor_lamp")
	renderer.sync(world, 0.1, 0.0)
	assert_str(renderer.pick(ray[0] as Vector3, ray[1] as Vector3)).override_failure_message(
		"picked something the player has in their hands").is_not_equal("floor_lamp")


func test_putting_it_down_puts_it_back_on_screen() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	F.give(world, "floor_lamp")
	renderer.sync(world, 0.1, 0.0)
	assert_bool(F.act(world, "drop", Vector2i(6, 4))).override_failure_message(
		"could not put the lamp down").is_true()
	renderer.sync(world, 0.1, 0.0)
	assert_bool(renderer.object_node("floor_lamp").visible).override_failure_message(
		"the lamp was put down and never came back").is_true()


## The HUD is where a held thing lives instead.
func test_the_hud_names_what_you_are_holding() -> void:
	var world := F.world()
	var hud: GameHud = auto_free(GameHud.new())
	hud.setup(GameVisuals.load_table())
	F.give(world, "floor_lamp")
	hud.sync(world, 1)
	assert_str(hud.holding_value()).is_equal(world.objects.by_id("floor_lamp").name)
