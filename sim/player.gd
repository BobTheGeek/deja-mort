class_name SimPlayer
extends SimActor

## Player-only loop bookkeeping. The outcome tracker (M2) reads these.

var never_seen: bool = true
var seen_count: int = 0
var damage_taken: int = 0
var collected: PackedStringArray = []
var found_in: String = ""


func collect(id: String) -> bool:
	if collected.has(id):
		return false
	collected.append(id)
	return true
