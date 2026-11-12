extends Node
## Autoload "Sfx": efectos y musica sintetizados por codigo (ondas cuadradas,
## triangulares, sierra y ruido). No hay ningun archivo de audio.
##
##   Sfx.play("jump")            efecto de sonido
##   Sfx.play_music("night")     cambia de cancion con fundido cruzado
##
## Canciones: menu, day, sunset, night, shop, gameover. Se generan en un hilo
## aparte al arrancar para no congelar el juego; si se pide una cancion que
## aun no esta lista, empieza a sonar en cuanto termina de generarse.

const MIX_RATE := 22050
const MUSIC_RATE := 11025
const PLAYER_COUNT := 10
const FADE_TIME := 1.4
const SILENT_DB := -50.0

enum Wave { SQUARE, SAW, TRIANGLE }

## Intervalos (en semitonos) de las notas de un acorde mayor y menor.
const MAJOR := [0, 4, 7, 12, 16, 19, 24]
const MINOR := [0, 3, 7, 12, 15, 19, 24]

## Cada cancion: tempo, acordes [nota raiz MIDI, es_menor] (uno por compas),
## patron de melodia (indice de nota del acorde, -1 = silencio), patron de
## bajo (0 raiz, 1 quinta, 2 octava), duracion de nota y timbres.
const TRACKS := {
	"menu": {
		"bpm": 112.0, "chords": [[60, 0], [57, 1], [65, 0], [67, 0]],
		"lead": [0, -1, 2, -1, 3, -1, 2, 1, 4, -1, 3, -1, 2, -1, 1, -1],
		"bass": [0, -1, -1, 0, -1, -1, 1, -1, 0, -1, -1, 0, -1, 2, -1, -1],
		"lead_len": 2, "lead_wave": Wave.SQUARE, "lead_vol": 0.10, "bass_vol": 0.26, "drums": 0.5, "octave": 12,
	},
	"day": {
		"bpm": 136.0, "chords": [[57, 1], [53, 0], [60, 0], [55, 0]],
		"lead": [3, -1, 4, -1, 5, -1, 4, -1, 6, -1, 5, 4, 5, -1, 4, 2],
		"bass": [0, -1, 2, -1, 0, -1, 2, -1, 0, -1, 2, -1, 0, -1, 1, 2],
		"lead_len": 2, "lead_wave": Wave.SQUARE, "lead_vol": 0.10, "bass_vol": 0.28, "drums": 1.0, "octave": 0,
	},
	"sunset": {
		"bpm": 104.0, "chords": [[62, 1], [58, 0], [65, 0], [60, 0]],
		"lead": [2, -1, -1, 3, -1, -1, 4, -1, 3, -1, -1, 2, -1, 1, -1, -1],
		"bass": [0, -1, -1, -1, 1, -1, -1, -1, 0, -1, -1, -1, 2, -1, 1, -1],
		"lead_len": 3, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.22, "bass_vol": 0.24, "drums": 0.4, "octave": 12,
	},
	"night": {
		"bpm": 92.0, "chords": [[52, 1], [48, 0], [55, 0], [50, 0]],
		"lead": [0, -1, -1, -1, 2, -1, -1, 3, -1, -1, 2, -1, 1, -1, -1, -1],
		"bass": [0, -1, -1, -1, -1, -1, 0, -1, -1, -1, 1, -1, -1, -1, -1, -1],
		"lead_len": 4, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.24, "bass_vol": 0.26, "drums": 0.2, "octave": 24,
	},
	"shop": {
		"bpm": 120.0, "chords": [[65, 0], [62, 1], [58, 0], [60, 0]],
		"lead": [0, 2, -1, 3, -1, 2, 4, -1, 3, -1, 2, -1, 3, 2, 1, -1],
		"bass": [0, -1, 2, -1, 1, -1, 2, -1, 0, -1, 2, -1, 1, -1, 2, -1],
		"lead_len": 1, "lead_wave": Wave.SQUARE, "lead_vol": 0.09, "bass_vol": 0.24, "drums": 0.6, "octave": 12,
	},
	# --- Campana: un tema por mundo (con variante nocturna automatica) ---
	"forest": {
		"bpm": 118.0, "chords": [[55, 0], [52, 1], [60, 0], [62, 0]], "night": true,
		"lead": [0, -1, 2, 3, -1, 2, 4, -1, 3, -1, 2, -1, 1, 2, -1, -1],
		"bass": [0, -1, -1, 2, -1, -1, 1, -1, 0, -1, -1, 2, -1, 1, -1, -1],
		"lead_len": 2, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.22, "bass_vol": 0.26, "drums": 0.6, "octave": 12,
	},
	"inferno": {
		"bpm": 152.0, "chords": [[52, 1], [52, 1], [48, 0], [50, 0]], "night": true,
		"lead": [0, 0, 3, -1, 2, -1, 0, 4, -1, 3, 2, -1, 0, -1, 1, 2],
		"bass": [0, 0, -1, 0, 2, -1, 0, -1, 0, 0, -1, 0, 1, -1, 2, -1],
		"lead_len": 1, "lead_wave": Wave.SAW, "lead_vol": 0.10, "bass_vol": 0.32, "drums": 1.2, "octave": 0,
	},
	"crystal": {
		"bpm": 96.0, "chords": [[61, 0], [58, 1], [54, 0], [56, 0]], "night": true,
		"lead": [0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 5, 3, 2, 1],
		"bass": [0, -1, -1, -1, 1, -1, -1, -1, 0, -1, -1, -1, 2, -1, -1, -1],
		"lead_len": 1, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.20, "bass_vol": 0.24, "drums": 0.3, "octave": 12,
	},
	"frost": {
		"bpm": 84.0, "chords": [[50, 1], [46, 0], [53, 0], [45, 1]], "night": true,
		"lead": [4, -1, -1, 3, -1, -1, 2, -1, -1, -1, 3, -1, 1, -1, -1, -1],
		"bass": [0, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, -1, -1, -1, -1, -1],
		"lead_len": 3, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.24, "bass_vol": 0.22, "drums": 0.25, "octave": 24,
	},
	"desert": {
		"bpm": 128.0, "chords": [[50, 1], [51, 0], [50, 1], [48, 0]], "night": true,
		"lead": [0, -1, 1, 2, -1, 1, 0, -1, 3, -1, 2, 1, 2, -1, 0, -1],
		"bass": [0, -1, 0, -1, 1, -1, 0, -1, 0, -1, 0, -1, 2, -1, 1, -1],
		"lead_len": 2, "lead_wave": Wave.SQUARE, "lead_vol": 0.09, "bass_vol": 0.28, "drums": 0.9, "octave": 12,
	},
	"boss": {
		"bpm": 164.0, "chords": [[45, 1], [46, 0], [45, 1], [44, 0]],
		"lead": [0, 3, 0, 4, 0, 3, 5, 4, 0, 3, 0, 4, 6, 5, 4, 3],
		"bass": [0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 1, 1, 2, 2],
		"lead_len": 1, "lead_wave": Wave.SAW, "lead_vol": 0.09, "bass_vol": 0.34, "drums": 1.3, "octave": 12,
	},
	"victory": {
		"bpm": 140.0, "chords": [[60, 0], [65, 0], [67, 0], [72, 0]],
		"lead": [0, -1, 2, -1, 4, -1, 2, 4, 5, -1, -1, 4, 5, -1, 6, -1],
		"bass": [0, -1, 2, -1, 0, -1, 2, -1, 0, -1, 2, -1, 0, -1, 2, -1],
		"lead_len": 2, "lead_wave": Wave.SQUARE, "lead_vol": 0.10, "bass_vol": 0.24, "drums": 0.8, "octave": 0,
	},
	"reward": {
		"bpm": 104.0, "chords": [[65, 0], [69, 1], [70, 0], [72, 0]],
		"lead": [2, -1, 3, -1, 4, -1, -1, 3, 2, -1, 1, -1, 2, -1, -1, -1],
		"bass": [0, -1, -1, 2, -1, -1, 1, -1, 0, -1, -1, 2, -1, -1, 1, -1],
		"lead_len": 2, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.22, "bass_vol": 0.22, "drums": 0.35, "octave": 12,
	},
	"gameover": {
		"bpm": 72.0, "chords": [[57, 1], [53, 0], [50, 1], [52, 1]],
		"lead": [4, -1, -1, -1, 3, -1, -1, -1, 2, -1, -1, -1, 1, -1, -1, -1],
		"bass": [0, -1, -1, -1, -1, -1, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1],
		"lead_len": 4, "lead_wave": Wave.TRIANGLE, "lead_vol": 0.24, "bass_vol": 0.22, "drums": 0.0, "octave": 0,
	},
}

