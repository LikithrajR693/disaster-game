extends Node

# Senior Technical Audio Engine for READY OR NOT (SoundManager)
# Features:
# 1. Continuous real-time AudioStreamGenerator Ambience Bus (Monsoon rain, wind gusts, distant siren, and dynamic hazard proximity buzz/turbulence).
# 2. Multi-layered acoustic synthesis for every SFX (footsteps with surface detection, Richter 6.8 seismic roar, lightning thunder, tactical walkie-talkie squelches, nylon velcro rustles, and metallic barricade clanks).
# 3. Dynamic pitch randomization (±8%), natural ADSR dampening, and full integration with Master Audio Toggle & Volume.

var sound_enabled: bool = true:
	set(val):
		sound_enabled = val
		_update_bus_volume()
var master_volume: float = 0.8: # 0.0 to 1.0
	set(val):
		master_volume = clampf(val, 0.0, 1.0)
		_update_bus_volume()

# --- Continuous Ambience Bus Variables ---
var _ambience_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
const AMBIENCE_SAMPLE_RATE: float = 22050.0

var _rain_filter_phase: float = 0.0
var _siren_phase: float = 0.0
var _ambience_time: float = 0.0
var _brown_noise_val: float = 0.0
var _pink_b0: float = 0.0
var _pink_b1: float = 0.0
var _pink_b2: float = 0.0

# Hazard proximity spatial blend
var _proximity_electric_gain: float = 0.0
var _target_electric_gain: float = 0.0
var _proximity_water_gain: float = 0.0
var _target_water_gain: float = 0.0
var _hum_phase: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ambience_generator()
	_update_bus_volume()

func _setup_ambience_generator() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience_player.bus = "Master"
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = AMBIENCE_SAMPLE_RATE
	gen.buffer_length = 0.12 # low latency 120ms buffer
	_ambience_player.stream = gen
	add_child(_ambience_player)
	_ambience_player.play()
	_playback = _ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(delta: float) -> void:
	_ambience_time += delta
	# Smoothly interpolate spatial proximity gains
	_proximity_electric_gain = lerpf(_proximity_electric_gain, _target_electric_gain, delta * 6.0)
	_proximity_water_gain = lerpf(_proximity_water_gain, _target_water_gain, delta * 6.0)
	
	_feed_ambience_buffer()

func _feed_ambience_buffer() -> void:
	if _playback == null or not sound_enabled:
		return
		
	var frames_needed := _playback.get_frames_available()
	if frames_needed <= 0:
		return
		
	var dt := 1.0 / AMBIENCE_SAMPLE_RATE
	
	for i in range(frames_needed):
		# 1. Monsoon Rain & Wind: Pink/Brown noise passed through resonant low-pass filter (350Hz - 900Hz LFO)
		var white := randf_range(-1.0, 1.0)
		_pink_b0 = 0.99886 * _pink_b0 + white * 0.0555179
		_pink_b1 = 0.99332 * _pink_b1 + white * 0.0750759
		_pink_b2 = 0.96900 * _pink_b2 + white * 0.1538520
		var pink := _pink_b0 + _pink_b1 + _pink_b2 + white * 0.5362
		_brown_noise_val = lerpf(_brown_noise_val, white, 0.04)
		
		# Low frequency LFO wind swell (0.2 Hz)
		var wind_mod := (sin(_ambience_time * 1.25) + 1.0) * 0.5
		var rain_cutoff_blend := lerpf(0.08, 0.22, wind_mod)
		_rain_filter_phase = lerpf(_rain_filter_phase, (pink * 0.4 + _brown_noise_val * 0.6), rain_cutoff_blend)
		var rain_sample := _rain_filter_phase * 0.22 # gentle rain bed
		
		# 2. Distant Civil Defense / Emergency Siren (Sweep 520Hz - 680Hz, slow 4.5s rise/fall, mixed -22dB)
		_siren_phase += dt * (TAU * (600.0 + 80.0 * sin(_ambience_time * 1.39)))
		var siren_sample := sin(_siren_phase) * 0.045
		
		# 3. Dynamic Hazard Proximity: High-voltage 50Hz/100Hz AC buzz with random micro-arc crackles
		var electric_sample := 0.0
		if _proximity_electric_gain > 0.01:
			_hum_phase += dt * (TAU * 50.0)
			var mains_hum := sin(_hum_phase) * 0.6 + sin(_hum_phase * 2.0) * 0.4
			var micro_crackle := (randf_range(-1.0, 1.0) if randf() < 0.06 else 0.0) * 0.8
			electric_sample = (mains_hum * 0.5 + micro_crackle * 0.5) * _proximity_electric_gain * 0.28
			
		# 4. Floodwater turbulence proximity
		var water_sample := 0.0
		if _proximity_water_gain > 0.01:
			water_sample = _brown_noise_val * _proximity_water_gain * 0.26
			
		var final_sample := (rain_sample + siren_sample + electric_sample + water_sample) * master_volume
		final_sample = clampf(final_sample, -1.0, 1.0)
		_playback.push_frame(Vector2(final_sample, final_sample))

