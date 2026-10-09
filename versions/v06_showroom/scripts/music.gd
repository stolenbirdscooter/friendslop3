extends Node
## Endless procedural waltz-musette soundtrack for Windbags. Autoload `Music`.
## Streams through an AudioStreamGenerator (22050 Hz); everything is synthesized
## live from precomputed single-cycle wavetables and phase accumulators.
##
## Voices: plucked bass, "pah" chord stabs, detuned reed melody, reed countermelody,
## soft pad, plus a small pool of bell/brass voices (sparkles and stingers).
## Moods: menu, morning, dusk, night, results.

const SR: int = 22050
const SRF: float = 22050.0
const TBL: int = 2048
const TBLF: float = 2048.0
const BLOCK: int = 64
const NP: int = 6
const BUF_LEN: float = 0.5
const FILL_TARGET: float = 0.25
const MAX_PUSH: int = 2048
const TAU_MIX: float = 1.7
const TAU_INT: float = 0.7
const VIB_INC: float = 5.1 / 22050.0

const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const PENT: Array[int] = [0, 2, 4, 7, 9]
const KEYS: Array[int] = [0, 2, 5, 7, 10]

# Chords as Vector2i(root offset in semitones, quality: 0 major / 1 minor)
const C_I := Vector2i(0, 0)
const C_II := Vector2i(2, 1)
const C_III := Vector2i(4, 1)
const C_IV := Vector2i(5, 0)
const C_V := Vector2i(7, 0)
const C_VI := Vector2i(9, 1)
const C_BVII := Vector2i(10, 0)
const C_IVM := Vector2i(5, 1)  # borrowed minor iv
const C_IM := Vector2i(0, 1)
const C_BIII := Vector2i(3, 0)
const C_BVI := Vector2i(8, 0)

const PROG_Q_MAJ: Array = [
	[C_I, C_VI, C_II, C_V], [C_I, C_IV, C_II, C_V], [C_I, C_III, C_IV, C_V],
	[C_I, C_I, C_IV, C_V], [C_I, C_IV, C_I, C_V], [C_I, C_VI, C_IV, C_V],
]
const PROG_A_MAJ: Array = [
	[C_I, C_IV, C_V, C_I], [C_I, C_II, C_V, C_I], [C_I, C_VI, C_V, C_I],
	[C_I, C_IV, C_IVM, C_I], [C_I, C_IV, C_V, C_I],
]
const PROG_Q_MIN: Array = [
	[C_IM, C_IVM, C_BVII, C_V], [C_IM, C_BVI, C_IVM, C_V],
	[C_IM, C_BIII, C_BVII, C_V], [C_IM, C_IVM, C_IM, C_V],
]
const PROG_A_MIN: Array = [
	[C_IM, C_IVM, C_V, C_IM], [C_IM, C_BVI, C_V, C_IM], [C_IM, C_BVII, C_V, C_IM],
]

const PAT_MID: Array = [
	[2, 2, 2], [3, 3], [4, 2], [2, 4], [3, 1, 2], [2, 1, 1, 2], [1, 1, 2, 2], [2, 2, 1, 1],
	[6], [3, 2, 1],
]
const PAT_MID_W: Array[float] = [3.0, 3.0, 2.0, 2.0, 1.5, 1.5, 1.0, 1.0, 0.7, 1.0]
const PAT_END: Array = [[2, 4], [6], [3, 3], [1, 1, 4]]
const PAT_END_W: Array[float] = [3.0, 2.0, 2.0, 1.0]
const STEPS: Array[int] = [-2, -1, 0, 1, 2]
const STEPS_W: Array[float] = [0.12, 0.3, 0.1, 0.3, 0.12]

const MOODS: Dictionary = {
	"menu": {"bpm": 84.0, "bass": 0.0, "chord": 0.0, "reed": 0.0, "bell": 0.9, "pad": 1.0,
		"cut": 1600.0, "minor": false, "rest": 0.3, "bell_mel": 0.8, "bell_rand": 0.3,
		"bass_mode": 0, "chord_mode": 0},
	"morning": {"bpm": 108.0, "bass": 1.0, "chord": 1.0, "reed": 1.0, "bell": 0.55, "pad": 0.0,
		"cut": 2800.0, "minor": false, "rest": 0.12, "bell_mel": 0.12, "bell_rand": 0.15,
		"bass_mode": 1, "chord_mode": 2},
	"dusk": {"bpm": 92.0, "bass": 0.8, "chord": 0.55, "reed": 0.8, "bell": 0.4, "pad": 0.55,
		"cut": 1500.0, "minor": true, "rest": 0.3, "bell_mel": 0.15, "bell_rand": 0.2,
		"bass_mode": 1, "chord_mode": 1},
	"night": {"bpm": 76.0, "bass": 0.0, "chord": 0.0, "reed": 0.0, "bell": 0.8, "pad": 0.25,
		"cut": 1400.0, "minor": false, "rest": 0.6, "bell_mel": 0.3, "bell_rand": 0.2,
		"bass_mode": 0, "chord_mode": 0},
	"results": {"bpm": 112.0, "bass": 1.0, "chord": 1.0, "reed": 1.0, "bell": 0.7, "pad": 0.0,
		"cut": 3000.0, "minor": false, "rest": 0.0, "bell_mel": 0.4, "bell_rand": 0.2,
		"bass_mode": 1, "chord_mode": 2},
}
const RESULTS_TAIL: Dictionary = {"bpm": 90.0, "bass": 0.0, "chord": 0.0, "reed": 0.0,
	"bell": 0.8, "pad": 0.6, "cut": 1700.0, "minor": false, "rest": 0.45, "bell_mel": 0.5,
	"bell_rand": 0.25, "bass_mode": 0, "chord_mode": 0}

