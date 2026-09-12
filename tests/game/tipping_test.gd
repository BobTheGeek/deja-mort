extends GdUnitTestSuite

## From Bob's playtest: "When I tip the bookshelf, it falls through the wall."
##
## It fell north onto cells the sim had chosen correctly, but the renderer rolled
## it about Z regardless of which way it was falling — so a three-unit shelf
## swung sideways into the wall instead of lying down along its own footprint.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	return renderer


func _tip(world: SimWorld) -> void:
	F.goto(world, Vector2i(1, 7))
	F.act(world, "push", "bookshelf", "tip_first")
	F.act(world, "push", "bookshelf", "tip_second")


func test_the_sim_drops_it_on_floor_cells() -> void:
	var w := F.world()
	_tip(w)
	for cell in w.objects.by_id("bookshelf").cells:
		assert_int(w.grid.cell_type(cell)).override_failure_message(
			"the shelf landed on %s which is not floor" % cell).is_equal(SimGrid.FLOOR)


## A shelf falling north lies along north, which means pitching about X. Rolling
## about Z sends it sideways through the wall.
func test_it_falls_the_way_the_data_says_it_falls() -> void:
	var w := F.world()
	_tip(w)
	var renderer := _rendered(w)
	renderer.sync(w, 0.1)
	var node: Node3D = renderer.object_node("bookshelf")
	assert_object(node).is_not_null()
	assert_float(absf(node.rotation_degrees.x)).override_failure_message(
		"a north-falling shelf should pitch, not roll").is_greater(45.0)
	assert_float(absf(node.rotation_degrees.z)).override_failure_message(
		"rolling about Z is what put it through the wall").is_less(1.0)


func test_it_stays_inside_the_room() -> void:
	var w := F.world()
	_tip(w)
	var renderer := _rendered(w)
	renderer.sync(w, 0.1)
	var node: Node3D = renderer.object_node("bookshelf")
	var span := _bounds(node)
	assert_float(span.position.x).override_failure_message(
		"the shelf reaches x=%.2f, through the wall at x=1" % span.position.x).is_greater_equal(0.9)


func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in _all(node):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mi := child as MeshInstance3D
			var box: AABB = _chain(mi, node) * mi.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func _chain(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root.get_parent():
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