func update_hazard_proximity(closest_dist: float, hazard_type: String) -> void:
	# Effective proximity range: 350px down to 40px
	var prox := clampf(1.0 - (closest_dist - 40.0) / 310.0, 0.0, 1.0)
	match hazard_type:
		"ELECTRICAL":
			_target_electric_gain = prox
			_target_water_gain = 0.0
		"WATER":
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
	if bus_idx != -1:
		if not sound_enabled or master_volume <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

# --- REALISTIC MULTI-LAYERED PROCEDURAL SOUND EFFECTS ---

func play_footstep(surface_type: String = "asphalt") -> void:
	# Realistic two-part transient: low-end heel thud (65-95Hz) + surface transient burst
	var pitch_rnd := randf_range(0.92, 1.08)
	var stream: AudioStreamWAV = _synth_footstep(surface_type, pitch_rnd)
	_play_one_shot(stream)

func play_tremor_rumble(intensity: float = 1.0) -> void:
	# Cinema-grade Richter 6.8 seismic roar: 28Hz-48Hz sub-bass sine sweep + brown noise + concrete cracking spikes
	var stream := _synth_seismic_roar(intensity)
	_play_one_shot(stream)

func play_thunder_clap() -> void:
	# Sharp static crack transient followed by rolling bass thunder decay
	var stream := _synth_thunder_clap()
	_play_one_shot(stream)

func play_electric_arc() -> void:
	# Rapid-fire band-passed crackle bursts (1200-3500Hz) paired with 100Hz AC mains spike
	var stream := _synth_electric_arc()
	_play_one_shot(stream)

func play_hazard_alert() -> void:
	play_protocol_wrong()

func play_pickup() -> void:
	# Tactile gear-equip: nylon zipper / velcro fabric rustle followed by mechanical latch click
	var stream := _synth_gear_equip()
	_play_one_shot(stream)

func play_escort_link() -> void:
	# Walkie-talkie radio squelch + warm tactical acknowledgment chirp
	var stream := _synth_walkie_squelch()
	_play_one_shot(stream)

func play_barricade_success() -> void:
	# Heavy metallic barricade lock clank (FM metallic clang + ratcheting latch)
	var stream := _synth_barricade_clank()
	_play_one_shot(stream)

func play_protocol_correct() -> void:
	# Authoritative tactical terminal confirmation (warm low-mid harmonic pulse + radio click)
	var stream := _synth_terminal_confirm()
	_play_one_shot(stream)

func play_protocol_wrong() -> void:
	# Emergency dispatch alert double-thud (low muffled warning pulse 130Hz + radio buzz)
	var stream := _synth_dispatch_warning()
	_play_one_shot(stream)

func play_ui_click() -> void:
	# Crisp mechanical switch tick (12ms damped impulse)
	var stream := _synth_mech_switch()
	_play_one_shot(stream)

func play_ui_hover() -> void:
	var stream := _synth_hover_tick()
	_play_one_shot(stream)

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
		_: play_ui_click()

func _play_one_shot(stream: AudioStreamWAV) -> void:
	if not sound_enabled or stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.bus = "Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# --- ACOUSTIC SYNTHESIS GENERATORS (Zero external audio files) ---

