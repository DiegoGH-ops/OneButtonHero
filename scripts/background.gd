extends Node2D
## Fondo con efecto parallax dibujado integramente por codigo:
## cielo en bandas, sol/luna, estrellas, nubes, dos cordilleras, castillos,
## colinas y un bosque. Cada capa se desplaza a una velocidad distinta
## segun `scroll_x`. `target_mood` cambia la hora del dia (0 = dia, 1 = noche).

const Pal = preload("res://scripts/palette.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")

const W := 1280.0
const BASELINE := 600.0
const COLUMN := 8.0

var scroll_x: float = 0.0
var mood: float = 0.0
var target_mood: float = 0.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	mood = move_toward(mood, target_mood, delta * 0.05)
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_celestial()
	_draw_clouds()
	# Cordillera lejana (nevada) y cordillera media.
	_draw_ridge(0.04, 170.0, 220.0, 0.0045, 0.0117, 0.0, _tint(Pal.SILVER.lerp(Pal.CYAN, 0.3)), 300.0)
	_draw_castles()
	_draw_ridge(0.10, 110.0, 150.0, 0.0062, 0.0171, 1.7, _tint(Pal.STEEL.lerp(Pal.SKY, 0.12)), 0.0)
	_draw_hills()
	_draw_forest()


# ------------------------------------------------------------------- cielo --

func _sky_color(t: float) -> Color:
	var a: float = minf(t * 2.0, 1.0)
	var b: float = clampf(t * 2.0 - 1.0, 0.0, 1.0)
	var day: Color = Pal.BLUE.lerp(Pal.SKY, a).lerp(Pal.CYAN, b)
	var dusk: Color = Pal.NAVY.lerp(Pal.PURPLE, a).lerp(Pal.ORANGE, b)
	var night: Color = Pal.INK.lerp(Pal.NAVY, t)
	if mood < 0.5:
		return day.lerp(dusk, mood * 2.0)
	return dusk.lerp(night, (mood - 0.5) * 2.0)


func _tint(c: Color) -> Color:
	return c.lerp(Pal.INK, mood * 0.55)


func _sprite_tint(alpha: float = 1.0) -> Color:
	var c: Color = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.32, 0.34, 0.55, 1.0), mood * 0.75)
	c.a = alpha
	return c


func _draw_sky() -> void:
	var bands: int = 15
	var band_h: float = BASELINE / float(bands)
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		draw_rect(Rect2(0.0, float(i) * band_h, W, band_h + 1.0), _sky_color(t))
	draw_rect(Rect2(0.0, BASELINE, W, 720.0 - BASELINE), _sky_color(1.0))


func _draw_disc(center: Vector2, radius: int, px: float, color: Color) -> void:
	for y in range(-radius, radius + 1):
		var half: int = int(sqrt(float(radius * radius - y * y)))
		draw_rect(Rect2(center.x - float(half) * px, center.y + float(y) * px, float(half * 2 + 1) * px, px), color)


func _draw_celestial() -> void:
	# Estrellas: aparecen al anochecer.
	var star_alpha: float = clampf((mood - 0.4) / 0.5, 0.0, 1.0)
	if star_alpha > 0.0:
		for i in 46:
			var sx: float = snappedf(PixelArt.hash01(i, 1) * W, 4.0)
			var sy: float = snappedf(PixelArt.hash01(i, 2) * 380.0, 4.0)
			var twinkle: float = 0.6 + 0.4 * sin(_time * 2.0 + float(i))
			draw_rect(Rect2(sx, sy, 4.0, 4.0), Color(Pal.WHITE, star_alpha * twinkle))
	# Sol: desciende hacia el horizonte a medida que avanza la partida.
	var sun_alpha: float = clampf(1.0 - (mood - 0.55) * 4.0, 0.0, 1.0)
	if sun_alpha > 0.0:
		var sun: Vector2 = Vector2(1040.0, 190.0 + mood * 380.0)
		_draw_disc(sun, 9, 6.0, Color(Pal.YELLOW, sun_alpha))
		_draw_disc(sun, 6, 6.0, Color(Pal.WHITE, sun_alpha * 0.6))
	# Luna.
	var moon_alpha: float = clampf((mood - 0.5) * 3.0, 0.0, 1.0)
	if moon_alpha > 0.0:
		var moon: Vector2 = Vector2(300.0, 130.0)
		_draw_disc(moon, 7, 6.0, Color(Pal.WHITE, moon_alpha))
		_draw_disc(moon + Vector2(12.0, -6.0), 2, 6.0, Color(Pal.SILVER, moon_alpha))
		_draw_disc(moon + Vector2(-12.0, 12.0), 1, 6.0, Color(Pal.SILVER, moon_alpha))


