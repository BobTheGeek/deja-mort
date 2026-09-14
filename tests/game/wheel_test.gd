extends GdUnitTestSuite

## The wheel, rebuilt from Claude Design's turn-1 spec (docs/ui/SPEC.md,
## direction A — tiles on a ring). Bob's verdict on the old one was "not legible
## and needs a serious design pass"; it was nine default grey buttons in a ring.
##
## These are the claims the spec makes that code can be wrong about: where the
## slots are, that they stay on screen, that an unavailable slot is legibly
## unavailable rather than merely faint, that the cost of an action is visible
## without a tooltip, and that a refusal says so.
##
## Written before the implementation.

const F := preload("res://tests/support/sim_fixture.gd")
const VERB_COUNT := 9


func _wheel(world: SimWorld) -> ActionWheel:
	var wheel: ActionWheel = auto_free(ActionWheel.new())
	wheel.setup(GameVisuals.load_table(), world)
	return wheel


func _open(world: SimWorld, target: Variant = "fridge", at := Vector2(960, 540),
		index := 1, count := 1) -> ActionWheel:
	var wheel := _wheel(world)
	wheel.open_at(world, target, at, index, count)
	wheel.advance(1.0)          # let the open tween finish
	return wheel


# --- the table ---------------------------------------------------------------

## Every key the wheel reads must be in visuals.json. A silent fallback is how a
## design lands half-applied and nobody notices.
func test_the_table_carries_every_number_the_wheel_reads() -> void:
	var v := GameVisuals.load_table()
	var missing := PackedStringArray()
	for key in ActionWheel.REQUIRED_KEYS:
		if v.get_value("wheel." + str(key), null) == null:
			missing.append(str(key))
	assert_array(Array(missing)).override_failure_message(
		"visuals.json is missing wheel keys: %s" % [missing]).is_empty()


func test_every_verb_has_an_icon_on_disk() -> void:
	var missing := PackedStringArray()
	for entry in F.content().verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var path: String = GameVisuals.load_table().get_value("wheel.icon_path", "") % verb
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_array(Array(missing)).override_failure_message(
		"verbs with no icon: %s" % [missing]).is_empty()


# --- geometry ----------------------------------------------------------------

func test_the_slots_sit_where_the_spec_puts_them() -> void:
	var world := F.world()
	var wheel := _open(world)
	var v := GameVisuals.load_table()
	var radius := v.number("wheel.radius")
	var angles: Dictionary = v.get_value("wheel.slot_angles_deg", {})
	assert_int(wheel.verbs().size()).is_equal(VERB_COUNT)
	for entry in F.content().verbs:
		var verb := str((entry as Dictionary).get("id", ""))
		var slot := str((entry as Dictionary).get("slot", ""))
		var centre := wheel.slot_centre(verb)
		if slot == "center":
			assert_vector(centre).override_failure_message(
				"the centre verb is not in the centre").is_equal_approx(wheel.centre_point(), Vector2.ONE)
			continue
		var offset := centre - wheel.centre_point()
		assert_float(offset.length()).override_failure_message(
			"%s sits %.1f from the centre, not %.1f" % [verb, offset.length(), radius]) \
			.is_equal_approx(radius, 1.0)
		# Zero degrees is straight up and they run clockwise.
		var wanted := Vector2(sin(deg_to_rad(float(angles[slot]))), -cos(deg_to_rad(float(angles[slot]))))
		assert_float(offset.normalized().dot(wanted)).override_failure_message(
			"%s (%s) points the wrong way round the ring" % [verb, slot]).is_greater(0.99)


func test_no_two_slots_overlap_and_each_is_big_enough_for_a_thumb() -> void:
	var world := F.world()
	var wheel := _open(world)
	var v := GameVisuals.load_table()
	var size := v.number("wheel.slot_size")
	assert_float(size).override_failure_message(
		"a %.0fpx slot is under the 44dp touch minimum" % size).is_greater_equal(
			v.number("wheel.min_touch_target"))
	var verbs := wheel.verbs()
	for a in verbs:
		for b in verbs:
			if a == b:
				continue
			var gap := wheel.slot_centre(str(a)).distance_to(wheel.slot_centre(str(b)))
			var touching := (wheel.slot_size(str(a)) + wheel.slot_size(str(b))) * 0.5
			assert_float(gap).override_failure_message(
				"%s and %s overlap: %.1f apart, %.1f wide" % [a, b, gap, touching]).is_greater(touching)


