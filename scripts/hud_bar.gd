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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
