extends RefCounted
## Efectos visuales propios de cada heroe (particulas, halos, alas de luz,
## engranajes...). Los usan player.gd y hero_preview.gd para que el heroe
## se vea igual en partida, en la tienda y en el menu.
##
## Coordenadas: los pies del heroe estan en (0, 0) y `s` es la escala (1 =
## tamano de juego, pixel de 4). `t` es el tiempo en segundos. "back" se
## dibuja detras del heroe y "front" delante.

const Pal = preload("res://scripts/palette.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")

## Datos de aspecto de un heroe a partir de su entrada del catalogo.
static func top_sprite(skin: Dictionary) -> String:
	return String(skin.get("top", "hero_top"))


## Los heroes rediseñados tienen colores propios en el torso: no se
## recolorean (el remap solo tine piernas y capa).
static func top_map(skin: Dictionary) -> Dictionary:
	if bool(skin.get("top_remap", true)):
		return skin.get("remap", {})
	return {}


static func top_key(skin: Dictionary) -> String:
	return String(skin.get("id", "")) + ("" if bool(skin.get("top_remap", true)) else "_top")


static func cape_prefix(skin: Dictionary) -> String:
	return String(skin.get("cape", "hero_cape_"))


## Altura del torso en pixeles de pantalla (algunos son mas altos: cuernos,
## sombreros...). El borde inferior siempre queda sobre las piernas.
static func top_offset_y(skin: Dictionary, px: float) -> float:
	return -16.0 * px / 4.0 - PixelArt.size_of(top_sprite(skin), px).y


static func _sq(ci: CanvasItem, p: Vector2, size: float, c: Color) -> void:
	ci.draw_rect(Rect2(Vector2(snappedf(p.x, 2.0), snappedf(p.y, 2.0)) - Vector2(size, size) * 0.5, Vector2(size, size)), c)


## Efectos que van detras del heroe.
static func draw_back(ci: CanvasItem, fx: String, t: float, s: float, bob: float) -> void:
	var head: Vector2 = Vector2(4.0, -52.0 + bob) * s
	match fx:
		"halo":
			# Alas de luz y halo flotante.
			var lift: float = sin(t * 3.0) * 3.0 * s
			for side in [-1.0, 1.0]:
				for i in 4:
					var wx: float = -6.0 * s + side * (10.0 + float(i) * 8.0) * s
					var wy: float = (-44.0 - float(i) * 6.0 + bob) * s + lift
					ci.draw_rect(Rect2(wx - 3.0 * s, wy, 6.0 * s, (16.0 - float(i) * 2.0) * s), Color(Pal.YELLOW, 0.25))
			PixelArt.draw_glow(ci, head, 34.0 * s, Color(Pal.YELLOW, 0.25))
		"dark":
			# Humo oscuro que sale de la armadura.
			for i in 6:
				var life: float = fposmod(t * 0.7 + float(i) / 6.0, 1.0)
				var p: Vector2 = Vector2(-16.0 + float(i % 3) * 14.0 - life * 10.0, -30.0 - life * 50.0 + bob) * s
				_sq(ci, p, (10.0 - life * 5.0) * s, Color(Pal.VOID, 0.55 * (1.0 - life)))
		"cracks":
			var beat: float = 0.5 + 0.5 * sin(t * 5.0)
			PixelArt.draw_glow(ci, Vector2(0.0, -34.0 + bob) * s, 30.0 * s, Color(Pal.VIOLET, 0.25 + 0.25 * beat))
		"rays":
			# Rayos de sol detras de la cabeza.
			for i in 8:
				var a: float = t * 0.6 + float(i) * TAU / 8.0
				var from: Vector2 = head + Vector2(cos(a), sin(a)) * 14.0 * s
				var to: Vector2 = head + Vector2(cos(a), sin(a)) * 30.0 * s
				ci.draw_line(from, to, Color(Pal.YELLOW, 0.45), 3.0 * s)
		"souls":
			PixelArt.draw_glow(ci, head, 26.0 * s, Color(Pal.LIME, 0.18))
		"icecrown":
			PixelArt.draw_glow(ci, head + Vector2(0.0, -10.0) * s, 30.0 * s, Color(Pal.CYAN, 0.22))
		"hellfire":
			for i in 5:
				var flick: float = absf(sin(t * 9.0 + float(i) * 1.3))
				ci.draw_rect(Rect2(Vector2(-20.0 + float(i) * 9.0, -6.0 - flick * 12.0) * s, Vector2(6.0, 6.0 + flick * 12.0) * s), Color(Pal.RED, 0.5))