# Mix levels
const L_BASS: float = 0.34
const L_CHORD: float = 0.075
const L_REED: float = 0.2
const L_COUNTER: float = 0.12
const L_PAD: float = 0.045
const L_BELL: float = 0.2
const ECHO_SEND: float = 0.55

var _rng := RandomNumberGenerator.new()
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _vol_db: float = -12.0
var _cap: int = 0

# wavetables
var _sin_tab := PackedFloat32Array()
var _reed_tab := PackedFloat32Array()
var _bass_tab := PackedFloat32Array()
var _soft_tab := PackedFloat32Array()
var _pad_tab := PackedFloat32Array()

# block mix buffers
var _mix_l := PackedFloat32Array()
var _mix_r := PackedFloat32Array()
var _mix_s := PackedFloat32Array()

# echo
var _dl_l := PackedFloat32Array()
var _dl_r := PackedFloat32Array()
var _dp_l: int = 0
var _dp_r: int = 0
var _fb_l: float = 0.0
var _fb_r: float = 0.0

# mood / control state
var _mood: String = ""
var _p_rest: float = 0.3
var _p_bell_mel: float = 0.5
var _p_bell_rand: float = 0.3
var _p_bass_mode: int = 0
var _p_chord_mode: int = 0
var _minor: bool = false
var _t_bpm: float = 90.0
var _t_bass: float = 0.0
var _t_chord: float = 0.0
var _t_reed: float = 0.0
var _t_bell: float = 0.0
var _t_pad: float = 0.0
var _t_cut: float = 2000.0
var _g_bass: float = 0.0
var _g_chord: float = 0.0
var _g_reed: float = 0.0
var _g_counter: float = 0.0
var _g_bell: float = 0.0
var _g_pad: float = 0.0
var _cut_s: float = 2000.0
var _lp_a: float = 0.3
var _inten: float = 0.0
var _inten_s: float = 0.0
var _fade: float = 0.0
var _bpm_s: float = 84.0

# sequencer
var _tick_left: int = 0
var _tick_acc: float = 0.0
var _tick_len: float = 7000.0
var _tick: int = 0
var _bar_in_phrase: int = -1
var _phrase_bars: int = 0
var _phrase_chords: Array = []
var _phrase_notes: Array = []
var _note_idx: int = 0
var _phrase_is_q: bool = true
var _phrase_count: int = 0
var _last_q_notes: Array = []
var _bar_rest: bool = false
var _force_new: bool = false
var _cadence_next: bool = false
var _tail_next: bool = false
var _key_pc: int = 0
var _tonic: int = 60
var _cur_chord := Vector2i(0, 0)
var _bass_root: int = 36
var _chord_midi: Array[int] = [48, 52, 55]
var _counter_pool: Array[int] = []
var _counter_last: int = 62
var _st_queue: Array[String] = []

# bass voice
var _b_ph: float = 0.0
var _b_inc: float = 0.0
var _b_a: float = 0.0
var _b_rise: float = 0.0
var _b_dec: float = 0.999
var _b_vel: float = 1.0
var _b_vel_t: float = 1.0

# chord voice
var _c_ph := PackedFloat32Array([0.0, 0.0, 0.0])
var _c_inc := PackedFloat32Array([0.0, 0.0, 0.0])
var _c_a: float = 0.0
var _c_rise: float = 0.0
var _c_dec: float = 0.999
var _c_vel: float = 1.0

# reed voice (melody) and counter voice
var _r_ph1: float = 0.0
var _r_ph2: float = 0.0
var _r_vph: float = 0.0
var _r_inc: float = 0.01
var _r_tinc: float = 0.01
var _r_env: float = 0.0
var _r_gate: float = 0.0
var _r_off: int = 0
var _r_age: float = 0.0
var _r_lp1: float = 0.0
var _r_lp2: float = 0.0
var _k_ph: float = 0.0
var _k_vph: float = 0.3
var _k_inc: float = 0.01
var _k_tinc: float = 0.01
var _k_env: float = 0.0
var _k_gate: float = 0.0
var _k_off: int = 0
var _k_lp1: float = 0.0
var _k_lp2: float = 0.0

# pad
var _pd_ph := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _pd_inc := PackedFloat32Array([0.0, 0.0, 0.0])
var _pd_tinc := PackedFloat32Array([0.0, 0.0, 0.0])
var _pd_lfo: float = 0.0

