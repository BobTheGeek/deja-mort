extends GdUnitTestSuite

## One test per rule id in content/rules.json, plus a coverage test that fails
## if a rule is ever added without one.

const F := preload("res://tests/support/sim_fixture.gd")


func test_every_rule_id_has_a_test() -> void:
	var missing := PackedStringArray()
	for id in F.rule_ids():
		if not has_method("test_rule_" + id):
			missing.append(id)
	assert_array(Array(missing)).override_failure_message(
		"rules with no test: %s" % [missing]).is_empty()


# --- handling ----------------------------------------------------------------

func test_rule_inspect() -> void:
	var w := F.world()
	assert_bool(F.act(w, "inspect", "toaster")).is_true()
	assert_bool(F.fired(w, "inspect")).is_true()
	assert_int(int(w.objects.by_id("toaster").get_state("inspected", 0))).is_equal(1)


func test_rule_grab() -> void:
	var w := F.world()
	assert_bool(F.act(w, "grab", "kitchen_knife")).is_true()
	assert_str(w.player.holding).is_equal("kitchen_knife")
	assert_bool(F.fired(w, "grab")).is_true()


func test_grab_refuses_a_shut_container() -> void:
	var w := F.world()
	assert_bool(w.verb_on("grab", "glass_jar")).is_false()
	assert_bool(F.act(w, "open", "cabinet")).is_true()
	assert_bool(F.act(w, "grab", "glass_jar")).is_true()


func test_rule_place_in_container() -> void:
	var w := F.world()
	F.give(w, "kitchen_knife")
	assert_bool(F.act(w, "drop", "counter_knife", "place_in_container")).is_true()
	assert_str(w.player.holding).is_empty()
	assert_bool(w.objects.by_id("counter_knife").contains.has("kitchen_knife")).is_true()


func test_rule_drop() -> void:
	var w := F.world()
	F.give(w, "kitchen_knife")
	assert_bool(F.act(w, "drop", Vector2i(4, 2), "drop")).is_true()
	assert_str(w.player.holding).is_empty()
	assert_vector(w.objects.by_id("kitchen_knife").origin()).is_equal(Vector2i(4, 2))


# --- pushing and tipping -----------------------------------------------------

func test_rule_push() -> void:
	var w := F.world()
	assert_bool(F.goto(w, Vector2i(3, 3))).is_true()
	assert_bool(F.act(w, "push", "rug", "push")).is_true()
	assert_vector(w.objects.by_id("rug").origin()).is_equal(Vector2i(1, 3))


func test_rule_push_heavy() -> void:
	var w := F.world()
	assert_bool(F.goto(w, Vector2i(3, 2))).is_true()
	assert_bool(F.act(w, "push", "moving_boxes", "push_heavy")).is_true()
	assert_vector(w.objects.by_id("moving_boxes").origin()).is_equal(Vector2i(1, 2))


func test_rule_tip_first() -> void:
	var w := F.world()
	assert_bool(F.goto(w, Vector2i(1, 7))).is_true()
	assert_bool(F.act(w, "push", "bookshelf", "tip_first")).is_true()
	assert_bool(bool(w.objects.by_id("bookshelf").get_state("leaning"))).is_true()


func test_rule_tip_second() -> void:
	var w := F.world()
	assert_bool(F.goto(w, Vector2i(1, 7))).is_true()
	assert_bool(F.act(w, "push", "bookshelf", "tip_first")).is_true()
	assert_bool(F.act(w, "push", "bookshelf", "tip_second")).is_true()
	var shelf := w.objects.by_id("bookshelf")
	assert_bool(bool(shelf.get_state("tipped"))).is_true()
	assert_array(shelf.cells).contains([Vector2i(1, 3)])


func test_tipped_shelf_pins_whoever_is_under_it() -> void:
	var w := F.world()
	var victim := F.target_actor(w, Vector2i(1, 3))
	assert_bool(F.goto(w, Vector2i(1, 7))).is_true()
	F.act(w, "push", "bookshelf", "tip_first")
	F.act(w, "push", "bookshelf", "tip_second")
	assert_bool(victim.has_status("pinned")).is_true()
	assert_bool(victim.is_vulnerable()).is_true()


func test_rule_push_to_brace() -> void:
	var w := F.world()
	assert_bool(F.goto(w, Vector2i(3, 2))).is_true()
	assert_bool(F.act(w, "push", "moving_boxes", "push_heavy")).is_true()
	assert_str(str(w.objects.by_id("front_door").get_state("braced_by"))).is_equal("moving_boxes")
	assert_bool(F.fired(w, "push_to_brace")).is_true()
	assert_array(Array(w.discoveries)).contains(["brace_door"])


