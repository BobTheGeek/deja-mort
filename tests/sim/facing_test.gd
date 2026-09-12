extends GdUnitTestSuite

## From Bob's playtest: "the characters don't often face the correct way. The
## character should always face the object they are interacting with."
##
## `facing` was only ever written while walking, so it kept whatever direction
## the last step happened to be — usually not the thing being acted on, and
## never right for an object you were already standing next to.
##
## Facing is sim state, not presentation: the attacker's perception is entitled
## to know which way someone is turned.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")


func test_you_turn_to_face_what_you_act_on() -> void:
	var world := F.world()
	assert_bool(F.act(world, "toggle", "floor_lamp")).is_true()
	_assert_faces(world.player, Vector2i(7, 5), "the floor lamp")


## The bad case: no walking happens at all, so nothing used to set facing.
func test_you_turn_even_when_you_do_not_have_to_walk() -> void:
	var world := F.world()
	assert_bool(F.goto(world, Vector2i(6, 6))).is_true()
	var before := world.player.facing
	assert_bool(F.act(world, "toggle", "tv")).is_true()
	_assert_faces(world.player, Vector2i(6, 7), "the television")
	assert_str(str(world.player.facing)).override_failure_message(
		"facing never changed; it is still %s" % [before]).is_not_equal(str(before))


func test_acting_on_a_cell_turns_you_to_the_cell() -> void:
	var world := F.world()
	F.give(world, "floor_lamp")
	assert_bool(F.goto(world, Vector2i(6, 5))).is_true()
	assert_bool(F.act(world, "drop", Vector2i(6, 4))).is_true()
	_assert_faces(world.player, Vector2i(6, 4), "the cell it was dropped on")


## A two-cell object is faced at the part of it you are standing next to, not
## at some far corner.
func test_a_wide_object_is_faced_at_the_nearest_part_of_it() -> void:
	var world := F.world()
	assert_bool(F.act(world, "push", "couch")).is_true()
	var facing := world.player.facing
	assert_int(absi(facing.x) + absi(facing.y)).override_failure_message(
		"facing %s is not one square step" % [facing]).is_equal(1)


func test_walking_still_faces_the_way_you_walk() -> void:
	var world := F.world()
	assert_bool(F.goto(world, Vector2i(6, 3))).is_true()
	_assert_faces(world.player, Vector2i(6, 2), "the way it was walking")


func test_he_turns_to_the_player_before_he_swings() -> void:
	var world := F.world()
	var victim := world.player
	world.step_seconds(2.0)
	assert_object(world.attacker).is_not_null()
	while world.attacker != null and not world.attacker.inside and world.time_s() < 60.0:
		world.step()
	if world.attacker == null or not world.attacker.inside:
		return
	while world.player.alive and world.time_s() < 120.0:
		world.step()
	assert_bool(victim.alive).override_failure_message(
		"he never got there, so there is nothing to face").is_false()
	_assert_faces(world.attacker, victim.pos, "the player he just killed")


# --- helpers -----------------------------------------------------------------

## One square step towards the target, which is what `facing` holds.
func _assert_faces(actor: SimActor, cell: Vector2i, what: String) -> void:
	var delta := cell - actor.pos
	var wanted := Vector2i(signi(delta.x), signi(delta.y))
	if absi(delta.x) > absi(delta.y):
		wanted = Vector2i(signi(delta.x), 0)
	elif absi(delta.y) > absi(delta.x):
		wanted = Vector2i(0, signi(delta.y))
	assert_str(str(actor.facing)).override_failure_message(
		"stood at %s it should face %s towards %s, but faces %s" % [
			actor.pos, wanted, what, actor.facing]).is_equal(str(wanted))
