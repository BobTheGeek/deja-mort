class_name SimRng
extends RefCounted

## The only source of randomness in sim/. Constructed with an explicit seed.
## Nothing in sim/ may call randf(), randi() or Time.*.

var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func _init(rng_seed: int = 0) -> void:
	_seed = rng_seed
	_rng.seed = rng_seed


func seed_value() -> int:
	return _seed


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Deterministic pick. Empty input returns null rather than erroring.
func pick(options: Array) -> Variant:
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]


func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state


func fork(salt: int) -> SimRng:
	var child := SimRng.new(_seed ^ salt)
	return child