# bell / brass pool
var _p_on := PackedInt32Array()
var _p_kind := PackedInt32Array()
var _p_delay := PackedInt32Array()
var _p_hold := PackedInt32Array()
var _p_ph := PackedFloat32Array()
var _p_ph2 := PackedFloat32Array()
var _p_inc := PackedFloat32Array()
var _p_env := PackedFloat32Array()
var _p_rise := PackedFloat32Array()
var _p_dec := PackedFloat32Array()
var _p_amp := PackedFloat32Array()
var _p_pl := PackedFloat32Array()
var _p_pr := PackedFloat32Array()
var _p_slide := PackedFloat32Array()
var _p_lp := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_tables()
	_mix_l.resize(BLOCK)
	_mix_r.resize(BLOCK)
	_mix_s.resize(BLOCK)
	_dl_l.resize(6173)
	_dl_r.resize(5387)
	_p_on.resize(NP)
	_p_kind.resize(NP)
	_p_delay.resize(NP)
	_p_hold.resize(NP)
	for a: PackedFloat32Array in [_p_ph, _p_ph2, _p_inc, _p_env, _p_rise, _p_dec, _p_amp,
			_p_pl, _p_pr, _p_slide, _p_lp]:
		a.resize(NP)
	_key_pc = KEYS[_rng.randi() % KEYS.size()]
	_update_tonic()
	_mood = ""
	set_mood("menu")
	# Start fully faded in on the target levels of the first mood.
	_g_bass = _t_bass
	_g_chord = _t_chord
	_g_reed = _t_reed
	_g_bell = _t_bell
	_g_pad = _t_pad
	_cut_s = _t_cut
	_bpm_s = _t_bpm
	_force_new = false
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SRF
	gen.buffer_length = BUF_LEN
	_player.stream = gen
	_player.volume_db = _vol_db
	if AudioServer.get_bus_index(&"Music") >= 0:
		_player.bus = &"Music"
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback


# ---------------------------------------------------------------- public API

func set_mood(m: String) -> void:
	if not MOODS.has(m):
		push_warning("Music: unknown mood '%s'" % m)
		return
	if m == _mood and m != "results":
		return
	_mood = m
	_apply_params(MOODS[m])
	_force_new = true
	_cadence_next = (m == "results")
	_tail_next = false


func set_intensity(x: float) -> void:
	_inten = clampf(x, 0.0, 1.0)


func set_volume_db(db: float) -> void:
	_vol_db = db
	if _player != null:
		_player.volume_db = db


func stinger(kind: String) -> void:
	if kind != "deliver" and kind != "fail" and kind != "day":
		push_warning("Music: unknown stinger '%s'" % kind)
		return
	if _st_queue.size() < 4:
		_st_queue.append(kind)


func set_seed(s: int) -> void:
	_rng.seed = s


# ---------------------------------------------------------------- streaming

func _process(_delta: float) -> void:
	if _pb == null:
		return
	var avail: int = _pb.get_frames_available()
	if avail <= 0:
		return
	_cap = maxi(_cap, avail)
	var cap: int = _cap
	var buffered: int = cap - avail
	var want: int = int(FILL_TARGET * SRF) - buffered
	if want <= 0:
		return
	_pb.push_buffer(_render(mini(mini(want, avail), MAX_PUSH)))


