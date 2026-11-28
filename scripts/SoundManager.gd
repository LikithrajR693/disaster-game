extends Node

# Technical Audio Engine for READY OR NOT (SoundManager autoload) - 100% procedural, zero audio files.
# Ambience bus: resonant rain/wind LPF (350-900 Hz LFO), -22 dB siren (520-680 Hz / 4.5 s),
# hazard proximity (50/100 Hz transformer buzz + micro-arcs, floodwater turbulence).
# SFX: layered noise + damped tones + FM, cached (3 variants), pre-warmed, +/-8% pitch jitter.
# Master ON/OFF + volume applied ONCE on the Master bus.
# Public API unchanged.

const SFX_SR: int = 32000
const AMB_SR: float = 22050.0
const MAX_VOICES: int = 24
const VARIANTS: int = 3

var sound_enabled: bool = true:
	set(val):
		sound_enabled = val
		_update_bus_volume()
var master_volume: float = 0.8:
	set(val):
		master_volume = clampf(val, 0.0, 1.0)
		_update_bus_volume()

var _ambience_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _ambience_time: float = 0.0
var _ambience_gain: float = 1.0
var _ambience_lowpass: float = 0.0
var _pink_b0: float = 0.0
var _pink_b1: float = 0.0
var _pink_b2: float = 0.0
var _brown: float = 0.0
var _svf_low: float = 0.0
var _svf_band: float = 0.0
var _drop_env: float = 0.0
var _siren_phase: float = 0.0
var _siren_lp: float = 0.0
var _proximity_electric_gain: float = 0.0
var _target_electric_gain: float = 0.0
var _proximity_water_gain: float = 0.0
var _target_water_gain: float = 0.0
var _hum_phase: float = 0.0
var _arc_env: float = 0.0
var _water_mod: float = 0.5
var _water_lp: float = 0.0
var _cache: Dictionary = {}
var _voices: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_ambience_generator()
	_update_bus_volume()
	call_deferred("_prewarm")

func _setup_ambience_generator() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience_player.bus = "Master"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = AMB_SR
	gen.buffer_length = 0.12
	_ambience_player.stream = gen
	add_child(_ambience_player)
	_ambience_player.play()
	_playback = _ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	_ambience_time += delta
	var mix_delta := delta / maxf(Engine.time_scale, 0.001)
	var ducked := get_tree().paused or Engine.time_scale < 0.5
	var target_gain := GameConfig.AMBIENCE_PAUSE_GAIN if ducked else 1.0
	_ambience_gain = lerpf(_ambience_gain, target_gain, minf(mix_delta * 12.0, 1.0))
	_proximity_electric_gain = lerpf(_proximity_electric_gain, _target_electric_gain, minf(delta * 6.0, 1.0))
	_proximity_water_gain = lerpf(_proximity_water_gain, _target_water_gain, minf(delta * 6.0, 1.0))
	_feed_ambience_buffer()

