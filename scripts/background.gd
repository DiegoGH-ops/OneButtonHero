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
	var style: String = String(Daylight.theme.get("style", "forest"))
	if style == "frost" or style == "crystal":
		_draw_aurora(style == "crystal")
	_draw_celestial()
	# Cada mundo tiene su propio paisaje por capas (parallax): cada capa se
	# desplaza a una velocidad distinta segun su distancia.
	match style:
		"inferno":
			_draw_inferno()
		"crystal":
			_draw_clouds()
			_draw_crystal()
		"frost":
			_draw_clouds()
			_draw_frost()
		"desert":
			_draw_clouds()
			_draw_desert()
		_:
			_draw_clouds()
			_draw_light_shafts()
			_draw_ridge(0.04, 170.0, 220.0, 0.0045, 0.0117, 0.0, _tint(Daylight.theme_color("far", Pal.SILVER.lerp(Pal.CYAN, 0.3))), 300.0)
			_draw_castles()
			_draw_ridge(0.10, 110.0, 150.0, 0.0062, 0.0171, 1.7, _tint(Daylight.theme_color("mid", Pal.STEEL.lerp(Pal.SKY, 0.12))), 0.0)
			_draw_giant_trees()
			_draw_hills()
			_draw_ruins()
			_draw_birds()
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


# ------------------------------------------------------- paisajes por mundo --

## Columnas suavizadas (dunas, laderas) con una funcion seno.
func _draw_waves(factor: float, base_h: float, amp: float, freq: float, phase: float, color: Color, rim: Color) -> void:
	var scroll: float = scroll_x * factor
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	var count: int = int(W / COLUMN) + 2
	for i in count:
		var wx: float = float(first + i) * COLUMN
		var sx: float = float(i) * COLUMN - offset
		var h: float = snappedf(base_h + amp * (0.5 + 0.5 * sin(wx * freq + phase)) + amp * 0.3 * sin(wx * freq * 2.7 + phase * 1.3), 4.0)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, h + 720.0 - BASELINE), color)
		draw_rect(Rect2(sx, BASELINE - h, COLUMN, 4.0), rim)


## Elementos repetidos a lo largo del mundo: devuelve [indice, x en pantalla]
## de los que caen dentro de la vista para una capa con `factor` de parallax.
func _cells(factor: float, period: float, margin: float) -> Array:
	var scroll: float = scroll_x * factor
	var first: int = int(floor((scroll - margin) / period))
	var count: int = int((W + margin * 2.0) / period) + 2
	var result: Array = []
	for n in count:
		var c: int = first + n
		result.append([c, float(c) * period - scroll])
	return result


## Rayos de luz entre las nubes del bosque (solo de dia).
func _draw_light_shafts() -> void:
	var strength: float = (1.0 - Daylight.darkness()) * (1.0 - Daylight.warmth() * 0.4)
	if strength < 0.05:
		return
	for i in 4:
		var x: float = fposmod(PixelArt.hash01(i, 71) * W + _time * 6.0 - scroll_x * 0.02, W + 300.0) - 300.0
		var w: float = 50.0 + PixelArt.hash01(i, 72) * 60.0
		var alpha: float = strength * (0.05 + 0.03 * sin(_time * 0.7 + float(i)))
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + w, 0.0), Vector2(x + w + 260.0, BASELINE), Vector2(x + 260.0, BASELINE)]), Color(Pal.YELLOW.lerp(Pal.WHITE, 0.6), alpha))


## Arboles ancestrales gigantes en segundo plano.
func _draw_giant_trees() -> void:
	var color: Color = _tint(Daylight.theme_color("forest", Pal.TEAL)).darkened(0.25)
	for item in _cells(0.16, 900.0, 300.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 81) < 0.4:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 82) * 300.0
		var h: float = 300.0 + PixelArt.hash01(c, 83) * 120.0
		draw_rect(Rect2(x - 18.0, BASELINE - h * 0.6, 36.0, h * 0.6), color.darkened(0.2))
		for k in 4:
			var cx: float = x + (PixelArt.hash01(c * 4 + k, 84) - 0.5) * 160.0
			var cy: float = BASELINE - h + PixelArt.hash01(c * 4 + k, 85) * 120.0
			_draw_disc(Vector2(cx, cy), 9 + k % 3, 8.0, color)


