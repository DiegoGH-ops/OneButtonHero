extends Node
## Autoload "Sfx": todos los sonidos se sintetizan por codigo al arrancar
## (ondas cuadradas, triangulares, sierra y ruido). No existe ningun archivo
## de audio en el proyecto, asi que nada puede "faltar".
##
## Uso:  Sfx.play("jump")   Sfx.start_music()

const MIX_RATE := 22050
const MUSIC_RATE := 11025
const PLAYER_COUNT := 8

enum Wave { SQUARE, SAW, TRIANGLE }

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next: int = 0
var _music_buf: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20240607
	_build_sounds()
	for i in PLAYER_COUNT:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = _build_music()
	add_child(_music)
	GameData.settings_changed.connect(refresh)
	refresh()


## Reproduce un efecto. `pitch` permite variar ligeramente el tono.
func play(sound: String, pitch: float = 1.0) -> void:
	if not GameData.sfx_enabled or not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


func start_music() -> void:
	if GameData.music_enabled and not _music.playing:
		_music.play()


func stop_music() -> void:
	_music.stop()


## Aplica volumen y estado de la musica segun los ajustes guardados.
func refresh() -> void:
	var vol: float = maxf(GameData.volume, 0.0001)
	for p in _players:
		p.volume_db = linear_to_db(vol)
	_music.volume_db = linear_to_db(vol * 0.55)
	if GameData.music_enabled:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


# ---------------------------------------------------------------- sintesis --

func _build_sounds() -> void:
	_streams["jump"] = _to_stream(_tone(0.16, 280.0, 620.0, Wave.SQUARE, 0.28), MIX_RATE)
	_streams["land"] = _to_stream(_tone(0.07, 160.0, 70.0, Wave.TRIANGLE, 0.30, 0.5), MIX_RATE)
	_streams["attack"] = _to_stream(_tone(0.13, 1200.0, 300.0, Wave.SAW, 0.26, 0.75), MIX_RATE)
	_streams["click"] = _to_stream(_tone(0.05, 700.0, 900.0, Wave.SQUARE, 0.18), MIX_RATE)
	_streams["hurt"] = _to_stream(_tone(0.32, 300.0, 60.0, Wave.SAW, 0.40, 0.3), MIX_RATE)

	var kill: PackedFloat32Array = _tone(0.07, 520.0, 300.0, Wave.SQUARE, 0.30, 0.2)
	kill.append_array(_tone(0.16, 300.0, 90.0, Wave.SQUARE, 0.30, 0.35))
	_streams["kill"] = _to_stream(kill, MIX_RATE)

	var coin: PackedFloat32Array = _tone(0.06, 988.0, 988.0, Wave.SQUARE, 0.20)
	coin.append_array(_tone(0.16, 1319.0, 1319.0, Wave.SQUARE, 0.20))
	_streams["coin"] = _to_stream(coin, MIX_RATE)

	_streams["gem"] = _to_stream(_melody([784.0, 988.0, 1175.0, 1568.0], 0.06, 0.22, Wave.SQUARE, 0.20), MIX_RATE)
	_streams["level"] = _to_stream(_melody([523.0, 659.0, 784.0, 1047.0], 0.07, 0.22, Wave.SQUARE, 0.22), MIX_RATE)
	_streams["gameover"] = _to_stream(_melody([392.0, 330.0, 262.0, 196.0], 0.16, 0.45, Wave.TRIANGLE, 0.45), MIX_RATE)


## Un tono con barrido de frecuencia f0 -> f1 y mezcla opcional de ruido.
func _tone(duration: float, f0: float, f1: float, wave: int, vol: float, noise: float = 0.0) -> PackedFloat32Array:
	var count: int = int(duration * MIX_RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / float(count)
		phase += lerpf(f0, f1, t) / float(MIX_RATE)
		if phase >= 1.0:
			phase -= 1.0
		var s: float = 0.0
		if wave == Wave.SQUARE:
			s = 1.0 if phase < 0.5 else -1.0
		elif wave == Wave.SAW:
			s = 2.0 * phase - 1.0
		else:
			s = 4.0 * absf(phase - 0.5) - 1.0
		if noise > 0.0:
			s = lerpf(s, _rng.randf_range(-1.0, 1.0), noise)
		var env: float = minf(1.0, float(i) / 80.0) * pow(1.0 - t, 1.5)
		out[i] = s * env * vol
	return out


## Varias notas seguidas; la ultima dura `last_duration`.
func _melody(freqs: Array, note_duration: float, last_duration: float, wave: int, vol: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i in freqs.size():
		var f: float = freqs[i]
		var d: float = last_duration if i == freqs.size() - 1 else note_duration
		out.append_array(_tone(d, f, f, wave, vol))
	return out


## Convierte muestras -1..1 en un AudioStreamWAV de 16 bits mono.
func _to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


# ------------------------------------------------------------------ musica --

func _midi_to_freq(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


## Suma una nota al buffer de musica (envolvente lineal descendente).
func _add_note(start: int, max_length: int, freq: float, wave: int, vol: float) -> void:
	var phase: float = 0.0
	var inc: float = freq / float(MUSIC_RATE)
	var length: int = mini(max_length, _music_buf.size() - start)
	if length <= 0:
		return
	var end: int = start + length
	var inv_len: float = 1.0 / float(length)
	for i in range(start, end):
		phase += inc
		if phase >= 1.0:
			phase -= 1.0
		var s: float = 0.0
		if wave == Wave.SQUARE:
			s = 1.0 if phase < 0.5 else -1.0
		else:
			s = 4.0 * absf(phase - 0.5) - 1.0
		var t: float = float(i - start) * inv_len
		_music_buf[i] += s * vol * (1.0 - t)


## Bucle de 4 compases estilo chiptune (La menor - Fa - Do - Sol).
func _build_music() -> AudioStreamWAV:
	var lead: Array = [
		69, 0, 72, 0, 76, 0, 72, 0, 81, 0, 76, 72, 76, 0, 72, 0,
		65, 0, 69, 0, 72, 0, 69, 0, 77, 0, 72, 69, 72, 0, 69, 0,
		64, 0, 67, 0, 72, 0, 67, 0, 76, 0, 72, 67, 72, 0, 67, 0,
		62, 0, 67, 0, 71, 0, 67, 0, 74, 0, 71, 74, 76, 0, 74, 71,
	]
	var roots: Array = [45, 41, 48, 43]
	var step_len: int = int(float(MUSIC_RATE) * 60.0 / 132.0 / 4.0)
	var total: int = step_len * lead.size()
	_music_buf = PackedFloat32Array()
	_music_buf.resize(total)
	_music_buf.fill(0.0)
	for step in lead.size():
		var note: int = lead[step]
		if note > 0:
			_add_note(step * step_len, step_len * 2, _midi_to_freq(note), Wave.SQUARE, 0.11)
		var in_bar: int = step % 16
		var bar: int = int(float(step) / 16.0)
		var root: int = roots[bar]
		if in_bar % 4 == 0:
			_add_note(step * step_len, step_len * 2, _midi_to_freq(root), Wave.TRIANGLE, 0.30)
		elif in_bar == 6 or in_bar == 14:
			_add_note(step * step_len, step_len * 2, _midi_to_freq(root + 12), Wave.TRIANGLE, 0.24)
	var stream: AudioStreamWAV = _to_stream(_music_buf, MUSIC_RATE)
	_music_buf = PackedFloat32Array()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream
