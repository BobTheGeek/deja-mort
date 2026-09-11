class_name SimEvent
extends RefCounted

## One typed record on the bus. Consumers: attacker perception (M2), the outcome
## tracker (M2), presentation (M3). The sim never reads `meta` back.

const NO_CELL := Vector2i(-1, -1)

const TYPE_NOISE := "noise"
const TYPE_LIGHT := "light"
const TYPE_STATE_CHANGE := "state_change"
const TYPE_HAZARD_SPAWN := "hazard_spawn"
const TYPE_ACTOR_MOVE := "actor_move"
const TYPE_ACTOR_STATUS := "actor_status"
const TYPE_ATTACK := "attack"
const TYPE_DEATH := "death"
const TYPE_ENDING := "ending"
const TYPE_DISCOVERY := "discovery"
const TYPE_INTERACTION := "interaction"
const TYPE_TIMER := "timer"

const TYPES: PackedStringArray = [
	TYPE_NOISE, TYPE_LIGHT, TYPE_STATE_CHANGE, TYPE_HAZARD_SPAWN, TYPE_ACTOR_MOVE,
	TYPE_ACTOR_STATUS, TYPE_ATTACK, TYPE_DEATH, TYPE_ENDING, TYPE_DISCOVERY,
	TYPE_INTERACTION, TYPE_TIMER,
]

var tick: int = 0
var type: String = ""
var cell: Vector2i = NO_CELL
var loudness: float = 0.0
var light: float = 0.0
var actor: String = ""
var object: String = ""
var rule_id: String = ""
var meta: Dictionary = {}


static func make(p_tick: int, p_type: String, fields: Dictionary = {}) -> SimEvent:
	var e := SimEvent.new()
	e.tick = p_tick
	e.type = p_type
	e.cell = fields.get("cell", NO_CELL)
	e.loudness = float(fields.get("loudness", 0.0))
	e.light = float(fields.get("light", 0.0))
	e.actor = str(fields.get("actor", ""))
	e.object = str(fields.get("object", ""))
	e.rule_id = str(fields.get("rule_id", ""))
	e.meta = fields.get("meta", {})
	return e


## Stable one-line form. Determinism tests diff these, so the format must not
## depend on dictionary iteration order.
func to_line() -> String:
	var meta_keys := meta.keys()
	meta_keys.sort()
	var parts := PackedStringArray()
	for k in meta_keys:
		parts.append("%s=%s" % [k, meta[k]])
	return "t%04d %-13s cell=%s loud=%.1f light=%.1f actor=%s obj=%s rule=%s {%s}" % [
		tick, type, cell, loudness, light, actor, object, rule_id, ",".join(parts),
	]