## Bandada de pajaros que cruza el cielo.
func _draw_birds() -> void:
	if Daylight.darkness() > 0.7:
		return
	var tint: Color = _tint(Pal.INK)
	for i in 6:
		var x: float = fposmod(PixelArt.hash01(i, 91) * W - _time * (60.0 + float(i) * 6.0) - scroll_x * 0.05, W + 200.0) - 100.0
		var y: float = 140.0 + float(i % 3) * 22.0 + sin(_time * 1.5 + float(i)) * 8.0 + float(i) * 6.0
		var flap: float = 4.0 if int(_time * 6.0 + float(i)) % 2 == 0 else -2.0
		draw_rect(Rect2(x - 8.0, y + flap, 8.0, 4.0), tint)
		draw_rect(Rect2(x, y, 4.0, 4.0), tint)
		draw_rect(Rect2(x + 4.0, y + flap, 8.0, 4.0), tint)


## Aurora: bandas de luz ondulantes en el cielo nocturno (mas debil de dia
## en el mundo de cristal).
func _draw_aurora(crystal: bool) -> void:
	var dark: float = Daylight.darkness()
	var strength: float = dark if not crystal else 0.35 + 0.65 * dark
	if strength < 0.05:
		return
	var colors: Array = [Pal.LIME, Pal.CYAN, Pal.GREEN] if not crystal else [Pal.PINK, Pal.CYAN, Color("b06fd0")]
	for band in 3:
		var color: Color = colors[band]
		var x: float = 0.0
		while x < W:
			var y: float = 70.0 + float(band) * 36.0 + sin(x * 0.006 + _time * 0.5 + float(band) * 1.7) * 34.0
			var h: float = 50.0 + 30.0 * sin(x * 0.011 + _time * 0.8 + float(band))
			draw_rect(Rect2(x, y, 16.0, h), Color(color, 0.10 * strength))
			draw_rect(Rect2(x, y, 16.0, 6.0), Color(color, 0.18 * strength))
			x += 16.0


# ----------------------------------------------------------------- Infernus --

func _draw_inferno() -> void:
	# Nubes de ceniza en lugar de nubes blancas.
	for i in 6:
		var x: float = fposmod(PixelArt.hash01(i, 11) * (W + 400.0) - scroll_x * 0.03 - _time * 8.0, W + 400.0) - 200.0
		var y: float = 40.0 + PixelArt.hash01(i, 13) * 160.0
		PixelArt.draw(self, "cloud_a" if i % 2 == 0 else "cloud_b", Vector2(roundf(x), roundf(y)), 8.0, Color(0.25, 0.12, 0.14, 0.85))
	_draw_ridge(0.04, 160.0, 200.0, 0.0045, 0.0117, 0.0, _tint(Daylight.theme_color("far", Pal.PURPLE)), 0.0)
	_draw_volcanoes()
	_draw_ridge(0.10, 100.0, 150.0, 0.0062, 0.0171, 1.7, _tint(Daylight.theme_color("mid", Pal.INK)), 0.0)
	_draw_lavafalls()
	# Agujas de obsidiana.
	var spire: Color = _tint(Daylight.theme_color("hill", Pal.RED)).darkened(0.35)
	for item in _cells(0.24, 260.0, 120.0):
		var c: int = item[0]
		var x: float = float(item[1]) + PixelArt.hash01(c, 31) * 120.0
		var h: float = 90.0 + PixelArt.hash01(c, 32) * 140.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 26.0, BASELINE), Vector2(x - 4.0, BASELINE - h), Vector2(x + 4.0, BASELINE - h), Vector2(x + 26.0, BASELINE)]), spire)
		draw_rect(Rect2(x - 2.0, BASELINE - h * 0.7, 4.0, h * 0.5), Color(Pal.ORANGE, 0.5 + 0.3 * sin(_time * 3.0 + float(c))))
	_draw_waves(0.45, 50.0, 26.0, 0.012, 0.0, _tint(Daylight.theme_color("forest", Pal.INK)), Color(Pal.RED, 0.9))
	# Resplandor de lava sobre el horizonte y calima.
	for i in 6:
		var a: float = 0.16 * (1.0 - float(i) / 6.0)
		draw_rect(Rect2(0.0, BASELINE - 40.0 - float(i) * 20.0, W, 20.0), Color(Pal.ORANGE, a))
	for i in 4:
		var y: float = 420.0 + float(i) * 34.0 + sin(_time * 2.0 + float(i)) * 6.0
		draw_rect(Rect2(0.0, y, W, 2.0), Color(Pal.YELLOW, 0.05))