## Efectos que van delante del heroe.
static func draw_front(ci: CanvasItem, fx: String, t: float, s: float, bob: float) -> void:
	var head: Vector2 = Vector2(4.0, -52.0 + bob) * s
	match fx:
		"halo":
			var ring_y: float = (-74.0 + bob) * s + sin(t * 3.0) * 3.0 * s
			ci.draw_rect(Rect2(Vector2(-10.0 * s, ring_y), Vector2(24.0 * s, 4.0 * s)), Pal.YELLOW)
			ci.draw_rect(Rect2(Vector2(-6.0 * s, ring_y - 2.0 * s), Vector2(16.0 * s, 2.0 * s)), Pal.WHITE)
			for i in 3:
				var life: float = fposmod(t * 0.8 + float(i) / 3.0, 1.0)
				_sq(ci, Vector2(-20.0 + float(i) * 20.0, -20.0 - life * 60.0) * s, 4.0 * s, Color(Pal.WHITE, 1.0 - life))
		"dark":
			# Ojos rojos que laten tras el visor.
			var beat: float = 0.5 + 0.5 * sin(t * 4.0)
			PixelArt.draw_glow(ci, Vector2(8.0, -46.0 + bob) * s, 12.0 * s, Color(Pal.RED, 0.4 + 0.4 * beat))
		"spectral":
			for i in 5:
				var life: float = fposmod(t * 0.9 + float(i) / 5.0, 1.0)
				var p: Vector2 = Vector2(-24.0 - life * 30.0, -40.0 + sin(t * 4.0 + float(i)) * 14.0 + bob) * s
				_sq(ci, p, (6.0 - life * 3.0) * s, Color(Pal.CYAN, 0.7 * (1.0 - life)))
			var blink: float = 0.6 + 0.4 * sin(t * 7.0)
			PixelArt.draw_glow(ci, Vector2(12.0, -48.0 + bob) * s, 10.0 * s, Color(Pal.CYAN, 0.5 * blink))
		"petals", "flowers":
			var tint: Color = Pal.PINK if fx == "petals" else Pal.YELLOW
			for i in 6:
				var life: float = fposmod(t * 0.5 + float(i) / 6.0, 1.0)
				var x: float = 30.0 - life * 70.0 + sin(t * 3.0 + float(i) * 2.0) * 8.0
				var y: float = -80.0 + life * 80.0
				_sq(ci, Vector2(x, y) * s, 4.0 * s, Color(tint if i % 2 == 0 else Pal.WHITE, 0.9 * (1.0 - life * 0.6)))
		"cracks":
			for i in 4:
				var life: float = fposmod(t * 1.2 + float(i) / 4.0, 1.0)
				var p: Vector2 = Vector2(-12.0 + float(i) * 8.0, -30.0 - life * 40.0 + bob) * s
				_sq(ci, p, 4.0 * s, Color(Pal.VIOLET if i % 2 == 0 else Pal.LIME, 1.0 - life))
		"shards":
			for i in 4:
				var a: float = t * 2.0 + float(i) * TAU / 4.0
				var p: Vector2 = Vector2(cos(a) * 34.0, -36.0 + sin(a) * 16.0 + bob) * s
				var c: Color = Pal.CYAN if i % 2 == 0 else Pal.PINK
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -7.0) * s, p + Vector2(4.0, 0.0) * s, p + Vector2(0.0, 7.0) * s, p + Vector2(-4.0, 0.0) * s]), c)
		"gears":
			# Antena que parpadea y chispas de los engranajes.
			var on: bool = fposmod(t, 0.8) < 0.4
			_sq(ci, Vector2(1.0, -78.0 + bob) * s, 6.0 * s, Pal.YELLOW if on else Pal.ORANGE)
			for i in 3:
				var life: float = fposmod(t * 2.0 + float(i) / 3.0, 1.0)
				_sq(ci, Vector2(-22.0 - life * 12.0, -30.0 + life * 10.0 + bob) * s, 3.0 * s, Color(Pal.YELLOW, 1.0 - life))
			var steam: float = fposmod(t * 0.9, 1.0)
			_sq(ci, Vector2(-30.0 - steam * 10.0, -50.0 - steam * 20.0 + bob) * s, (6.0 + steam * 6.0) * s, Color(Pal.SILVER, 0.5 * (1.0 - steam)))
		"souls":
			for i in 3:
				var a: float = t * 1.6 + float(i) * TAU / 3.0
				var p: Vector2 = Vector2(cos(a) * 30.0, -40.0 + sin(a * 2.0) * 10.0 + bob) * s
				_sq(ci, p, 8.0 * s, Color(Pal.WHITE, 0.8))
				_sq(ci, p + Vector2(-2.0, -1.0) * s, 2.0 * s, Pal.LIME)
				_sq(ci, p + Vector2(2.0, -1.0) * s, 2.0 * s, Pal.LIME)
		"sparks":
			if fposmod(t, 1.2) < 0.25:
				for i in 3:
					_sq(ci, Vector2(14.0 + float(i) * 5.0, -30.0 - float(i) * 6.0 + bob) * s, 3.0 * s, Pal.YELLOW)
		"leaves":
			for i in 4:
				var life: float = fposmod(t * 0.4 + float(i) / 4.0, 1.0)
				var p: Vector2 = Vector2(20.0 - life * 60.0, -70.0 + life * 70.0 + sin(t * 4.0 + float(i)) * 6.0) * s
				_sq(ci, p, 5.0 * s, Color(Pal.GREEN if i % 2 == 0 else Pal.LIME, 1.0 - life * 0.5))
		"fireflies":
			for i in 4:
				var a: float = t * (0.8 + float(i) * 0.2) + float(i) * 2.0
				var p: Vector2 = Vector2(sin(a) * 34.0, -40.0 + cos(a * 1.3) * 26.0) * s
				var glow: float = 0.5 + 0.5 * sin(t * 6.0 + float(i) * 1.7)
				_sq(ci, p, 4.0 * s, Color(Pal.YELLOW, glow))
		"frost":
			for i in 5:
				var life: float = fposmod(t * 0.7 + float(i) / 5.0, 1.0)
				var p: Vector2 = Vector2(-26.0 + float(i) * 13.0, -64.0 + life * 30.0 + bob) * s
				var c: Color = Color(Pal.WHITE, 0.9 * (1.0 - life))
				ci.draw_rect(Rect2(p + Vector2(-1.0, -4.0) * s, Vector2(2.0, 8.0) * s), c)
				ci.draw_rect(Rect2(p + Vector2(-4.0, -1.0) * s, Vector2(8.0, 2.0) * s), c)
		"snow":
			for i in 8:
				var life: float = fposmod(t * 0.35 + float(i) / 8.0, 1.0)
				var x: float = -36.0 + float(i) * 10.0 + sin(t * 2.0 + float(i)) * 4.0
				_sq(ci, Vector2(x, -90.0 + life * 90.0) * s, 4.0 * s, Color(Pal.WHITE, 0.85))
		"sparkle":
			for i in 4:
				var blink: float = maxf(sin(t * 5.0 + float(i) * 1.6), 0.0)
				var p: Vector2 = Vector2(-24.0 + float(i) * 16.0, -70.0 + float((i * 7) % 4) * 14.0 + bob) * s
				ci.draw_rect(Rect2(p + Vector2(-1.0, -5.0) * s, Vector2(2.0, 10.0) * s), Color(Pal.YELLOW, blink))
				ci.draw_rect(Rect2(p + Vector2(-5.0, -1.0) * s, Vector2(10.0, 2.0) * s), Color(Pal.WHITE, blink))
		"hellfire":
			var beat: float = 0.5 + 0.5 * sin(t * 6.0)
			PixelArt.draw_glow(ci, Vector2(8.0, -46.0 + bob) * s, 10.0 * s, Color(Pal.YELLOW, 0.4 + 0.4 * beat))
		"embers":
			for i in 6:
				var life: float = fposmod(t * 0.9 + float(i) / 6.0, 1.0)
				var p: Vector2 = Vector2(-16.0 + float(i) * 6.0 + sin(t * 3.0 + float(i)) * 6.0, -70.0 - life * 40.0 + bob) * s
				_sq(ci, p, 4.0 * s, Color(Pal.YELLOW if i % 2 == 0 else Pal.ORANGE, 1.0 - life))
		"runes":
			for i in 3:
				var a: float = t * 1.2 + float(i) * TAU / 3.0
				var p: Vector2 = Vector2(cos(a) * 32.0, -34.0 + sin(a) * 12.0 + bob) * s
				var c: Color = Color(Pal.PINK, 0.9)
				ci.draw_rect(Rect2(p + Vector2(-3.0, -5.0) * s, Vector2(2.0, 10.0) * s), c)
				ci.draw_rect(Rect2(p + Vector2(-3.0, -5.0) * s, Vector2(6.0, 2.0) * s), c)
				ci.draw_rect(Rect2(p + Vector2(-3.0, -1.0) * s, Vector2(5.0, 2.0) * s), c)
		"sand":
			for i in 6:
				var life: float = fposmod(t * 1.1 + float(i) / 6.0, 1.0)
				_sq(ci, Vector2(-10.0 - life * 50.0, -6.0 - float(i % 3) * 8.0) * s, 3.0 * s, Color(Pal.YELLOW, 0.8 * (1.0 - life)))
		"dust":
			for i in 3:
				var life: float = fposmod(t * 1.4 + float(i) / 3.0, 1.0)
				_sq(ci, Vector2(-14.0 - life * 30.0, -4.0 - life * 10.0) * s, (4.0 + life * 6.0) * s, Color(Pal.SILVER, 0.45 * (1.0 - life)))
		"bubbles":
			for i in 4:
				var life: float = fposmod(t * 0.6 + float(i) / 4.0, 1.0)
				var p: Vector2 = Vector2(-20.0 + float(i) * 12.0 + sin(t * 3.0 + float(i)) * 4.0, -20.0 - life * 70.0) * s
				ci.draw_arc(p, 4.0 * s, 0.0, TAU, 10, Color(Pal.SKY, 0.8 * (1.0 - life)), 2.0 * s)
		"chi":
			var r: float = fposmod(t * 0.8, 1.0)
			ci.draw_arc(Vector2(0.0, -34.0 + bob) * s, (20.0 + r * 30.0) * s, 0.0, TAU, 24, Color(Pal.LIME, 0.6 * (1.0 - r)), 2.0 * s)
		"icecrown":
			for i in 3:
				var a: float = t * 1.5 + float(i) * TAU / 3.0
				var p: Vector2 = head + Vector2(cos(a) * 22.0, -18.0 + sin(a) * 6.0) * s
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3.0, -6.0) * s, p + Vector2(3.0, -6.0) * s, p + Vector2(0.0, 6.0) * s]), Pal.CYAN)
		"rays":
			PixelArt.draw_glow(ci, head, 18.0 * s, Color(Pal.YELLOW, 0.3))
