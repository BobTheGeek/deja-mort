class_name SimRuleContext
extends RefCounted

## Everything a rule needs to decide whether it fires, and on what.

var verb: String = ""
var actor: SimActor = null
var held: SimObject = null
var target: SimObject = null
var target_actor: SimActor = null
var subject: SimObject = null   # the object an internal rule reacts to (e.g. what was just pushed)
var cell: Vector2i = SimEvent.NO_CELL
var world: Object = null   # SimWorld; typed loosely to avoid a cyclic dependency


static func make(p_world: Object, p_verb: String, p_actor: SimActor, p_target: SimObject, p_cell: Vector2i, p_held: SimObject, p_target_actor: SimActor = null) -> SimRuleContext:
	var ctx := SimRuleContext.new()
	ctx.world = p_world
	ctx.verb = p_verb
	ctx.actor = p_actor
	ctx.target = p_target
	ctx.cell = p_cell
	ctx.held = p_held
	ctx.target_actor = p_target_actor
	return ctx


func target_cell() -> Vector2i:
	if target != null:
		return target.origin()
	return cell