func _draw_volcanoes() -> void:
	var color: Color = _tint(Daylight.theme_color("mid", Pal.INK)).lightened(0.05)
	for item in _cells(0.06, 1100.0, 400.0):
		var c: int = item[0]
		var x: float = float(item[1]) + PixelArt.hash01(c, 41) * 400.0
		var h: float = 300.0 + PixelArt.hash01(c, 42) * 80.0
		var top: float = BASELINE - h
		draw_colored_polygon(PackedVector2Array([Vector2(x - 260.0, BASELINE), Vector2(x - 46.0, top), Vector2(x + 46.0, top), Vector2(x + 260.0, BASELINE)]), color)
		# Rios de lava por la ladera.
		for k in 3:
			var lx: float = x - 30.0 + float(k) * 30.0
			draw_line(Vector2(lx, top + 4.0), Vector2(lx + (float(k) - 1.0) * 120.0, BASELINE), Color(Pal.ORANGE, 0.55), 4.0)
		PixelArt.draw_glow(self, Vector2(x, top), 110.0, Color(Pal.ORANGE, 0.45))
		draw_rect(Rect2(x - 46.0, top - 4.0, 92.0, 8.0), Pal.YELLOW)
		# Erupcion periodica: bolas de fuego que suben y caen.
		var cycle: float = fposmod(_time + float(c) * 2.3, 7.0)
		if cycle < 2.2:
			for k in 8:
				var t: float = cycle - float(k) * 0.08
				if t <= 0.0:
					continue
				var vx: float = (PixelArt.hash01(c * 8 + k, 43) - 0.5) * 160.0
				var vy: float = -260.0 - PixelArt.hash01(c * 8 + k, 44) * 140.0
				var p: Vector2 = Vector2(x + vx * t, top + vy * t + 160.0 * t * t)
				draw_rect(Rect2(p, Vector2(8.0, 8.0)), Pal.ORANGE if k % 2 == 0 else Pal.YELLOW)


func _draw_lavafalls() -> void:
	for item in _cells(0.10, 700.0, 100.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 51) < 0.4:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 52) * 300.0
		var top: float = BASELINE - _ridge_height(x + scroll_x * 0.10, 100.0, 150.0, 0.0062, 0.0171, 1.7) + 8.0
		draw_rect(Rect2(x, top, 16.0, BASELINE - top), Color(Pal.RED, 0.9))
		var flow: float = fposmod(_time * 120.0, 24.0)
		var y: float = top - 24.0 + flow
		while y < BASELINE:
			draw_rect(Rect2(x + 4.0, maxf(y, top), 8.0, 10.0), Pal.ORANGE)
			y += 24.0
		PixelArt.draw_glow(self, Vector2(x + 8.0, BASELINE - 10.0), 50.0, Color(Pal.ORANGE, 0.4))


# --------------------------------------------------------------- Amethystia --

func _draw_crystal() -> void:
	_draw_ridge(0.04, 160.0, 200.0, 0.0045, 0.0117, 0.0, _tint(Daylight.theme_color("far", Pal.PURPLE)), 0.0)
	_draw_crystal_spires(0.08, 1.0)
	_draw_ridge(0.10, 100.0, 150.0, 0.0062, 0.0171, 1.7, _tint(Daylight.theme_color("mid", Pal.PURPLE)), 0.0)
	_draw_floating_shards()
	_draw_hills()
	_draw_crystal_spires(0.45, 0.35)


## Agujas de cristal hexagonales con una faceta iluminada y un destello que
## las recorre.
func _draw_crystal_spires(factor: float, size: float) -> void:
	var base_color: Color = _tint(Daylight.theme_color("hill", Pal.PINK)).lightened(0.1)
	for item in _cells(factor, 520.0 * size + 140.0, 200.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 61) < 0.3:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 62) * 200.0 * size
		var h: float = (220.0 + PixelArt.hash01(c, 63) * 200.0) * size
		var w: float = (50.0 + PixelArt.hash01(c, 64) * 30.0) * size
		var lean: float = (PixelArt.hash01(c, 65) - 0.5) * 60.0 * size
		var tip: Vector2 = Vector2(x + lean, BASELINE - h)
		var body: PackedVector2Array = PackedVector2Array([Vector2(x - w, BASELINE), Vector2(x - w, BASELINE - h * 0.75 + lean * 0.2), tip, Vector2(x + w, BASELINE - h * 0.75 - lean * 0.2), Vector2(x + w, BASELINE)])
		draw_colored_polygon(body, base_color)
		draw_colored_polygon(PackedVector2Array([Vector2(x, BASELINE), Vector2(x, BASELINE - h * 0.75), tip, Vector2(x + w, BASELINE - h * 0.75 - lean * 0.2), Vector2(x + w, BASELINE)]), base_color.lightened(0.18))
		var shine: float = fposmod(_time * 0.35 + PixelArt.hash01(c, 66), 1.0)
		var sy: float = BASELINE - h * 0.75 * shine
		draw_rect(Rect2(x - w, sy, w * 2.0, 4.0 * size + 2.0), Color(Pal.WHITE, 0.35 * (1.0 - shine)))
		if size < 0.5:
			PixelArt.draw_glow(self, Vector2(x, BASELINE - h * 0.4), w * 2.5, Color(Pal.PINK, 0.25 + 0.35 * Daylight.darkness()))