func _feed_ambience_buffer() -> void:
	if _playback == null or not sound_enabled:
		return
	var frames := mini(_playback.get_frames_available(), 4096)
	if frames <= 0:
		return
	var dt := 1.0 / AMB_SR
	var ducked := get_tree().paused or Engine.time_scale < 0.5
	var ambience_cutoff := GameConfig.AMBIENCE_DUCKED_CUTOFF if ducked else GameConfig.AMBIENCE_NORMAL_CUTOFF
	var lowpass_alpha := 1.0 - exp(-TAU * ambience_cutoff / AMB_SR)
	var lfo := 0.5 + 0.5 * sin(_ambience_time * TAU * 0.12 + 1.3 * sin(_ambience_time * 0.31))
	var cutoff := lerpf(350.0, 900.0, lfo)
	var svf_f := 2.0 * sin(PI * cutoff / AMB_SR)
	var svf_qd := 1.0 / 1.8
	var gust := 0.5 + 0.5 * sin(_ambience_time * 0.55)
	var siren_freq := 600.0 - 80.0 * cos(TAU * _ambience_time / 4.5)
	var siren_gate := 0.75 + 0.25 * sin(_ambience_time * 0.13)
	var siren_pan := 0.5 + 0.3 * sin(_ambience_time * 0.21)
	const SIREN_GAIN: float = 0.0794
	var e_gain := _proximity_electric_gain
	var w_gain := _proximity_water_gain
	for i in range(frames):
		var w := randf_range(-1.0, 1.0)
		_pink_b0 = 0.99765 * _pink_b0 + w * 0.0990460
		_pink_b1 = 0.96300 * _pink_b1 + w * 0.2965164
		_pink_b2 = 0.57000 * _pink_b2 + w * 1.0526913
		var pink := (_pink_b0 + _pink_b1 + _pink_b2 + w * 0.1848) * 0.5
		_brown = (_brown + 0.02 * w) / 1.02
		_svf_low += svf_f * _svf_band
		var high := pink - _svf_low - svf_qd * _svf_band
		_svf_band += svf_f * high
		var bed := _svf_low * 1.4
		var wind := _brown * 4.0 * (0.35 + 0.65 * gust)
		if randf() < 0.006:
			_drop_env = randf_range(0.4, 1.0)
		_drop_env *= 0.985
		var patter := w * _drop_env * 0.06
		var rain := bed * 0.6 + wind * 0.3 + patter
		_siren_phase = fmod(_siren_phase + TAU * siren_freq * dt, TAU)
		var sir := (sin(_siren_phase) + 0.3 * sin(_siren_phase * 2.0)) * SIREN_GAIN * siren_gate
		_siren_lp += 0.25 * (sir - _siren_lp)
		var electric := 0.0
		if e_gain > 0.01:
			_hum_phase = fmod(_hum_phase + TAU * 50.0 * dt, TAU)
			var hum := tanh((sin(_hum_phase) * 0.6 + sin(_hum_phase * 2.0) * 0.6 + sin(_hum_phase * 3.0) * 0.15) * 1.8) * 0.5
			if randf() < 0.0012:
				_arc_env = randf_range(0.5, 1.0)
			_arc_env *= 0.992
			electric = (hum * 0.22 + randf_range(-1.0, 1.0) * _arc_env * 0.35) * e_gain
		var water := 0.0
		if w_gain > 0.01:
			_water_mod = lerpf(_water_mod, randf(), 0.0008)
			_water_lp += 0.12 * (pink * 2.0 - _water_lp)
			water = (_water_lp * (0.4 + 1.2 * _water_mod) + pink * 0.25 * _water_mod * _water_mod) * w_gain * 0.9
		var mono := (rain + electric + water) * _ambience_gain
		_ambience_lowpass += lowpass_alpha * (mono - _ambience_lowpass)
		if ducked:
			mono = _ambience_lowpass
		var siren_gain := GameConfig.AMBIENCE_PAUSE_GAIN if ducked else 1.0
		var left := clampf(mono + _siren_lp * siren_gain * (1.0 - siren_pan) * 1.4, -0.95, 0.95)
		var right := clampf(mono + _siren_lp * siren_gain * siren_pan * 1.4, -0.95, 0.95)
		_playback.push_frame(Vector2(left, right))

func update_hazard_proximity(closest_dist: float, hazard_type: String) -> void:
	var prox := clampf(1.0 - (closest_dist - 40.0) / 310.0, 0.0, 1.0)
	match hazard_type.to_upper():
		"ELECTRICAL":
			_target_electric_gain = prox
			_target_water_gain = 0.0
		"WATER", "FLOOD":
			_target_water_gain = prox
			_target_electric_gain = 0.0
		_:
			_target_electric_gain = 0.0
			_target_water_gain = 0.0

func set_muted(muted: bool) -> void:
	sound_enabled = not muted

func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)

func _update_bus_volume() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx == -1:
		return
	if not sound_enabled or master_volume <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

# ---------------- PUBLIC SFX API ----------------

func play_footstep(surface_type: String = "asphalt") -> void:
	var key := "asphalt"
	match surface_type.to_lower():
		"water", "flood", "flooded":
			key = "water"
		"rubble", "gravel", "debris":
			key = "rubble"
	_play_one_shot(_stream_for("foot_" + key, _build_footstep.bind(key)), -2.0)

