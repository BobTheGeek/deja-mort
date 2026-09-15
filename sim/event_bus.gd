class_name SimEventBus
extends RefCounted

## The one bus. sim/ emits; everything else subscribes. Presentation never emits.

var _log: Array[SimEvent] = []
var _subscribers: Array[Callable] = []


func emit_event(e: SimEvent) -> void:
	_log.append(e)
	for cb in _subscribers:
		if cb.is_valid():
			cb.call(e)


func subscribe(cb: Callable) -> void:
	if not _subscribers.has(cb):
		_subscribers.append(cb)


func unsubscribe(cb: Callable) -> void:
	_subscribers.erase(cb)


func log_all() -> Array[SimEvent]:
	return _log.duplicate()


## How many events have happened. A listener keeps this as a mark and reads on
## from it, so what it hears does not depend on where in the tick the noise was
## made — the attacker used to listen at step 3 and the television made its noise
## at step 5, which meant the television could not be heard at all.
func count() -> int:
	return _log.size()


func from_index(index: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for i in range(maxi(index, 0), _log.size()):
		out.append(_log[i])
	return out


func since(tick: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in _log:
		if e.tick >= tick:
			out.append(e)
	return out


func of_type(type: String) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in _log:
		if e.type == type:
			out.append(e)
	return out


func to_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for e in _log:
		lines.append(e.to_line())
	return lines


func clear() -> void:
	_log.clear()
