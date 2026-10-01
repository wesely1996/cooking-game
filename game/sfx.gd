extends Node
## Sound effects (autoload "Sfx"). Every sound is synthesized at start-up, so
## there are no audio files to license yet. Real recordings can replace them
## later by name.

const RATE := 22050
const VOICES := 10

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds = {
		"chop": _make(0.09, func(t, n): return n * _env(t, 0.002, 0.08) * 0.9, 0.35),
		"slice": _make(0.14, func(t, n): return (n * 0.6 + sin(TAU * 2400.0 * t) * 0.3) * _env(t, 0.01, 0.12), 0.5),
		"squish": _make(0.16, func(t, _n): return sin(TAU * (220.0 - 600.0 * t) * t) * _env(t, 0.01, 0.15), 1.0),
		"roll": _make(0.22, func(t, n): return n * _env(t, 0.06, 0.15) * 0.7, 0.12),
		"swirl": _make(0.3, func(t, n): return (n * 0.5 + sin(TAU * (300.0 + 400.0 * t) * t) * 0.3) * _env(t, 0.05, 0.24), 0.15),
		"whoosh": _make(0.32, func(t, n): return n * _env(t, 0.12, 0.2) * 0.8, 0.1),
		"thud": _make(0.14, func(t, n): return (sin(TAU * 90.0 * t) + n * 0.3) * _env(t, 0.003, 0.13), 0.3),
		"pop": _make(0.08, func(t, _n): return sin(TAU * (500.0 + 3000.0 * t) * t) * _env(t, 0.002, 0.07), 1.0),
		"ding": _make(0.7, func(t, _n): return (sin(TAU * 1320.0 * t) + 0.4 * sin(TAU * 2640.0 * t)) * exp(-t * 6.0) * 0.6, 1.0),
		"bell": _make(0.9, func(t, _n): return (sin(TAU * 1568.0 * t) + 0.5 * sin(TAU * 2093.0 * t)) * exp(-t * 4.0) * 0.5, 1.0),
		"coin": _make(0.25, func(t, _n): return signf(sin(TAU * (988.0 if t < 0.07 else 1319.0) * t)) * _env(t, 0.002, 0.22) * 0.25, 1.0),
		"nope": _make(0.3, func(t, _n): return signf(sin(TAU * 140.0 * t)) * (1.0 if fmod(t, 0.15) < 0.11 else 0.0) * 0.25, 1.0),
		"sizzle": _make(0.6, func(t, n): return n * _env(t, 0.05, 0.5) * 0.5, 0.9),
		"angry": _make(0.4, func(t, _n): return signf(sin(TAU * (180.0 - 60.0 * t) * t)) * _env(t, 0.02, 0.35) * 0.3, 1.0),
		"cheer": _make(0.8, func(t, n): return (n * 0.4 + sin(TAU * 880.0 * t) * 0.2 * sin(TAU * 6.0 * t)) * _env(t, 0.1, 0.6), 0.5),
	}


func play(sound: String, pitch_variation: float = 0.08) -> void:
	if not Game.settings.sound or not _sounds.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _sounds[sound]
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	player.play()


# Builds a mono 16-bit sound from fn(t, noise) -> sample in -1..1. `smooth`
# is a one-pole low-pass factor for the noise (lower = darker).
func _make(duration: float, fn: Callable, smooth: float) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := 0.0
	for i in count:
		var t := float(i) / RATE
		noise += (_rng.randf_range(-1.0, 1.0) - noise) * smooth
		var sample := clampf(fn.call(t, noise), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


# Attack/decay envelope.
static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return maxf(0.0, 1.0 - (t - attack) / decay)