func _draw_floating_shards() -> void:
	for item in _cells(0.25, 300.0, 100.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 67) < 0.4:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 68) * 140.0
		var y: float = 200.0 + PixelArt.hash01(c, 69) * 200.0 + sin(_time * 1.2 + float(c)) * 14.0
		var s: float = 10.0 + PixelArt.hash01(c, 70) * 14.0
		var color: Color = Pal.PINK if c % 2 == 0 else Pal.CYAN
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - s * 1.6), Vector2(x + s, y), Vector2(x, y + s * 1.6), Vector2(x - s, y)]), _tint(color))
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - s * 1.6), Vector2(x + s, y), Vector2(x, y)]), _tint(color.lightened(0.3)))
		PixelArt.draw_glow(self, Vector2(x, y), s * 3.0, Color(color, 0.2))


# ---------------------------------------------------------------- Frostfall --

func _draw_frost() -> void:
	_draw_ridge(0.04, 180.0, 230.0, 0.0045, 0.0117, 0.0, _tint(Daylight.theme_color("far", Pal.WHITE)), 260.0)
	_draw_castles()
	_draw_ridge(0.10, 110.0, 160.0, 0.0062, 0.0171, 1.7, _tint(Daylight.theme_color("mid", Pal.SILVER)), 150.0)
	_draw_hills()
	# Picos de hielo.
	for item in _cells(0.30, 340.0, 100.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 73) < 0.35:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 74) * 160.0
		for k in 3:
			var h: float = 60.0 + PixelArt.hash01(c * 3 + k, 75) * 90.0
			var px: float = x + float(k) * 22.0 - 22.0
			draw_colored_polygon(PackedVector2Array([Vector2(px - 14.0, BASELINE - 30.0), Vector2(px, BASELINE - 30.0 - h), Vector2(px + 14.0, BASELINE - 30.0)]), _tint(Pal.CYAN.lerp(Pal.WHITE, 0.4)))
			draw_line(Vector2(px, BASELINE - 30.0 - h), Vector2(px + 5.0, BASELINE - 34.0), _tint(Pal.WHITE), 3.0)
	_draw_forest()
	# Nieve acumulada sobre el bosque.
	var cap: Color = _tint(Pal.WHITE)
	var scroll: float = scroll_x * 0.45
	var first: int = int(floor(scroll / COLUMN))
	var offset: float = roundf(scroll - float(first) * COLUMN)
	for i in int(W / COLUMN) + 2:
		var wx: float = float(first + i) * COLUMN
		draw_rect(Rect2(float(i) * COLUMN - offset, BASELINE - _forest_height(wx) - 2.0, COLUMN, 8.0), cap)


# ------------------------------------------------------------------ Solaris --

func _draw_desert() -> void:
	_draw_waves(0.03, 120.0, 70.0, 0.003, 0.0, _tint(Daylight.theme_color("far", Pal.YELLOW)), _tint(Daylight.theme_color("far", Pal.YELLOW)).lightened(0.15))
	_draw_pyramids()
	_draw_waves(0.10, 80.0, 60.0, 0.0045, 1.4, _tint(Daylight.theme_color("mid", Pal.ORANGE)), _tint(Daylight.theme_color("mid", Pal.ORANGE)).lightened(0.15))
	_draw_obelisks()
	_draw_waves(0.22, 60.0, 34.0, 0.007, 2.2, _tint(Daylight.theme_color("hill", Pal.YELLOW)), _tint(Daylight.theme_color("hill", Pal.YELLOW)).lightened(0.2))
	_draw_palms()
	_draw_waves(0.45, 40.0, 20.0, 0.011, 0.6, _tint(Daylight.theme_color("forest", Pal.BROWN)), _tint(Daylight.theme_color("forest", Pal.BROWN)).lightened(0.2))
	# Calima: lineas de aire caliente que tiemblan.
	var heat: float = (1.0 - Daylight.darkness()) * 0.06
	for i in 5:
		var y: float = 380.0 + float(i) * 40.0 + sin(_time * 3.0 + float(i) * 1.7) * 5.0
		draw_rect(Rect2(0.0, y, W, 3.0), Color(Pal.WHITE, heat))
	# Buitres en circulo.
	for i in 3:
		var a: float = _time * 0.6 + float(i) * TAU / 3.0
		var center: Vector2 = Vector2(fposmod(900.0 - scroll_x * 0.05, W + 400.0) - 200.0, 150.0)
		var p: Vector2 = center + Vector2(cos(a) * 90.0, sin(a) * 26.0)
		var flap: float = 3.0 if int(_time * 5.0 + float(i)) % 2 == 0 else -2.0
		draw_rect(Rect2(p.x - 10.0, p.y + flap, 10.0, 3.0), _tint(Pal.INK))
		draw_rect(Rect2(p.x, p.y, 4.0, 4.0), _tint(Pal.INK))
		draw_rect(Rect2(p.x + 4.0, p.y + flap, 10.0, 3.0), _tint(Pal.INK))


