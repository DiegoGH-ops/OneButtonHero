extends Node2D
## Dibuja el suelo visible (hierba, tierra, decoracion y abismos).
## Solo pinta las baldosas que caben en pantalla, asi que el mundo puede
## ser infinito sin gastar memoria. Las colisiones del suelo las crea
## level_generator.gd con nodos StaticBody2D (ground_span.gd).

const Pal = preload("res://scripts/palette.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Daylight = preload("res://scripts/daylight.gd")

const TILE := 32.0
const GROUND_Y := 560.0
const DEPTH := 160.0
const DECOR := ["tuft", "flower_a", "tuft", "flower_b", "tuft", "mushroom", "flower_a"]

## Coordenada X del mundo que coincide con el borde izquierdo de la pantalla.
var view_left: float = 0.0
## Lista de huecos como Vector2(inicio, fin). Es la misma lista del generador.
var holes: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _in_hole(x: float) -> bool:
	for item in holes:
		var hole: Vector2 = item
		if x > hole.x and x < hole.y:
			return true
	return false


func _draw() -> void:
	var first: int = int(floor(view_left / TILE)) - 1
	var count: int = int(1280.0 / TILE) + 3
	# Cada mundo recolorea el suelo (lava, cristal, nieve, arena...).
	var remap: Dictionary = Daylight.theme.get("ground", {})
	var remap_key: String = String(Daylight.theme.get("ground_key", ""))
	var decor_on: bool = bool(Daylight.theme.get("decor", true))
	for n in count:
		var i: int = first + n
		var x: float = float(i) * TILE
		if _in_hole(x + TILE * 0.5):
			# Abismo: se oscurece el fondo que asoma por el hueco.
			draw_rect(Rect2(x, GROUND_Y + 8.0, TILE, DEPTH - 8.0), Color(Pal.INK, 0.5))
			if bool(Daylight.theme.get("lava", false)):
				# Lago de lava al fondo del abismo.
				var wave: float = sin(float(i) * 1.3 + float(Time.get_ticks_msec()) * 0.004) * 4.0
				draw_rect(Rect2(x, GROUND_Y + 96.0 + wave, TILE, DEPTH), Pal.RED)
				draw_rect(Rect2(x, GROUND_Y + 96.0 + wave, TILE, 6.0), Pal.ORANGE)
				continue
			draw_rect(Rect2(x, GROUND_Y + 56.0, TILE, DEPTH - 56.0), Color(Pal.INK, 0.6))
			continue

		var top: String = "ground_top_a" if PixelArt.hash01(i, 1) < 0.5 else "ground_top_b"
		PixelArt.draw_skin(self, top, Vector2(x, GROUND_Y - 4.0), 4.0, Color(1.0, 1.0, 1.0, 1.0), remap, remap_key)
		for row in 4:
			var r: float = PixelArt.hash01(i, 10 + row)
			var sprite: String = "dirt_a"
			if r > 0.9:
				sprite = "dirt_c"
			elif r > 0.5:
				sprite = "dirt_b"
			var shade: float = 1.0 - 0.13 * float(row + 1)
			PixelArt.draw_skin(self, sprite, Vector2(x, GROUND_Y + 32.0 + float(row) * TILE), 4.0, Color(shade, shade, shade, 1.0), remap, remap_key)

		# Hielo: brillo azulado sobre la superficie.
		if Daylight.is_ice(x + TILE * 0.5):
			draw_rect(Rect2(x, GROUND_Y - 4.0, TILE, 12.0), Color(Pal.CYAN, 0.75))
			draw_rect(Rect2(x + 4.0 + float(posmod(i, 3)) * 8.0, GROUND_Y - 2.0, 8.0, 4.0), Pal.WHITE)
		# Infernus: las grietas brillan como lava.
		if bool(Daylight.theme.get("lava", false)) and PixelArt.hash01(i, 9) < 0.3:
			draw_rect(Rect2(x + 8.0, GROUND_Y + 40.0, 12.0, 4.0), Pal.ORANGE)
		var hole_left: bool = _in_hole(x - TILE * 0.5)
		var hole_right: bool = _in_hole(x + TILE * 1.5)
		if hole_left:
			draw_rect(Rect2(x, GROUND_Y, 4.0, DEPTH), Pal.INK)
		if hole_right:
			draw_rect(Rect2(x + TILE - 4.0, GROUND_Y, 4.0, DEPTH), Pal.INK)

		# Decoracion estable (hierba, flores, setas) lejos de los bordes.
		if decor_on and not hole_left and not hole_right and PixelArt.hash01(i, 5) < 0.24:
			var pick: int = int(PixelArt.hash01(i, 6) * float(DECOR.size())) % DECOR.size()
			var decor: String = DECOR[pick]
			var sz: Vector2 = PixelArt.size_of(decor, 4.0)
			PixelArt.draw(self, decor, Vector2(x + 4.0, GROUND_Y - sz.y + 4.0), 4.0)
