extends RefCounted
## Procedural synthesis: everything Ded Drift sounds like is generated here as
## raw samples (no audio files shipped). All render functions are pure and
## thread-safe; AudioDirector runs them on a background thread at startup.
##
## Musical identity (from the original's soundtrack plan): D minor, ~84 BPM,
## detuned saw pads (Vangelis), tape hum always underneath, lo-fi grit.

const RATE := 22050
const BPM := 84.0
const BEATS := 16  # 4 bars of 4/4 per loop

# Dm - Bb - Gm - A  (pad voicings / bass roots, MIDI numbers)
const CHORDS := [[50, 53, 57], [46, 50, 53], [43, 50, 58], [45, 52, 61]]
const ROOTS := [38, 34, 31, 33]
const PENTA := [74, 77, 79, 81, 84, 86]


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func beat_len() -> float:
	return 60.0 / BPM


static func loop_samples() -> int:
	return int(round(BEATS * beat_len() * RATE))


static func lp_coef(cutoff: float) -> float:
	return 1.0 - exp(-TAU * cutoff / RATE)


## 16-bit PCM bytes (thread-safe). Turn into a stream with make_stream().
static func to_pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return bytes


static func make_stream(pcm: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = pcm
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = pcm.size() / 2
	return w


# --- music layers ------------------------------------------------------------------

## Detuned saw pad through a slowly breathing low-pass. The "bed".
static func render_pad() -> PackedFloat32Array:
	var n := loop_samples()
	var out := PackedFloat32Array()
	out.resize(n)
	var bar_n := n / 4
	var phases := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var incs := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var lp := 0.0
	var lp2 := 0.0
	var a := lp_coef(700.0)
	var bar_secs := float(bar_n) / RATE
	var current_bar := -1
	for i in n:
		var bar := mini(i / bar_n, 3)
		if bar != current_bar:
			current_bar = bar
			var chord: Array = CHORDS[bar]
			for k in 6:
				incs[k] = hz(chord[k / 2]) * (1.006 if k % 2 == 0 else 0.994) / RATE
		var t_in_bar := float(i - bar * bar_n) / RATE
		var env := minf(1.0, t_in_bar / 0.6) * minf(1.0, (bar_secs - t_in_bar) / 0.5)
		var acc := 0.0
		for k in 6:
			phases[k] = fmod(phases[k] + incs[k], 1.0)
			acc += phases[k] * 2.0 - 1.0
		acc /= 6.0
		if i % 64 == 0:
			a = lp_coef(700.0 + 500.0 * sin(TAU * float(i) / n))
		lp += a * (acc - lp)
		lp2 += a * (lp - lp2)
		out[i] = lp2 * env * 0.55
	return out


## Bass eighths + a soft kick on 1 and 3. Calm-flight drive.
static func render_pulse() -> PackedFloat32Array:
	var n := loop_samples()
	var out := PackedFloat32Array()
	out.resize(n)
	var bar_n := n / 4
	var eighth := beat_len() * 0.5
	var phase := 0.0
	var lp := 0.0
	var a := lp_coef(420.0)
	var kick_phase := 0.0
	var last_note := -1
	var inc := 0.0
	for i in n:
		var bar := mini(i / bar_n, 3)
		var t := float(i) / RATE
		var t8 := fmod(t, eighth)
		var note: int = ROOTS[bar] + (12 if int(t / eighth) % 4 == 3 else 0)
		if note != last_note:
			last_note = note
			inc = hz(note) / RATE
		phase = fmod(phase + inc, 1.0)
		var sq := 1.0 if phase < 0.5 else -1.0
		lp += a * (sq * exp(-t8 * 7.0) - lp)
		var tb := fmod(t, beat_len() * 2.0)
		var kf := 45.0 + 90.0 * exp(-tb * 30.0)
		kick_phase = fmod(kick_phase + kf / RATE, 1.0)
		var kick := sin(TAU * kick_phase) * exp(-tb * 9.0)
		out[i] = lp * 0.42 + kick * 0.5
	return out


## 16th-note arpeggio + offbeat hats + backbeat noise. Fades in when hunted.
static func render_tension() -> PackedFloat32Array:
	var n := loop_samples()
	var out := PackedFloat32Array()
	out.resize(n)
	var bar_n := n / 4
	var six := beat_len() * 0.25
	var phase := 0.0
	var hp_lp := 0.0
	var hp_a := lp_coef(3000.0)
	var rs := 12345
	var last_note := -1
	var inc := 0.0
	for i in n:
		var bar := mini(i / bar_n, 3)
		var t := float(i) / RATE
		var step := int(t / six)
		var ts := fmod(t, six)
		var chord: Array = CHORDS[bar]
		var note: int = chord[[0, 1, 2, 1][step % 4]] + 12 + (12 if step % 8 >= 4 else 0)
		if note != last_note:
			last_note = note
			inc = hz(note) / RATE
		phase = fmod(phase + inc, 1.0)
		var tri := 4.0 * absf(phase - 0.5) - 1.0
		var arp := tri * exp(-ts * 18.0) * 0.30
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var noise := float(rs) / 1073741823.5 - 1.0
		hp_lp += hp_a * (noise - hp_lp)
		var hiss := noise - hp_lp
		var tb := fmod(t, beat_len())
		var hat := hiss * exp(-absf(tb - beat_len() * 0.5) * 60.0) * 0.35
		var tsn := fmod(t + beat_len(), beat_len() * 2.0)
		var snare := noise * exp(-tsn * 14.0) * 0.18
		out[i] = arp + hat + snare
	return out


## Sparse FM bells over a D drone. The terminal theme.
static func render_terminal() -> PackedFloat32Array:
	var n := loop_samples()
	var out := PackedFloat32Array()
	out.resize(n)
	var beat := beat_len()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var bells := []
	for b in BEATS:
		bells.append(PENTA[rng.randi() % PENTA.size()] if rng.randf() < 0.55 else -1)
	var drone_phase := 0.0
	var drone_inc := hz(38) / RATE
	for i in n:
		var t := float(i) / RATE
		var b := int(t / beat)
		var tb := t - b * beat
		var s := 0.0
		var note: int = bells[b % BEATS]
		if note > 0:
			var f := hz(note)
			var env := exp(-tb * 2.2)
			s += sin(TAU * f * tb + 2.0 * env * sin(TAU * f * 2.0 * tb)) * env * 0.22
		# the previous bell rings on into this beat
		var prev: int = bells[(b + BEATS - 1) % BEATS]
		if prev > 0:
			var tp := tb + beat
			s += sin(TAU * hz(prev) * tp) * exp(-tp * 2.2) * 0.12
		drone_phase = fmod(drone_phase + drone_inc, 1.0)
		s += sin(TAU * drone_phase) * 0.16 + sin(TAU * drone_phase * 2.0) * 0.05
		out[i] = s
	return out


## Tape hum: 50/100 Hz mains + hiss. Seamless 2 s loop (whole cycles).
static func render_hum() -> PackedFloat32Array:
	var n := RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var rs := 777
	var lp := 0.0
	var a := lp_coef(2500.0)
	for i in n:
		var t := float(i) / RATE
		rs = (rs * 1103515245 + 12345) & 0x7fffffff
		var noise := float(rs) / 1073741823.5 - 1.0
		lp += a * (noise - lp)
		out[i] = sin(TAU * 50.0 * t) * 0.10 + sin(TAU * 100.0 * t) * 0.05 + lp * 0.05
	return out


# --- sound effects -----------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Frequency sweep with an exponential decay. wave: "sine", "square", "saw", "tri".
static func sweep(seconds: float, f0: float, f1: float, decay: float, wave := "sine", gain := 0.6) -> PackedFloat32Array:
	var out := _buf(seconds)
	var phase := 0.0
	var n := out.size()
	var inc := f0 / RATE
	for i in n:
		if i % 16 == 0:
			inc = f0 * pow(f1 / f0, float(i) / n) / RATE
		phase = fmod(phase + inc, 1.0)
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if phase < 0.5 else -1.0
			"saw":
				v = phase * 2.0 - 1.0
			"tri":
				v = 4.0 * absf(phase - 0.5) - 1.0
			_:
				v = sin(TAU * phase)
		out[i] = v * exp(-float(i) / RATE * decay) * gain
	return out


## Low-passed noise burst; cutoff sweeps from c0 to c1.
static func noise_burst(seconds: float, c0: float, c1: float, decay: float, gain := 0.7, noise_seed := 1) -> PackedFloat32Array:
	var out := _buf(seconds)
	var n := out.size()
	var lp := 0.0
	var a := lp_coef(c0)
	var s := noise_seed
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var noise := float(s) / 1073741823.5 - 1.0
		if i % 32 == 0:
			a = lp_coef(c0 * pow(c1 / c0, float(i) / n))
		lp += a * (noise - lp)
		out[i] = lp * exp(-float(i) / RATE * decay) * gain
	return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_s := 0.0) -> PackedFloat32Array:
	var off := int(offset_s * RATE)
	var out := a.duplicate()
	if out.size() < b.size() + off:
		out.resize(b.size() + off)
	for i in b.size():
		out[i + off] += b[i]
	return out


