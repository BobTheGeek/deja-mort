extends GdUnitTestSuite

## M4 tranche 1: the mood. docs/06 says it plainly — "the mood is a lighting rig,
## not an art skill". One light, real shadows, minimal ambient, desaturated
## palette with one warm accent, and the room sitting on a plinth in the dark.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


# --- brand colours come from the brand, not from a second copy ----------------

func test_a_visual_value_can_name_a_brand_token() -> void:
	var v := _visuals()
	assert_object(v.token("ACCENT")).is_equal(Brand.ACCENT)
	assert_object(v.token("BG_DARK")).is_equal(Brand.BG_DARK)


func test_an_unknown_token_is_loud_not_silent() -> void:
	assert_object(_visuals().token("NOT_A_TOKEN")).is_null()


func test_the_void_and_the_accent_are_tokens_not_hex() -> void:
	var raw := FileAccess.get_file_as_string(GameVisuals.PATH)
	assert_bool(raw.contains("\"$BG_DARK\"")) \
		.override_failure_message("the void should name $BG_DARK, not repeat its hex").is_true()
	assert_bool(raw.contains("\"$ACCENT\"")) \
		.override_failure_message("the warm accent should name $ACCENT").is_true()


func test_the_void_resolves_to_the_brand_ink() -> void:
	assert_object(_visuals().colour("void.color")).is_equal(Brand.BG_DARK)


func test_the_bulb_burns_the_brand_amber() -> void:
	assert_object(_visuals().colour("light.color")).is_equal(Brand.ACCENT)


# --- one light, per room, from data ------------------------------------------

func test_the_room_says_where_its_light_hangs() -> void:
	var lighting: Dictionary = F.world().room.get("lighting", {})
	assert_dict(lighting).override_failure_message("room_01_studio has no lighting block").is_not_empty()
	var bulb: Dictionary = lighting.get("bulb", {})
	assert_array(bulb.get("cell", [])).override_failure_message("the bulb has no cell").is_not_empty()
	assert_float(float(bulb.get("energy", 0.0))).is_greater(0.0)


func test_the_renderer_hangs_exactly_one_bulb() -> void:
	var renderer := _rendered()
	assert_int(_count_lights(renderer)).override_failure_message(
		"docs/06: one light source per room").is_equal(1)


func test_the_bulb_casts_real_shadows() -> void:
	var bulb := _first_light(_rendered())
	assert_object(bulb).is_not_null()
	assert_bool(bulb.shadow_enabled).is_true()


func test_killing_the_lights_darkens_the_bulb() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var lit_energy := _first_light(renderer).light_energy
	F.act(world, "toggle", "light_switch")
	renderer.sync(world, 0.1)
	assert_float(_first_light(renderer).light_energy).override_failure_message(
		"the switch did not change the light").is_less(lit_energy)


# --- the diorama ------------------------------------------------------------

## The room is a specimen case floating in darkness. It needs something to float.
func test_the_room_sits_on_a_plinth() -> void:
	assert_object(_rendered().find_child("Base", true, false)) \
		.override_failure_message("no diorama base under the room").is_not_null()


func test_the_plinth_is_wider_than_the_room() -> void:
	var world := F.world()
	var base := _rendered(world).find_child("Base", true, false) as MeshInstance3D
	assert_object(base).is_not_null()
	var size: Vector3 = (base.mesh as BoxMesh).size
	assert_float(size.x).is_greater(float(world.grid.width))
	assert_float(size.z).is_greater(float(world.grid.height))


# --- helpers ----------------------------------------------------------------

func _rendered(world: SimWorld = null) -> RoomRenderer:
	var w := world if world != null else F.world()
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(w, _visuals())
	return renderer


func _count_lights(node: Node) -> int:
	var total := 0
	if node is Light3D:
		total += 1
	for child in node.get_children():
		total += _count_lights(child)
	return total


func _first_light(node: Node) -> Light3D:
	if node is Light3D:
		return node
	for child in node.get_children():
		var found := _first_light(child)
		if found != null:
			return found
	return null
