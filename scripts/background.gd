extends Node2D
## Fondo parallax dibujado por codigo y sincronizado con el ciclo de dia y
## noche (daylight.gd): cielo, sol, luna, estrellas, nubes, dos cordilleras,
## castillos con ventanas iluminadas, colinas, ruinas medievales, bosque y
## particulas ambientales (polen de dia, hojas al atardecer).

const Pal = preload("res://scripts/palette.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Daylight = preload("res://scripts/daylight.gd")

const W := 1280.0
const BASELINE := 600.0
const COLUMN := 8.0
const RUINS := ["ruin_arch", "ruin_column", "ruin_wall", "ruin_column"]

var scroll_x: float = 0.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_celestial()
	_draw_clouds()
	_draw_ridge(0.04, 170.0, 220.0, 0.0045, 0.0117, 0.0, _tint(Daylight.theme_color("far", Pal.SILVER.lerp(Pal.CYAN, 0.3))), 300.0)
	_draw_castles()
	_draw_ridge(0.10, 110.0, 150.0, 0.0062, 0.0171, 1.7, _tint(Daylight.theme_color("mid", Pal.STEEL.lerp(Pal.SKY, 0.12))), 0.0)
	_draw_hills()
	_draw_ruins()
	_draw_forest()
	_draw_particles()


# ------------------------------------------------------------------- cielo --

## Color del cielo a una altura t (0 arriba, 1 horizonte) segun la hora.
func _sky_color(t: float) -> Color:
	var a: float = minf(t * 2.0, 1.0)
	var b: float = clampf(t * 2.0 - 1.0, 0.0, 1.0)
	var sky: Array = Daylight.theme.get("sky", ["3b5dc9", "41a6f6", "73eff7"])
	var day: Color = Color(String(sky[0])).lerp(Color(String(sky[1])), a).lerp(Color(String(sky[2])), b)
	var warm: Color
	if fposmod(Daylight.time, 1.0) < 0.3:
		warm = Pal.BLUE.lerp(Pal.PINK, a).lerp(Pal.YELLOW, b)
	else:
		warm = Pal.NAVY.lerp(Pal.PURPLE, a * 0.8).lerp(Pal.RED, a * 0.5).lerp(Pal.ORANGE, b)
	var night: Color = Color(0.04, 0.05, 0.11).lerp(Pal.NAVY, t * 0.8)
	return day.lerp(warm, Daylight.warmth()).lerp(night, Daylight.darkness())


## Tine un color plano segun la luz ambiental.
func _tint(c: Color) -> Color:
	var amb: Color = Daylight.ambient()
	return Color(c.r * amb.r, c.g * amb.g, c.b * amb.b, c.a).lerp(Pal.INK, Daylight.darkness() * 0.25)


func _sprite_tint(alpha: float = 1.0) -> Color:
	var c: Color = Daylight.ambient().lerp(Color(0.2, 0.22, 0.4), Daylight.darkness() * 0.3)
	c.a = alpha
	return c


func _draw_sky() -> void:
	var bands: int = 18
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
	var dark: float = Daylight.darkness()
	# Estrellas animadas (titilan y aparecen poco a poco).
	if dark > 0.02:
		for i in 60:
			var sx: float = snappedf(PixelArt.hash01(i, 1) * W, 4.0)
			var sy: float = snappedf(PixelArt.hash01(i, 2) * 400.0, 4.0)
			var twinkle: float = 0.55 + 0.45 * sin(_time * (1.5 + PixelArt.hash01(i, 3) * 2.5) + float(i))
			var size: float = 4.0 if i % 7 != 0 else 8.0
			draw_rect(Rect2(sx, sy, size, size), Color(Pal.WHITE, dark * twinkle))
		# Estrella fugaz ocasional.
		var cycle: float = fposmod(_time, 9.0)
		if cycle < 0.7:
			var p: Vector2 = Vector2(300.0 + cycle * 700.0, 60.0 + cycle * 220.0)
			for k in 5:
				draw_rect(Rect2(p.x - float(k) * 12.0, p.y - float(k) * 4.0, 8.0, 4.0), Color(Pal.WHITE, dark * (1.0 - float(k) * 0.2)))
	# Sol con resplandor; se vuelve naranja cerca del horizonte.
	if Daylight.sun_visible():
		var sun: Vector2 = Daylight.sun_position()
		var sun_color: Color = Pal.YELLOW.lerp(Pal.ORANGE, Daylight.warmth())
		PixelArt.draw_glow(self, sun, 190.0, Color(sun_color, 0.35))
		_draw_disc(sun, 9, 6.0, sun_color)
		_draw_disc(sun, 6, 6.0, Color(Pal.WHITE, 0.6))
	# Luna creciente.
	var moon_alpha: float = clampf((fposmod(Daylight.time, 1.0) - 0.62) * 8.0, 0.0, 1.0) * dark
	if moon_alpha > 0.02:
		var moon: Vector2 = Daylight.moon_position()
		PixelArt.draw_glow(self, moon, 150.0, Color(Pal.SILVER, 0.25 * moon_alpha))
		_draw_disc(moon, 7, 6.0, Color(Pal.WHITE, moon_alpha))
		_draw_disc(moon + Vector2(18.0, -12.0), 5, 6.0, Color(_sky_color(0.3), moon_alpha))


func _draw_clouds() -> void:
	var span: float = W + 400.0
	var tint: Color = _sprite_tint(0.92).lerp(Color(Pal.PINK, 0.92), Daylight.warmth() * 0.5)
	for i in 8:
		var base: float = PixelArt.hash01(i, 11) * span
		var drift: float = 6.0 + PixelArt.hash01(i, 12) * 10.0
		var x: float = fposmod(base - scroll_x * 0.03 - _time * drift, span) - 200.0
		var y: float = 40.0 + PixelArt.hash01(i, 13) * 230.0
		var cloud_px: float = 6.0 if i % 2 == 0 else 8.0
		var sprite: String = "cloud_b" if i % 3 == 0 else "cloud_a"
		PixelArt.draw(self, sprite, Vector2(roundf(x), roundf(y)), cloud_px, tint)


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
		if index % 5 == 0:
			draw_rect(Rect2(sx, BASELINE - h + 16.0, COLUMN, maxf(h - 16.0, 0.0)), shade)
		if snow_line > 0.0:
			var cap: float = h - snow_line - float(posmod(index, 3)) * 8.0
			if cap > 0.0:
				draw_rect(Rect2(sx, BASELINE - h, COLUMN, cap), snow)


func _draw_castles() -> void:
	var period: float = 1900.0
	var scroll: float = scroll_x * 0.10
	var first: int = int(floor((scroll - 900.0) / period))
	var dark: float = Daylight.darkness()
	for k in range(first, first + 3):
		var wx: float = float(k) * period + 700.0
		var sx: float = roundf(wx - scroll - 54.0)
		if sx < -200.0 or sx > W + 100.0:
			continue
		var top: float = BASELINE - _ridge_height(wx, 110.0, 150.0, 0.0062, 0.0171, 1.7) - 60.0
		PixelArt.draw(self, "castle", Vector2(sx, top), 6.0, _sprite_tint())
		# Ventanas encendidas de noche.
		if dark > 0.1:
			for cell in [Vector2(2.0, 3.0), Vector2(15.0, 3.0), Vector2(8.0, 4.0), Vector2(9.0, 4.0), Vector2(2.0, 8.0), Vector2(15.0, 8.0)]:
				var c: Vector2 = cell
				var wpos: Vector2 = Vector2(sx + c.x * 6.0, top + c.y * 6.0)
				draw_rect(Rect2(wpos, Vector2(6.0, 6.0)), Color(Pal.YELLOW, dark))
				PixelArt.draw_glow(self, wpos + Vector2(3.0, 3.0), 16.0, Color(Pal.ORANGE, 0.4 * dark))


func _hill_height(wx: float) -> float:
	return snappedf(74.0 + 46.0 * sin(wx * 0.0040) + 20.0 * sin(wx * 0.011 + 2.0), 4.0)


func _draw_hills() -> void:
	var scroll: float = scroll_x * 0.22
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	var color: Color = _tint(Daylight.theme_color("hill", Pal.TEAL.lerp(Pal.GREEN, 0.45)))
	var rim: Color = color.lightened(0.18)
	for i in count:
		var wx: float = float(first + i) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = _hill_height(wx)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h), color)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, 4.0), rim)


## Ruinas medievales: arcos, columnas y muros derruidos entre las colinas.
func _draw_ruins() -> void:
	var scroll: float = scroll_x * 0.32
	var cell: float = 430.0
	var first: int = int(floor((scroll - 200.0) / cell))
	var tint: Color = _sprite_tint().darkened(0.08)
	for n in 5:
		var c: int = first + n
		if PixelArt.hash01(c, 41) < 0.35:
			continue
		var sprite: String = RUINS[int(PixelArt.hash01(c, 42) * 4.0) % 4]
		var sz: Vector2 = PixelArt.size_of(sprite, 6.0)
		var sx: float = float(c) * cell + PixelArt.hash01(c, 43) * 200.0 - scroll
		PixelArt.draw(self, sprite, Vector2(roundf(sx), BASELINE - 38.0 - sz.y), 6.0, tint)


func _forest_height(wx: float) -> float:
	return snappedf(64.0 + 14.0 * sin(wx * 0.009) + 8.0 * sin(wx * 0.023 + 1.0), 4.0)


func _draw_forest() -> void:
	var scroll: float = scroll_x * 0.45
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	var color: Color = _tint(Daylight.theme_color("forest", Pal.TEAL.lerp(Pal.NAVY, 0.2)))
	var rim: Color = color.lightened(0.12)
	for i in count:
		var wx: float = float(first + i) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = _forest_height(wx)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h + 720.0 - BASELINE), color)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, 4.0), rim)
	var cell: float = 120.0
	var first_cell: int = int(floor((scroll - 120.0) / cell))
	var cells: int = int(W / cell) + 4
	var tree_tint: Color = _sprite_tint().darkened(0.12) * Daylight.theme_color("tree_tint", Color(1.0, 1.0, 1.0))
	var density: float = float(Daylight.theme.get("trees", 1.0))
	for n in cells:
		var c: int = first_cell + n
		if PixelArt.hash01(c, 21) < 1.0 - 0.72 * density:
			continue
		var wx: float = float(c) * cell + PixelArt.hash01(c, 22) * 70.0
		var sx: float = wx - scroll
		var sprite: String = "tree_pine" if PixelArt.hash01(c, 23) < 0.6 else "tree_round"
		var tree_px: float = 5.0 if PixelArt.hash01(c, 24) < 0.5 else 6.0
		var sz: Vector2 = PixelArt.size_of(sprite, tree_px)
		var base_y: float = BASELINE - _forest_height(wx) + 10.0
		PixelArt.draw(self, sprite, Vector2(roundf(sx - sz.x * 0.5), base_y - sz.y), tree_px, tree_tint)


