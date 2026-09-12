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

## Every object you can see, clickable where you can see it. This is the whole
## bug, as a test.
func test_every_drawn_object_can_be_clicked_on_its_own_body() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var missed := PackedStringArray()
	var behind := PackedStringArray()
	var total := 0
	for obj in world.objects.all():
		var node := renderer.object_node(obj.id)
		if node == null or not node.visible:
			continue
		var box := renderer.object_bounds(obj.id)
		if box.size == Vector3.ZERO:
			continue
		total += 1
		# Sampled across the body, not just at the centre: something standing
		# behind a wardrobe is half hidden, and half is enough to click.
		var hit := ""
		for point in _samples(box):
			var ray := _ray_through(point as Vector3)
			if renderer.pick(ray[0] as Vector3, ray[1] as Vector3) == obj.id:
				hit = obj.id
				break
		if hit == obj.id:
			continue
		# Nothing wrong with the picking: something taller is standing in front.
		# Room 1's fridge covers the corner of the kitchen behind it.
		var centre := _ray_through(box.get_center())
		var occluder := renderer.pick(centre[0] as Vector3, centre[1] as Vector3)
		if not occluder.is_empty() \
				and renderer.object_bounds(occluder).size.y > box.size.y:
			behind.append("%s (behind %s)" % [obj.id, occluder])
			continue
		missed.append("%s (centre picks '%s')" % [obj.id, occluder])
	assert_int(total).override_failure_message("nothing was drawn to click").is_greater(20)
	assert_array(Array(missed)).override_failure_message(
		"objects you cannot click where you can see them:\n  %s" % "\n  ".join(missed)).is_empty()
	# Some hiding is the room's own geometry, but it is a cost and it is counted.
	assert_int(behind.size()).override_failure_message(
		"too much of Room 1 is hidden behind taller furniture:\n  %s" % "\n  ".join(behind)) \
		.is_less_equal(2)


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
