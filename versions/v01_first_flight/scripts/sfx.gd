extends Node
## Procedural sound effects for Windbags. Registered as autoload `Sfx`.
## All sounds are synthesized at startup into 16-bit mono 22050 Hz AudioStreamWAV.

const SR := 22050
const POOL_2D := 12
const POOL_3D := 16

var _sounds: Dictionary = {}
var _loops: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next3d := 0


func _ready() -> void:
	_rng.seed = 0x57_1D_BA_65
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"Master"
		p3.unit_size = 6.0
		p3.max_distance = 90.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(p3)
		_pool3d.append(p3)
	_generate_all()


# ---------------------------------------------------------------- public API

func has_sound(name: String) -> bool:
	return _sounds.has(name) or _loops.has(name)


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	var s: AudioStream = _sounds.get(name, null)
	if s == null:
		s = _loops.get(name, null)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = maxf(0.05, pitch * randf_range(0.96, 1.04))
	p.volume_db = vol_db
	p.play()


func play3d(name: String, pos: Vector3, pitch := 1.0, vol_db := 0.0) -> void:
	var s: AudioStream = _sounds.get(name, null)
	if s == null:
		s = _loops.get(name, null)
	if s == null:
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = s
	p.global_position = pos
	p.pitch_scale = maxf(0.05, pitch * randf_range(0.96, 1.04))
	p.volume_db = vol_db
	p.play()


func make_loop(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Master"
	var s: AudioStream = _loops.get(name, null)
	if s == null:
		s = _sounds.get(name, null)
	p.stream = s
	add_child(p)
	if s != null:
		p.play()
	return p


# ---------------------------------------------------------------- generation

func _generate_all() -> void:
	_sounds["squeak"] = _finish(_squeak(0.35, 700.0, 1.0), 6, 40)
	_sounds["squeak_short"] = _finish(_squeak(0.12, 350.0, 0.5), 4, 25, 0.5)
	_sounds["boing"] = _finish(_boing(), 4, 30)
	_sounds["pump"] = _finish(_pump(), 8, 80)
	_sounds["roar"] = _finish(_roar(), 6, 120)
	_sounds["vent"] = _finish(_vent(), 10, 120)
	_sounds["puff"] = _finish(_puff(), 10, 60)
	_sounds["deflate"] = _finish(_deflate(), 10, 80)
	_sounds["pop"] = _finish(_pop(), 1, 20)
	_sounds["thud"] = _finish(_thud(), 2, 40)
	_sounds["grab"] = _finish(_grab(), 3, 25)
	_sounds["throw"] = _finish(_throw(), 10, 60)
	_sounds["deliver"] = _finish(_deliver(), 3, 150)
	_sounds["wrong"] = _finish(_wrong(), 8, 80)
	_sounds["whistle"] = _finish(_whistle(), 15, 80)
	_sounds["bell"] = _finish(_bell(), 2, 300)
	_sounds["splash"] = _finish(_splash(), 8, 100)
	_sounds["creak"] = _finish(_creak(), 15, 60)
	_sounds["coin"] = _finish(_coin(), 2, 60, 0.7)
	_sounds["ui"] = _finish(_ui(), 2, 15, 0.5)
	_loops["roar_loop"] = _finish_loop(_roar_loop(), 0.3)
	_loops["wind_loop"] = _finish_loop(_wind_loop(), 0.6)


# ---------------------------------------------------------------- helpers

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * SR))
	return b


func _noise(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = _rng.randf_range(-1.0, 1.0)
	return b


func _lp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / SR)
	var y := 0.0
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		y += a * (x[i] - y)
		out[i] = y
	return out


func _hp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var l := _lp(x, fc)
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		out[i] = x[i] - l[i]
	return out