func _synth_footstep(surface: String, pitch_mult: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.055
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	var is_water := (surface == "water")
	var heel_freq := (75.0 if is_water else 85.0) * pitch_mult
	var heel_decay := 45.0
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# 1. Heel thud
		var thud := sin(TAU * heel_freq * t) * exp(-heel_decay * t) * 0.65
		# 2. Surface transient burst
		var surface_noise := 0.0
		if is_water:
			# High-passed water splash slap
			var splash := (randf_range(-1.0, 1.0) if randf() < 0.7 else 0.0) * exp(-30.0 * t)
			surface_noise = splash * 0.45
		else:
			# Crisp gravel / asphalt scuff
			var grit := randf_range(-1.0, 1.0) * exp(-70.0 * t)
			surface_noise = grit * 0.28
			
		var val := clampf((thud + surface_noise) * 0.75, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_seismic_roar(intensity: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 1.85
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	var sub_phase := 0.0
	var brown := 0.0
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var progress := t / duration
		
		# 28Hz to 48Hz sub-bass sine sweep
		var sub_freq := lerpf(30.0, 46.0, sin(progress * PI))
		sub_phase += TAU * sub_freq / float(mix_rate)
		var sub := sin(sub_phase) * 0.55
		
		# Heavy filtered brown noise roar
		var white := randf_range(-1.0, 1.0)
		brown = lerpf(brown, white, 0.05)
		
		# 5 concrete fracture cracking spikes at random intervals
		var crack := 0.0
		if (i > 2000 and i < 2200) or (i > 8000 and i < 8300) or (i > 15000 and i < 15350) or (i > 26000 and i < 26250):
			crack = randf_range(-1.0, 1.0) * 0.75
			
		var env := sin(progress * PI)
		var val := clampf((sub * 0.5 + brown * 0.4 + crack * 0.4) * env * intensity * 0.85, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_thunder_clap() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 1.7
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	var brown := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Initial high-frequency lightning static crack (40ms)
		var initial_crack := randf_range(-1.0, 1.0) * exp(-45.0 * t) if t < 0.06 else 0.0
		# Rolling low-pass bass thunder decay
		var white := randf_range(-1.0, 1.0)
		brown = lerpf(brown, white, 0.04)
		var bass_sub := sin(TAU * 42.0 * t) * 0.4
		var decay := exp(-2.2 * t)
		
		var val := clampf((initial_crack * 0.6 + (brown * 0.6 + bass_sub * 0.4) * decay) * 0.85, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_electric_arc() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.16
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	var bp_state := 0.0
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Rapid-fire band-passed crackle (1200-3500Hz)
		var white := randf_range(-1.0, 1.0)
		bp_state = lerpf(bp_state, white, 0.35)
		var hum := sin(TAU * 100.0 * t) * 0.35
		var burst := (bp_state if randf() < 0.4 else 0.0) * exp(-14.0 * t)
		var val := clampf((burst * 0.7 + hum * 0.3) * 0.75, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_gear_equip() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.15
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Nylon fabric velcro rustle
		var rustle := randf_range(-1.0, 1.0) * (1.0 - t / duration) * 0.25
		# Mechanical buckle snap click at t = 0.08s
		var click := 0.0
		if t > 0.075 and t < 0.095:
			var ct := t - 0.075
			click = sin(TAU * 1450.0 * ct) * exp(-280.0 * ct) * 0.75
			
		var val := clampf(rustle + click, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_walkie_squelch() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.26
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var val := 0.0
		if t < 0.045:
			# Opening radio squelch burst
			val = randf_range(-1.0, 1.0) * 0.42
		elif t < 0.18:
			# Clean tactical two-tone comms confirmation (880Hz -> 1174Hz)
			var f := 880.0 if t < 0.11 else 1174.66
			val = sin(TAU * f * t) * 0.45
		else:
			# Tail static release
			val = randf_range(-1.0, 1.0) * exp(-30.0 * (t - 0.18)) * 0.35
			
		var amp := int(clampf(val * 0.75, -1.0, 1.0) * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_barricade_clank() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.24
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Heavy metallic clang (FM harmonic frequencies: 320Hz, 740Hz, 1260Hz)
		var clang := (sin(TAU * 320.0 * t) * 0.5 + sin(TAU * 740.0 * t) * 0.35 + sin(TAU * 1260.0 * t) * 0.25) * exp(-16.0 * t)
		# Ratcheting latch click
		var ratchet := (randf_range(-1.0, 1.0) if fmod(t, 0.02) < 0.005 and t < 0.1 else 0.0) * 0.4
		var val := clampf((clang * 0.65 + ratchet * 0.35) * 0.85, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_terminal_confirm() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.16
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Warm low-mid harmonic pulse (440Hz + 880Hz) + radio click
		var tone := (sin(TAU * 440.0 * t) * 0.6 + sin(TAU * 880.0 * t) * 0.4) * exp(-18.0 * t)
		var click := randf_range(-1.0, 1.0) * exp(-90.0 * t) * 0.2
		var val := clampf((tone * 0.8 + click) * 0.7, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_dispatch_warning() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.28
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Low muffled warning double pulse (130Hz)
		var p1 := sin(TAU * 130.0 * t) * exp(-28.0 * t) if t < 0.12 else 0.0
		var p2 := sin(TAU * 120.0 * (t - 0.13)) * exp(-28.0 * (t - 0.13)) if t >= 0.13 else 0.0
		var buzz := randf_range(-1.0, 1.0) * 0.15 * exp(-10.0 * t)
		var val := clampf((p1 + p2 + buzz) * 0.85, -1.0, 1.0)
		var amp := int(val * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_mech_switch() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.02
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		# Crisp 12ms damped impulse (1800Hz damped sine)
		var val := sin(TAU * 1800.0 * t) * exp(-190.0 * t) * 0.55
		var amp := int(clampf(val, -1.0, 1.0) * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _synth_hover_tick() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.012
	var total_samples := int(mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(mix_rate)
		var val := sin(TAU * 2400.0 * t) * exp(-320.0 * t) * 0.22
		var amp := int(clampf(val, -1.0, 1.0) * 32767.0)
		samples[i * 2] = amp & 0xFF
		samples[i * 2 + 1] = (amp >> 8) & 0xFF
		
	return _make_wav(samples, mix_rate)

func _make_wav(samples: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = samples
	return wav
