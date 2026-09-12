extends GdUnitTestSuite

## Figures moved in steps because presentation eased toward the cell the actor
## had already reached, so it decelerated into every tile and then jumped to the
## next. The sim already knows walk_progress, the path ahead and which way the
## actor faces; this is presentation finally reading them.
##
## docs/02 §3: "Presentation interpolates between ticks."
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, GameVisuals.load_table())
	return renderer


func test_a_still_actor_stands_on_its_cell() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	assert_vector(node.position).is_equal_approx(
		IsoCamera.cell_to_world(world.player.pos, 0.0), Vector3.ONE * 0.02)


## Halfway between two tiles means halfway on screen, not most of the way to one.
func test_an_actor_mid_step_renders_between_the_two_cells() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var from := world.player.pos
	var to := from + Vector2i(1, 0)
	world.player.path = [to] as Array[Vector2i]
	world.player.walk_progress = 0.5
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	var midpoint := IsoCamera.cell_to_world(from, 0.0).lerp(IsoCamera.cell_to_world(to, 0.0), 0.5)
	assert_vector(node.position).override_failure_message(
		"halfway between %s and %s should render at %s, got %s" % [from, to, midpoint, node.position]) \
		.is_equal_approx(midpoint, Vector3.ONE * 0.06)


func test_progress_drives_the_position_monotonically() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var from := world.player.pos
	var to := from + Vector2i(1, 0)
	world.player.path = [to] as Array[Vector2i]
	var last := -1.0
	for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
		world.player.walk_progress = progress
		renderer.sync(world, 0.1)
		var node: Node3D = renderer.actor_node(world.player.id)
		var travelled := node.position.distance_to(IsoCamera.cell_to_world(from, 0.0))
		assert_float(travelled).override_failure_message(
			"progress %.2f did not move the figure further along" % progress).is_greater(last)
		last = travelled


## The renderer is told how far through the current tick it is, so a 10 Hz sim
## still moves smoothly at 60 frames a second.
func test_the_renderer_takes_a_tick_fraction() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var from := world.player.pos
	world.player.path = [from + Vector2i(1, 0)] as Array[Vector2i]
	world.player.walk_progress = 0.0

	renderer.sync(world, 0.0, 0.0)
	var node: Node3D = renderer.actor_node(world.player.id)
	var at_start := node.position

	renderer.sync(world, 0.0, 0.9)
	assert_vector(node.position).override_failure_message(
		"the tick fraction did not move the figure").is_not_equal(at_start)


func test_a_walking_figure_faces_where_it_is_going() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var node: Node3D = renderer.actor_node(world.player.id)

	world.player.facing = Vector2i(1, 0)
	for i in 30:
		renderer.sync(world, 0.1)
	var east := node.rotation_degrees.y

	world.player.facing = Vector2i(0, 1)
	for i in 30:
		renderer.sync(world, 0.1)
	assert_float(node.rotation_degrees.y).override_failure_message(
		"the figure faces the same way going east and going south").is_not_equal(east)


func test_the_game_passes_its_tick_fraction_through() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_bool(source.contains("_accumulator / _tick_seconds")) \
		.override_failure_message("main.gd computes a tick fraction but never hands it over").is_true()
