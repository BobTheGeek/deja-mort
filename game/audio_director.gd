class_name AudioDirector
extends Node3D

## Subscribes to the sim's event bus and turns events into sound. It is a
## consumer of the same events the attacker's perception reads — one bus, two
## listeners — so if you can hear him, it is because the sim said he made noise.
##
## Cues are synthesised here. No audio file ships before M4, and greybox means
## greybox for ears too.

const MAP_PATH := "res://content/audio_map.json"
const SAMPLE_RATE := 22050

var map: Dictionary = {}
var played: int = 0            # tests and captures read this

var _streams: Dictionary = {}  # cue name -> AudioStreamWAV
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _metronome_at: float = 0.0


func setup() -> void:
	var json := JSON.new()
	if not FileAccess.file_exists(MAP_PATH) or json.parse(FileAccess.get_file_as_string(MAP_PATH)) != OK:
		push_error("AudioDirector: cannot read %s" % MAP_PATH)
		return
	map = json.data
	for name in (map.get("cues", {}) as Dictionary):
		_streams[name] = _synthesise(map["cues"][name])
	for i in int(map.get("voices", 12)):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = float(map.get("unit_size", 9.0))
		voice.max_distance = float(map.get("max_distance", 24.0))
		voice.volume_db = float(map.get("bus_gain_db", -4.0))
		add_child(voice)
		_voices.append(voice)


func listen(world: SimWorld) -> void:
	_metronome_at = 0.0
	world.events.subscribe(_on_event)


## The timer is the soundtrack, and for most of the loop the soundtrack is
## nothing. A cue only plays inside its window, so leaving `cue` out of the map
## is what keeps the clock quiet until the last ten seconds.
func tick_metronome(world: SimWorld) -> void:
	var spec: Dictionary = map.get("metronome", {})
	if spec.is_empty() or not world.ending.is_empty():
		return
	var remaining := world.timer_remaining_s()
	var urgent := remaining <= float(spec.get("urgent_below_s", 10.0)) and remaining > 0.0
	var cue := str(spec.get("urgent_cue", "")) if urgent else str(spec.get("cue", ""))
	if cue.is_empty():
		return
	var interval := float(spec.get("urgent_interval_s", 0.5)) if urgent \
		else float(spec.get("interval_s", 1.0))
	var elapsed := world.time_s()
	if elapsed < _metronome_at:
		_metronome_at = 0.0
	# The clock has been silent, so _metronome_at is still back at zero and the
	# first tick of the window lands the moment it opens.
	if elapsed < _metronome_at + interval:
		return
	_metronome_at = elapsed
	_play(cue, _listener_cell(world), 1.0)


func _on_event(event: SimEvent) -> void:
	var rule := _match(event)
	if rule.is_empty():
		return
	var gain := 1.0
	if bool(rule.get("scale_by_loudness", false)):
		gain = clampf(event.loudness / 6.0, 0.25, 1.5)
	var at := event.cell
	if bool(rule.get("global", false)) or at == SimEvent.NO_CELL:
		at = SimEvent.NO_CELL
	_play(str(rule.get("cue", "")), at, gain)


## First match wins, top to bottom, on event fields only.
func _match(event: SimEvent) -> Dictionary:
	for rule in map.get("events", []):
		var spec: Dictionary = rule
		if str(spec.get("type", "")) != event.type:
			continue
		if spec.has("meta") and not event.meta.has(str(spec["meta"])):
			continue
		if spec.has("layer") and str(event.meta.get("layer", "")) != str(spec["layer"]):
			continue
		if spec.has("role") and not _role_matches(event, str(spec["role"])):
			continue
		if spec.has("min_loudness") and event.loudness < float(spec["min_loudness"]):
			continue
		return spec
	return {}


func _role_matches(event: SimEvent, role: String) -> bool:
	# The player's own footsteps are not information; his are.
	return role == "attacker" and event.actor != "player" and not event.actor.is_empty()


func _play(cue: String, cell: Vector2i, gain: float) -> void:
	if not _streams.has(cue) or _voices.is_empty():
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _streams[cue]
	voice.position = IsoCamera.cell_to_world(cell, 0.6) if cell != SimEvent.NO_CELL else position
	voice.volume_db = float(map.get("bus_gain_db", -4.0)) + linear_to_db(clampf(gain, 0.05, 2.0))
	voice.play()
	played += 1


func _listener_cell(world: SimWorld) -> Vector2i:
	return world.player.pos


## A tone or a noise burst with an exponential decay. Crude on purpose.
func _synthesise(spec: Dictionary) -> AudioStreamWAV:
	var ms := int(spec.get("ms", 120))
	var hz := float(spec.get("hz", 440.0))
	var gain := float(spec.get("gain", 0.6))
	var decay := float(spec.get("decay", 6.0))
	var noisy := str(spec.get("kind", "tone")) == "noise"
	var count := int(SAMPLE_RATE * ms / 1000.0)

	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var step := TAU * hz / float(SAMPLE_RATE)
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var envelope: float = exp(-decay * t) * gain
		var sample: float = randf() * 2.0 - 1.0 if noisy else sin(phase)
		if noisy:
			# Cheap one-pole low pass so noise reads as a thud, not static.
			sample = lerpf(sample, sin(phase), 0.35)
		phase += step
		var value := int(clampf(sample * envelope, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
