extends GdUnitTestSuite

## M4, the last of it. docs/06's state → visual table, in full:
## burning gets fire and an orange light, `on` gets a light child, concealed
## gets nothing at all, and a downed figure changes pose instead of just tipping
## over.
##
## Particles are CPUParticles3D on purpose: the project falls back to GL
## Compatibility on mobile, where GPU particles are not dependable.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	return renderer


# --- concealed means concealed ------------------------------------------------

## The whole point of hiding a hazard under a rug is that it stops being visible.
## docs/06 spells out the visual for `concealed`: none.
func test_a_concealed_hazard_draws_nothing() -> void:
	assert_object(_visuals().get_value("hazard.layers.concealed", null)) \
		.override_failure_message("concealed still has a look; that defeats the rug").is_null()


func test_covering_a_hazard_removes_its_marker() -> void:
	var world := F.world()
	F.give(world, "cooking_oil")
	F.act(world, "use-held-on", Vector2i(1, 3), "pour_slippery")
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var before := _hazard_patches(renderer)
	F.goto(world, Vector2i(3, 3))
	F.act(world, "push", "rug", "push")
	renderer.sync(world, 0.1)
	assert_bool(world.hazards.has("concealed", Vector2i(1, 3))).is_true()
	assert_int(_hazard_patches(renderer)).override_failure_message(
		"concealing a hazard should not add a patch").is_less_equal(before)


# --- particles ----------------------------------------------------------------

func test_the_lively_hazards_declare_particles() -> void:
	var layers: Dictionary = _visuals().get_value("hazard.layers", {})
	for layer in ["burning", "shock", "wet"]:
		assert_bool((layers.get(layer, {}) as Dictionary).has("particles")) \
			.override_failure_message("%s has no particles" % layer).is_true()


func test_a_burning_cell_catches_fire_on_screen() -> void:
	var world := F.world()
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	assert_int(_particle_systems(renderer)).override_failure_message(
		"a burning cell produced no fire").is_greater(0)


func test_particles_are_cpu_driven_for_the_mobile_fallback() -> void:
	var world := F.world()
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	for node in _all(renderer):
		assert_bool(node is GPUParticles3D).override_failure_message(
			"GPU particles are not dependable on the GL Compatibility fallback").is_false()


func test_a_hazard_that_goes_out_takes_its_particles_with_it() -> void:
	var world := F.world()
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	assert_int(_particle_systems(renderer)).is_greater(0)
	world.hazards.clear("burning", Vector2i(5, 5))
	renderer.sync(world, 0.1)
	assert_int(_particle_systems(renderer)).override_failure_message(
		"the fire went out but the flames stayed").is_equal(0)


# --- light that comes from the room, not the rig -------------------------------

## docs/06: `on` gets a light child, `burning` gets an orange point light. The
## room still has exactly one *bulb*; these are things in the room glowing.
func test_switching_something_on_lights_it() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var before := _lights(renderer)
	F.act(world, "toggle", "tv", "toggle_on")
	renderer.sync(world, 0.1)
	assert_int(_lights(renderer)).override_failure_message(
		"turning the television on lit nothing").is_greater(before)


func test_a_burning_cell_glows() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var before := _lights(renderer)
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	renderer.sync(world, 0.1)
	assert_int(_lights(renderer)).override_failure_message(
		"fire should cast light").is_greater(before)


# --- poses --------------------------------------------------------------------

## There is a rig now, so being knocked down is a pose and not a rotation.
func test_a_downed_figure_changes_pose() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var node: Node3D = renderer.actor_node(world.player.id)
	var standing := _animation_player(node).current_animation
	world.apply_status(world.player, "prone", 3.0, "test")
	renderer.sync(world, 0.1)
	assert_str(_animation_player(node).current_animation) \
		.override_failure_message("a downed figure is still in its standing pose") \
		.is_not_equal(standing)


func test_the_collectible_is_worth_spotting() -> void:
	var look := _visuals().object_look(PackedStringArray(["collectible", "carryable"]))
	assert_float(float(look.get("emission", 0.0))).override_failure_message(
		"the one hidden thing in the room should catch the light").is_greater(0.0)


# --- helpers ------------------------------------------------------------------

func _hazard_patches(node: Node) -> int:
	var total := 0
	for child in _all(node):
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh \
				and str(child.name).begins_with("hazard:"):
			total += 1
	return total


func _particle_systems(node: Node) -> int:
	var total := 0
	for child in _all(node):
		if child is CPUParticles3D:
			total += 1
	return total


func _lights(node: Node) -> int:
	var total := 0
	for child in _all(node):
		if child is Light3D:
			total += 1
	return total


func _animation_player(node: Node) -> AnimationPlayer:
	for child in _all(node):
		if child is AnimationPlayer:
			return child
	return null


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