func test_a_tap_lands_on_the_slot_you_aimed_at() -> void:
	var world := F.world()
	var wheel := _open(world)
	for verb in wheel.verbs():
		assert_str(wheel.verb_at(wheel.slot_centre(str(verb)))).override_failure_message(
			"tapping the middle of %s hits nothing" % verb).is_equal(str(verb))


func test_tapping_the_gap_outside_the_ring_dismisses_rather_than_guessing() -> void:
	var world := F.world()
	var wheel := _open(world)
	var far := wheel.centre_point() + Vector2(GameVisuals.load_table().number("wheel.radius") * 3.0, 0.0)
	assert_str(wheel.verb_at(far)).override_failure_message(
		"a tap well outside the ring chose a verb").is_empty()


# --- staying on screen -------------------------------------------------------

func test_the_wheel_stays_on_screen_when_you_tap_in_a_corner() -> void:
	var world := F.world()
	var v := GameVisuals.load_table()
	var frame := Vector2(v.number("ui.design_width", 1920.0), v.number("ui.design_height", 1080.0))
	var margin := v.number("wheel.edge_margin")
	for corner in [Vector2(4, 4), Vector2(frame.x - 4, 4), Vector2(4, frame.y - 4), frame - Vector2(4, 4)]:
		var wheel := _wheel(world)
		wheel.open_at(world, "fridge", corner)
		wheel.advance(1.0)
		var box := wheel.occupied_rect()
		assert_bool(box.position.x >= margin - 0.5 and box.position.y >= margin - 0.5
			and box.end.x <= frame.x - margin + 0.5 and box.end.y <= frame.y - margin + 0.5) \
			.override_failure_message("tapped %s and the wheel occupies %s of a %s frame" % [
				corner, box, frame]).is_true()
		assert_bool(wheel.needs_leader()).override_failure_message(
			"the wheel moved off the tap point at %s without drawing the leader that says so" % corner) \
			.is_true()


func test_a_tap_in_open_space_needs_no_leader() -> void:
	var world := F.world()
	assert_bool(_open(world).needs_leader()).override_failure_message(
		"a leader line drawn when the wheel is exactly on the tap point").is_false()


# --- what a slot says --------------------------------------------------------

func test_an_unavailable_slot_is_more_than_just_faint() -> void:
	var world := F.world()
	var wheel := _open(world)
	# Nothing is held, so Throw cannot be available.
	assert_str(wheel.slot_state("throw")).is_equal("unavailable")
	var style := wheel.slot_style("throw")
	assert_str(str(style.get("border_style", ""))).override_failure_message(
		"unavailable reads as a dashed border, not only a lower alpha").is_equal("dashed")
	assert_float(float(style.get("icon_alpha", 1.0))).is_less(0.5)


func test_an_available_slot_shows_what_the_action_costs() -> void:
	var world := F.world()
	var wheel := _open(world)
	assert_str(wheel.slot_state("open")).is_equal("available")
	assert_float(wheel.cost_of("open")).override_failure_message(
		"opening the fridge should cost time and the slot should say so").is_greater(0.0)
	assert_str(wheel.cost_label("open")).override_failure_message(
		"no cost printed on an available slot").is_not_empty()


func test_an_unavailable_slot_prints_no_cost() -> void:
	var world := F.world()
	assert_str(_open(world).cost_label("throw")).override_failure_message(
		"an unavailable slot is advertising a price").is_empty()


func test_inspect_is_free_and_says_nothing_about_time() -> void:
	var world := F.world()
	var wheel := _open(world)
	assert_float(wheel.cost_of("inspect")).is_equal_approx(0.0, 0.001)
	assert_str(wheel.cost_label("inspect")).override_failure_message(
		"thinking is free; the centre slot should not print 0.0s").is_empty()