## Particulas ambientales: polen durante el dia y hojas al atardecer.
func _draw_particles() -> void:
	var pollen: float = (1.0 - Daylight.darkness()) * (1.0 - Daylight.warmth()) * 0.55
	var leaves: float = Daylight.warmth() * 0.85
	for i in 26:
		var h1: float = PixelArt.hash01(i, 51)
		var h2: float = PixelArt.hash01(i, 52)
		if i % 2 == 0 and pollen > 0.03:
			var x: float = fposmod(h1 * W + _time * (14.0 + h2 * 20.0) - scroll_x * 0.5, W)
			var y: float = fposmod(h2 * 560.0 - _time * (8.0 + h1 * 10.0) + sin(_time + float(i)) * 12.0, 560.0)
			draw_rect(Rect2(snappedf(x, 2.0), snappedf(y, 2.0), 4.0, 4.0), Color(Pal.WHITE, pollen * (0.5 + 0.5 * h1)))
		elif i % 2 == 1 and leaves > 0.03:
			var lx: float = fposmod(h1 * W - _time * (40.0 + h2 * 30.0) - scroll_x * 0.6, W)
			var ly: float = fposmod(h2 * 560.0 + _time * (30.0 + h1 * 25.0), 560.0)
			var leaf: Color = Pal.ORANGE if i % 4 == 1 else Pal.RED
			draw_rect(Rect2(snappedf(lx + sin(_time * 2.0 + float(i)) * 14.0, 2.0), snappedf(ly, 2.0), 6.0, 4.0), Color(leaf, leaves))
	_draw_world_particles()


## Particulas propias de cada mundo: ascuas, destellos, nieve o arena.
func _draw_world_particles() -> void:
	var kind: String = String(Daylight.theme.get("particles", "pollen"))
	if kind == "pollen":
		return
	for i in 34:
		var h1: float = PixelArt.hash01(i, 61)
		var h2: float = PixelArt.hash01(i, 62)
		if kind == "embers":
			var ex: float = fposmod(h1 * W + sin(_time + float(i)) * 24.0 - scroll_x * 0.5, W)
			var ey: float = fposmod(h2 * 600.0 - _time * (40.0 + h1 * 50.0), 600.0)
			draw_rect(Rect2(snappedf(ex, 2.0), snappedf(ey, 2.0), 4.0, 4.0), Color(Pal.ORANGE if i % 2 == 0 else Pal.YELLOW, 0.85))
		elif kind == "snow":
			var nx: float = fposmod(h1 * W - _time * 30.0 - scroll_x * 0.5 + sin(_time * 1.5 + float(i)) * 16.0, W)
			var ny: float = fposmod(h2 * 600.0 + _time * (50.0 + h1 * 40.0), 600.0)
			draw_rect(Rect2(snappedf(nx, 2.0), snappedf(ny, 2.0), 4.0, 4.0), Color(Pal.WHITE, 0.85))
		elif kind == "sand":
			var sx: float = fposmod(h1 * W - _time * (260.0 + h2 * 160.0) - scroll_x * 0.5, W)
			draw_rect(Rect2(sx, snappedf(h2 * 560.0, 4.0), 18.0, 2.0), Color(Pal.YELLOW, 0.45))
		else:
			var cx: float = fposmod(h1 * W - scroll_x * 0.2, W)
			var glint: float = maxf(sin(_time * 2.0 + float(i) * 1.3), 0.0)
			var c: Color = Color(Pal.PINK if i % 2 == 0 else Pal.CYAN, glint)
			draw_rect(Rect2(snappedf(cx, 4.0), snappedf(h2 * 520.0, 4.0), 4.0, 4.0), c)
			draw_rect(Rect2(snappedf(cx, 4.0) - 4.0, snappedf(h2 * 520.0, 4.0), 12.0, 4.0), Color(c, glint * 0.4))
