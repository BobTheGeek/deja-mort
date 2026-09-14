extends GdUnitTestSuite

## From the fifth playtest: "the curtains don't look like curtains; just a big
## brown block."
##
## They were. Nothing in the furniture kit is a curtain, so they fell through to
## the greybox: a box filling its square, coloured brown by the `flammable` tag
## and 1.5 m tall by `hides-player`.
##
## Hanging cloth is a shape, and a shape is a look. `cloth` is a tag now, and the
## look it carries draws two tall thin panels with a gap instead of one box —
## which is what a curtain is from across a room.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	renderer.sync(world, 0.1, 0.0)
	return renderer


func test_cloth_is_a_tag_the_content_knows_about() -> void:
	assert_bool(F.content().has_tag("cloth")).override_failure_message(
		"the look keys off a tag that tags.json has never heard of").is_true()


func test_the_curtains_are_cloth() -> void:
	assert_bool(F.world().objects.by_id("curtains").has_tag("cloth")).is_true()


func test_cloth_hangs_rather_than_filling_its_square() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var node := renderer.object_node("curtains")
	var panels := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			panels += 1
	assert_int(panels).override_failure_message(
		"the curtains are still one box").is_greater_equal(2)


func test_it_is_tall_and_thin_and_not_a_cube() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var box := renderer.object_bounds("curtains")
	assert_float(box.size.y).override_failure_message(
		"curtains that are %.2f m tall are a stool" % box.size.y).is_greater(1.9)
	assert_float(minf(box.size.x, box.size.z)).override_failure_message(
		"cloth %.2f m thick is a wardrobe" % minf(box.size.x, box.size.z)).is_less(0.3)


## It still hides a player, so it still has to cover the square it is on.
func test_it_still_spans_the_square_it_hides_you_in() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var box := renderer.object_bounds("curtains")
	assert_float(maxf(box.size.x, box.size.z)).override_failure_message(
		"a curtain you can hide behind has to be as wide as the window").is_greater(0.8)


func test_nothing_else_in_the_room_turned_into_a_curtain() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for id in ["couch", "bed", "fridge", "rug"]:
		var node := renderer.object_node(str(id))
		assert_object(node).is_not_null()
		assert_bool(world.objects.by_id(str(id)).has_tag("cloth")).override_failure_message(
			"%s picked up the cloth tag" % id).is_false()


## A wall cabinet is on the wall. Drawn on the floor it is furniture, and the
## fridge standing in front of it hides it completely.
func test_a_wall_cabinet_hangs_on_the_wall() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	for id in ["cabinet", "med_cabinet", "light_switch"]:
		var mounted := float(world.objects.by_id(str(id)).prop("mount_y", 0.0))
		assert_float(mounted).override_failure_message(
			"%s is still sitting on the floor" % id).is_greater(0.9)
		assert_float(renderer.object_bounds(str(id)).position.y).override_failure_message(
			"%s is mounted in the data and drawn on the floor" % id).is_greater(0.5)