func _render(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	var i: int = 0
	while i < n:
		if _tick_left <= 0:
			_on_tick()
		var m: int = mini(mini(n - i, _tick_left), BLOCK)
		_smooth(m)
		_mix_l.fill(0.0)
		_mix_r.fill(0.0)
		_mix_s.fill(0.0)
		_v_bass(m)
		_v_chord(m)
		_v_reed(m)
		_v_counter(m)
		_v_pad(m)
		_v_pool(m)
		_v_out(m, out, i)
		_tick_left -= m
		i += m
	return out


func _smooth(m: int) -> void:
	var dt: float = float(m) / SRF
	var k: float = 1.0 - exp(-dt / TAU_MIX)
	_g_bass += (_t_bass - _g_bass) * k
	_g_chord += (_t_chord - _g_chord) * k
	_g_reed += (_t_reed - _g_reed) * k
	_g_bell += (_t_bell - _g_bell) * k
	_g_pad += (_t_pad - _g_pad) * k
	_cut_s += (_t_cut - _cut_s) * k
	_inten_s += (_inten - _inten_s) * (1.0 - exp(-dt / TAU_INT))
	var ss: float = smoothstep(0.25, 0.7, _inten_s)
	_g_counter = _g_reed * ss
	_lp_a = 1.0 - exp(-TAU * _cut_s / SRF)
	_fade = minf(1.0, _fade + dt / 2.5)
	_b_vel += (_b_vel_t - _b_vel) * 0.3
	for q in 3:
		_pd_inc[q] += (_pd_tinc[q] - _pd_inc[q]) * 0.006
	_r_inc += (_r_tinc - _r_inc) * 0.2
	_k_inc += (_k_tinc - _k_inc) * 0.2
	_r_age += dt
	if _r_off > 0:
		_r_off -= m
		if _r_off <= 0:
			_r_gate = 0.0
	if _k_off > 0:
		_k_off -= m
		if _k_off <= 0:
			_k_gate = 0.0


# ---------------------------------------------------------------- voices

func _v_bass(m: int) -> void:
	if _g_bass < 0.003 or (_b_a < 0.0004 and _b_rise <= 0.0):
		return
	var tab := _bass_tab
	var ml := _mix_l
	var mr := _mix_r
	var ph: float = _b_ph
	var inc: float = _b_inc
	var a: float = _b_a
	var rise: float = _b_rise
	var dec: float = _b_dec
	var gain: float = _g_bass * _b_vel * L_BASS
	for j in m:
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		if rise > 0.0:
			a += rise
			if a >= 1.0:
				a = 1.0
				rise = 0.0
		else:
			a *= dec
		var s: float = tab[int(ph * TBLF)] * a * gain
		ml[j] += s * 0.78
		mr[j] += s * 0.62
	_b_ph = ph
	_b_a = a
	_b_rise = rise


func _v_chord(m: int) -> void:
	if _g_chord < 0.003 or (_c_a < 0.0004 and _c_rise <= 0.0):
		return
	var tab := _soft_tab
	var ml := _mix_l
	var mr := _mix_r
	var p0: float = _c_ph[0]
	var p1: float = _c_ph[1]
	var p2: float = _c_ph[2]
	var i0: float = _c_inc[0]
	var i1: float = _c_inc[1]
	var i2: float = _c_inc[2]
	var a: float = _c_a
	var rise: float = _c_rise
	var dec: float = _c_dec
	var gain: float = _g_chord * _c_vel * L_CHORD
	for j in m:
		p0 += i0
		if p0 >= 1.0:
			p0 -= 1.0
		p1 += i1
		if p1 >= 1.0:
			p1 -= 1.0
		p2 += i2
		if p2 >= 1.0:
			p2 -= 1.0
		if rise > 0.0:
			a += rise
			if a >= 1.0:
				a = 1.0
				rise = 0.0
		else:
			a *= dec
		var s: float = (tab[int(p0 * TBLF)] + tab[int(p1 * TBLF)] + tab[int(p2 * TBLF)]) * a * gain
		ml[j] += s * 0.85
		mr[j] += s * 0.7
	_c_ph[0] = p0
	_c_ph[1] = p1
	_c_ph[2] = p2
	_c_a = a
	_c_rise = rise


func _v_reed(m: int) -> void:
	if _g_reed < 0.003 or (_r_gate < 0.5 and _r_env < 0.0006):
		return
	var tab := _reed_tab
	var sn := _sin_tab
	var ml := _mix_l
	var mr := _mix_r
	var ms := _mix_s
	var ph1: float = _r_ph1
	var ph2: float = _r_ph2
	var vph: float = _r_vph
	var inc: float = _r_inc
	var env: float = _r_env
	var gate: float = _r_gate
	var rate: float = 0.0035 if gate > env else 0.0012
	var a: float = _lp_a
	var s1: float = _r_lp1
	var s2: float = _r_lp2
	var vib: float = clampf(_r_age - 0.18, 0.0, 0.6) * 0.0075
	var gain: float = _g_reed * L_REED
	for j in m:
		vph += VIB_INC
		if vph >= 1.0:
			vph -= 1.0
		var f: float = inc * (1.0 + sn[int(vph * TBLF)] * vib)
		ph1 += f * 1.0032
		if ph1 >= 1.0:
			ph1 -= 1.0
		ph2 += f * 0.9968
		if ph2 >= 1.0:
			ph2 -= 1.0
		env += (gate - env) * rate
		s1 += a * (tab[int(ph1 * TBLF)] + tab[int(ph2 * TBLF)] - s1)
		s2 += a * (s1 - s2)
		var o: float = s2 * env * gain
		ml[j] += o * 0.62
		mr[j] += o * 0.82
		ms[j] += o
	_r_ph1 = ph1
	_r_ph2 = ph2
	_r_vph = vph
	_r_env = env
	_r_lp1 = s1
	_r_lp2 = s2


func _v_counter(m: int) -> void:
	if _g_counter < 0.003 or (_k_gate < 0.5 and _k_env < 0.0006):
		return
	var tab := _reed_tab
	var sn := _sin_tab
	var ml := _mix_l
	var mr := _mix_r
	var ms := _mix_s
	var ph: float = _k_ph
	var vph: float = _k_vph
	var inc: float = _k_inc
	var env: float = _k_env
	var gate: float = _k_gate
	var rate: float = 0.004 if gate > env else 0.0015
	var a: float = _lp_a * 0.55
	var s1: float = _k_lp1
	var s2: float = _k_lp2
	var gain: float = _g_counter * L_COUNTER
	for j in m:
		vph += VIB_INC * 0.9
		if vph >= 1.0:
			vph -= 1.0
		ph += inc * (1.0 + sn[int(vph * TBLF)] * 0.004)
		if ph >= 1.0:
			ph -= 1.0
		env += (gate - env) * rate
		s1 += a * (tab[int(ph * TBLF)] - s1)
		s2 += a * (s1 - s2)
		var o: float = s2 * env * gain
		ml[j] += o * 0.9
		mr[j] += o * 0.5
		ms[j] += o * 0.7
	_k_ph = ph
	_k_vph = vph
	_k_env = env
	_k_lp1 = s1
	_k_lp2 = s2


func _v_pad(m: int) -> void:
	if _g_pad < 0.003:
		return
	var tab := _pad_tab
	var sn := _sin_tab
	var ml := _mix_l
	var mr := _mix_r
	var ms := _mix_s
	var pa: PackedFloat32Array = _pd_ph
	var q0: float = pa[0]
	var q1: float = pa[1]
	var q2: float = pa[2]
	var r0: float = pa[3]
	var r1: float = pa[4]
	var r2: float = pa[5]
	var i0: float = _pd_inc[0]
	var i1: float = _pd_inc[1]
	var i2: float = _pd_inc[2]
	var lfo: float = _pd_lfo
	var gain: float = _g_pad * L_PAD
	for j in m:
		lfo += 0.13 / SRF
		if lfo >= 1.0:
			lfo -= 1.0
		var sw: float = 0.75 + 0.25 * sn[int(lfo * TBLF)]
		q0 += i0
		if q0 >= 1.0:
			q0 -= 1.0
		q1 += i1
		if q1 >= 1.0:
			q1 -= 1.0
		q2 += i2
		if q2 >= 1.0:
			q2 -= 1.0
		r0 += i0 * 1.004
		if r0 >= 1.0:
			r0 -= 1.0
		r1 += i1 * 0.996
		if r1 >= 1.0:
			r1 -= 1.0
		r2 += i2 * 1.003
		if r2 >= 1.0:
			r2 -= 1.0
		var l: float = (tab[int(q0 * TBLF)] + tab[int(q1 * TBLF)] + tab[int(q2 * TBLF)]) * sw * gain
		var r: float = (tab[int(r0 * TBLF)] + tab[int(r1 * TBLF)] + tab[int(r2 * TBLF)]) * sw * gain
		ml[j] += l
		mr[j] += r
		ms[j] += (l + r) * 0.5
	pa[0] = q0
	pa[1] = q1
	pa[2] = q2
	pa[3] = r0
	pa[4] = r1
	pa[5] = r2
	_pd_lfo = lfo


func _v_pool(m: int) -> void:
	var sn := _sin_tab
	var rt := _reed_tab
	var ml := _mix_l
	var mr := _mix_r
	var ms := _mix_s
	for s in NP:
		if _p_on[s] == 0:
			continue
		var j0: int = 0
		var dl: int = _p_delay[s]
		if dl > 0:
			if dl >= m:
				_p_delay[s] = dl - m
				continue
			j0 = dl
			_p_delay[s] = 0
		var kind: int = _p_kind[s]
		var ph: float = _p_ph[s]
		var ph2: float = _p_ph2[s]
		var inc: float = _p_inc[s]
		var env: float = _p_env[s]
		var rise: float = _p_rise[s]
		var dec: float = _p_dec[s]
		var hold: int = _p_hold[s]
		var slide: float = _p_slide[s]
		var lp: float = _p_lp[s]
		var pl: float = _p_pl[s]
		var pr: float = _p_pr[s]
		var amp: float = _p_amp[s]
		var alive: bool = true
		for j in range(j0, m):
			if rise > 0.0:
				env += rise
				if env >= 1.0:
					env = 1.0
					rise = 0.0
			elif hold > 0:
				hold -= 1
			else:
				env *= dec
				if env < 0.0004:
					alive = false
					break
			var o: float
			if kind == 0:
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				ph2 += inc * 2.76
				if ph2 >= 1.0:
					ph2 -= 1.0
				o = (sn[int(ph * TBLF)] + 0.3 * env * sn[int(ph2 * TBLF)]) * env * amp
			else:
				inc *= slide
				ph += inc
				if ph >= 1.0:
					ph -= 1.0
				lp += (0.06 + 0.16 * env) * (rt[int(ph * TBLF)] - lp)
				o = lp * env * amp
			ml[j] += o * pl
			mr[j] += o * pr
			ms[j] += o * (1.0 if kind == 0 else 0.4)
		_p_ph[s] = ph
		_p_ph2[s] = ph2
		_p_inc[s] = inc
		_p_env[s] = env
		_p_rise[s] = rise
		_p_hold[s] = hold
		_p_lp[s] = lp
		if not alive:
			_p_on[s] = 0


func _v_out(m: int, out: PackedVector2Array, start: int) -> void:
	var ml := _mix_l
	var mr := _mix_r
	var ms := _mix_s
	var dl := _dl_l
	var dr := _dl_r
	var nl: int = dl.size()
	var nr: int = dr.size()
	var pl: int = _dp_l
	var pr: int = _dp_r
	var fl: float = _fb_l
	var fr: float = _fb_r
	var fade: float = _fade * _fade * (3.0 - 2.0 * _fade)
	for j in m:
		var send: float = ms[j] * ECHO_SEND
		var wl: float = dl[pl]
		var wr: float = dr[pr]
		fl += 0.42 * (wl - fl)
		fr += 0.42 * (wr - fr)
		dl[pl] = send + fr * 0.42
		dr[pr] = send * 0.8 + fl * 0.42
		pl += 1
		if pl >= nl:
			pl = 0
		pr += 1
		if pr >= nr:
			pr = 0
		var l: float = (ml[j] + wl * 0.5) * fade
		var r: float = (mr[j] + wr * 0.5) * fade
		# soft limiter: Pade tanh approximation, exactly +-1 at |x| >= 3
		if l > 3.0:
			l = 3.0
		elif l < -3.0:
			l = -3.0
		if r > 3.0:
			r = 3.0
		elif r < -3.0:
			r = -3.0
		l = l * (27.0 + l * l) / (27.0 + 9.0 * l * l)
		r = r * (27.0 + r * r) / (27.0 + 9.0 * r * r)
		out[start + j] = Vector2(l, r)
	_dp_l = pl
	_dp_r = pr
	_fb_l = fl
	_fb_r = fr


# ---------------------------------------------------------------- sequencer

func _on_tick() -> void:
	var tk: int = _tick
	if tk == 0:
		_on_bar()
	if tk % 2 == 0:
		_fire_stingers()
	_seq_melody(tk)
	_seq_bass(tk)
	_seq_chords(tk)
	_seq_counter(tk)
	_seq_sparkle()
	_tick = (tk + 1) % 6
	_bpm_s += (_t_bpm * (1.0 + 0.05 * _inten_s) - _bpm_s) * 0.06
	_tick_len = 30.0 / _bpm_s * SRF
	_tick_acc += _tick_len
	_tick_left = maxi(1, int(_tick_acc))
	_tick_acc -= float(_tick_left)


func _on_bar() -> void:
	_bar_in_phrase += 1
	if _bar_in_phrase >= _phrase_bars or _force_new:
		_force_new = false
		_new_phrase()
	_cur_chord = _phrase_chords[_bar_in_phrase]
	_set_chord(_cur_chord)
	var last: bool = _bar_in_phrase == _phrase_bars - 1
	_bar_rest = _bar_in_phrase > 0 and _rng.randf() < _p_rest * (0.4 if last else 1.0)


func _new_phrase() -> void:
	_bar_in_phrase = 0
	_note_idx = 0
	if _cadence_next:
		_cadence_next = false
		_tail_next = true
		_phrase_bars = 3
		_phrase_chords = [C_IV, C_V, C_I]
		_phrase_notes = [Vector3i(0, 3, 5), Vector3i(3, 3, 7), Vector3i(6, 2, 8),
			Vector3i(8, 2, 6), Vector3i(10, 2, 4), Vector3i(12, 6, 7)]
		_phrase_is_q = false
		_last_q_notes = []
		return
	if _tail_next:
		_tail_next = false
		_apply_params(RESULTS_TAIL)
	_phrase_count += 1
	if _phrase_count % 8 == 0 and _rng.randf() < 0.6:
		var nk: int = KEYS[_rng.randi() % KEYS.size()]
		if nk != _key_pc:
			_key_pc = nk
			_update_tonic()
	# alternate question / answer
	_phrase_is_q = not _phrase_is_q or _phrase_count <= 1
	var progs: Array
	if _minor:
		progs = PROG_Q_MIN if _phrase_is_q else PROG_A_MIN
	else:
		progs = PROG_Q_MAJ if _phrase_is_q else PROG_A_MAJ
	_phrase_bars = 4
	_phrase_chords = (progs[_rng.randi() % progs.size()] as Array).duplicate()
	if _phrase_is_q and not _minor and _rng.randf() < 0.25:
		_phrase_chords[2] = C_II  # ii - V
	_phrase_notes = _gen_melody(_phrase_chords, _phrase_is_q)
	if _phrase_is_q:
		_last_q_notes = _phrase_notes


func _gen_melody(chords: Array, is_q: bool) -> Array:
	var notes: Array = []
	var bars: int = chords.size()
	var deg: int = [0, 2, 4, 7][_rng.randi() % 4]
	var b0: int = 0
	if not is_q and _last_q_notes.size() > 0 and _rng.randf() < 0.65:
		# answer begins like the question
		for nt: Vector3i in _last_q_notes:
			if nt.x < 12:
				notes.append(nt)
				deg = nt.z
		b0 = 2
	for b in range(b0, bars):
		var last: bool = b == bars - 1
		var pat: Array
		if last:
			pat = PAT_END[_wpick(PAT_END_W)]
		else:
			pat = PAT_MID[_wpick(PAT_MID_W)]
		var t: int = b * 6
		for k in pat.size():
			var d: int = pat[k]
			if not (b == 0 and k == 0):
				var w: Array[float] = STEPS_W.duplicate()
				var pull: float = clampf((float(deg) - 3.0) * 0.07, -0.5, 0.5)
				for q in 5:
					w[q] *= (1.0 + pull) if STEPS[q] < 0 else (1.0 - pull) if STEPS[q] > 0 else 1.0
				deg += STEPS[_wpick(w)]
			deg = clampi(deg, -3, 10)
			if t % 2 == 0 and not _is_chord_tone(deg, chords[b]) and _rng.randf() < 0.65:
				for off: int in [1, -1, 2, -2]:
					if _is_chord_tone(deg + off, chords[b]):
						deg += off
						break
			notes.append(Vector3i(t, d, deg))
			t += d
	# phrase ending: half cadence for the question, tonic for the answer
	var targets: Array[int] = []
	if is_q:
		targets.assign([1, 4, 8])
	else:
		targets.assign([0, 7])
	var cur: int = (notes[notes.size() - 1] as Vector3i).z
	var best: int = targets[0]
	for tg in targets:
		if absi(tg - cur) < absi(best - cur):
			best = tg
	var ln: Vector3i = notes[notes.size() - 1]
	notes[notes.size() - 1] = Vector3i(ln.x, ln.y, best)
	if notes.size() >= 2:
		var pn: Vector3i = notes[notes.size() - 2]
		notes[notes.size() - 2] = Vector3i(pn.x, pn.y, best + (1 if _rng.randf() < 0.5 else -1))
	return notes


func _wpick(w: Array) -> int:
	var total: float = 0.0
	for x: float in w:
		total += x
	var r: float = _rng.randf() * total
	for i in w.size():
		r -= float(w[i])
		if r <= 0.0:
			return i
	return w.size() - 1


func _is_chord_tone(deg: int, ch: Vector2i) -> bool:
	var sc: Array[int] = MINOR if _minor else MAJOR
	var pc: int = posmod(sc[posmod(deg, 7)], 12)
	var third: int = 3 if ch.y == 1 else 4
	return pc == posmod(ch.x, 12) or pc == posmod(ch.x + third, 12) or pc == posmod(ch.x + 7, 12)


func _deg_midi(deg: int) -> int:
	var sc: Array[int] = MINOR if _minor else MAJOR
	return _tonic + sc[posmod(deg, 7)] + 12 * floori(float(deg) / 7.0)


func _update_tonic() -> void:
	_tonic = 60 + _key_pc if _key_pc <= 5 else 48 + _key_pc


func _set_chord(ch: Vector2i) -> void:
	var root_pc: int = posmod(_key_pc + ch.x, 12)
	var third: int = 3 if ch.y == 1 else 4
	var r: int = 46 + posmod(root_pc - 46, 12)
	_chord_midi = [r, r + third, r + 7]
	_bass_root = 36 + root_pc
	for q in 3:
		_pd_tinc[q] = _mtof(_chord_midi[q]) / SRF
		if _pd_inc[q] == 0.0:
			_pd_inc[q] = _pd_tinc[q]
	_counter_pool.clear()
	for o in [-12, 0, 12]:
		for q in 3:
			var n: int = _chord_midi[q] + 12 + o
			if n >= 55 and n <= 69:
				_counter_pool.append(n)


func _seq_melody(tk: int) -> void:
	var pt: int = _bar_in_phrase * 6 + tk
	while _note_idx < _phrase_notes.size():
		var nt: Vector3i = _phrase_notes[_note_idx]
		if nt.x > pt:
			break
		_note_idx += 1
		if nt.x < pt or _bar_rest:
			continue
		var midi: int = _deg_midi(nt.z)
		if _g_reed > 0.02:
			_r_tinc = _mtof(midi) / SRF
			if _r_env < 0.05:
				_r_inc = _r_tinc
			_r_env *= 0.6
			_r_gate = 1.0
			_r_off = int(float(nt.y) * _tick_len * 0.93)
			_r_age = 0.0
		if _rng.randf() < _p_bell_mel + 0.25 * _inten_s:
			_bell(midi + 12, 0.8, 1.6)


func _seq_bass(tk: int) -> void:
	if _t_bass < 0.01 or _p_bass_mode <= 0:
		return
	var mode: int = _p_bass_mode
	if _inten_s > 0.35:
		mode += 1
	if _inten_s > 0.75:
		mode += 1
	mode = mini(mode, 3)
	var midi: int = -1
	var vel: float = 1.0
	if tk == 0:
		midi = _bass_root
	elif tk == 4 and mode >= 2:
		midi = _bass_root + 7
		vel = 0.6
	elif tk == 2 and mode >= 3:
		midi = _bass_root + 12
		vel = 0.5
	if midi < 0:
		return
	_b_inc = _mtof(midi) / SRF
	_b_vel_t = vel
	if _b_a < 0.05:
		_b_vel = vel
	_b_rise = 1.0 / 110.0
	_b_dec = exp(-1.0 / (0.3 * SRF))


func _seq_chords(tk: int) -> void:
	if _t_chord < 0.01 or _p_chord_mode <= 0:
		return
	var vel: float = 0.0
	if tk == 2 and _p_chord_mode >= 2:
		vel = 1.0
	elif tk == 4:
		vel = 0.85
	if vel <= 0.0:
		return
	for q in 3:
		_c_inc[q] = _mtof(_chord_midi[q]) / SRF
	_c_vel = vel
	_c_rise = 1.0 / 60.0
	_c_dec = exp(-1.0 / (0.15 * SRF))


func _seq_counter(tk: int) -> void:
	if _g_counter < 0.01 or (tk != 0 and tk != 3) or _counter_pool.is_empty():
		return
	var cands: Array[int] = []
	for n in _counter_pool:
		if n != _counter_last and absi(n - _counter_last) <= 5:
			cands.append(n)
	var note: int = _counter_last
	if cands.is_empty():
		note = _counter_pool[_rng.randi() % _counter_pool.size()]
	else:
		note = cands[_rng.randi() % cands.size()]
	_counter_last = note
	_k_tinc = _mtof(note) / SRF
	if _k_env < 0.05:
		_k_inc = _k_tinc
	_k_env *= 0.6
	_k_gate = 1.0
	_k_off = int(3.0 * _tick_len * 0.92)


func _seq_sparkle() -> void:
	if _t_bell < 0.05 or _bar_rest:
		return
	if _rng.randf() < (_p_bell_rand + 0.3 * _inten_s) * 0.3:
		var sc: Array[int] = MINOR if _minor else MAJOR
		var deg: int = PENT[_rng.randi() % PENT.size()]
		var midi: int = _tonic + 12 + sc[deg % 7] + 12 * (_rng.randi() % 2)
		_bell(midi, 0.6, 2.2)


func _bell(midi: int, amp: float, tau: float, delay: int = 0, pan: float = NAN) -> void:
	var p: float = pan if not is_nan(pan) else _rng.randf_range(-0.7, 0.7)
	_pool_note(0, float(midi), delay, amp * _g_bell_amp(), tau, 0, p, 0.0, 0)


func _g_bell_amp() -> float:
	return maxf(_g_bell, 0.0) * L_BELL * 1.4


func _pool_note(kind: int, midi: float, delay: int, amp: float, tau: float, hold: int,
		pan: float, slide_semis: float, slide_samples: int) -> void:
	var s: int = -1
	for i in NP:
		if _p_on[i] == 0:
			s = i
			break
	if s < 0:
		var lo: float = 9.0
		for i in NP:
			if _p_env[i] < lo:
				lo = _p_env[i]
				s = i
	_p_on[s] = 1
	_p_kind[s] = kind
	_p_delay[s] = delay
	_p_hold[s] = hold
	_p_ph[s] = 0.0
	_p_ph2[s] = 0.0
	_p_inc[s] = _mtof(midi) / SRF
	_p_env[s] = 0.0
	_p_rise[s] = 1.0 / (25.0 if kind == 0 else 770.0)
	_p_dec[s] = exp(-1.0 / (tau * SRF))
	_p_amp[s] = amp
	var a: float = (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	_p_pl[s] = cos(a)
	_p_pr[s] = sin(a)
	_p_slide[s] = pow(2.0, -slide_semis / 12.0 / float(slide_samples)) if slide_samples > 0 else 1.0
	_p_lp[s] = 0.0


# ---------------------------------------------------------------- stingers

func _fire_stingers() -> void:
	while not _st_queue.is_empty():
		_do_stinger(_st_queue.pop_front())


func _do_stinger(kind: String) -> void:
	var bs: float = _tick_len * 2.0
	var third: int = 3 if _minor else 4
	var base: int = _tonic + 12
	var amp: float = 0.55
	match kind:
		"deliver":
			var offs: Array[int] = [0, third, 7, 12, 12 + third]
			for i in offs.size():
				_pool_note(0, float(base + offs[i]), int(float(i) * 0.27 * bs), amp * (0.7 + 0.1 * i),
					1.1 if i < 4 else 2.4, 0, -0.4 + 0.2 * i, 0.0, 0)
			_pool_note(0, float(base + 24), int(1.35 * bs), amp * 0.4, 2.0, 0, 0.5, 0.0, 0)
		"fail":
			var n0: int = _tonic + 7 - 12
			_pool_note(1, float(n0), 0, 0.5, 0.2, int(0.55 * bs), -0.1, 0.0, 0)
			_pool_note(1, float(n0 - 1), int(0.8 * bs), 0.5, 0.35, int(1.0 * bs), 0.1, 2.5,
				int(1.8 * bs))
		"day":
			var seq: Array = [[0.0, 7, 0.4], [0.5, 12, 0.4], [1.0, 16 if not _minor else 15, 0.4],
				[1.5, 19, 1.3]]
			for e: Array in seq:
				var t0: int = int(float(e[0]) * bs)
				var nn: float = float(_tonic + int(e[1]))
				_pool_note(1, nn, t0, 0.42, 0.45, int(float(e[2]) * bs), 0.0, 0.0, 0)
				_pool_note(0, nn + 12.0, t0, 0.25, 1.4, 0, 0.3, 0.0, 0)


# ---------------------------------------------------------------- helpers

func _apply_params(p: Dictionary) -> void:
	_t_bpm = float(p["bpm"])
	_t_bass = float(p["bass"])
	_t_chord = float(p["chord"])
	_t_reed = float(p["reed"])
	_t_bell = float(p["bell"])
	_t_pad = float(p["pad"])
	_t_cut = float(p["cut"])
	_p_rest = float(p["rest"])
	_p_bell_mel = float(p["bell_mel"])
	_p_bell_rand = float(p["bell_rand"])
	_p_bass_mode = int(p["bass_mode"])
	_p_chord_mode = int(p["chord_mode"])
	var mn: bool = bool(p["minor"])
	if mn != _minor:
		_minor = mn
		_force_new = true


func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _additive(amps: Array[float]) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TBL)
	var pk: float = 0.0001
	for i in TBL:
		var v: float = 0.0
		for h in amps.size():
			v += amps[h] * sin(TAU * float(h + 1) * float(i) / TBLF)
		t[i] = v
		pk = maxf(pk, absf(v))
	for i in TBL:
		t[i] /= pk
	return t


func _build_tables() -> void:
	_sin_tab = _additive([1.0])
	# reed: odd-heavy sawish spectrum, 9 harmonics (no aliasing under 1.2 kHz)
	var ra: Array[float] = []
	for h in range(1, 10):
		ra.append((1.0 if h % 2 == 1 else 0.55) / float(h))
	_reed_tab = _additive(ra)
	_bass_tab = _additive([1.0, 0.55, 0.22, 0.1])
	_soft_tab = _additive([1.0, 0.3, 0.12, 0.05])
	_pad_tab = _additive([1.0, 0.2, 0.08])
