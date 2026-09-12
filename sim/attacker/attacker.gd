class_name SimAttacker
extends SimActor

## The attacker is a SimActor with a profile, a memory and a set of eyes. He
## walks, bleeds and slips through exactly the same world.step() path the player
## does — see SimWorld._step_hazards_on_actors.

var profile: SimAttackerProfile = null
var perception: SimAttackerPerception = null
var memory: SimAttackerMemory = null

var inside: bool = false
var left: bool = false
var entry_id: String = ""
var search_elapsed_s: float = 0.0
var searched: Dictionary = {}
var incapacitated_since: int = -1
var hazard_path_cost: float = 0.0


static func create(p: SimAttackerProfile, start: Vector2i, vulnerable: PackedStringArray, prior_loops: Array = []) -> SimAttacker:
	var a := SimAttacker.new()
	a.configure(p.id, start, p.walk_speed, p.durability, vulnerable)
	a.role = "attacker"
	a.profile = p
	a.perception = SimAttackerPerception.new()
	a.memory = SimAttackerMemory.new()
	a.memory.configure(p, prior_loops)
	return a


func is_incapacitated() -> bool:
	return not alive or has_status("pinned")


## Path cost he adds to a cell: hazards he has seen, plus whatever memory says
## to stay away from.
func path_extra_cost(cell: Vector2i) -> float:
	var extra := memory.extra_path_cost(cell)
	if perception.known_hazards.has(cell):
		extra += hazard_path_cost
	return extra
