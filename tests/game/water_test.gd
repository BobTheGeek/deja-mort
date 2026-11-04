extends GdUnitTestSuite

## The water, shaped (Bob's ask): pouring out of the sink should read as real
## water — an organic edge and a puddle, at least in shape. A wet region draws
## as ONE smoothed outline mesh ringed by a waterline band, never a grid of
## tiles; and a running wet-source visibly pours.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	renderer.sync(world, 0.1, 0.0)
	return renderer


## Every node in the tree with this exact name, so the tests can count bodies.
func _named(node: Node, want: String) -> Array:
	var out: Array = []
	if node.name == want:
		out.append(node)
	for child in node.get_children():
		out.append_array(_named(child, want))
	return out


func test_a_wet_region_draws_one_outline_mesh() -> void:
	var world := F.world()
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		world.hazards.spawn("wet", cell, SimHazardField.FOREVER)
	var renderer := _rendered(world)
	assert_int(_named(renderer, "WaterBody").size()).override_failure_message(
		"three wet cells should draw one puddle, not three tiles").is_equal(1)


func test_two_wet_regions_draw_two_bodies() -> void:
	var world := F.world()
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(6, 6)]:
		world.hazards.spawn("wet", cell, SimHazardField.FOREVER)
	var renderer := _rendered(world)
	assert_int(_named(renderer, "WaterBody").size()).override_failure_message(
		"a detached puddle needs its own body").is_equal(2)


func test_the_waterline_follows_the_outline() -> void:
	var world := F.world()
	for cell in [Vector2i(1, 1), Vector2i(2, 1)]:
		world.hazards.spawn("wet", cell, SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var bodies := _named(renderer, "WaterBody")
	var lines := _named(renderer, "Waterline")
	assert_int(bodies.size()).override_failure_message(
		"two wet cells should draw one body").is_equal(1)
	assert_int(lines.size()).override_failure_message(
		"the water's edge has no waterline").is_equal(1)
	if bodies.size() == 1 and lines.size() == 1:
		var body_box: AABB = (bodies[0] as MeshInstance3D).mesh.get_aabb()
		var line_box: AABB = (lines[0] as MeshInstance3D).mesh.get_aabb()
		assert_bool(line_box.size.x > body_box.size.x and line_box.size.z > body_box.size.z) \
			.override_failure_message(
				"the waterline does not ring the body: %s vs %s" % [line_box, body_box]).is_true()


func test_growing_the_region_rebuilds_the_body() -> void:
	var world := F.world()
	for cell in [Vector2i(1, 1), Vector2i(2, 1)]:
		world.hazards.spawn("wet", cell, SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var first := _named(renderer, "WaterBody")
	assert_int(first.size()).override_failure_message("no body before the growth").is_equal(1)
	if first.size() != 1:
		return
	var before: Node = first[0]
	world.hazards.spawn("wet", Vector2i(1, 2), SimHazardField.FOREVER)
	renderer.sync(world, 0.1, 0.0)
	var second := _named(renderer, "WaterBody")
	assert_int(second.size()).override_failure_message("no body after the growth").is_equal(1)
	if second.size() != 1:
		return
	assert_bool(second[0] != before).override_failure_message(
		"the body did not rebuild when the region grew").is_true()


func test_the_sink_fills_then_overflows() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	F.goto(world, Vector2i(3, 2))
	F.act(world, "toggle", "sink", "toggle_wet_source")
	renderer.sync(world, 0.1, 0.0)
	var pour: Node = renderer.object_node("sink").get_node_or_null("PourStream")
	assert_object(pour).is_not_null()
	if pour == null:
		return
	var basin := pour.get_node_or_null("BasinFill") as MeshInstance3D
	var overflow: Node3D = pour.get_node_or_null("Overflow")
	assert_object(basin).is_not_null()
	assert_object(overflow).is_not_null()
	if basin == null or overflow == null:
		return
	assert_bool(overflow.visible).override_failure_message(
		"the sink overflows before it fills").is_false()
	var low := basin.position.y
	renderer.sync(world, 1.0, 0.0)
	assert_float(basin.position.y).override_failure_message(
		"the basin does not fill").is_greater(low)
	renderer.sync(world, 5.0, 0.0)
	assert_bool(overflow.visible).override_failure_message(
		"the sink never overflows").is_true()


func test_a_running_wet_source_pours() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_int(_named(renderer.object_node("sink"), "PourStream").size()) \
		.override_failure_message("the sink pours while it is off").is_equal(0)
	F.goto(world, Vector2i(3, 2))
	F.act(world, "toggle", "sink", "toggle_wet_source")
	renderer.sync(world, 0.1, 0.0)
	assert_int(_named(renderer.object_node("sink"), "PourStream").size()) \
		.override_failure_message("a running sink draws no stream").is_equal(1)
