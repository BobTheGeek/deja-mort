extends GdUnitTestSuite

## From Bob's playtest: "the attacker walks over and stands next to my character
## and then it just says 'lose'. That totally abandons the feel of the game. We
## need a brief attack and death animation, which should differ based on the
## room and manner of death."
##
## docs/06: "Deaths: stylized. A slump, a fall, the light flickers, fade to the
## loop counter. No blood, no gore."
##
## The sim already says how you died — TYPE_ATTACK carries the weapon and
## TYPE_DEATH carries the cause — and the rig carries twenty-four clips. Nothing
## presentation-side ever asked. The beat is a lookup from cause to clips, with
## the room allowed the last word, and it decides nothing: the sim has already
## ended the loop before the first frame of it plays.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")
const RIG := "res://assets/models/quaternius/Casual_2.gltf"


func _visuals() -> GameVisuals:
	return GameVisuals.load_table()


# --- the lookup --------------------------------------------------------------

func test_a_death_has_a_beat_at_all() -> void:
	var beat := DeathBeat.resolve(_visuals(), {}, "stabbed")
	assert_str(str(beat.get("victim_clip", ""))).override_failure_message(
		"no clip for the person dying").is_not_empty()
	assert_float(float(beat.get("hold_s", 0.0))).override_failure_message(
		"the loop resets before you can see anything").is_greater(1.2)


func test_the_manner_of_death_changes_it() -> void:
	var v := _visuals()
	var stabbed := DeathBeat.resolve(v, {}, "stabbed")
	var electrocuted := DeathBeat.resolve(v, {}, "electrocuted")
	assert_str(str(stabbed)).override_failure_message(
		"every death plays the same beat").is_not_equal(str(electrocuted))


## Dying to your own trap has no one swinging at you.
func test_a_death_with_no_killer_has_no_swing() -> void:
	var beat := DeathBeat.resolve(_visuals(), {}, "electrocuted")
	assert_str(str(beat.get("attacker_clip", ""))).override_failure_message(
		"something is swinging at a man who touched a live wire").is_empty()


func test_the_room_gets_the_last_word() -> void:
	var room := {"death": {"by_cause": {"stabbed": {"hold_s": 9.5}}}}
	assert_float(float(DeathBeat.resolve(_visuals(), room, "stabbed").get("hold_s", 0.0))) \
		.override_failure_message("a room cannot stage its own death").is_equal(9.5)


func test_an_unknown_cause_still_gets_a_death() -> void:
	var beat := DeathBeat.resolve(_visuals(), {}, "trampled_by_horses")
	assert_str(str(beat.get("victim_clip", ""))).is_not_empty()
	assert_float(float(beat.get("hold_s", 0.0))).is_greater(1.2)


## Every way the content can kill you, staged. A cause with no entry falls back,
## and a silent fallback is how "it just says lose" happened in the first place.
func test_every_cause_the_content_can_produce_is_staged() -> void:
	var by_cause: Dictionary = _visuals().get_value("death.by_cause", {})
	var missing := PackedStringArray()
	for cause in _causes_in_content():
		if not by_cause.has(cause):
			missing.append(cause)
	assert_array(Array(missing)).override_failure_message(
		"these deaths have no beat: %s" % [missing]).is_empty()


func test_every_clip_it_names_is_really_on_the_rig() -> void:
	var clips := _rig_clips()
	var missing := PackedStringArray()
	var by_cause: Dictionary = _visuals().get_value("death.by_cause", {})
	for cause in by_cause:
		var beat := DeathBeat.resolve(_visuals(), {}, str(cause))
		for key in ["attacker_clip", "victim_clip"]:
			var clip := str(beat.get(key, ""))
			if not clip.is_empty() and not clips.has(clip):
				missing.append("%s.%s = %s" % [cause, key, clip])
	assert_array(Array(missing)).override_failure_message(
		"clips that do not exist: %s" % [missing]).is_empty()


# --- the renderer ------------------------------------------------------------

