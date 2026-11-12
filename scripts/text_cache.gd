extends RefCounted
## Textos pixel art convertidos en texturas y guardados en cache.
## PixelFont dibuja cada letra con varios rectangulos; para pantallas con
## cientos de textos que se redibujan cada fotograma (el arbol de mejoras con
## zoom) es mucho mas barato dibujar una textura ya hecha y escalarla.
##
##   var tex: ImageTexture = TextCache.get_texture("HOLA", Pal.WHITE)
##   draw_texture_rect(tex, Rect2(pos, TextCache.size_of("HOLA", px)), false)
##
## La textura se crea a 1 pixel por pixel de fuente, con sombra de 1 pixel y
## 3 filas extra arriba para las tildes. Se escala con filtro "nearest".

const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

const TOP := 3
const MAX_ENTRIES := 900

static var _cache: Dictionary = {}


## Tamano en pantalla de un texto dibujado a `px` pixeles por pixel de fuente
## (incluye la sombra y el margen superior de las tildes).
static func size_of(text: String, px: float) -> Vector2:
	return Vector2(maxf(PixelFont.text_width(text, px), px), float(PixelFont.GLYPH_H + TOP + 1) * px)


## Desplazamiento vertical que hay que restar para que el texto quede en la
## misma posicion que con PixelFont.draw_text.
static func top_offset(px: float) -> float:
	return float(TOP) * px


static func get_texture(source: String, color: Color, shadow: Color = Pal.INK) -> ImageTexture:
	# Texto ya traducido y en la forma de la fuente pixel.
	var text: String = PixelFont.pixel_form(PixelFont.resolve(source))
	var key: String = "%s|%s|%s" % [text, color.to_html(), shadow.to_html()]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > MAX_ENTRIES:
		_cache.clear()
	var w: int = maxi(text.length() * PixelFont.ADVANCE, 1) + 1
	var h: int = PixelFont.GLYPH_H + TOP + 1
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for pass_index in 2:
		var offset: int = 1 if pass_index == 0 else 0
		var tint: Color = shadow if pass_index == 0 else color
		if pass_index == 0 and shadow.a <= 0.0:
			continue
		var cursor: int = 0
		for i in text.length():
			var ch: String = text[i]
			if ch != " ":
				for item in PixelFont._glyph_runs(ch):
					var run: Vector3i = item
					for k in run.z:
						var x: int = cursor + run.x + k + offset
						var y: int = run.y + TOP + offset
						if x >= 0 and x < w and y >= 0 and y < h:
							image.set_pixel(x, y, tint)
			cursor += PixelFont.ADVANCE
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Dibuja un texto en `ci` con su esquina superior izquierda en `pos` (como
## PixelFont.draw_text). Respeta la transformacion activa del CanvasItem.
static func draw(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, shadow: Color = Pal.INK) -> void:
	if text.is_empty():
		return
	# Idiomas con otras escrituras: se dibuja directamente con su fuente.
	if PixelFont.needs_vector(PixelFont.resolve(text)):
		PixelFont.draw_text_shadowed(ci, text, pos, px, color, shadow, false, 1.0 * px)
		return
	var tex: ImageTexture = get_texture(text, color, shadow)
	var size: Vector2 = Vector2(float(tex.get_width()), float(tex.get_height())) * px
	ci.draw_texture_rect(tex, Rect2(pos - Vector2(0.0, top_offset(px)), size), false)


## Ancho en pantalla de un texto (igual que PixelFont.text_width).
static func width(text: String, px: float) -> float:
	return PixelFont.text_width(text, px)
