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
	for layer in ["burning", "shock", "wet", "dust"]:
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


## First Light §4: the shelf landing puffs dust through the hazard layer —
## visual only, no gameplay effect (not in HAZARD_LAYERS, not in hazard_effects).
func test_a_dust_cell_puffs_on_screen() -> void:
	var world := F.world()
	world.hazards.spawn("dust", Vector2i(1, 3), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	assert_int(_particle_systems(renderer)).override_failure_message(
		"a dust cell produced no puff").is_greater(0)


## Found by the First Light acceptance shots: CPUParticles3D draws nothing
## without a mesh (`mesh` has no default), so every hazard particle since M4 —
## water, fire, shock, gas — was invisible. Nodes were counted; pixels were not.
func test_particles_have_a_mesh_to_draw_with() -> void:
	var world := F.world()
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var counted := 0
	for node in _all(renderer):
		if node is CPUParticles3D:
			counted += 1
			assert_object((node as CPUParticles3D).mesh).override_failure_message(
				"a CPUParticles3D with no mesh draws nothing").is_not_null()
	assert_int(counted).override_failure_message("no particle system to inspect").is_greater(0)


## Review minor: particle materials must follow the layer spec — translucent
## for dust and water, unshaded only where something glows.
func test_particle_materials_follow_the_spec() -> void:
	var world := F.world()
	world.hazards.spawn("burning", Vector2i(5, 5), SimHazardField.FOREVER)
	world.hazards.spawn("dust", Vector2i(1, 3), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var fire := _hazard_particles(renderer, "burning", Vector2i(5, 5))
	var dust := _hazard_particles(renderer, "dust", Vector2i(1, 3))
	assert_object(fire).is_not_null()
	assert_object(dust).is_not_null()
	var fire_mat := fire.material_override as StandardMaterial3D
	var dust_mat := dust.material_override as StandardMaterial3D
	assert_bool(fire_mat != null and fire_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED) \
		.override_failure_message("fire should glow unshaded: %s" % [fire_mat]).is_true()
	assert_bool(dust_mat != null and dust_mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED) \
		.override_failure_message("dust should take the room light, not glow: %s" % [dust_mat]).is_true()
	assert_bool(dust_mat != null and dust_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA) \
		.override_failure_message("dust should be translucent: %s" % [dust_mat]).is_true()
	assert_bool(dust_mat != null and dust_mat.albedo_color.a < 1.0) \
		.override_failure_message("dust alpha is not below 1: %s" % [dust_mat]).is_true()


## Review minor: one mesh and one material per (alpha, shading) for the whole
## room, not a fresh pair for every hazard cell.
func test_particle_resources_are_shared_across_cells() -> void:
	var world := F.world()
	world.hazards.spawn("wet", Vector2i(1, 1), SimHazardField.FOREVER)
	world.hazards.spawn("wet", Vector2i(2, 1), SimHazardField.FOREVER)
	var renderer := _rendered(world)
	renderer.sync(world, 0.1)
	var a := _hazard_particles(renderer, "wet", Vector2i(1, 1))
	var b := _hazard_particles(renderer, "wet", Vector2i(2, 1))
	assert_object(a).is_not_null()
	assert_object(b).is_not_null()
	assert_bool(a.mesh == b.mesh).override_failure_message(
		"particle meshes are not shared across cells").is_true()
	assert_bool(a.material_override == b.material_override).override_failure_message(
		"particle materials are not shared across cells").is_true()


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


## The particle system attached to one cell's hazard patch, for material
## checks. Patch nodes are named "hazard_<layer>_<x>,<y>" — Godot sanitizes
## the colon and @ out of node names.
func _hazard_particles(node: Node, layer: String, cell: Vector2i) -> CPUParticles3D:
	var wanted := "hazard_%s_%d,%d" % [layer, cell.x, cell.y]
	for child in _all(node):
		if child is MeshInstance3D and str(child.name) == wanted:
			for sub in child.get_children():
				if sub is CPUParticles3D:
					return sub as CPUParticles3D
	return null


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