func play_tremor_rumble(intensity: float = 1.0) -> void:
	var vol := linear_to_db(clampf(0.55 + 0.45 * intensity, 0.1, 1.6))
	_play_one_shot(_stream_for("rumble", _build_seismic), vol)

func play_thunder_clap() -> void:
	_play_one_shot(_stream_for("thunder", _build_thunder))

func play_electric_arc() -> void:
	_play_one_shot(_stream_for("arc", _build_arc))

func play_hazard_alert() -> void:
	play_protocol_wrong()

func play_pickup() -> void:
	_play_one_shot(_stream_for("pickup", _build_pickup))

func play_escort_link() -> void:
	_play_one_shot(_stream_for("escort", _build_walkie))

func play_barricade_success() -> void:
	_play_one_shot(_stream_for("barricade", _build_barricade))

func play_protocol_correct() -> void:
	_play_one_shot(_stream_for("proto_ok", _build_terminal_ok))

func play_protocol_wrong() -> void:
	_play_one_shot(_stream_for("proto_bad", _build_dispatch_warning))

func play_ui_click() -> void:
	_play_one_shot(_stream_for("ui_click", _build_ui_click))

func play_ui_hover() -> void:
	_play_one_shot(_stream_for("ui_hover", _build_ui_hover), -6.0)

func play_sfx(sfx_name: String) -> void:
	match sfx_name:
		"click": play_ui_click()
		"hover": play_ui_hover()
		"pickup": play_pickup()
		"inspect": play_electric_arc()
		"alert": play_escort_link()
		"warning": play_protocol_wrong()
		"success": play_protocol_correct()
		"rumble": play_tremor_rumble(1.0)
		"thunder": play_thunder_clap()
		"siren": play_escort_link()
		"barricade": play_barricade_success()
		_: play_ui_click()

# ---------------- PLAYBACK / CACHE ----------------

func _stream_for(key: String, builder: Callable) -> AudioStreamWAV:
	var arr: Array = _cache.get(key, [])
	if arr.size() < VARIANTS:
		var s: AudioStreamWAV = builder.call()
		arr.append(s)
		_cache[key] = arr
		return s
	return arr[randi() % arr.size()]

func _prewarm() -> void:
	var jobs: Array[Callable] = [
		func(): _stream_for("ui_click", _build_ui_click),
		func(): _stream_for("foot_asphalt", _build_footstep.bind("asphalt")),
		func(): _stream_for("foot_water", _build_footstep.bind("water")),
		func(): _stream_for("foot_rubble", _build_footstep.bind("rubble")),
		func(): _stream_for("ui_hover", _build_ui_hover),
		func(): _stream_for("pickup", _build_pickup),
		func(): _stream_for("escort", _build_walkie),
		func(): _stream_for("proto_ok", _build_terminal_ok),
		func(): _stream_for("proto_bad", _build_dispatch_warning),
		func(): _stream_for("barricade", _build_barricade),
		func(): _stream_for("arc", _build_arc),
		func(): _stream_for("thunder", _build_thunder),
		func(): _stream_for("rumble", _build_seismic),
	]
	for job in jobs:
		await get_tree().process_frame
		job.call()

func _play_one_shot(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	if not sound_enabled or stream == null or _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.bus = "Master"
	p.volume_db = volume_db + randf_range(-GameConfig.AUDIO_GAIN_JITTER_DB, GameConfig.AUDIO_GAIN_JITTER_DB)
	p.pitch_scale = randf_range(1.0 - GameConfig.AUDIO_PITCH_JITTER, 1.0 + GameConfig.AUDIO_PITCH_JITTER)
	_voices += 1
	p.finished.connect(_on_voice_finished.bind(p))
	add_child(p)
	p.play()

func _on_voice_finished(p: AudioStreamPlayer) -> void:
	_voices = maxi(_voices - 1, 0)
	p.queue_free()

# ---------------- DSP HELPERS ----------------

func _new_buf(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(SFX_SR * duration))
	return b

func _env(t: float, attack: float, decay: float) -> float:
	var a := 1.0 if attack <= 0.0 else minf(t / attack, 1.0)
	return a * exp(-decay * t)

func _add_tone(buf: PackedFloat32Array, start: float, dur: float, amp: float, f0: float, f1: float, decay: float, attack: float = 0.001, harm2: float = 0.0) -> void:
	var i0 := int(start * SFX_SR)
	var n := int(dur * SFX_SR)
	var phase := 0.0
	for i in range(n):
		var idx := i0 + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SFX_SR)
		var f := lerpf(f0, f1, float(i) / maxf(float(n), 1.0))
		phase += TAU * f / float(SFX_SR)
		var s := sin(phase)
		if harm2 > 0.0:
			s += harm2 * sin(phase * 2.0)
		buf[idx] += s * amp * _env(t, attack, decay)

