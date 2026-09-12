class_name SimAction
extends RefCounted

## One scheduled thing an actor is doing: walk there, then do that, for N ticks.

const KIND_WALK := "walk"
const KIND_VERB := "verb"
const KIND_WAIT := "wait"
const KIND_ATTACKER := "attacker"

const PHASE_WALKING := "walking"
const PHASE_PERFORMING := "performing"
const PHASE_DONE := "done"

var kind: String = KIND_WALK
var phase: String = PHASE_WALKING
var verb: String = ""
var rule_id: String = ""
var target_id: String = ""
var target_cell: Vector2i = SimEvent.NO_CELL
var duration_ticks: int = 0
var ends_tick: int = 0
var issued_tick: int = 0
var meta: Dictionary = {}


func describe() -> String:
	if kind == KIND_WAIT:
		return "wait"
	if kind == KIND_WALK:
		return "walk_to %s" % target_cell
	return "%s %s" % [verb, target_id if not target_id.is_empty() else str(target_cell)]
