extends Control
## Marcadores de la partida: vidas, escudo, monedas, hora del dia, efectos
## activos, puntuacion, multiplicador, record y velocidad.
## Se redibuja solo cuando cambia algun valor.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

const SPEED_PIPS := 10

var score: int = 0:
	set(value):
		if score != value:
			score = value
			queue_redraw()

var high_score: int = 0:
	set(value):
		if high_score != value:
			high_score = value
			queue_redraw()

var coins: int = 0:
	set(value):
		if coins != value:
			coins = value
			queue_redraw()

var lives: int = 3:
	set(value):
		if lives != value:
			lives = value
			queue_redraw()

var max_lives: int = 3

var level: int = 1:
	set(value):
		if level != value:
			level = value
			queue_redraw()

var speed_pips: int = 1:
	set(value):
		if speed_pips != value:
			speed_pips = value
			queue_redraw()

var speed_value: int = 0:
	set(value):
		if speed_value != value:
			speed_value = value
			queue_redraw()

var shield: bool = false:
	set(value):
		if shield != value:
			shield = value
			queue_redraw()

## Nombre de la fase del dia ("MAÑANA", "NOCHE"...).
var phase_name: String = "":
	set(value):
		if phase_name != value:
			phase_name = value
			queue_redraw()

var night: bool = false:
	set(value):
		if night != value:
			night = value
			queue_redraw()

## Texto del multiplicador de puntos ("" si no hay).
var multiplier_text: String = "":
	set(value):
		if multiplier_text != value:
			multiplier_text = value
			queue_redraw()

## Efectos activos, separados por saltos de linea.
var effects_text: String = "":
	set(value):
		if effects_text != value:
			effects_text = value
			queue_redraw()


## Combo de precision: acciones perfectas seguidas y su multiplicador.
var combo_count: int = 0:
	set(value):
		if combo_count != value:
			combo_count = value
			queue_redraw()

var combo_mult: float = 1.0:
	set(value):
		if not is_equal_approx(combo_mult, value):
			combo_mult = value
			queue_redraw()

## Progreso del nivel de campana (0..1; negativo = oculto).
var progress: float = -1.0:
	set(value):
		if absf(progress - value) > 0.002:
			progress = value
			queue_redraw()

## Jefe: nombre y vida restante (0..1; negativo = sin jefe).
var boss_name: String = ""
var boss_ratio: float = -1.0:
	set(value):
		if absf(boss_ratio - value) > 0.001:
			boss_ratio = value
			queue_redraw()

var level_name: String = "":
	set(value):
		level_name = value
		queue_redraw()

var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	# Con multiplicadores altos el indicador de combo vibra de energia.
	if combo_mult >= 2.0:
		queue_redraw()


func _disc(center: Vector2, radius: int, color: Color) -> void:
	for y in range(-radius, radius + 1):
		var half: int = int(sqrt(float(radius * radius - y * y)))
		draw_rect(Rect2(center.x - float(half) * 4.0, center.y + float(y) * 4.0, float(half * 2 + 1) * 4.0, 4.0), color)