## State-variable band-pass with centre frequency swept linearly f0 -> f1.
func _bp(x: PackedFloat32Array, f0: float, f1: float, q: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	var k := 1.0 / q
	for i in n:
		var f := lerpf(f0, f1, float(i) / maxf(1.0, n - 1.0))
		var g := 2.0 * sin(PI * minf(f, SR * 0.2) / SR)
		low += g * band
		var high := x[i] - low - k * band
		band += g * high
		out[i] = band * k
	return out


func _add(dst: PackedFloat32Array, src: PackedFloat32Array, gain := 1.0, offset := 0) -> void:
	for i in src.size():
		var j := i + offset
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


func _add_bell(dst: PackedFloat32Array, start: float, freq: float, tau: float, amp := 1.0,
		ratios := [1.0, 2.0, 3.0, 4.2], amps := [1.0, 0.4, 0.25, 0.1]) -> void:
	var off := int(start * SR)
	var n := dst.size() - off
	for p in ratios.size():
		var w: float = TAU * freq * ratios[p] / SR
		var a: float = amp * amps[p]
		var t_p := tau / (1.0 + 0.5 * p)
		for i in n:
			var t := float(i) / SR
			var e := exp(-t / t_p)
			if e < 0.001:
				break
			var att := minf(1.0, i / 40.0)
			dst[off + i] += sin(w * i) * e * a * att


func _finish(x: PackedFloat32Array, fade_in_ms := 3, fade_out_ms := 20, peak_scale := 1.0) -> AudioStreamWAV:
	var n := x.size()
	var fi := mini(n / 2, int(fade_in_ms * SR / 1000.0))
	var fo := mini(n / 2, int(fade_out_ms * SR / 1000.0))
	for i in fi:
		x[i] *= float(i) / fi
	for i in fo:
		x[n - 1 - i] *= float(i) / fo
	var pk := 0.0001
	for i in n:
		pk = maxf(pk, absf(x[i]))
	var g := 0.8 * peak_scale / pk
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(x[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	return s


## x must be longer than the loop body by `xfade` seconds; the extra tail is
## crossfaded into the head so loop end flows into loop start.
func _finish_loop(x: PackedFloat32Array, xfade: float) -> AudioStreamWAV:
	var xf := int(xfade * SR)
	var n := x.size() - xf
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i]
	for i in xf:
		var w := float(i) / xf
		out[i] = x[i] * w + x[n + i] * (1.0 - w)
	var s := _finish(out, 0, 0)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s


# ---------------------------------------------------------------- sounds

func _squeak(dur: float, base: float, breath: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var n := b.size()
	var nz := _hp(_noise(n), 3000.0)
	var ph := 0.0
	var vr := _rng.randf() * TAU
	for i in n:
		var t := float(i) / SR
		var u := t / dur
		var vib := 1.0 + 0.06 * sin(TAU * 30.0 * t + 2.0 * sin(TAU * 7.0 * t) + vr)
		var f := base * (1.0 + 0.1 * u) * vib
		ph += TAU * f / SR
		var s := sin(ph) + 0.28 * sin(2.0 * ph) + 0.08 * sin(3.0 * ph)
		var env := pow(sin(PI * clampf(u, 0.0, 1.0)), 0.5) * (1.0 - 0.3 * u)
		b[i] = (s + nz[i] * 0.12 * breath) * env
	return b


func _boing() -> PackedFloat32Array:
	var b := _buf(0.18)
	var n := b.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var u := t / 0.18
		var f := lerpf(180.0, 420.0, u) * (1.0 + 0.05 * sin(TAU * 38.0 * t))
		ph += TAU * f / SR
		b[i] = (sin(ph) + 0.35 * sin(2.0 * ph)) * (1.0 - 0.5 * u)
	return b


func _pump() -> PackedFloat32Array:
	var n := int(0.35 * SR)
	var nz := _bp(_noise(n), 500.0, 900.0, 1.5)
	var b := _buf(0.35)
	for i in n:
		var u := float(i) / n
		b[i] = nz[i] * pow(sin(PI * u), 1.5) * 1.0
	var thunk := _buf(0.12)
	for i in thunk.size():
		var t := float(i) / SR
		thunk[i] = sin(TAU * 110.0 * t * (1.0 - 2.0 * t)) * exp(-t / 0.035)
	_add(b, thunk, 1.2)
	return b


func _roar() -> PackedFloat32Array:
	var n := int(0.9 * SR)
	var a := _lp(_noise(n), 600.0)
	var c := _lp(_noise(n), 1800.0)
	var b := _buf(0.9)
	for i in n:
		var t := float(i) / SR
		var env := minf(1.0, t / 0.025) * exp(-t / 0.35)
		var rumble := sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 83.0 * t) * 0.2
		b[i] = (a[i] * 2.5 + c[i] * 0.6 * (1.0 + 0.4 * sin(TAU * 17.0 * t)) + rumble) * env
	return b


func _roar_loop() -> PackedFloat32Array:
	var n := int(2.3 * SR)
	var a := _lp(_noise(n), 450.0)
	var c := _lp(_noise(n), 1400.0)
	var b := _buf(2.3)
	for i in n:
		var t := float(i) / SR
		var m := 1.0 + 0.25 * sin(TAU * 0.9 * t) + 0.15 * sin(TAU * 13.0 * t)
		b[i] = (a[i] * 3.0 + c[i] * 0.5 + sin(TAU * 52.0 * t) * 0.25) * m
	return b


func _wind_loop() -> PackedFloat32Array:
	var n := int(4.6 * SR)
	var a := _lp(_noise(n), 500.0)
	var c := _bp(_noise(n), 700.0, 1100.0, 1.2)
	var b := _buf(4.6)
	for i in n:
		var t := float(i) / SR
		var sw := 0.6 + 0.25 * sin(TAU * 0.35 * t + 1.0) + 0.15 * sin(TAU * 0.8 * t)
		b[i] = (a[i] * 2.0 + c[i] * 0.8) * sw
	return b


func _vent() -> PackedFloat32Array:
	var n := int(0.8 * SR)
	var h := _hp(_noise(n), 2500.0)
	var b := _buf(0.8)
	for i in n:
		var t := float(i) / SR
		b[i] = h[i] * minf(1.0, t / 0.015) * exp(-t / 0.3)
	return b


func _puff() -> PackedFloat32Array:
	var n := int(0.5 * SR)
	var s := _bp(_noise(n), 300.0, 2500.0, 1.2)
	var b := _buf(0.5)
	for i in n:
		var u := float(i) / n
		b[i] = s[i] * (0.3 + 0.7 * u) * minf(1.0, u / 0.08) * (1.0 - 0.6 * pow(u, 4.0))
	return b


func _deflate() -> PackedFloat32Array:
	var n := int(0.9 * SR)
	var b := _buf(0.9)
	var nz := _noise(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var u := t / 0.9
		var f := 420.0 * pow(120.0 / 420.0, u) * (1.0 + 0.04 * sin(TAU * 23.0 * t))
		ph += f / SR
		var saw := 2.0 * (ph - floorf(ph)) - 1.0
		var flutter := 0.5 + 0.5 * sin(TAU * lerpf(32.0, 18.0, u) * t)
		flutter = 0.35 + 0.65 * flutter * flutter
		b[i] = (saw + nz[i] * 0.15) * flutter * (1.0 - 0.6 * u)
	return _lp(b, 2200.0)


func _pop() -> PackedFloat32Array:
	var n := int(0.15 * SR)
	var h := _hp(_noise(n), 500.0)
	var b := _buf(0.15)
	for i in n:
		var t := float(i) / SR
		b[i] = h[i] * exp(-t / 0.02) + sin(TAU * 220.0 * t * (1.0 - 3.0 * t)) * exp(-t / 0.03) * 0.6
	return b


func _thud() -> PackedFloat32Array:
	var n := int(0.2 * SR)
	var l := _lp(_noise(n), 500.0)
	var b := _buf(0.2)
	for i in n:
		var t := float(i) / SR
		b[i] = sin(TAU * 90.0 * t * (1.0 - 0.8 * t)) * exp(-t / 0.06) + l[i] * 1.5 * exp(-t / 0.025)
	return b


func _grab() -> PackedFloat32Array:
	var b := _buf(0.1)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * lerpf(300.0, 520.0, t / 0.1) / SR
		b[i] = (sin(ph) + 0.3 * sin(2.0 * ph)) * exp(-t / 0.03)
	return b


func _throw() -> PackedFloat32Array:
	var n := int(0.25 * SR)
	var s := _bp(_noise(n), 400.0, 1600.0, 1.5)
	var b := _buf(0.25)
	for i in n:
		var u := float(i) / n
		b[i] = s[i] * pow(sin(PI * pow(u, 0.7)), 1.5)
	return b


func _deliver() -> PackedFloat32Array:
	var b := _buf(0.9)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_add_bell(b, i * 0.12, notes[i], 0.22, 1.0 if i < 3 else 1.2,
				[1.0, 2.0, 3.0, 4.2], [1.0, 0.35, 0.2, 0.08])
	return b


func _wrong() -> PackedFloat32Array:
	var b := _buf(0.7)
	var ph := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / SR
		var second := t >= 0.34
		var lt := t - (0.34 if second else 0.0)
		var f := 330.0 if not second else 262.0
		f *= (1.0 - 0.04 * minf(1.0, lt / 0.3)) * (1.0 + 0.012 * sin(TAU * 6.0 * t))
		ph += f / SR
		var saw := 2.0 * (ph - floorf(ph)) - 1.0
		var env := minf(1.0, lt / 0.03) * (1.0 - smoothstep(0.24, 0.34, lt) * (1.0 if not second else 0.0))
		if second:
			env *= 1.0 - smoothstep(0.2, 0.36, lt)
		var wah := 0.6 + 0.4 * sin(PI * clampf(lt / 0.34, 0.0, 1.0))
		b[i] = saw * env * wah
	var nasal := _bp(b, 1000.0, 800.0, 2.5)
	for i in n:
		b[i] = nasal[i] * 1.5 + b[i] * 0.2
	return b


func _whistle() -> PackedFloat32Array:
	var b := _buf(0.8)
	var nz := _bp(_noise(b.size()), 2800.0, 2800.0, 3.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var second := t >= 0.38
		var f := 1175.0 if second else 880.0
		var trill := 1.0 + 0.025 * sin(TAU * 38.0 * t)
		ph += TAU * f * trill / SR
		var lt := t - (0.38 if second else 0.0)
		var env := minf(1.0, lt / 0.03)
		var dur_end := 0.42 if second else 0.34
		env *= 1.0 - smoothstep(dur_end - 0.06, dur_end, lt) * (1.0 if not second else 0.0)
		if second:
			env *= 1.0 - smoothstep(0.3, 0.42, lt)
		var am := 0.8 + 0.2 * sin(TAU * 38.0 * t)
		b[i] = (sin(ph) + 0.15 * sin(2.0 * ph) + nz[i] * 0.6) * env * am
	return b


func _bell() -> PackedFloat32Array:
	var b := _buf(1.5)
	_add_bell(b, 0.0, 880.0, 0.5, 1.0,
			[1.0, 2.76, 5.4, 8.93, 0.5], [1.0, 0.5, 0.3, 0.15, 0.4])
	# slightly detuned twin for beating shimmer
	_add_bell(b, 0.0, 884.0, 0.45, 0.4, [1.0, 2.76], [1.0, 0.4])
	return b


func _splash() -> PackedFloat32Array:
	var n := int(0.5 * SR)
	var l := _lp(_noise(n), 700.0)
	l = _lp(l, 900.0)
	var b := _buf(0.5)
	for i in n:
		var t := float(i) / SR
		b[i] = l[i] * minf(1.0, t / 0.02) * exp(-t / 0.14)
	return b


func _creak() -> PackedFloat32Array:
	var n := int(0.4 * SR)
	var x := PackedFloat32Array()
	x.resize(n)
	var nz := _noise(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += lerpf(24.0, 38.0, t / 0.4) * (1.0 + 0.3 * sin(TAU * 5.0 * t)) / SR
		var gate := pow(maxf(0.0, sin(TAU * ph)), 3.0)
		var crackle := 1.0 if nz[i] > 0.6 else 0.25
		x[i] = nz[i] * gate * crackle
	var r := _bp(x, 450.0, 800.0, 9.0)
	var b := _buf(0.4)
	for i in n:
		var u := float(i) / n
		b[i] = r[i] * sin(PI * u)
	return b


func _coin() -> PackedFloat32Array:
	var b := _buf(0.3)
	_add_bell(b, 0.0, 1760.0, 0.09, 1.0, [1.0, 2.0], [1.0, 0.2])
	_add_bell(b, 0.07, 2349.0, 0.1, 1.0, [1.0, 2.0], [1.0, 0.2])
	return b


func _ui() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / SR
		b[i] = sin(TAU * lerpf(900.0, 600.0, t / 0.05) * t) * exp(-t / 0.012)
	return b
