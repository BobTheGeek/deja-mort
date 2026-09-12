class_name SimActor
extends RefCounted

## Shared actor state. The player and (from M2) the attacker are both this.

var id: String = ""
var role: String = "player"        # player | attacker — hazard specs key off this, not the id
var pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(0, 1)
var holding: String = ""
var hidden_in: String = ""
var status: Dictionary = {}          # effect name -> until_tick
var status_since: Dictionary = {}    # effect name -> tick it was first applied
var hazard_last_damage: Dictionary = {}  # layer -> tick it last hurt this actor
var hazard_since: Dictionary = {}        # layer -> tick this actor first stood in it
var durability: int = 1
var walk_speed: float = 1.0          # tiles/s, from JSON
var alive: bool = true
var death_cause: String = ""

var action: SimAction = null
var path: Array[Vector2i] = []
var walk_progress: float = 0.0

var _vulnerable_statuses: PackedStringArray = []


func configure(p_id: String, start: Vector2i, speed: float, hp: int, vulnerable_statuses: PackedStringArray) -> void:
	id = p_id
	pos = start
	walk_speed = speed
	durability = hp
	_vulnerable_statuses = vulnerable_statuses


func has_status(name: String) -> bool:
	return status.has(name)


func apply_status_until(name: String, until_tick: int) -> void:
	var current: int = int(status.get(name, -1))
	status[name] = maxi(current, until_tick)


func clear_status(name: String) -> void:
	status.erase(name)


func expire_statuses(tick: int) -> PackedStringArray:
	var expired := PackedStringArray()
	for name in status.keys():
		if int(status[name]) <= tick:
			expired.append(name)
	expired.sort()
	for name in expired:
		status.erase(name)
		status_since.erase(name)
	return expired


func status_names() -> PackedStringArray:
	var names := PackedStringArray(status.keys())
	names.sort()
	return names


func is_vulnerable() -> bool:
	for s in _vulnerable_statuses:
		if status.has(s):
			return true
	return false


func is_hidden() -> bool:
	return not hidden_in.is_empty()


func is_busy() -> bool:
	return action != null


func hands_free() -> bool:
	return holding.is_empty()


func cancel_action() -> void:
	action = null
	path.clear()
	walk_progress = 0.0