# --- the caption -------------------------------------------------------------

func test_the_caption_names_the_object() -> void:
	var world := F.world()
	var wheel := _open(world, "toaster")
	assert_str(wheel.caption_lines()[0]).is_equal(world.objects.by_id("toaster").name)


func test_the_caption_counts_a_stacked_cell_and_only_then() -> void:
	var world := F.world()
	var stacked := _open(world, "toaster", Vector2(960, 540), 2, 5).caption_lines()
	assert_int(stacked.size()).is_greater(1)
	assert_str(stacked[1]).contains("2 of 5")
	assert_int(_open(world, "couch").caption_lines().size()).override_failure_message(
		"a lone object should not be told it is 1 of 1").is_equal(1)


func test_hovering_a_slot_names_the_verb_and_its_cost() -> void:
	var world := F.world()
	var wheel := _open(world)
	wheel.hover_at(wheel.slot_centre("open"))
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).override_failure_message(
		"hovering a slot says nothing: %s" % [lines]).contains("Open")


# --- refusal -----------------------------------------------------------------

func test_a_refusal_marks_the_slot_and_keeps_the_wheel_open() -> void:
	var world := F.world()
	var wheel := _open(world, "glass_jar")
	assert_bool(world.verb_on("grab", "glass_jar")).override_failure_message(
		"grabbing through a shut cabinet should be refused").is_false()
	wheel.report_refused("grab")
	assert_str(wheel.slot_state("grab")).is_equal("refused")
	assert_bool(wheel.is_open()).is_true()
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).contains("can't")
	assert_object(wheel.slot_style("grab").get("border")).override_failure_message(
		"a refusal is the accent, and nothing in this game is red") \
		.is_equal(GameVisuals.load_table().colour("wheel.refused_color"))


func test_the_refusal_clears_itself() -> void:
	var world := F.world()
	var wheel := _open(world, "glass_jar")
	wheel.report_refused("grab")
	wheel.advance(GameVisuals.load_table().number("wheel.refused_hold_s") + 0.1)
	assert_str(wheel.slot_state("grab")).override_failure_message(
		"the slot is still shouting about a refusal from a while ago").is_not_equal("refused")


# --- opening and closing -----------------------------------------------------

func test_it_opens_over_time_rather_than_appearing() -> void:
	var world := F.world()
	var wheel := _wheel(world)
	wheel.open_at(world, "fridge", Vector2(960, 540))
	assert_float(wheel.open_progress()).override_failure_message(
		"the wheel is fully open on the frame it was asked to open").is_less(1.0)
	wheel.advance(GameVisuals.load_table().number("wheel.open_duration_s") + 0.01)
	assert_float(wheel.open_progress()).is_equal_approx(1.0, 0.001)


func test_closing_forgets_the_target() -> void:
	var world := F.world()
	var wheel := _open(world)
	wheel.close()
	assert_bool(wheel.is_open()).is_false()
	assert_object(wheel.target()).is_null()


## The vignette dims the room. It is not there to dim the timer the player is
## racing, so it is a separate node the game parents below the HUD.
func test_the_pause_vignette_is_not_part_of_the_wheel() -> void:
	var world := F.world()
	var wheel := _wheel(world)
	var backdrop: Control = auto_free(wheel.backdrop())
	assert_object(backdrop).is_not_null()
	assert_object(backdrop.get_parent()).override_failure_message(
		"the vignette is inside the wheel, so it can only ever draw over the HUD").is_null()
	assert_bool(backdrop.visible).is_false()
	wheel.open_at(world, "fridge", Vector2(960, 540))
	assert_bool(backdrop.visible).override_failure_message(
		"the wheel opened and its backdrop did not").is_true()
	wheel.close()
	assert_bool(backdrop.visible).override_failure_message(
		"the room is still dimmed after the wheel closed").is_false()


func test_the_game_puts_the_vignette_under_the_hud() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	var backdrop := source.find("_wheel.backdrop()")
	var hud := source.find("_hud = GameHud.new()")
	assert_int(backdrop).override_failure_message("nothing adds the backdrop").is_greater(-1)
	assert_int(backdrop).override_failure_message(
		"the backdrop is added after the HUD, so it draws over it").is_less(hud)


