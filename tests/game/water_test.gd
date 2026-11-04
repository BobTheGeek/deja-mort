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
	assert_object(overflow.get_node_or_null("SplashRing")).override_failure_message(
		"the spill lands with no ripple rings").is_not_null()


## Water pools against furniture bases: the sim cannot mark an occupied cell
## wet, but the drawn region creeps one cell under it, or the puddle visibly
## stops short of the cabinet it just ran down.
func test_water_pools_against_furniture_bases() -> void:
	var world := F.world()
	world.hazards.spawn("wet", Vector2i(4, 2), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var bodies := _named(renderer, "WaterBody")
	assert_int(bodies.size()).is_equal(1)
	if bodies.size() != 1:
		return
	var box: AABB = (bodies[0] as MeshInstance3D).mesh.get_aabb()
	assert_float(box.size.z).override_failure_message(
		"the puddle stops short of the sink instead of pooling under it: %s" % [box]).is_greater(1.4)


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


## COLD PAINT: the water is painted, not lit. A lit blue under the amber bulb
## and the 0.55 saturation grade is exactly the mauve the target is not; an
## unshaded sheet at 0.85 opacity keeps the floor from showing through.
func test_the_water_is_painted_not_lit() -> void:
	var world := F.world()
	world.hazards.spawn("wet", Vector2i(1, 1), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var bodies := _named(renderer, "WaterBody")
	assert_int(bodies.size()).is_equal(1)
	if bodies.size() != 1:
		return
	var material := (bodies[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_object(material).is_not_null()
	if material == null:
		return
	assert_int(material.shading_mode).override_failure_message(
		"the puddle takes the room light, so the amber bulb tints it").is_equal(
			BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_float(material.albedo_color.a).override_failure_message(
		"the floor shows through the paint: alpha %f" % material.albedo_color.a) \
		.is_greater_equal(0.8)


## The foam edge is a brush stroke: the strip texture carries the bright core,
## the soft halo and the broken dashes the target's waterline has.
func test_the_foam_edge_carries_the_brush_texture() -> void:
	var world := F.world()
	world.hazards.spawn("wet", Vector2i(1, 1), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var lines := _named(renderer, "Waterline")
	assert_int(lines.size()).is_equal(1)
	if lines.size() != 1:
		return
	var material := (lines[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_object(material).is_not_null()
	if material == null:
		return
	assert_object(material.albedo_texture).override_failure_message(
		"the foam edge is bare geometry with no brush texture").is_not_null()


## Darkness is gameplay: painted or not, the water still lives in the room and
## must dip with the bulb instead of glowing like a lamp in the dark.
func test_the_water_dims_with_the_room() -> void:
	var world := F.world()
	world.hazards.spawn("wet", Vector2i(1, 1), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	var bodies := _named(renderer, "WaterBody")
	assert_int(bodies.size()).is_equal(1)
	if bodies.size() != 1:
		return
	var material := (bodies[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_object(material).is_not_null()
	if material == null:
		return
	var lit := material.albedo_color.r
	renderer._apply_lighting(false)
	var dark := material.albedo_color.r
	assert_float(dark).override_failure_message(
		"the puddle is a lamp: it stays bright when the room goes dark").is_less(lit)
	renderer._apply_lighting(true)
	assert_float(material.albedo_color.r).override_failure_message(
		"the water does not come back with the light").is_greater(dark)


## The pour hangs under the sink but is not part of its model: the sink's own
## `on` state repaint must not reach the water, or the cascade and the rings
## come out painted in the sink's colour with no whites at all — which is
## exactly what the capture comparison against the network found.
func test_the_pour_keeps_its_water_materials() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	F.goto(world, Vector2i(3, 2))
	F.act(world, "toggle", "sink", "toggle_wet_source")
	renderer.sync(world, 0.1, 0.0)
	renderer.sync(world, 3.0, 0.0)
	var pour: Node = renderer.object_node("sink").get_node_or_null("PourStream")
	assert_object(pour).is_not_null()
	if pour == null:
		return
	var overflow: Node3D = pour.get_node_or_null("Overflow")
	assert_object(overflow).is_not_null()
	if overflow == null:
		return
	var run := overflow.get_node_or_null("OverflowRun") as MeshInstance3D
	assert_object(run).is_not_null()
	if run == null:
		return
	assert_bool(run.material_override is ShaderMaterial).override_failure_message(
		"the sink's state repaint swallowed the cascade's own shader material").is_true()
	var ring := overflow.get_node_or_null("SplashRing") as MeshInstance3D
	assert_object(ring).is_not_null()
	if ring == null:
		return
	var ring_mat := ring.material_override as StandardMaterial3D
	assert_bool(ring_mat != null and ring_mat.albedo_texture != null) \
		.override_failure_message(
			"the rings lost their brush texture to the sink's repaint").is_true()


## A pour built while the room is already dark must arrive dimmed: the sheet's
## light level is only corrected on a lighting transition, and there is none
## while the room stays dark — so it must be set at birth.
func test_a_pour_born_in_the_dark_is_dimmed() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	F.goto(world, Vector2i(1, 7))
	F.act(world, "toggle", "light_switch", "toggle_light_switch")
	renderer.sync(world, 0.1, 0.0)
	F.goto(world, Vector2i(3, 2))
	F.act(world, "toggle", "sink", "toggle_wet_source")
	renderer.sync(world, 0.1, 0.0)
	var pour: Node = renderer.object_node("sink").get_node_or_null("PourStream")
	assert_object(pour).is_not_null()
	if pour == null:
		return
	var overflow: Node3D = pour.get_node_or_null("Overflow")
	assert_object(overflow).is_not_null()
	if overflow == null:
		return
	var run := overflow.get_node_or_null("OverflowRun") as MeshInstance3D
	assert_object(run).is_not_null()
	if run == null:
		return
	var sheet := run.material_override as ShaderMaterial
	assert_object(sheet).is_not_null()
	if sheet == null:
		return
	var level: Variant = sheet.get_shader_parameter("light_level")
	assert_bool(level != null and float(level) < 1.0).override_failure_message(
		"a pour born in the dark runs at full brightness: %s" % [level]).is_true()
