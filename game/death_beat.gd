class_name DeathBeat
extends RefCounted

## How a death is staged: which clip the killer plays, which clip the body
## plays, and how long the loop waits before it resets.
##
## docs/06: "Deaths: stylized. A slump, a fall, the light flickers, fade to the
## loop counter. No blood, no gore."
##
## This decides nothing. The sim has already ended the loop and already said how
## you died — TYPE_ATTACK carries the weapon, TYPE_DEATH carries the cause. This
## is the lookup from that cause to a performance, and a room may override any
## field of it, because the same knife in a different room is a different beat.


## Defaults, then the cause, then the room. Later wins, field by field.
static func resolve(visuals: GameVisuals, room: Dictionary, cause: String) -> Dictionary:
	var beat: Dictionary = {
		"attacker_clip": "",
		"victim_clip": str(visuals.get_value("death.victim_clip", "Death")),
		"hold_s": visuals.number("death.hold_s", 2.0),
		"light_flicker": visuals.number("death.light_flicker", 0.0),
	}
	_merge(beat, (visuals.get_value("death.by_cause", {}) as Dictionary).get(cause, {}))
	var room_death: Dictionary = room.get("death", {})
	_merge(beat, room_death)
	_merge(beat, (room_death.get("by_cause", {}) as Dictionary).get(cause, {}))
	return beat


static func _merge(into: Dictionary, from: Dictionary) -> void:
	for key in into:
		if from.has(key):
			into[key] = from[key]