# --- why a slot is off -------------------------------------------------------

## The session log's one clear finding: Bob tapped the knife, could not grab it,
## and nothing told him his hands were full of floor lamp.
func test_hovering_a_slot_that_is_off_says_why() -> void:
	var world := F.world()
	F.give(world, "floor_lamp")
	var wheel := _open(world, "kitchen_knife")
	assert_str(wheel.slot_state("grab")).is_equal("unavailable")
	wheel.hover_at(wheel.slot_centre("grab"))
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).override_failure_message(
		"the wheel still says nothing about why Grab is off: %s" % [lines]).contains("hands are full")


func test_the_words_come_from_the_table_not_from_the_sim() -> void:
	var world := F.world()
	F.give(world, "floor_lamp")
	var wheel := _open(world, "kitchen_knife")
	assert_str(wheel.reason_for("grab")).is_equal(
		str((GameVisuals.load_table().get_value("wheel.reasons", {}) as Dictionary)["actor.hands_free"]))


## No rule covers toggling a rug. That is not a reason and the wheel does not
## invent one.
func test_a_slot_with_no_rule_behind_it_gets_no_excuse() -> void:
	var world := F.world()
	var wheel := _open(world, "rug")
	assert_str(wheel.slot_state("toggle")).is_equal("unavailable")
	assert_str(wheel.reason_for("toggle")).is_empty()
	wheel.hover_at(wheel.slot_centre("toggle"))
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).override_failure_message(
		"an excuse was invented for a verb that simply does not apply").is_equal("Toggle")


func test_an_available_slot_still_shows_its_cost_rather_than_a_reason() -> void:
	var world := F.world()
	var wheel := _open(world, "fridge")
	wheel.hover_at(wheel.slot_centre("open"))
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).contains("s")
	assert_str(wheel.reason_for("open")).is_empty()


## A phone has no hover. Tapping a slot that is off has to say the same thing,
## or the explanation only ever exists on desktop.
func test_tapping_a_slot_that_is_off_says_why_too() -> void:
	var world := F.world()
	F.give(world, "floor_lamp")
	var wheel := _open(world, "kitchen_knife")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = wheel.slot_centre("grab")
	wheel._gui_input(event)
	assert_bool(wheel.is_open()).override_failure_message(
		"tapping an unavailable slot closed the wheel").is_true()
	var lines := wheel.caption_lines()
	assert_str(lines[lines.size() - 1]).override_failure_message(
		"tapped Grab and the wheel said nothing: %s" % [lines]).contains("hands are full")


# --- browsing a stacked square -----------------------------------------------

## Bob: "when there are multiple items available, like in the counter drawer,
## can we put left/right arrows to allow the user to easily scroll through them,
## see their descriptions, and choose an action on the currently visible item?"
##
## Tapping the square again cycled, and nothing on screen said so except a line
## of text. Five things share the counter square.

func _stacked(world: SimWorld) -> ActionWheel:
	var cell := world.objects.by_id("toaster").origin()
	var options := ClickTarget.options_for(world, cell)
	assert_int(options.size()).override_failure_message(
		"this test needs a square with several things on it").is_greater(2)
	var wheel := _wheel(world)
	wheel.open_at(world, options[0], Vector2(960, 540), 1, options.size(), options)
	wheel.advance(1.0)
	return wheel


func test_a_stacked_square_gets_arrows() -> void:
	var world := F.world()
	var wheel := _stacked(world)
	var v := GameVisuals.load_table()
	for side in ["prev", "next"]:
		var box := wheel.arrow_rect(str(side))
		assert_float(box.size.x).override_failure_message(
			"the %s arrow is %.0f across, under the touch minimum" % [side, box.size.x]) \
			.is_greater_equal(v.number("wheel.min_touch_target"))


func test_one_thing_on_a_square_gets_no_arrows() -> void:
	var world := F.world()
	var wheel := _open(world, "couch")
	assert_float(wheel.arrow_rect("next").size.x).override_failure_message(
		"arrows for a square with one thing on it").is_equal_approx(0.0, 0.001)