## Separacion minima (ms) entre dos reproducciones del mismo efecto.
const MIN_GAP_MS := {"coin": 45, "hover": 70, "click": 60, "land": 90, "jump": 60, "kill": 50, "hit": 50, "step": 120, "combo": 300, "dodge": 120}

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track: String = ""
var _fade: Tween
var _next: int = 0
var _last_played: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _thread: Thread
var _intensity: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20240607
	_build_sounds()
	for i in PLAYER_COUNT:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_active = _music_a
	GameData.settings_changed.connect(refresh)
	refresh()
	_thread = Thread.new()
	_thread.start(_render_all_tracks)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


## Reproduce un efecto. `pitch` permite variar ligeramente el tono.
func play(sound: String, pitch: float = 1.0) -> void:
	if not GameData.sfx_enabled or not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	var gap: int = int(MIN_GAP_MS.get(sound, 30))
	if now - int(_last_played.get(sound, -1000)) < gap:
		return
	_last_played[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


## Cambia de cancion con un fundido cruzado suave.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	_start_current()


## Intensidad de la musica (0-3) segun el combo: acelera y sube un poco.
func set_intensity(level: int) -> void:
	if level == _intensity:
		return
	_intensity = level
	var pitch: float = 1.0 + 0.03 * float(level)
	_music_a.pitch_scale = pitch
	_music_b.pitch_scale = pitch
	if _active.playing and (_fade == null or not _fade.is_running()):
		_active.volume_db = _music_db()


func stop_music() -> void:
	_current_track = ""
	_music_a.stop()
	_music_b.stop()


func _music_db() -> float:
	return linear_to_db(maxf(GameData.music_volume * (0.6 + 0.05 * float(_intensity)), 0.0001))


func _start_current() -> void:
	if not GameData.music_enabled or _current_track == "" or not _music_streams.has(_current_track):
		return
	var old: AudioStreamPlayer = _active
	var fresh: AudioStreamPlayer = _music_b if _active == _music_a else _music_a
	_active = fresh
	fresh.stream = _music_streams[_current_track]
	fresh.volume_db = SILENT_DB
	fresh.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(fresh, "volume_db", _music_db(), FADE_TIME)
	_fade.tween_property(old, "volume_db", SILENT_DB, FADE_TIME)
	_fade.chain().tween_callback(old.stop)


## Aplica volumenes y silencios segun los ajustes guardados.
func refresh() -> void:
	var vol: float = maxf(GameData.sfx_volume, 0.0001)
	for p in _players:
		p.volume_db = linear_to_db(vol)
	if GameData.music_enabled:
		if _active.playing:
			if _fade == null or not _fade.is_running():
				_active.volume_db = _music_db()
		else:
			_start_current()
	else:
		_music_a.stop()
		_music_b.stop()


# ---------------------------------------------------------------- efectos --

func _build_sounds() -> void:
	_add("jump", _tone(0.16, 280.0, 620.0, Wave.SQUARE, 0.26))
	_add("land", _tone(0.07, 160.0, 70.0, Wave.TRIANGLE, 0.30, 0.5))
	_add("attack", _tone(0.13, 1200.0, 300.0, Wave.SAW, 0.24, 0.75))
	_add("click", _tone(0.05, 700.0, 900.0, Wave.SQUARE, 0.18))
	_add("hover", _tone(0.03, 1100.0, 1300.0, Wave.TRIANGLE, 0.16))
	_add("hurt", _tone(0.32, 300.0, 60.0, Wave.SAW, 0.40, 0.3))
	_add("hit", _tone(0.09, 900.0, 500.0, Wave.SQUARE, 0.26, 0.5))
	_add("error", _melody([150.0, 110.0], 0.09, 0.16, Wave.SAW, 0.30))
	_add("shield", _melody([1318.0, 988.0, 659.0], 0.06, 0.2, Wave.TRIANGLE, 0.4))
	_add("power_turbo", _tone(0.35, 200.0, 1100.0, Wave.SAW, 0.24, 0.25))
	_add("power_wave", _tone(0.45, 420.0, 50.0, Wave.SQUARE, 0.34, 0.6))
	_add("soul", _tone(0.5, 110.0, 880.0, Wave.SAW, 0.30, 0.35))
	_add("good", _tone(0.07, 660.0, 880.0, Wave.TRIANGLE, 0.35))
	_add("perfect", _melody([880.0, 1319.0], 0.05, 0.16, Wave.SQUARE, 0.20))
	_add("legendary", _melody([1047.0, 1319.0, 1568.0, 2093.0, 2637.0], 0.04, 0.3, Wave.SQUARE, 0.22))
	_add("victory", _melody([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.1, 0.6, Wave.SQUARE, 0.22))
	var kill: PackedFloat32Array = _tone(0.07, 520.0, 300.0, Wave.SQUARE, 0.30, 0.2)
	kill.append_array(_tone(0.16, 300.0, 90.0, Wave.SQUARE, 0.30, 0.35))
	_add("kill", kill)
	_add("coin", _melody([988.0, 1319.0], 0.06, 0.16, Wave.SQUARE, 0.20))
	_add("gem", _melody([784.0, 988.0, 1175.0, 1568.0], 0.06, 0.22, Wave.SQUARE, 0.20))
	_add("heart", _melody([523.0, 784.0, 1047.0], 0.08, 0.25, Wave.TRIANGLE, 0.4))
	_add("buy", _melody([1047.0, 1319.0, 1568.0, 2093.0], 0.05, 0.25, Wave.SQUARE, 0.20))
	_add("upgrade", _melody([392.0, 523.0, 659.0, 784.0, 1047.0], 0.07, 0.35, Wave.SQUARE, 0.22))
	_add("level", _melody([523.0, 659.0, 784.0, 1047.0], 0.07, 0.22, Wave.SQUARE, 0.22))
	_add("mission", _melody([659.0, 659.0, 784.0, 1047.0, 1319.0], 0.08, 0.4, Wave.SQUARE, 0.22))
	_add("step", _tone(0.03, 140.0, 90.0, Wave.TRIANGLE, 0.10, 0.85))
	_add("dodge", _tone(0.18, 1800.0, 400.0, Wave.TRIANGLE, 0.18, 0.7))
	_add("combo", _melody([784.0, 988.0, 1319.0], 0.05, 0.18, Wave.SQUARE, 0.18))
	_add("diamond", _melody([1568.0, 2093.0, 2637.0, 3136.0, 2637.0, 3136.0], 0.05, 0.4, Wave.TRIANGLE, 0.35))
	_add("unlock", _melody([523.0, 784.0, 1047.0, 1568.0], 0.08, 0.5, Wave.SQUARE, 0.20))
	_add("slash_heavy", _tone(0.22, 2200.0, 180.0, Wave.SAW, 0.28, 0.6))
	_add("boss_hit", _tone(0.3, 220.0, 40.0, Wave.SQUARE, 0.45, 0.45))
	_add("revive", _melody([262.0, 330.0, 392.0, 523.0, 659.0, 784.0, 1047.0], 0.06, 0.4, Wave.TRIANGLE, 0.4))
	_add("gameover", _melody([392.0, 330.0, 262.0, 196.0], 0.16, 0.45, Wave.TRIANGLE, 0.45))


func _add(sound: String, samples: PackedFloat32Array) -> void:
	_streams[sound] = _to_stream(_to_bytes(samples), MIX_RATE)


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


func _to_bytes(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return bytes


## Crea un AudioStreamWAV de 16 bits mono a partir de bytes PCM.
func _to_stream(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


# ------------------------------------------------------------------ musica --

## Se ejecuta en un hilo: solo calcula bytes, sin tocar nodos ni recursos.
func _render_all_tracks() -> void:
	var result: Dictionary = {}
	for track in TRACKS:
		var def: Dictionary = TRACKS[track]
		result[track] = _render_track(def)
		# Variante nocturna: mas lenta, mas suave y sin apenas percusion.
		if bool(def.get("night", false)):
			var night: Dictionary = def.duplicate()
			night["bpm"] = float(def["bpm"]) * 0.82
			night["lead_wave"] = Wave.TRIANGLE
			night["lead_vol"] = 0.22
			night["drums"] = float(def["drums"]) * 0.35
			result[String(track) + "_night"] = _render_track(night)
	call_deferred("_on_tracks_ready", result)


func _on_tracks_ready(result: Dictionary) -> void:
	for track in result:
		var bytes: PackedByteArray = result[track]
		var stream: AudioStreamWAV = _to_stream(bytes, MUSIC_RATE)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(bytes.size() / 2.0)
		_music_streams[track] = stream
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_start_current()


## Genera un bucle de 4 compases a partir de la definicion de una cancion.
func _render_track(def: Dictionary) -> PackedByteArray:
	var bpm: float = def["bpm"]
	var chords: Array = def["chords"]
	var lead: Array = def["lead"]
	var bass: Array = def["bass"]
	var lead_len: int = def["lead_len"]
	var lead_wave: int = def["lead_wave"]
	var lead_vol: float = def["lead_vol"]
	var bass_vol: float = def["bass_vol"]
	var drums: float = def["drums"]
	var octave: int = def["octave"]
	var step_len: int = int(float(MUSIC_RATE) * 60.0 / bpm / 4.0)
	var total: int = step_len * 16 * chords.size()
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = 7

	# Lista de notas: [inicio, duracion, frecuencia, onda, volumen].
	var notes: Array = []
	for bar in chords.size():
		var chord: Array = chords[bar]
		var root: int = chord[0]
		var tones: Array = MINOR if int(chord[1]) == 1 else MAJOR
		# En el ultimo compas la melodia sube para cerrar la frase.
		var lift: int = 1 if bar == chords.size() - 1 else 0
		for step in 16:
			var start: int = (bar * 16 + step) * step_len
			var lead_index: int = lead[step]
			if lead_index >= 0:
				var tone: int = tones[mini(lead_index + lift, tones.size() - 1)]
				notes.append([start, step_len * lead_len, _midi_to_freq(root + tone + octave), lead_wave, lead_vol])
			var bass_index: int = bass[step]
			if bass_index >= 0:
				var interval: int = [0, 7, 12][bass_index]
				notes.append([start, step_len * 2, _midi_to_freq(root - 12 + interval), Wave.TRIANGLE, bass_vol])

	for item in notes:
		var note: Array = item
		var start_i: int = note[0]
		var length: int = mini(int(note[1]), total - start_i)
		var inc: float = float(note[2]) / float(MUSIC_RATE)
		var wave: int = note[3]
		var vol: float = note[4]
		var phase: float = 0.0
		var inv_len: float = 1.0 / float(maxi(length, 1))
		for i in length:
			phase += inc
			if phase >= 1.0:
				phase -= 1.0
			var s: float = 0.0
			if wave == Wave.SQUARE:
				s = 1.0 if phase < 0.5 else -1.0
			elif wave == Wave.SAW:
				s = 2.0 * phase - 1.0
			else:
				s = 4.0 * absf(phase - 0.5) - 1.0
			buf[start_i + i] += s * vol * (1.0 - float(i) * inv_len)

	# Percusion: bombo en cada tiempo y platillo a contratiempo.
	if drums > 0.0:
		var steps: int = 16 * chords.size()
		for step in steps:
			var start_d: int = step * step_len
			if step % 4 == 0:
				var kick_len: int = mini(step_len, total - start_d)
				var kick_phase: float = 0.0
				for i in kick_len:
					var t: float = float(i) / float(kick_len)
					kick_phase += lerpf(150.0, 45.0, t) / float(MUSIC_RATE)
					buf[start_d + i] += sin(kick_phase * TAU) * 0.30 * drums * (1.0 - t)
			elif step % 4 == 2:
				var hat_len: int = mini(int(float(step_len) * 0.4), total - start_d)
				for i in hat_len:
					buf[start_d + i] += noise.randf_range(-1.0, 1.0) * 0.07 * drums * (1.0 - float(i) / float(hat_len))

	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return bytes


func _midi_to_freq(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)