func test_rule_cover_hazard() -> void:
	var w := F.world()
	F.give(w, "cooking_oil")
	assert_bool(F.act(w, "use-held-on", Vector2i(1, 3), "pour_slippery")).is_true()
	assert_bool(F.goto(w, Vector2i(3, 3))).is_true()
	assert_bool(F.act(w, "push", "rug", "push")).is_true()
	assert_bool(w.hazards.has("concealed", Vector2i(1, 3))).is_true()
	assert_array(Array(w.discoveries)).contains(["oil_under_rug"])


func test_rule_plug_cord_trip() -> void:
	var w := F.world()
	F.give(w, "floor_lamp")
	assert_bool(F.act(w, "drop", Vector2i(1, 3), "drop")).is_true()
	assert_bool(w.hazards.has("trip", Vector2i(1, 3))).is_true()
	assert_array(Array(w.discoveries)).contains(["cord_trip"])


func test_cord_trip_stays_quiet_away_from_a_chokepoint() -> void:
	var w := F.world()
	F.give(w, "floor_lamp")
	assert_bool(F.act(w, "drop", Vector2i(6, 6), "drop")).is_true()
	assert_int(w.hazards.count("trip")).is_equal(0)
	assert_array(Array(w.discoveries)).not_contains(["cord_trip"])


# --- hiding ------------------------------------------------------------------

func test_rule_hide() -> void:
	var w := F.world()
	assert_bool(F.act(w, "hide", "closet")).is_true()
	assert_str(w.player.hidden_in).is_equal("closet")


func test_rule_unhide() -> void:
	var w := F.world()
	assert_bool(F.act(w, "hide", "closet")).is_true()
	assert_bool(w.fire_manual("unhide", w.player)).is_true()
	assert_str(w.player.hidden_in).is_empty()


func test_any_other_action_leaves_the_hiding_spot() -> void:
	var w := F.world()
	F.act(w, "hide", "closet")
	F.act(w, "inspect", "closet")
	assert_str(w.player.hidden_in).is_empty()


# --- doors, switches, toggles ------------------------------------------------

func test_rule_open_close() -> void:
	var w := F.world()
	assert_bool(F.act(w, "open", "cabinet")).is_true()
	assert_bool(bool(w.objects.by_id("cabinet").get_state("open"))).is_true()


func test_rule_open_window() -> void:
	var w := F.world()
	assert_bool(F.act(w, "open", "window", "open_window")).is_true()
	assert_bool(bool(w.objects.by_id("window").get_state("open"))).is_true()
	assert_int(int(w.room_state.get("hearing_mask", 0))).is_equal(1)


func test_rule_toggle_light_switch() -> void:
	var w := F.world()
	assert_bool(bool(w.room_state["lit"])).is_true()
	assert_bool(F.act(w, "toggle", "light_switch")).is_true()
	assert_bool(bool(w.room_state["lit"])).is_false()
	assert_array(Array(w.discoveries)).contains(["lights_out"])


func test_rule_toggle_lock() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "front_door", "toggle_lock")).is_true()
	assert_bool(bool(w.objects.by_id("front_door").get_state("locked"))).is_true()


func test_rule_toggle_chain() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "door_chain", "toggle_chain")).is_true()
	assert_bool(bool(w.objects.by_id("door_chain").get_state("chained"))).is_true()


func test_rule_toggle_on() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "tv", "toggle_on")).is_true()
	assert_bool(bool(w.objects.by_id("tv").get_state("on"))).is_true()


func test_rule_toggle_off() -> void:
	var w := F.world()
	F.act(w, "toggle", "tv", "toggle_on")
	assert_bool(F.act(w, "toggle", "tv", "toggle_off")).is_true()
	assert_bool(bool(w.objects.by_id("tv").get_state("on"))).is_false()


func test_a_lure_keeps_making_noise_while_it_is_on() -> void:
	var w := F.world()
	F.act(w, "toggle", "tv", "toggle_on")
	var before := w.events.of_type(SimEvent.TYPE_NOISE).size()
	w.step_seconds(10.0)
	assert_int(w.events.of_type(SimEvent.TYPE_NOISE).size()).is_greater(before)


func test_rule_toggle_wet_source() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "sink", "toggle_wet_source")).is_true()
	assert_bool(w.hazards.spread_active("wet")).is_true()


func test_rule_toggle_wet_source_off() -> void:
	var w := F.world()
	F.act(w, "toggle", "sink", "toggle_wet_source")
	assert_bool(F.act(w, "toggle", "sink", "toggle_wet_source_off")).is_true()
	assert_bool(w.hazards.spread_active("wet")).is_false()


