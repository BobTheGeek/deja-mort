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


## Bob, sixth playtest: "much like the bed earlier, the stove, sink, counter are
## all turned the wrong way. Their fronts are against the wall."
##
## They were: every one of them carried mesh_yaw 180. Kenney's furniture faces
## +Z at yaw 0 — checked by rendering the models with a marker on their +Z side —
## so a piece against the north wall faces 0, not 180. The room was full of
## furniture showing its back.
func test_nothing_against_a_wall_faces_into_it() -> void:
	var world := F.world()
	var wrong := PackedStringArray()
	for obj in world.objects.all():
		if str(obj.prop("mesh", "")).is_empty() or obj.cells.is_empty():
			continue
		var yaw := int(round(float(obj.prop("mesh_yaw", 0.0)))) % 360
		# Which way the front points, given Kenney faces +Z at yaw 0.
		var facing := Vector2i(0, 1)
		match yaw:
			90: facing = Vector2i(1, 0)
			180: facing = Vector2i(0, -1)
			270: facing = Vector2i(-1, 0)
		var ahead: Vector2i = obj.origin() + facing
		if not world.grid.in_bounds(ahead) or world.grid.cell_type(ahead) == SimGrid.WALL:
			wrong.append("%s faces %s into a wall" % [obj.id, facing])
	assert_array(Array(wrong)).override_failure_message(
		"furniture showing its back to the room:\n  %s" % "\n  ".join(wrong)).is_empty()


## The layout standard is only worth having if the build checks it.
func test_the_lint_carries_the_layout_rules() -> void:
	var source := FileAccess.get_file_as_string("res://tools/lint_room.gd")
	for code in ["fixture-off-wall", "faces-a-wall", "no-room-to-use", "marooned"]:
		assert_str(source).override_failure_message(
			"the lint does not check %s" % code).contains(code)
	assert_str(source).override_failure_message(
		"a room cannot declare an exception, so a violation has nowhere to go but a fix") \
		.contains("layout_exceptions")


## Every exception is a decision somebody wrote down, with the reason attached.
func test_every_declared_exception_says_why() -> void:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://content/rooms/room_01_studio.json"))
	var declared: Dictionary = (json.data as Dictionary).get("layout_exceptions", {})
	for id in declared:
		assert_int(str(declared[id]).length()).override_failure_message(
			"'%s' is excused with no reason" % id).is_greater(40)


func test_the_fixtures_are_tagged_as_fixtures() -> void:
	var world := F.world()
	var untagged := PackedStringArray()
	for id in ["stove", "sink", "fridge", "bathtub", "bed", "closet", "bookshelf", "toilet"]:
		if not world.objects.by_id(str(id)).has_tag("fixture"):
			untagged.append(str(id))
	assert_array(Array(untagged)).override_failure_message(
		"these belong against a wall and nothing says so: %s" % [untagged]).is_empty()
