extends GdUnitTestSuite

## game/ is presentation. These guard the two rules that keep it that way: the
## look is data, and no object is ever named.

const F := preload("res://tests/support/sim_fixture.gd")
const GAME_DIR := "res://game"


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func test_the_visual_table_loads_and_covers_what_the_renderer_needs() -> void:
	var v := _visuals()
	assert_dict(v.data).is_not_empty()
	for block in ["camera", "light", "floor", "wall", "actor", "object", "state_visual", "hazard", "wheel", "hud"]:
		assert_object(v.get_value(block, null)) \
			.override_failure_message("visuals.json is missing '%s'" % block).is_not_null()


## Every layer has a look except `concealed`, whose documented visual is none —
## a hazard hidden under a rug that still drew a marker would be no use at all.
func test_every_hazard_layer_has_a_look_except_the_hidden_one() -> void:
	var layers: Dictionary = _visuals().get_value("hazard.layers", {})
	for layer in SimHazardField.LAYERS:
		if layer == "concealed":
			assert_bool(layers.has(layer)) \
				.override_failure_message("concealed must draw nothing").is_false()
			continue
		assert_bool(layers.has(layer)) \
			.override_failure_message("no visual for hazard layer '%s'" % layer).is_true()


func test_every_wheel_slot_in_verbs_json_has_an_angle() -> void:
	var v := _visuals()
	var angles: Dictionary = v.get_value("wheel.slot_angles_deg", {})
	for entry in F.content().verbs:
		var slot := str((entry as Dictionary).get("slot", ""))
		if slot == "center":
			continue
		assert_bool(angles.has(slot)) \
			.override_failure_message("verb slot '%s' has no wheel angle" % slot).is_true()


## The hard rule, enforced rather than trusted: presentation may key off tags and
## state, never off an object id.
func test_no_object_id_appears_in_the_visual_table_or_in_game_code() -> void:
	# An id that is also a tag name proves nothing — `window` is both a Room 1
	# object and a tag in tags.json, and a tag in the visual table is the point.
	var tags := F.content().tags
	var ids := PackedStringArray()
	for obj in F.room_data().get("objects", []):
		var id := str((obj as Dictionary).get("id", ""))
		if not id.is_empty() and not tags.has(id):
			ids.append(id)
	var offenders := PackedStringArray()
	var sources := PackedStringArray([GameVisuals.PATH, AudioDirector.MAP_PATH])
	sources.append_array(_gd_files(GAME_DIR))
	for path in sources:
		var text := FileAccess.get_file_as_string(path)
		for id in ids:
			if text.contains('"%s"' % id):
				offenders.append("%s names %s" % [path, id])
	assert_array(Array(offenders)).override_failure_message(
		"presentation must not name objects: %s" % [offenders]).is_empty()


func test_an_object_look_is_built_from_its_tags() -> void:
	var v := _visuals()
	var plain := v.object_look(PackedStringArray([]))
	var hideable := v.object_look(PackedStringArray(["hides-player"]))
	assert_float(float(hideable["height"])).is_greater(float(plain["height"]))
	var carried := v.object_look(PackedStringArray(["carryable"]))
	assert_float(float(carried["height"])).is_less(float(plain["height"]))


func test_the_same_tags_always_resolve_to_the_same_look() -> void:
	var v := _visuals()
	var tags := PackedStringArray(["movable", "heavy", "container"])
	assert_str(JSON.stringify(v.object_look(tags), "", true)) \
		.is_equal(JSON.stringify(v.object_look(tags), "", true))


func test_state_overrides_the_base_look() -> void:
	var v := _visuals()
	var base := v.object_look(PackedStringArray(["flammable"]))
	var alight := v.apply_state(base, {"burning": true})
	assert_float(float(alight.get("emission", 0.0))).is_greater(0.0)
	assert_array(alight["color"]).is_not_equal(base["color"])


func test_a_false_state_changes_nothing() -> void:
	var v := _visuals()
	var base := v.object_look(PackedStringArray(["flammable"]))
	assert_str(JSON.stringify(v.apply_state(base, {"burning": false}), "", true)) \
		.is_equal(JSON.stringify(base, "", true))


func test_a_grid_cell_maps_to_the_centre_of_its_tile() -> void:
	assert_vector(IsoCamera.cell_to_world(Vector2i(3, 4))).is_equal(Vector3(3.5, 0.0, 4.5))


func _gd_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	out.sort()
	return out