func test_the_arrows_walk_through_what_is_there() -> void:
	var world := F.world()
	var wheel := _stacked(world)
	var first: Variant = wheel.target()
	assert_bool(wheel.press_at(wheel.arrow_rect("next").get_center())).is_true()
	assert_str(str(wheel.target())).override_failure_message(
		"the arrow did not move the selection").is_not_equal(str(first))
	assert_bool(wheel.is_open()).override_failure_message(
		"the arrow closed the wheel").is_true()
	assert_str(wheel.caption_lines()[1]).contains("2 of")


func test_they_wrap_round_rather_than_stopping() -> void:
	var world := F.world()
	var wheel := _stacked(world)
	var first: Variant = wheel.target()
	wheel.press_at(wheel.arrow_rect("prev").get_center())
	assert_str(wheel.caption_lines()[1]).override_failure_message(
		"stepping back from the first should land on the last").contains(
			"%d of" % ClickTarget.options_for(world, world.objects.by_id("toaster").origin()).size())
	wheel.press_at(wheel.arrow_rect("next").get_center())
	assert_str(str(wheel.target())).is_equal(str(first))


## What each verb can do follows the selection, or the arrows are decoration.
func test_the_verbs_follow_the_selection() -> void:
	var world := F.world()
	var wheel := _stacked(world)
	var seen := {}
	for _step in ClickTarget.options_for(world, world.objects.by_id("toaster").origin()).size():
		seen[str(wheel.target())] = wheel.slot_state("grab")
		wheel.press_at(wheel.arrow_rect("next").get_center())
	var states := {}
	for id in seen:
		states[str(seen[id])] = true
	assert_int(states.size()).override_failure_message(
		"every one of five different things offers exactly the same Grab").is_greater(1)


## The description is the reward for Inspect. Browsing shows it for things you
## have already looked at, and stays quiet about the rest.
func test_the_caption_carries_a_description_once_you_have_looked() -> void:
	var world := F.world()
	var wheel := _stacked(world)
	var quiet := " ".join(wheel.caption_lines())
	var toaster := world.objects.by_id("toaster")
	assert_str(quiet).override_failure_message(
		"the wheel is giving away what Inspect is for").not_contains(toaster.inspect)

	assert_bool(F.act(world, "inspect", "toaster")).is_true()
	var after := _stacked(world)
	while str(after.target()) != "toaster":
		after.press_at(after.arrow_rect("next").get_center())
	assert_str(" ".join(after.caption_lines())).override_failure_message(
		"it has been inspected and the wheel still will not repeat it").contains(toaster.inspect)


# --- putting it down ---------------------------------------------------------

## Bob, eighth playtest: "I picked up the jar and then I could not put it down."
##
## He was holding it and he kept tapping things — the cooker, the pan, the boxes,
## the fridge, the drawer. Every one of those wheels had Drop greyed out, because
## Drop wanted a bare floor square and he never tapped one.
##
## While your hands are full, Drop is live on whatever you are looking at. This
## walks every object in the room so it cannot come back for a few of them.
func test_drop_is_live_on_anything_while_your_hands_are_full() -> void:
	var world := F.world()
	F.give(world, "glass_jar")
	var dead := PackedStringArray()
	for obj in world.objects.all():
		if obj.id == "glass_jar":
			continue
		var wheel := _open(world, obj.id)
		if wheel.slot_state("drop") != "available":
			dead.append(obj.id)
	assert_array(Array(dead)).override_failure_message(
		"holding the jar and Drop is dead on: %s" % [dead]).is_empty()


## And with empty hands it is off everywhere, with the reason said out loud
## rather than a silent dead slot.
func test_drop_is_off_and_says_so_when_your_hands_are_empty() -> void:
	var world := F.world()
	var wheel := _open(world, "fridge")
	assert_str(wheel.slot_state("drop")).is_equal("unavailable")
	assert_str(wheel.reason_for("drop")).override_failure_message(
		"Drop is off and the wheel does not say why").is_not_empty()
