extends CanvasLayer
## Aviso animado de logro conseguido. Vive dentro de GameData (autoload), asi
## aparece igual en el menu y en partida. Los logros de oro o mejor llevan
## rayos de luz; los de diamante y legendarios ocupan el centro de la
## pantalla con destello y particulas.

const Achievements = preload("res://scripts/achievements.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

var _queue: Array = []
var _current: Dictionary = {}
var _time: float = 0.0
var _duration: float = 0.0
var _canvas: Control
var _sparks: Array = []


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(1280.0, 720.0)
	add_child(_canvas)
	_canvas.draw.connect(_draw_card)
	GameData.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(entry: Dictionary) -> void:
	_queue.append(entry)


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.01)
	if _current.is_empty():
		if _queue.is_empty():
			return
		_current = _queue.pop_front()
		_time = 0.0
		var tier: int = int(_current["tier"])
		_duration = 3.2 if tier < 2 else (4.0 if tier < 4 else 5.5)
		Sfx.play("unlock", 0.9 + 0.05 * float(tier))
		if tier >= 4:
			Sfx.play("victory")
			_spawn_sparks(_big_center(), Achievements.tier_color(tier), 70)
	_time += real
	_update_sparks(real)
	if _time >= _duration:
		_current = {}
		_sparks.clear()
	_canvas.queue_redraw()


func _big_center() -> Vector2:
	return Vector2(640.0, 300.0)


func _spawn_sparks(origin: Vector2, color: Color, amount: int) -> void:
	for i in amount:
		var angle: float = randf() * TAU
		var speed: float = randf_range(140.0, 520.0)
		_sparks.append({"p": origin, "v": Vector2(cos(angle), sin(angle)) * speed, "t": 0.0, "life": randf_range(0.7, 1.6), "c": color if i % 3 else Pal.WHITE, "s": randf_range(4.0, 10.0)})


func _update_sparks(delta: float) -> void:
	var alive: Array = []
	for item in _sparks:
		var spark: Dictionary = item
		spark["t"] = float(spark["t"]) + delta
		if float(spark["t"]) < float(spark["life"]):
			var v: Vector2 = spark["v"]
			v *= 1.0 - 1.8 * delta
			v.y += 220.0 * delta
			spark["v"] = v
			spark["p"] = Vector2(spark["p"]) + v * delta
			alive.append(spark)
	_sparks = alive


func _text(text: String, center_x: float, y: float, px: float, color: Color) -> void:
	var w: float = PixelFont.text_width(text, px)
	PixelFont.draw_text_shadowed(_canvas, text, Vector2(roundf(center_x - w * 0.5), y), px, color, Pal.INK)


func _draw_card() -> void:
	if _current.is_empty():
		return
	var tier: int = int(_current["tier"])
	var color: Color = Achievements.tier_color(tier)
	var appear: float = clampf(_time / 0.35, 0.0, 1.0)
	var vanish: float = clampf((_duration - _time) / 0.4, 0.0, 1.0)
	var alpha: float = minf(appear, vanish)
	var big: bool = tier >= 4
	var size: Vector2 = Vector2(640.0, 190.0) if big else Vector2(470.0, 118.0)
	var center: Vector2 = _big_center() if big else Vector2(1280.0 - size.x * 0.5 - 20.0, 92.0 + (1.0 - appear) * -140.0)
	if big:
		# Destello y velo de pantalla completa.
		var flash: float = 1.0 - clampf(_time / 0.5, 0.0, 1.0)
		_canvas.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(Pal.INK, 0.55 * alpha))
		_canvas.draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(color, 0.35 * flash))
	if tier >= 2:
		# Rayos giratorios detras de la tarjeta.
		var rays: int = 12 if big else 8
		var length: float = 420.0 if big else 190.0
		for i in rays:
			var angle: float = _time * 0.8 + float(i) * TAU / float(rays)
			var a: Vector2 = center + Vector2(cos(angle), sin(angle)) * length
			var b: Vector2 = center + Vector2(cos(angle + 0.12), sin(angle + 0.12)) * length
			_canvas.draw_colored_polygon(PackedVector2Array([center, a, b]), Color(color, 0.18 * alpha))
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	_canvas.draw_rect(rect, Color(Pal.INK, 0.95 * alpha))
	_canvas.draw_rect(rect, Color(color, alpha), false, 4.0)
	var medal_radius: float = 54.0 if big else 34.0
	var medal_at: Vector2 = rect.position + Vector2(medal_radius + 24.0, size.y * 0.5)
	var pulse: float = 1.0 + 0.06 * sin(_time * 8.0)
	_canvas.modulate.a = alpha
	Achievements.draw_medal(_canvas, medal_at, medal_radius * pulse, tier, Achievements.icon_for(_current), false)
	var text_x: float = rect.position.x + medal_radius * 2.0 + 48.0
	var text_center: float = text_x + (rect.end.x - text_x - 16.0) * 0.5
	var header: String = "¡LOGRO LEGENDARIO!" if tier >= 5 else "LOGRO DESBLOQUEADO"
	_text(header, text_center, rect.position.y + (20.0 if big else 12.0), 3.0 if big else 2.0, color)
	_text(Achievements.title(_current), text_center, rect.position.y + (60.0 if big else 36.0), 5.0 if big else 3.0, Pal.WHITE)
	_text(Loc.s(Achievements.tier_name(tier)) + " - " + Loc.s(String(_current["cat"])), text_center, rect.position.y + (110.0 if big else 70.0), 2.0, color)
	_text(Loc.s("+%d MONEDAS  +%d DIAMANTES") % [int(_current["coins"]), int(_current["gems"])], text_center, rect.position.y + (140.0 if big else 92.0), 2.0, Pal.YELLOW)
	for item in _sparks:
		var spark: Dictionary = item
		var k: float = 1.0 - float(spark["t"]) / float(spark["life"])
		var s: float = float(spark["s"]) * k
		_canvas.draw_rect(Rect2(Vector2(spark["p"]) - Vector2(s, s) * 0.5, Vector2(s, s)), Color(Color(spark["c"]), k))