func test_rule_toggle_gas_source() -> void:
	var w := F.world()
	assert_bool(F.act(w, "toggle", "stove", "toggle_gas_source")).is_true()
	var stove := w.objects.by_id("stove")
	assert_bool(bool(stove.get_state("on"))).is_true()
	assert_bool(bool(stove.get_state("lit"))).is_false()
	w.step_seconds(5.0)
	assert_float(w.hazards.gas_level(w.grid.zone_of(stove.origin()))).is_greater(0.0)


func test_rule_toggle_stove_ignite() -> void:
	var w := F.world()
	F.act(w, "toggle", "stove", "toggle_gas_source")
	assert_bool(F.act(w, "toggle", "stove", "toggle_stove_ignite")).is_true()
	assert_bool(w.hazards.has("hot", w.objects.by_id("stove").origin())).is_true()


func test_rule_toggle_burner_off() -> void:
	var w := F.world()
	F.act(w, "toggle", "stove", "toggle_gas_source")
	F.act(w, "toggle", "stove", "toggle_stove_ignite")
	assert_bool(F.act(w, "toggle", "stove", "toggle_burner_off")).is_true()
	assert_bool(w.hazards.has("hot", Vector2i(1, 1))).is_false()


func test_rule_call_help() -> void:
	var w := F.world()
	F.act(w, "open", "nightstand")
	w.objects.by_id("phone").set_state("charged", true)
	assert_bool(F.act(w, "toggle", "phone", "call_help")).is_true()
	assert_float(w.timer_remaining("help_arrives")).is_greater(0.0)
	assert_array(Array(w.discoveries)).contains(["phone_help"])


func test_rule_charge_phone() -> void:
	var w := F.world()
	F.act(w, "open", "nightstand")
	F.give(w, "charger")
	assert_bool(F.act(w, "use-held-on", "phone", "charge_phone")).is_true()
	assert_bool(bool(w.objects.by_id("phone").get_state("charged"))).is_false()
	w.step_seconds(float(w.system("phone.charge_s")) + 1.0)
	assert_bool(bool(w.objects.by_id("phone").get_state("charged"))).is_true()


# --- throwing ----------------------------------------------------------------

func test_rule_throw_at_cell() -> void:
	var w := F.world()
	F.give(w, "umbrella")
	assert_bool(F.goto(w, Vector2i(4, 5))).is_true()
	assert_bool(F.act(w, "throw", Vector2i(4, 3), "throw_at_cell")).is_true()
	assert_vector(w.objects.by_id("umbrella").origin()).is_equal(Vector2i(4, 3))


func test_throw_refuses_a_cell_out_of_range() -> void:
	var w := F.world()
	F.give(w, "umbrella")
	assert_bool(F.goto(w, Vector2i(7, 7))).is_true()
	assert_int(w.grid.distance(Vector2i(7, 7), Vector2i(1, 2))).is_greater(int(w.system("ranges.throw_cell")))
	assert_bool(w.verb_on("throw", Vector2i(1, 2), "throw_at_cell")).is_false()


func test_rule_throw_fragile_at_cell() -> void:
	var w := F.world()
	F.give(w, "glass_jar")
	assert_bool(F.goto(w, Vector2i(4, 4))).is_true()
	assert_bool(F.act(w, "throw", Vector2i(4, 6), "throw_fragile_at_cell")).is_true()
	assert_bool(bool(w.objects.by_id("glass_jar").get_state("broken"))).is_true()
	assert_bool(w.objects.by_id("glass_jar").has_tag("sharp")).is_true()


func test_rule_throw_at_actor() -> void:
	var w := F.world()
	var mark := F.target_actor(w, Vector2i(6, 6))
	F.give(w, "frying_pan")
	assert_bool(F.goto(w, Vector2i(6, 5))).is_true()
	assert_bool(F.act(w, "throw", "dummy", "throw_at_actor")).is_true()
	assert_bool(mark.has_status("stunned")).is_true()


func test_rule_throw_conductive_into_wet() -> void:
	var w := F.world()
	F.act(w, "toggle", "sink", "toggle_wet_source")
	F.give(w, "toaster")
	assert_bool(F.goto(w, Vector2i(5, 4))).is_true()
	w.step_seconds(60.0)
	assert_bool(F.act(w, "throw", Vector2i(3, 2), "throw_conductive_into_wet")).is_true()
	assert_bool(w.hazards.has("shock", Vector2i(1, 2))).is_true()
	assert_array(Array(w.discoveries)).contains(["water_and_current"])


# --- using held items --------------------------------------------------------

