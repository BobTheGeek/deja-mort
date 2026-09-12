class_name SimAttackerPerception
extends RefCounted

## What he can see and hear this tick. Reads the same event bus presentation reads.

const HAZARD_LAYERS: PackedStringArray = ["slippery", "burning", "shock", "trip"]

var target_visible: bool = false
var has_last_known: bool = false
var last_known_pos: Vector2i = SimEvent.NO_CELL
var has_investigate: bool = false
var investigate_target: Vector2i = SimEvent.NO_CELL
var suspicion: float = 0.0
var known_hazards: Dictionary = {}
var changed: bool = false   # set when what he knows actually changed this tick


func observe(world: SimWorld, att: SimActor, profile: SimAttackerProfile) -> void:
	var was_visible := target_visible
	var was_investigating := investigate_target
	_look(world, att, profile)
	_listen(world, att, profile)
	_note_hazards(world, att, profile)
	# Only a transition is news. A target that stays visible must not cancel the
	# plan that is walking towards it.
	if (target_visible and not was_visible) or (has_investigate and investigate_target != was_investigating):
		changed = true


func effective_sight(world: SimWorld, profile: SimAttackerProfile) -> int:
	if bool(world.room_state.get("lit", true)) or profile.has_flashlight:
		return profile.sight_range
	return int(profile.sight_range / 2)


func consume_change() -> bool:
	var value := changed
	changed = false
	return value


func clear_investigation() -> void:
	has_investigate = false
	investigate_target = SimEvent.NO_CELL
	suspicion = 0.0


func _look(world: SimWorld, att: SimActor, profile: SimAttackerProfile) -> void:
	target_visible = false
	var player := world.player
	if not player.alive or player.is_hidden():
		return
	if world.grid.distance(att.pos, player.pos) > effective_sight(world, profile):
		return
	if not world.grid.has_los(att.pos, player.pos, Callable(world, "blocks_sight")):
		return
	target_visible = true
	has_last_known = true
	last_known_pos = player.pos
	if player.never_seen:
		player.never_seen = false
		world.emit(SimEvent.TYPE_ACTOR_STATUS, {
			"cell": player.pos, "actor": att.id, "meta": {"saw": player.id},
		})
	player.seen_count += 1


## L * sensitivity - distance - mask >= 0, exactly as the spec states it.
func _listen(world: SimWorld, att: SimActor, profile: SimAttackerProfile) -> void:
	var mask := float(world.room_state.get("hearing_mask", 0))
	for e in world.events.since(world.tick):
		if e.type != SimEvent.TYPE_NOISE or e.actor == att.id:
			continue
		if e.cell == SimEvent.NO_CELL:
			continue
		var d := float(world.grid.distance(att.pos, e.cell))
		if e.loudness * profile.hearing_sensitivity - d - mask < 0.0:
			continue
		if e.loudness < suspicion and has_investigate:
			continue
		has_investigate = true
		investigate_target = e.cell
		suspicion = e.loudness


## Concealed hazards are invisible to him. Wet is not a hazard he knows about.
func _note_hazards(world: SimWorld, att: SimActor, profile: SimAttackerProfile) -> void:
	var sight := effective_sight(world, profile)
	for layer in HAZARD_LAYERS:
		for c in world.hazards.cells(layer):
			if world.hazards.has("concealed", c):
				continue
			if world.grid.distance(att.pos, c) > sight:
				continue
			if world.grid.has_los(att.pos, c, Callable(world, "blocks_sight")):
				known_hazards[c] = true