func _draw_pyramids() -> void:
	for item in _cells(0.06, 1300.0, 400.0):
		var c: int = item[0]
		var x: float = float(item[1]) + PixelArt.hash01(c, 76) * 500.0
		var h: float = 200.0 + PixelArt.hash01(c, 77) * 110.0
		var base_y: float = BASELINE - 60.0
		var light: Color = _tint(Color("e0b060"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - h * 1.1, base_y), Vector2(x, base_y - h), Vector2(x, base_y)]), light)
		draw_colored_polygon(PackedVector2Array([Vector2(x, base_y - h), Vector2(x + h * 1.1, base_y), Vector2(x, base_y)]), light.darkened(0.25))
		# Escalones.
		var steps: int = int(h / 24.0)
		for k in steps:
			var y: float = base_y - float(k) * 24.0
			var half: float = (h - float(k) * 24.0) * 1.1
			draw_rect(Rect2(x - half, y - 2.0, half * 2.0, 2.0), Color(light.darkened(0.35), 0.6))
		draw_rect(Rect2(x - 6.0, base_y - h - 4.0, 12.0, 8.0), Color(Pal.YELLOW, 0.9))


func _draw_obelisks() -> void:
	var color: Color = _tint(Color("b8763a"))
	for item in _cells(0.16, 640.0, 120.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 78) < 0.45:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 79) * 260.0
		var h: float = 140.0 + PixelArt.hash01(c, 80) * 90.0
		var base_y: float = BASELINE - 40.0
		draw_rect(Rect2(x - 14.0, base_y - h, 28.0, h), color)
		draw_rect(Rect2(x, base_y - h, 14.0, h), color.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 14.0, base_y - h), Vector2(x, base_y - h - 26.0), Vector2(x + 14.0, base_y - h)]), _tint(Pal.YELLOW))
		for k in 3:
			draw_rect(Rect2(x - 8.0, base_y - h + 30.0 + float(k) * 28.0, 10.0, 6.0), color.darkened(0.35))


func _draw_palms() -> void:
	var trunk: Color = _tint(Pal.BROWN)
	var leaves: Color = _tint(Pal.GREEN.darkened(0.15))
	for item in _cells(0.36, 520.0, 120.0):
		var c: int = item[0]
		if PixelArt.hash01(c, 86) < 0.5:
			continue
		var x: float = float(item[1]) + PixelArt.hash01(c, 87) * 220.0
		var base_y: float = BASELINE - 30.0
		var sway: float = sin(_time * 1.3 + float(c)) * 6.0
		for k in 8:
			var bend: float = float(k * k) * 0.6 + sway * float(k) / 8.0
			draw_rect(Rect2(x + bend - 6.0, base_y - float(k + 1) * 16.0, 12.0, 16.0), trunk if k % 2 == 0 else trunk.darkened(0.15))
		var crown: Vector2 = Vector2(x + 38.0 + sway, base_y - 132.0)
		for k in 5:
			var a: float = -PI * 0.15 - float(k) * PI * 0.175 + sin(_time * 1.3 + float(c + k)) * 0.06
			var tip: Vector2 = crown + Vector2(cos(a), -sin(a)) * Vector2(70.0, 34.0) * Vector2(1.0, -1.0)
			draw_line(crown, tip, leaves, 8.0)
			draw_line(crown, crown + (tip - crown) * 0.6 + Vector2(0.0, 6.0), leaves.lightened(0.15), 4.0)