func _add_noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, hp: float, lp: float, attack: float = 0.0005) -> void:
	var i0 := int(start * SFX_SR)
	var n := int(dur * SFX_SR)
	var a_lp := 1.0 - exp(-TAU * minf(lp, 15000.0) / float(SFX_SR))
	var a_hp := 1.0 - exp(-TAU * maxf(hp, 1.0) / float(SFX_SR))
	var l1 := 0.0
	var h := 0.0
	for i in range(n):
		var idx := i0 + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SFX_SR)
		l1 += a_lp * (randf_range(-1.0, 1.0) - l1)
		h += a_hp * (l1 - h)
		buf[idx] += (l1 - h) * amp * _env(t, attack, decay)

func _add_band(buf: PackedFloat32Array, start: float, dur: float, amp: float, fc0: float, fc1: float, q: float, decay: float, attack: float = 0.001) -> void:
	var i0 := int(start * SFX_SR)
	var n := int(dur * SFX_SR)
	var qd := 1.0 / q
	var low := 0.0
	var band := 0.0
	for i in range(n):
		var idx := i0 + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SFX_SR)
		var fc := lerpf(fc0, fc1, float(i) / maxf(float(n), 1.0))
		var f := 2.0 * sin(PI * fc / float(SFX_SR))
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - qd * band
		band += f * high
		buf[idx] += band * 2.5 * amp * _env(t, attack, decay)

