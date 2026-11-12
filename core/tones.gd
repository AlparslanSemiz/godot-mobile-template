class_name Tones
extends RefCounted
## Tiny synthesized sound effects, so the template ships without audio files.
## Replace with real .wav/.ogg assets in a real game.

const MIX_RATE: int = 44100


static func click() -> AudioStreamWAV:
	return sweep(900.0, 700.0, 0.04, 0.35)


static func jump() -> AudioStreamWAV:
	return sweep(420.0, 820.0, 0.09, 0.4)


static func score() -> AudioStreamWAV:
	return sweep(980.0, 1320.0, 0.08, 0.35)


static func hit() -> AudioStreamWAV:
	return sweep(300.0, 70.0, 0.25, 0.6, true)


## A sine (or noisy) pitch sweep with a fast attack and an exponential tail.
static func sweep(from_hz: float, to_hz: float, seconds: float, volume: float, noisy: bool = false) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in count:
		var t: float = float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, t) / MIX_RATE
		var envelope: float = minf(t * 40.0, 1.0) * exp(-4.0 * t)
		var sample: float = sin(phase)
		if noisy:
			sample = lerpf(sample, rng.randf_range(-1.0, 1.0), 0.5)
		bytes.encode_s16(i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