func _draw() -> void:
	# --- Vidas y escudo ---
	for i in max_lives:
		var sprite: String = "heart" if i < lives else "heart_empty"
		PixelArt.draw(self, sprite, Vector2(24.0 + float(i) * 44.0, 20.0), 4.0)
	if shield:
		PixelArt.draw(self, "icon_shield", Vector2(28.0 + float(max_lives) * 44.0, 20.0), 3.0)

	# --- Monedas ---
	PixelArt.draw(self, "coin_0", Vector2(24.0, 66.0), 3.0)
	PixelFont.draw_text_shadowed(self, "x%d" % coins, Vector2(56.0, 68.0), 3.0, Pal.YELLOW, Pal.INK, true)

	# --- Hora del dia ---
	var disc_center: Vector2 = Vector2(36.0, 118.0)
	if night:
		_disc(disc_center, 2, Pal.INK)
		_disc(disc_center, 2, Pal.WHITE)
		draw_rect(Rect2(disc_center.x + 2.0, disc_center.y - 10.0, 8.0, 12.0), Pal.NAVY)
	else:
		_disc(disc_center, 2, Pal.YELLOW)
	PixelFont.draw_text_shadowed(self, phase_name, Vector2(56.0, 112.0), 2.0, Pal.CYAN if night else Pal.WHITE, Pal.INK, true)

	# --- Efectos activos ---
	var lines: PackedStringArray = effects_text.split("\n", false)
	for i in lines.size():
		PixelFont.draw_text_shadowed(self, lines[i], Vector2(24.0, 144.0 + float(i) * 22.0), 2.0, Pal.LIME, Pal.INK, true)

	# --- Puntuacion, multiplicador y record ---
	var score_text: String = str(score)
	var score_w: float = PixelFont.text_width(score_text, 6.0)
	PixelFont.draw_text_shadowed(self, score_text, Vector2(roundf(640.0 - score_w * 0.5), 14.0), 6.0, Pal.WHITE, Pal.INK, true)
	var best: int = maxi(high_score, score)
	var record_text: String = "RÉCORD %d" % best
	var record_w: float = PixelFont.text_width(record_text, 2.0)
	var record_color: Color = Pal.YELLOW if score > high_score and high_score > 0 else Pal.SILVER
	PixelFont.draw_text_shadowed(self, record_text, Vector2(roundf(640.0 - record_w * 0.5), 72.0), 2.0, record_color, Pal.INK, true)
	if multiplier_text != "":
		var mult_w: float = PixelFont.text_width(multiplier_text, 3.0)
		PixelFont.draw_text_shadowed(self, multiplier_text, Vector2(roundf(640.0 - mult_w * 0.5), 98.0), 3.0, Pal.ORANGE, Pal.INK, true)

	# --- Combo de precision (muy visible; cambia con el multiplicador) ---
	if combo_count > 0:
		var combo_text: String = "COMBO %d" % combo_count
		if combo_mult > 1.0:
			combo_text += "  X%.1f" % combo_mult
		var combo_px: float = 3.0
		var combo_color: Color = Pal.WHITE
		var jitter: Vector2 = Vector2.ZERO
		if combo_mult >= 4.0:
			combo_px = 5.0
			combo_color = Pal.RED if int(_time * 10.0) % 2 == 0 else Pal.ORANGE
			jitter = Vector2(sin(_time * 40.0) * 3.0, cos(_time * 33.0) * 2.0)
		elif combo_mult >= 2.0:
			combo_px = 4.0
			combo_color = Pal.YELLOW if int(_time * 6.0) % 2 == 0 else Pal.ORANGE
			jitter = Vector2(0.0, sin(_time * 12.0) * 2.0)
		elif combo_mult > 1.0:
			combo_px = 4.0
			combo_color = Pal.LIME
		var combo_w: float = PixelFont.text_width(combo_text, combo_px)
		PixelFont.draw_text_shadowed(self, combo_text, Vector2(roundf(640.0 - combo_w * 0.5), 128.0) + jitter, combo_px, combo_color, Pal.INK, true)

	# --- Progreso del nivel ---
	if progress >= 0.0:
		draw_rect(Rect2(436.0, 700.0, 408.0, 14.0), Pal.INK)
		draw_rect(Rect2(440.0, 704.0, 400.0, 6.0), Pal.SLATE)
		draw_rect(Rect2(440.0, 704.0, 400.0 * clampf(progress, 0.0, 1.0), 6.0), Pal.LIME)
		draw_rect(Rect2(436.0 + 400.0 * clampf(progress, 0.0, 1.0), 698.0, 8.0, 18.0), Pal.YELLOW)
		PixelFont.draw_text_shadowed(self, level_name, Vector2(424.0 - PixelFont.text_width(level_name, 2.0), 700.0), 2.0, Pal.WHITE, Pal.INK, true)
		PixelFont.draw_text_shadowed(self, "META", Vector2(856.0, 700.0), 2.0, Pal.YELLOW, Pal.INK, true)

	# --- Barra de vida del jefe ---
	if boss_ratio >= 0.0:
		var name_w: float = PixelFont.text_width(boss_name, 3.0)
		PixelFont.draw_text_shadowed(self, boss_name, Vector2(roundf(700.0 - name_w * 0.5), 652.0), 3.0, Pal.RED, Pal.INK, true)
		draw_rect(Rect2(396.0, 684.0, 608.0, 24.0), Pal.INK)
		draw_rect(Rect2(400.0, 688.0, 600.0, 16.0), Pal.SLATE)
		draw_rect(Rect2(400.0, 688.0, 600.0 * clampf(boss_ratio, 0.0, 1.0), 16.0), Pal.RED)
		draw_rect(Rect2(400.0, 688.0, 600.0 * clampf(boss_ratio, 0.0, 1.0), 4.0), Pal.ORANGE)
		for mark in [0.33, 0.66]:
			var m: float = mark
			draw_rect(Rect2(400.0 + 600.0 * m - 2.0, 684.0, 4.0, 24.0), Pal.INK)

	# --- Velocidad ---
	var right: float = 1176.0
	var title: String = "VELOCIDAD"
	PixelFont.draw_text_shadowed(self, title, Vector2(right - PixelFont.text_width(title, 2.0), 20.0), 2.0, Pal.WHITE, Pal.INK, true)
	var pip_w: float = 12.0
	var pip_gap: float = 4.0
	var bar_w: float = float(SPEED_PIPS) * (pip_w + pip_gap) - pip_gap
	var bar_x: float = right - bar_w
	draw_rect(Rect2(bar_x - 4.0, 40.0, bar_w + 8.0, 20.0), Pal.INK)
	for i in SPEED_PIPS:
		var color: Color = Pal.SLATE
		if i < speed_pips:
			if i < 4:
				color = Pal.LIME
			elif i < 7:
				color = Pal.YELLOW
			else:
				color = Pal.RED
		draw_rect(Rect2(bar_x + float(i) * (pip_w + pip_gap), 44.0, pip_w, 12.0), color)
	var info: String = "NIVEL %d - %d M/S" % [level, speed_value]
	PixelFont.draw_text_shadowed(self, info, Vector2(right - PixelFont.text_width(info, 2.0), 68.0), 2.0, Pal.YELLOW, Pal.INK, true)