func _draw_clouds() -> void:
	var span: float = W + 400.0
	for i in 7:
		var base: float = PixelArt.hash01(i, 11) * span
		var drift: float = 6.0 + PixelArt.hash01(i, 12) * 10.0
		var x: float = fposmod(base - scroll_x * 0.03 - _time * drift, span) - 200.0
		var y: float = 40.0 + PixelArt.hash01(i, 13) * 230.0
		var cloud_px: float = 6.0 if i % 2 == 0 else 8.0
		var sprite: String = "cloud_b" if i % 3 == 0 else "cloud_a"
		PixelArt.draw(self, sprite, Vector2(roundf(x), roundf(y)), cloud_px, _sprite_tint(0.92))


# ---------------------------------------------------------------- montanas --

func _ridge_height(wx: float, base_h: float, amp: float, f1: float, f2: float, phase: float) -> float:
	var a: float = 1.0 - absf(sin(wx * f1 + phase))
	var b: float = 1.0 - absf(sin(wx * f2 + phase * 2.7))
	return snappedf(base_h + amp * (a * 0.65 + b * 0.35), 8.0)


## Dibuja una cordillera como columnas escalonadas (aspecto pixelado).
func _draw_ridge(factor: float, base_h: float, amp: float, f1: float, f2: float, phase: float, color: Color, snow_line: float) -> void:
	var scroll: float = scroll_x * factor
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	var snow: Color = _tint(Pal.WHITE)
	var shade: Color = color.darkened(0.12)
	for i in count:
		var index: int = first + i
		var wx: float = float(index) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = _ridge_height(wx, base_h, amp, f1, f2, phase)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h), color)
		# Franja sombreada para dar relieve.
		if index % 5 == 0:
			draw_rect(Rect2(sx, BASELINE - h + 16.0, COLUMN, maxf(h - 16.0, 0.0)), shade)
		if snow_line > 0.0:
			var cap: float = h - snow_line - float(posmod(index, 3)) * 8.0
			if cap > 0.0:
				draw_rect(Rect2(sx, BASELINE - h, COLUMN, cap), snow)


func _draw_castles() -> void:
	var factor: float = 0.10
	var period: float = 1900.0
	var scroll: float = scroll_x * factor
	var first: int = int(floor((scroll - 900.0) / period))
	for k in range(first, first + 3):
		var wx: float = float(k) * period + 700.0
		var sx: float = wx - scroll
		if sx < -140.0 or sx > W + 140.0:
			continue
		var h: float = _ridge_height(wx, 110.0, 150.0, 0.0062, 0.0171, 1.7)
		PixelArt.draw(self, "castle", Vector2(roundf(sx - 54.0), BASELINE - h - 60.0), 6.0, _sprite_tint())


func _hill_height(wx: float) -> float:
	return snappedf(74.0 + 46.0 * sin(wx * 0.0040) + 20.0 * sin(wx * 0.011 + 2.0), 4.0)


func _draw_hills() -> void:
	var scroll: float = scroll_x * 0.22
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	var color: Color = _tint(Pal.TEAL.lerp(Pal.GREEN, 0.45))
	var rim: Color = color.lightened(0.18)
	for i in count:
		var wx: float = float(first + i) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = _hill_height(wx)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h), color)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, 4.0), rim)


func _forest_height(wx: float) -> float:
	return snappedf(64.0 + 14.0 * sin(wx * 0.009) + 8.0 * sin(wx * 0.023 + 1.0), 4.0)


func _draw_forest() -> void:
	var scroll: float = scroll_x * 0.45
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	var color: Color = _tint(Pal.TEAL.lerp(Pal.NAVY, 0.2))
	var rim: Color = color.lightened(0.12)
	for i in count:
		var wx: float = float(first + i) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = _forest_height(wx)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h + 720.0 - BASELINE), color)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, 4.0), rim)
	# Arboles: uno por celda, con posicion, tipo y tamano estables.
	var cell: float = 120.0
	var first_cell: int = int(floor((scroll - 120.0) / cell))
	var cells: int = int(W / cell) + 4
	var tree_tint: Color = _sprite_tint().darkened(0.12)
	for n in cells:
		var c: int = first_cell + n
		if PixelArt.hash01(c, 21) < 0.28:
			continue
		var wx: float = float(c) * cell + PixelArt.hash01(c, 22) * 70.0
		var sx: float = wx - scroll
		var sprite: String = "tree_pine" if PixelArt.hash01(c, 23) < 0.6 else "tree_round"
		var tree_px: float = 5.0 if PixelArt.hash01(c, 24) < 0.5 else 6.0
		var sz: Vector2 = PixelArt.size_of(sprite, tree_px)
		var base_y: float = BASELINE - _forest_height(wx) + 10.0
		PixelArt.draw(self, sprite, Vector2(roundf(sx - sz.x * 0.5), base_y - sz.y), tree_px, tree_tint)
