extends GdUnitTestSuite

## M4's acceptance line is "every object state has a visual", and it was not met:
## you lock the front door, put the chain on, shove the fridge against it, and
## nothing on screen changes. Three facts the player acts on and cannot see.
##
## Every state now either has a look or is on a declared list of states that
## deliberately have none — so the exceptions are reviewable rather than
## accidental, which is the difference between a decision and an oversight.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


func _rendered(world: SimWorld) -> RoomRenderer:
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	renderer.sync(world, 0.1, 0.0)
	return renderer


# --- coverage ----------------------------------------------------------------

## The acceptance line, as a test.
func test_every_state_in_the_room_has_a_look_or_is_on_the_list() -> void:
	var v := _visuals()
	var table: Dictionary = v.get_value("state_visual", {})
	var declared_none: Array = v.get_value("state_visual_none", [])
	var uncovered := PackedStringArray()
	for obj in F.world().objects.all():
		for key in obj.state:
			var name := str(key)
			if table.has(name) or declared_none.has(name):
				continue
			# A state nobody decided about.
			if not uncovered.has(name):
				uncovered.append(name)
	assert_array(Array(uncovered)).override_failure_message(
		"states with no look and no decision: %s" % [uncovered]).is_empty()


func test_the_states_that_have_no_look_say_why_in_the_table() -> void:
	var v := _visuals()
	assert_array(v.get_value("state_visual_none", [])).override_failure_message(
		"the exceptions list is empty, which means either everything is drawn or "
		+ "nobody wrote the list").is_not_empty()
	assert_str(str(v.get_value("state_visual_none_comment", ""))).override_failure_message(
		"a list of exceptions with no reason attached is just a list").is_not_empty()


# --- the three that matter ---------------------------------------------------

func test_locking_a_door_changes_the_door() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_object(_marker(renderer, "front_door")).override_failure_message(
		"an unlocked door is already showing a lock").is_null()
	assert_bool(F.act(world, "toggle", "front_door", "toggle_lock")).override_failure_message(
		"could not lock the front door").is_true()
	renderer.sync(world, 0.1, 0.0)
	assert_object(_marker(renderer, "front_door")).override_failure_message(
		"the door is locked and nothing on screen says so").is_not_null()


func test_unlocking_it_takes_the_mark_away_again() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(F.act(world, "toggle", "front_door", "toggle_lock")).is_true()
	renderer.sync(world, 0.1, 0.0)
	assert_object(_marker(renderer, "front_door")).is_not_null()
	assert_bool(F.act(world, "toggle", "front_door", "toggle_lock")).is_true()
	renderer.sync(world, 0.1, 0.0)
	assert_object(_marker(renderer, "front_door")).override_failure_message(
		"the door is unlocked and still wearing a lock").is_null()


func test_the_chain_shows_when_it_is_on() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(F.act(world, "toggle", "door_chain", "toggle_chain")).is_true()
	renderer.sync(world, 0.1, 0.0)
	assert_object(_marker(renderer, "door_chain")).override_failure_message(
		"the chain is across the door and invisible").is_not_null()


## Bracing is the heaviest thing you can do to a door and had no look at all.
func test_a_braced_door_looks_braced() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	var door := world.objects.by_id("front_door")
	door.set_state("braced_by", "fridge")
	renderer.sync(world, 0.1, 0.0)
	assert_object(_marker(renderer, "front_door")).override_failure_message(
		"the fridge is against the door and nothing shows it").is_not_null()


# --- the look itself ---------------------------------------------------------

func test_a_marker_is_a_brand_colour_and_not_a_new_one() -> void:
	var v := _visuals()
	var table: Dictionary = v.get_value("state_visual", {})
	var wrong := PackedStringArray()
	for key in table:
		var spec: Variant = (table[key] as Dictionary).get("marker", null)
		if spec == null:
			continue
		var colour: Variant = (spec as Dictionary).get("color", null)
		if not (colour is String) or not str(colour).begins_with("$"):
			wrong.append("%s: %s" % [key, colour])
	assert_array(Array(wrong)).override_failure_message(
		"markers using a colour that is not a brand token: %s" % [wrong]).is_empty()


func test_the_mark_sits_on_the_thing_it_is_about() -> void:
	var world := F.world()
	var renderer := _rendered(world)
	assert_bool(F.act(world, "toggle", "front_door", "toggle_lock")).is_true()
	renderer.sync(world, 0.1, 0.0)
	var marker := _marker(renderer, "front_door")
	var door := renderer.object_node("front_door")
	# Off the scene tree there is no global transform; the marker is a child, so
	# its place in the room is the door's position plus its own offset.
	var at := door.position + marker.position
	assert_float(Vector2(at.x - door.position.x, at.z - door.position.z).length()) \
		.override_failure_message("the mark is not over its door: %s" % [at]).is_less(0.6)
	assert_float(at.y).override_failure_message(
		"the mark is on the floor or through the ceiling: y=%.2f" % at.y).is_between(0.3, 2.4)


func _marker(renderer: RoomRenderer, id: String) -> Node3D:
	var node := renderer.object_node(id)
	if node == null:
		return null
	for child in node.get_children():
		if child.name == RoomRenderer.STATE_MARKER:
			return child as Node3D
	return null