func test_the_renderer_can_be_told_to_play_one_clip_once() -> void:
	var world := F.world()
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	renderer.sync(world, 0.1, 0.0)
	renderer.play_once(world.player.id, "Punch_Right", 1.0)
	renderer.sync(world, 0.1, 0.0)
	assert_str(renderer.current_clip(world.player.id)).override_failure_message(
		"the swing never plays; idle wins").is_equal("Punch_Right")
	renderer.sync(world, 1.2, 0.0)
	assert_str(renderer.current_clip(world.player.id)).override_failure_message(
		"the swing never ends").is_not_equal("Punch_Right")


func test_the_body_plays_the_clip_its_cause_asks_for() -> void:
	var world := F.world()
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	world.kill_actor(world.player, "electrocuted", "test")
	renderer.sync(world, 0.1, 0.0)
	var wanted := str(DeathBeat.resolve(_visuals(), world.room, "electrocuted").get("victim_clip", ""))
	assert_str(renderer.current_clip(world.player.id)).override_failure_message(
		"electrocution plays the generic death").is_equal(wanted)


# --- helpers -----------------------------------------------------------------

func _causes_in_content() -> PackedStringArray:
	var out := PackedStringArray()
	var systems: Dictionary = F.content().systems
	var weapons: Dictionary = (systems.get("attacker", {}) as Dictionary).get("weapon_death_cause", {})
	for weapon in weapons:
		out.append(str(weapons[weapon]))
	for raw in F.content().rules:
		for effect in (raw as Dictionary).get("effects", []):
			var e: Dictionary = effect
			if e.get("op", "") == "damage" and e.has("cause") and not out.has(str(e["cause"])):
				out.append(str(e["cause"]))
	var hazards: Dictionary = systems.get("hazard_effects", {})
	for layer in hazards:
		var spec: Dictionary = hazards[layer]
		if spec.has("status") and spec.has("lethal_to") and not out.has(str(spec["status"])):
			out.append(str(spec["status"]))
	return out


func _rig_clips() -> PackedStringArray:
	var inst := (load(RIG) as PackedScene).instantiate()
	var player := _find_player(inst)
	var names := player.get_animation_list() if player != null else PackedStringArray()
	inst.free()
	return names


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


## docs/06: "a slump, a fall, the light flickers". A value in the table that
## nothing reads is a promise nobody keeps.
func test_the_light_flickers_for_the_deaths_that_ask_for_it() -> void:
	var world := F.world()
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	var beat := DeathBeat.resolve(_visuals(), world.room, "electrocuted")
	assert_float(float(beat.get("light_flicker", 0.0))).override_failure_message(
		"electrocution is the one death that should touch the lights").is_greater(0.0)
	renderer.flicker(float(beat["light_flicker"]))
	renderer.sync(world, 0.05, 0.0)
	assert_bool(renderer.is_flickering()).is_true()
	renderer.sync(world, float(beat["light_flicker"]) + 0.1, 0.0)
	assert_bool(renderer.is_flickering()).override_failure_message(
		"the bulb never settles again").is_false()


func test_a_quiet_death_leaves_the_lights_alone() -> void:
	var world := F.world()
	var renderer: RoomRenderer = auto_free(RoomRenderer.new())
	renderer.build(world, _visuals())
	renderer.flicker(float(DeathBeat.resolve(_visuals(), world.room, "stabbed").get("light_flicker", 0.0)))
	assert_bool(renderer.is_flickering()).override_failure_message(
		"a knife in a dark room should not strobe").is_false()


## The banner is the last beat, not the first. Naming the ending across the
## middle of the swing is what made a death read as a spreadsheet entry.
func test_the_word_comes_after_the_beat_not_across_it() -> void:
	var v := _visuals()
	var tail := v.number("death.banner_last_s", 0.0)
	assert_float(tail).override_failure_message(
		"nothing reserves time for the ending to be named").is_greater(0.0)
	var by_cause: Dictionary = v.get_value("death.by_cause", {})
	for cause in by_cause:
		var hold := float(DeathBeat.resolve(v, {}, str(cause)).get("hold_s", 0.0))
		assert_float(tail).override_failure_message(
			"'%s' holds %.1fs, which leaves no beat before the %.1fs banner" % [cause, hold, tail]) \
			.is_less(hold * 0.5)