static func crush(a: PackedFloat32Array, levels := 12.0) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in out.size():
		out[i] = round(out[i] * levels) / levels
	return out


static func notes(midis: Array, step_s: float, decay: float, wave := "square", gain := 0.35) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in midis.size():
		var f := hz(midis[k])
		out = mix(out, sweep(step_s * 2.5, f, f, decay, wave, gain), step_s * k)
	return out


static func render_sfx() -> Dictionary:
	var s := {}
	s["gun"] = crush(sweep(0.09, 1500.0, 450.0, 30.0, "square", 0.25), 10.0)
	s["enemy_shot"] = sweep(0.14, 900.0, 180.0, 20.0, "saw", 0.3)
	s["hit"] = mix(noise_burst(0.2, 3000.0, 300.0, 18.0, 0.7, 3), sweep(0.2, 140.0, 50.0, 14.0, "sine", 0.6))
	s["explode"] = mix(noise_burst(1.1, 2500.0, 80.0, 3.5, 0.9, 5), sweep(0.8, 90.0, 30.0, 4.0, "sine", 0.8))
	s["pickup"] = mix(sweep(0.08, 880.0, 880.0, 25.0, "square", 0.25), sweep(0.12, 1320.0, 1320.0, 18.0, "square", 0.25), 0.06)
	s["patch"] = notes([74, 78, 81, 86], 0.06, 12.0, "tri", 0.4)
	s["clamp"] = mix(mix(sweep(0.5, 220.0, 210.0, 7.0, "sine", 0.4), sweep(0.5, 347.0, 340.0, 9.0, "sine", 0.3)),
		mix(sweep(0.5, 563.0, 560.0, 11.0, "sine", 0.25), noise_burst(0.15, 4000.0, 800.0, 25.0, 0.6, 9)))
	s["snap"] = sweep(0.35, 420.0, 70.0, 8.0, "saw", 0.45)
	s["slingshot"] = mix(noise_burst(0.7, 300.0, 5000.0, 3.0, 0.5, 11), sweep(0.7, 200.0, 900.0, 3.0, "tri", 0.25))
	s["warp"] = mix(sweep(1.1, 90.0, 1800.0, 1.2, "saw", 0.35), noise_burst(1.1, 200.0, 6000.0, 1.5, 0.4, 13))
	s["jump_ready"] = notes([76, 83, 88], 0.1, 6.0, "sine", 0.45)
	s["ui_tap"] = sweep(0.03, 2200.0, 1800.0, 90.0, "square", 0.15)
	s["key"] = mix(noise_burst(0.025, 6000.0, 3000.0, 160.0, 0.5, 17), sweep(0.02, 2000.0, 1800.0, 200.0, "square", 0.08))
	s["deny"] = sweep(0.28, 120.0, 110.0, 6.0, "square", 0.3)
	s["exploit"] = notes([62, 65, 69, 74, 77, 81, 86, 89], 0.045, 10.0, "square", 0.25)
	s["release"] = notes([62, 66, 69, 74], 0.09, 4.0, "tri", 0.4)
	var siren := PackedFloat32Array()
	for k in 3:
		siren = mix(siren, sweep(0.3, 600.0, 900.0, 0.5, "saw", 0.3), 0.3 * k)
	s["alarm"] = siren
	for k in 4:
		s["bax%d" % k] = crush(sweep(0.055, 170.0 + 30.0 * k, 150.0 + 30.0 * k, 25.0, "square", 0.22), 8.0)
	var thrust := noise_burst(1.0, 180.0, 180.0, 0.0, 0.8, 21)
	s["thrust_loop"] = thrust
	return s
