extends Node2D
## RAPID SIX - SOBREVIVE O MUERE.
## Portal de piedra con seis runas. Al llegar a el, el heroe se detiene
## (player.gd) y empieza una cuenta atras en TIEMPO REAL: hay que hacer seis
## pulsaciones independientes (cada una con su liberacion: mantener pulsado
## no cuenta) antes de que termine. Cada pulsacion enciende una runa, sacude
## el portal y suena; a la sexta el portal estalla y el heroe sigue. Si se
## acaba el tiempo, el portal se desploma sobre el heroe.
##
## Variantes (se introducen poco a poco, ver level_generator.gd):
##   NORMAL         seis pulsaciones.
##   PRESSURE       el bruto del mundo alza el garrote sobre el heroe y baja
##                  con la cuenta atras (amenaza visible).
##   COMBO          detras del portal hay pinchos: tras romperlo hay que
##                  saltar enseguida (los coloca el generador).
##   EXTREME        ventana muy corta.
##   DOUBLE         dos portales seguidos (los coloca el generador).
##   SURVIVAL       tras la tercera runa el portal lanza una onda a ras de
##                  suelo: la siguiente pulsacion es un SALTO; despues, tres
##                  pulsaciones mas.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Fx = preload("res://scripts/fx.gd")

enum Variant { NORMAL, PRESSURE, COMBO, EXTREME, DOUBLE, SURVIVAL }
const NAMES := ["RAPID SIX", "RAPID SIX: BAJO PRESION", "RAPID SIX: COMBO", "RAPID SIX: EXTREMO", "RAPID SIX: DOBLE", "RAPID SIX: SUPERVIVENCIA"]
const HEIGHT := 260.0
## Distancia a la que el portal empieza a temblar (aviso).
const WARN_DISTANCE := 700.0

enum State { IDLE, ACTIVE, WAVE, DONE, FAILED }

## Ventana de tiempo (segundos reales) para las seis pulsaciones.
var window: float = 2.5
## Pulsaciones necesarias (6; los jefes piden mas en sus fases finales) y
## nombre que se muestra (los jefes usan el suyo: ENREDADERA, CADENAS...).
var taps_needed: int = 6
var title: String = ""
## Lo lanza un jefe: el exito le aturde y le hace dano.
var from_boss: bool = false
var variant: int = Variant.NORMAL
## Sprite y colores del bruto del mundo (variante PRESSURE).
var threat_sprite: String = "brute"
var threat_remap: Dictionary = {}
var threat_key: String = ""

var state: int = State.IDLE
var taps: int = 0
var time_left: float = 0.0
var _time: float = 0.0
var _shake: float = 0.0
var _flash: float = 0.0
var _wave_x: float = 0.0
var _wave_time: float = 0.0
var _player: Node2D
var _debris: Array = []


func _ready() -> void:
	add_to_group("rapid_six")
	add_to_group("glow")


## Datos para lights.gd.
var glow_radius: float = 80.0
var glow_color: Color = Pal.PURPLE
var glow_day: float = 0.3


func _process(delta: float) -> void:
	# Tiempo real: la ventana no depende de la velocidad del juego (1.5X/3X).
	var real: float = delta / maxf(Engine.time_scale, 0.05)
	_time += real
	_shake = maxf(_shake - real * 6.0, 0.0)
	_flash = maxf(_flash - real * 4.0, 0.0)
	modulate = Daylight.unlit().lerp(Color(1.0, 1.0, 1.0), 0.6)
	match state:
		State.ACTIVE:
			time_left -= real
			glow_color = Pal.RED.lerp(Pal.YELLOW, float(taps) / float(taps_needed))
			if time_left <= 0.0:
				_fail()
		State.WAVE:
			time_left -= real
			_wave_time += real
			_wave_x = -40.0 - _wave_time * 520.0
			_check_wave()
			if _wave_x < -260.0:
				state = State.ACTIVE
			elif time_left <= 0.0:
				_fail()
		State.DONE, State.FAILED:
			for item in _debris:
				var piece: Dictionary = item
				piece["v"] = Vector2(piece["v"]) + Vector2(0.0, 1400.0) * real
				piece["p"] = Vector2(piece["p"]) + Vector2(piece["v"]) * real
			if _time > 2.0:
				queue_free()
	queue_redraw()


## El heroe ha llegado: empieza la cuenta atras.
func engage(player: Node2D) -> void:
	if state != State.IDLE:
		return
	_player = player
	state = State.ACTIVE
	time_left = window
	taps = 0
	_time = 0.0
	_flash = 0.5
	Sfx.play("error", 0.6)
	Daylight.rapid_events.append({"event": "start", "variant": variant})