func _to_wav(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var n := buf.size()
	var peak := 0.0001
	for i in range(n):
		peak = maxf(peak, absf(buf[i]))
	var norm := gain / peak
	var fade := maxi(int(SFX_SR * 0.003), 1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var v := buf[i] * norm
		if i > n - fade:
			v *= float(n - i) / float(fade)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SFX_SR
	wav.stereo = false
	wav.data = data
	return wav

# ---------------- SFX BUILDERS ----------------

func _build_footstep(surface: String) -> AudioStreamWAV:
	var b := _new_buf(0.09)
	var heel := randf_range(65.0, 95.0)
	_add_tone(b, 0.0, 0.035, 1.0, heel * 1.15, heel * 0.85, 85.0, 0.002)
	match surface:
		"water":
			_add_noise(b, 0.0, 0.018, 0.55, 150.0, 1800.0, 9000.0)
			_add_band(b, 0.010, 0.07, 0.16, 800.0, 450.0, 1.2, 38.0, 0.006)
		"rubble":
			for k in 5:
				_add_noise(b, randf() * 0.014, 0.004, randf_range(0.2, 0.45), 400.0, 1000.0, 10000.0)
		_:
			_add_noise(b, 0.0, 0.018, 0.32, 200.0, 2500.0, 8000.0)
	return _to_wav(b, 0.8)

func _build_seismic() -> AudioStreamWAV:
	var dur := 1.8
	var b := _new_buf(dur)
	var n := b.size()
	var sub_phase := 0.0
	var brown := 0.0
	var mid := 0.0
	var rum := 0.5
	for i in range(n):
		var t := float(i) / float(SFX_SR)
		var p := t / dur
		var env := minf(t / 0.18, 1.0) * (1.0 - smoothstep(0.6, 1.0, p))
		env *= 1.0 + 0.5 * exp(-6.0 * t)
		var f := 28.0 + 20.0 * sin(clampf(p, 0.0, 1.0) * PI)
		sub_phase += TAU * f / float(SFX_SR)
		var w := randf_range(-1.0, 1.0)
		brown = (brown + 0.03 * w) / 1.03
		mid += 0.10 * (w - mid)
		rum = lerpf(rum, randf(), 0.002)
		var roar := brown * 5.0 * (0.6 + 0.8 * rum)
		b[i] = (sin(sub_phase) * 0.8 + roar * 0.9 + mid * 0.35 * (0.5 + rum)) * env
	var cracks := randi_range(4, 6)
	for k in cracks:
		var ts := randf_range(0.12, 1.55)
		_add_noise(b, ts, randf_range(0.010, 0.030), randf_range(1.2, 2.0), 90.0, 1800.0, 12000.0, 0.0003)
		if randf() < 0.6:
			for h in 3:
				_add_tone(b, ts, 0.07, 0.25, randf_range(2800.0, 7000.0), randf_range(2800.0, 7000.0), 70.0, 0.0005)
	return _to_wav(b, 0.9)

func _build_thunder() -> AudioStreamWAV:
	var b := _new_buf(1.7)
	_add_noise(b, 0.0, 0.04, 1.0, 60.0, 1500.0, 14000.0, 0.0003)
	var i0 := int(0.03 * SFX_SR)
	var n := b.size()
	var l1 := 0.0
	var l2 := 0.0
	var ph := randf() * TAU
	for i in range(i0, n):
		var t := float(i - i0) / float(SFX_SR)
		var fc := lerpf(450.0, 70.0, clampf(t / 1.6, 0.0, 1.0))
		var a := 1.0 - exp(-TAU * fc / float(SFX_SR))
		l1 += a * (randf_range(-1.0, 1.0) - l1)
		l2 += a * (l1 - l2)
		var roll := 0.65 + 0.35 * sin(t * 11.0 + ph) * sin(t * 4.3 + ph * 0.5)
		var env := minf(t / 0.08, 1.0) * exp(-1.9 * t) * roll
		var sub := sin(TAU * lerpf(55.0, 34.0, clampf(t / 1.6, 0.0, 1.0)) * t)
		b[i] += (l2 * 7.0 + sub * 0.35) * env
	return _to_wav(b, 0.9)

func _build_arc() -> AudioStreamWAV:
	var b := _new_buf(0.32)
	_add_tone(b, 0.0, 0.32, 0.5, 100.0, 100.0, 7.0, 0.002, 0.5)
	_add_tone(b, 0.0, 0.32, 0.12, 50.0, 50.0, 7.0, 0.002)
	_add_band(b, 0.0, 0.02, 1.6, 3000.0, 2200.0, 1.6, 80.0, 0.0003)
	var bursts := randi_range(9, 14)
	for k in bursts:
		var fc := randf_range(1200.0, 3500.0)
		_add_band(b, randf_range(0.01, 0.27), randf_range(0.003, 0.016), randf_range(0.4, 1.2), fc, fc * randf_range(0.7, 1.3), 1.8, 90.0, 0.0003)
	return _to_wav(b, 0.8)

func _build_pickup() -> AudioStreamWAV:
	var b := _new_buf(0.3)
	_add_band(b, 0.0, 0.17, 0.5, 1400.0, 4200.0, 1.4, 5.0, 0.01)
	for k in 14:
		_add_noise(b, randf() * 0.16, 0.006, randf_range(0.2, 0.5), 300.0, 400.0, 9000.0)
	var lt := 0.19
	_add_tone(b, lt, 0.03, 0.9, 190.0, 120.0, 120.0)
	_add_tone(b, lt, 0.02, 0.45, 2300.0, 2300.0, 260.0)
	_add_noise(b, lt, 0.006, 0.6, 500.0, 1500.0, 9000.0)
	_add_tone(b, lt + 0.028, 0.015, 0.4, 1700.0, 1700.0, 300.0)
	return _to_wav(b, 0.8)

func _build_walkie() -> AudioStreamWAV:
	var b := _new_buf(0.5)
	_add_noise(b, 0.0, 0.004, 0.8, 300.0, 300.0, 9000.0)
	_add_band(b, 0.0, 0.18, 0.45, 1800.0, 1800.0, 0.8, 3.0, 0.004)
	_add_tone(b, 0.15, 0.10, 0.55, 880.0, 880.0, 6.0, 0.004, 0.25)
	_add_tone(b, 0.24, 0.12, 0.55, 1174.66, 1174.66, 9.0, 0.004, 0.25)
	_add_noise(b, 0.36, 0.09, 0.55, 45.0, 500.0, 5000.0)
	return _to_wav(b, 0.7)

func _build_barricade() -> AudioStreamWAV:
	var b := _new_buf(0.55)
	var cph := 0.0
	var mph := 0.0
	for i in range(int(0.3 * SFX_SR)):
		var t := float(i) / float(SFX_SR)
		mph += TAU * 296.0 / float(SFX_SR)
		var idx_mod := 4.0 * exp(-18.0 * t)
		cph += TAU * 210.0 / float(SFX_SR)
		var fm := sin(cph + idx_mod * sin(mph)) * exp(-14.0 * t)
		var par := (sin(TAU * 320.0 * t) * 0.5 + sin(TAU * 740.0 * t) * 0.35 + sin(TAU * 1260.0 * t) * 0.25) * exp(-16.0 * t)
		b[i] += fm * 0.9 + par * 0.6
	_add_tone(b, 0.0, 0.05, 0.9, 130.0, 80.0, 70.0)
	for k in 4:
		var rt := 0.12 + k * 0.022
		_add_noise(b, rt, 0.006, 0.5, 400.0, 1200.0, 9000.0)
		_add_tone(b, rt, 0.01, 0.35, 1100.0 + k * 150.0, 1100.0 + k * 150.0, 300.0)
	_add_tone(b, 0.30, 0.16, 0.22, 660.0, 660.0, 12.0, 0.01, 0.3)
	_add_tone(b, 0.36, 0.16, 0.22, 880.0, 880.0, 12.0, 0.01, 0.3)
	return _to_wav(b, 0.85)

func _build_terminal_ok() -> AudioStreamWAV:
	var b := _new_buf(0.26)
	_add_noise(b, 0.0, 0.004, 0.5, 300.0, 400.0, 8000.0)
	_add_tone(b, 0.0, 0.2, 0.7, 220.0, 220.0, 13.0, 0.006)
	_add_tone(b, 0.0, 0.2, 0.45, 440.0, 440.0, 14.0, 0.006)
	_add_tone(b, 0.0, 0.2, 0.2, 660.0, 660.0, 16.0, 0.006)
	_add_tone(b, 0.07, 0.14, 0.35, 330.0, 495.0, 14.0, 0.006)
	return _to_wav(b, 0.6)

func _build_dispatch_warning() -> AudioStreamWAV:
	var b := _new_buf(0.36)
	_add_tone(b, 0.0, 0.12, 1.0, 130.0, 118.0, 26.0, 0.003, 0.2)
	_add_tone(b, 0.14, 0.14, 0.9, 120.0, 105.0, 24.0, 0.003, 0.2)
	_add_noise(b, 0.0, 0.1, 0.18, 14.0, 100.0, 450.0)
	for i in range(int(0.1 * SFX_SR)):
		var t := float(i) / float(SFX_SR)
		var gate := 0.5 + 0.5 * sin(TAU * 120.0 * t)
		b[i] += randf_range(-1.0, 1.0) * gate * 0.14 * exp(-18.0 * t)
	return _to_wav(b, 0.75)

func _build_ui_click() -> AudioStreamWAV:
	var b := _new_buf(0.02)
	_add_tone(b, 0.0, 0.012, 0.8, 2200.0, 1700.0, 330.0, 0.0002)
	_add_noise(b, 0.0, 0.006, 0.5, 450.0, 1800.0, 9000.0, 0.0001)
	return _to_wav(b, 0.5)

func _build_ui_hover() -> AudioStreamWAV:
	var b := _new_buf(0.012)
	_add_tone(b, 0.0, 0.008, 0.8, 2600.0, 2400.0, 500.0, 0.0002)
	return _to_wav(b, 0.25)