func test_rule_pour_slippery() -> void:
	var w := F.world()
	F.give(w, "cooking_oil")
	assert_bool(F.act(w, "use-held-on", Vector2i(1, 3), "pour_slippery")).is_true()
	assert_bool(w.hazards.has("slippery", Vector2i(1, 3))).is_true()
	assert_str(w.player.holding).is_empty()


func test_rule_ignite_flammable() -> void:
	var w := F.world()
	F.give(w, "lighter")
	assert_bool(F.act(w, "use-held-on", "curtains", "ignite_flammable")).is_true()
	assert_bool(w.hazards.has("burning", Vector2i(6, 1))).is_true()
	assert_array(Array(w.discoveries)).contains(["curtain_fire"])


func test_rule_aerosol_flash() -> void:
	var w := F.world()
	F.act(w, "toggle", "stove", "toggle_gas_source")
	F.act(w, "toggle", "stove", "toggle_stove_ignite")
	var burner := w.objects.by_id("stove").origin()
	var mark := F.target_actor(w, Vector2i(1, 2))   # a clear square beside the burner
	F.give(w, "hairspray")
	assert_bool(F.act(w, "use-held-on", burner, "aerosol_flash")).is_true()
	assert_bool(mark.has_status("blinded")).is_true()
	assert_array(Array(w.discoveries)).contains(["aerosol_flash"])


func test_rule_cut() -> void:
	var w := F.world()
	F.give(w, "kitchen_knife")
	assert_bool(F.act(w, "use-held-on", "curtains", "cut")).is_true()
	assert_bool(bool(w.objects.by_id("curtains").get_state("cut"))).is_true()


func test_rule_break_glass() -> void:
	var w := F.world()
	F.give(w, "frying_pan")
	assert_bool(F.act(w, "use-held-on", "coffee_table", "break_glass")).is_true()
	assert_bool(bool(w.objects.by_id("coffee_table").get_state("broken"))).is_true()


func test_rule_strike_vulnerable() -> void:
	var w := F.world()
	var mark := F.target_actor(w, Vector2i(6, 6))
	w.apply_status(mark, "prone", 5.0, "test")
	F.give(w, "frying_pan")
	assert_bool(F.goto(w, Vector2i(6, 5))).is_true()
	assert_bool(F.act(w, "use-held-on", "dummy", "strike_vulnerable")).is_true()
	assert_bool(mark.alive).is_false()


func test_rule_strike_exposed() -> void:
	var w := F.world()
	var mark := F.target_actor(w, Vector2i(6, 6))
	F.give(w, "kitchen_knife")
	assert_bool(F.goto(w, Vector2i(6, 5))).is_true()
	assert_bool(F.act(w, "use-held-on", "dummy", "strike_exposed")).is_true()
	assert_bool(mark.alive).is_true()
	assert_bool(w.player.has_status("exposed")).is_true()


## From Bob's eighth playtest: "I picked up the jar and then I could not put it
## down."
##
## He could not, and the log shows why: after grabbing it he tapped the stove,
## the pan, the boxes, the fridge, the drawer — nine taps on objects, no taps on
## bare floor. `drop` targets a *square*, so every one of those wheels had Drop
## greyed out, and a tap on floor two squares away walks you there rather than
## offering it.
##
## Putting something down beside a thing you are looking at is what people mean
## by putting it down. Drop works on an object now: it goes on that object's
## square.
func test_rule_drop_onto() -> void:
	var w := F.world()
	F.give(w, "glass_jar")
	assert_bool(F.act(w, "drop", "stove", "drop_onto")).override_failure_message(
		"holding a jar, standing at the cooker, and Drop is not available").is_true()
	assert_str(w.player.holding).is_empty()
	assert_bool(w.objects.by_id("glass_jar").cells.has(w.objects.by_id("stove").origin())) \
		.override_failure_message("dropped it at the cooker and it went somewhere else").is_true()


## An open container still wins: putting a jar in an open cupboard is putting it
## in the cupboard, not on top of it.
func test_an_open_container_still_takes_it_in() -> void:
	var w := F.world()
	assert_bool(F.act(w, "open", "counter_drawer")).is_true()
	F.give(w, "glass_jar")
	assert_bool(F.act(w, "drop", "counter_drawer")).is_true()
	var holder := w.objects.container_of("glass_jar")
	assert_object(holder).override_failure_message(
		"it should be inside the drawer, not on the floor beside it").is_not_null()
	assert_str(holder.id).is_equal("counter_drawer")


## And the bare square still works, because that is where you put things down
## when there is nothing to put them on.
func test_the_floor_still_takes_it() -> void:
	var w := F.world()
	F.give(w, "glass_jar")
	assert_bool(w.verb_on("drop", w.player.pos)).is_true()
	w.step_until_idle()
	assert_str(w.player.holding).is_empty()