## Pulsacion del heroe. Devuelve true si el portal la ha usado.
func tap() -> bool:
	if state == State.WAVE:
		# Durante la onda la pulsacion es un salto (lo hace player.gd).
		return false
	if state != State.ACTIVE:
		return false
	taps += 1
	_shake = 1.0
	_flash = 0.6
	Sfx.play("hit", 0.8 + 0.12 * float(taps))
	var parent: Node = get_parent()
	if parent != null:
		Fx.burst(parent, position + Vector2(10.0, -HEIGHT * 0.5), Pal.YELLOW, 6 + taps * 2, 260.0, 0.3, 5.0, 600.0, 90.0, Vector2.LEFT)
	if variant == Variant.SURVIVAL and taps == 3:
		state = State.WAVE
		_wave_time = 0.0
		_wave_x = -40.0
		time_left += 0.9
		Sfx.play("boss_hit", 0.7)
	elif taps >= taps_needed:
		_break()
	return true


## La onda de la variante SUPERVIVENCIA: si alcanza al heroe en el suelo,
## le golpea.
func _check_wave() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var hero_dx: float = _player.global_position.x - global_position.x
	var feet: float = Daylight.GROUND_Y - _player.global_position.y
	if absf(hero_dx - _wave_x) < 22.0 and feet < 26.0:
		_fail()


func _break() -> void:
	Daylight.rapid_events.append({"event": "success", "variant": variant, "left": time_left, "window": window, "boss": from_boss})
	Sfx.play("boss_hit", 1.2)
	Sfx.play("unlock")
	_shatter(true)
	if _player != null and is_instance_valid(_player):
		_player.call("release_rapid")


func _fail() -> void:
	Daylight.rapid_events.append({"event": "fail", "variant": variant, "boss": from_boss})
	Sfx.play("boss_hit", 0.5)
	if _player != null and is_instance_valid(_player):
		_player.call("rapid_hit")
	_shatter(false)


## Rompe el portal en pedazos (exito) o lo desploma (fallo). En ambos casos
## el camino queda libre: si el heroe sobrevive (Pluma de Fenix o prueba
## invencible), sigue corriendo.
func _shatter(success: bool) -> void:
	state = State.DONE if success else State.FAILED
	remove_from_group("rapid_six")
	_time = 0.0
	_debris = []
	for i in 18:
		var p: Vector2 = Vector2(randf_range(-8.0, 40.0), -randf_range(0.0, HEIGHT))
		var v: Vector2 = Vector2(randf_range(120.0, 520.0) * (1.0 if success else -0.4), randf_range(-620.0, -120.0))
		_debris.append({"p": p, "v": v, "s": randf_range(8.0, 18.0)})
	var parent: Node = get_parent()
	if parent != null:
		var color: Color = Pal.YELLOW if success else Pal.RED
		Fx.burst(parent, position + Vector2(16.0, -HEIGHT * 0.5), color, 34, 520.0, 0.8, 9.0, 700.0, 180.0, Vector2.UP)
		Fx.ring(parent, position + Vector2(16.0, -HEIGHT * 0.5), color, 160.0)
	if _player != null and is_instance_valid(_player) and not success:
		_player.call("release_rapid")


