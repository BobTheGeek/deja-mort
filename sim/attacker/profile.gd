class_name SimAttackerProfile
extends RefCounted

## An attacker is entirely described by this JSON. No room ever names one in code.

var id: String = ""
var display: String = ""
var entries: PackedStringArray = []
var weapon: String = "hands"
var walk_speed: float = 1.0
var sight_range: int = 0
var hearing_sensitivity: float = 1.0
var has_flashlight: bool = false
var patience_s: float = -1.0
var memory: String = "none"
var memory_loops: int = 0
var durability: int = 1
var strength: int = 1
var breach_costs: Dictionary = {}
var search_order: PackedStringArray = []
var search_duration_s: float = 1.0
var attack_range: int = 1
var attack_duration_s: float = 0.5


static func from_json(data: Dictionary) -> SimAttackerProfile:
	var p := SimAttackerProfile.new()
	p.id = str(data.get("id", ""))
	p.display = str(data.get("display", p.id))
	for e in data.get("entries", []):
		p.entries.append(str(e))
	p.weapon = str(data.get("weapon", "hands"))
	p.walk_speed = float(data.get("walk_speed", 1.0))
	p.sight_range = int(data.get("sight_range", 0))
	p.hearing_sensitivity = float(data.get("hearing_sensitivity", 1.0))
	p.has_flashlight = bool(data.get("has_flashlight", false))
	p.patience_s = float(data.get("patience_s", -1.0)) if data.get("patience_s", null) != null else -1.0
	p.memory = str(data.get("memory", "none"))
	p.memory_loops = int(data.get("memory_loops", 0))
	p.durability = int(data.get("durability", 1))
	p.strength = int(data.get("strength", 1))
	p.breach_costs = data.get("breach_costs", {})
	for s in data.get("search_order", []):
		p.search_order.append(str(s))
	p.search_duration_s = float(data.get("search_duration_s", 1.0))
	p.attack_range = int(data.get("attack_range", 1))
	p.attack_duration_s = float(data.get("attack_duration_s", 0.5))
	return p


static func load_by_id(attacker_id: String, dir_path: String = "res://content/attackers") -> SimAttackerProfile:
	var path := "%s/%s.json" % [dir_path, attacker_id]
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return from_json(json.data)


func breach_cost(key: String, fallback: float) -> float:
	return float(breach_costs.get(key, fallback))