func _draw() -> void:
	if state == State.DONE or state == State.FAILED:
		for item in _debris:
			var piece: Dictionary = item
			var s: float = float(piece["s"])
			draw_rect(Rect2(Vector2(piece["p"]) - Vector2(s, s) * 0.5, Vector2(s, s)), Pal.STEEL)
		return
	var hero_x: float = Daylight.player_pos.x
	var near: bool = global_position.x - hero_x < WARN_DISTANCE
	var shake: float = 0.0
	if state == State.ACTIVE or state == State.WAVE:
		shake = sin(_time * 70.0) * 4.0 * maxf(_shake, 0.3)
	elif near:
		shake = sin(_time * 50.0) * 1.5
	# Portal: dos pilares, dintel y losa central con seis runas.
	var x0: float = shake
	draw_rect(Rect2(x0 - 6.0, -HEIGHT, 44.0, HEIGHT), Pal.INK)
	draw_rect(Rect2(x0 - 2.0, -HEIGHT + 4.0, 36.0, HEIGHT - 4.0), Pal.SLATE)
	for r in 8:
		draw_rect(Rect2(x0 - 2.0, -float(r + 1) * 32.0, 36.0, 3.0), Pal.STEEL)
	draw_rect(Rect2(x0 - 12.0, -HEIGHT - 16.0, 56.0, 18.0), Pal.STEEL)
	# Grietas que crecen con cada pulsacion.
	for k in taps:
		var cy: float = -HEIGHT + 30.0 + float(k) * 38.0
		draw_line(Vector2(x0 + 4.0, cy), Vector2(x0 + 28.0, cy + 18.0), Pal.WHITE, 2.0)
	# Runas: se encienden con cada pulsacion.
	var rune_step: float = (HEIGHT - 40.0) / float(taps_needed)
	for i in taps_needed:
		var lit: bool = i < taps
		var ry: float = -HEIGHT + 24.0 + float(i) * rune_step
		var c: Color = Pal.PURPLE
		if lit:
			c = Pal.YELLOW
		elif state == State.ACTIVE:
			c = Pal.PURPLE.lerp(Pal.RED, 0.5 + 0.5 * sin(_time * 8.0))
		draw_rect(Rect2(x0 + 8.0, ry, 16.0, 16.0), Pal.INK)
		draw_rect(Rect2(x0 + 10.0, ry + 2.0, 12.0, 12.0), c)
		if lit:
			PixelArt.draw_glow(self, Vector2(x0 + 16.0, ry + 8.0), 22.0, Color(Pal.YELLOW, 0.7))
	if _flash > 0.0:
		draw_rect(Rect2(x0 - 6.0, -HEIGHT, 44.0, HEIGHT), Color(1.0, 1.0, 1.0, _flash * 0.5))
	if not near and state == State.IDLE:
		return
	# Contador de seis puntos y barra de tiempo sobre el portal.
	var caption: String = title if title != "" else String(NAMES[variant])
	PixelFont.draw_text_shadowed(self, caption, Vector2(16.0 - PixelFont.text_width(caption, 2.0) * 0.5, -HEIGHT - 76.0), 2.0, Pal.ORANGE, Pal.INK, true)
	for i in taps_needed:
		var lit2: bool = i < taps
		var dot: Rect2 = Rect2(16.0 - float(taps_needed) * 22.0 * 0.5 + float(i) * 22.0, -HEIGHT - 50.0, 16.0, 16.0)
		draw_rect(dot, Pal.INK)
		draw_rect(dot.grow(-3.0), Pal.YELLOW if lit2 else Pal.SLATE)
	if state == State.ACTIVE or state == State.WAVE:
		var ratio: float = clampf(time_left / window, 0.0, 1.0)
		draw_rect(Rect2(-50.0, -HEIGHT - 26.0, 132.0, 8.0), Pal.INK)
		draw_rect(Rect2(-48.0, -HEIGHT - 24.0, 128.0 * ratio, 4.0), Pal.LIME.lerp(Pal.RED, 1.0 - ratio))
		var msg: String = "¡SALTA LA ONDA!" if state == State.WAVE else "¡PULSA x%d!" % (taps_needed - taps)
		PixelFont.draw_text_shadowed(self, msg, Vector2(-60.0 - PixelFont.text_width(msg, 3.0), -150.0), 3.0, Pal.YELLOW if int(_time * 10.0) % 2 == 0 else Pal.WHITE, Pal.INK, true)
	elif state == State.IDLE:
		var need_text: String = "%d PULSACIONES" % taps_needed
		PixelFont.draw_text_shadowed(self, need_text, Vector2(16.0 - PixelFont.text_width(need_text, 2.0) * 0.5, -HEIGHT - 100.0), 2.0, Pal.WHITE, Pal.INK, true)
	# Onda de la variante SUPERVIVENCIA.
	if state == State.WAVE:
		for k in 3:
			draw_rect(Rect2(_wave_x - 20.0 + float(k) * 10.0, -8.0 - float(k) * 7.0, 44.0 - float(k) * 12.0, 8.0), Color(Pal.PURPLE.lerp(Pal.WHITE, float(k) * 0.3), 0.9))
	# Variante BAJO PRESION: el bruto del mundo alza el garrote sobre el
	# heroe y lo baja con la cuenta atras.
	if variant == Variant.PRESSURE and (state == State.ACTIVE or near):
		var progress: float = 0.0 if state != State.ACTIVE else 1.0 - clampf(time_left / window, 0.0, 1.0)
		var bx: float = 140.0
		PixelArt.draw_skin(self, threat_sprite, Vector2(bx - 42.0, -78.0), 6.0, Color(1.0, 1.0, 1.0, 1.0), threat_remap, threat_key)
		var club_y: float = lerpf(-200.0, -90.0, progress)
		var club_x: float = lerpf(bx, -60.0, progress)
		draw_rect(Rect2(club_x - 6.0, club_y, 12.0, 60.0), Pal.BROWN)
		draw_rect(Rect2(club_x - 14.0, club_y - 10.0, 28.0, 20.0), Pal.DARK_BROWN)
