extends RefCounted
## Convierte los sprites de texto (sprites.gd) en texturas reales y las dibuja.
## Las texturas se crean una sola vez y quedan en cache. Admite "remapeos" de
## color (aspectos del heroe, espadas...) y genera la textura de resplandor.

const Pal = preload("res://scripts/palette.gd")
const Sprites = preload("res://scripts/sprites.gd")

static var _colors: Dictionary = {}
static var _cache: Dictionary = {}
static var _glow: ImageTexture


static func _color_table() -> Dictionary:
	if _colors.is_empty():
		_colors = {
			"k": Pal.INK, "p": Pal.PURPLE, "r": Pal.RED, "o": Pal.ORANGE,
			"y": Pal.YELLOW, "L": Pal.LIME, "G": Pal.GREEN, "t": Pal.TEAL,
			"n": Pal.NAVY, "b": Pal.BLUE, "B": Pal.SKY, "c": Pal.CYAN,
			"w": Pal.WHITE, "l": Pal.SILVER, "g": Pal.STEEL, "d": Pal.SLATE,
			"h": Pal.SKIN, "u": Pal.BROWN, "e": Pal.DARK_BROWN, "m": Pal.PINK,
			"v": Pal.VIOLET, "x": Pal.VOID,
		}
	return _colors


## Devuelve la textura de un sprite. `color_map` cambia caracteres de color
## (por ejemplo {"b": "r"} pinta de rojo lo que era azul) y `remap_key`
## identifica esa variante en la cache.
static func tex(sprite_name: String, color_map: Dictionary = {}, remap_key: String = "") -> ImageTexture:
	var key: String = sprite_name + "|" + remap_key
	if _cache.has(key):
		return _cache[key]
	var rows: Array = []
	if Sprites.DATA.has(sprite_name):
		rows = Sprites.DATA[sprite_name]
	else:
		push_warning("Sprite desconocido: %s" % sprite_name)
		rows = ["r"]
	var colors: Dictionary = _color_table()
	var height: int = rows.size()
	var width: int = 1
	for item in rows:
		var line: String = item
		width = maxi(width, line.length())
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in height:
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if color_map.has(ch):
				ch = color_map[ch]
			if colors.has(ch):
				var c: Color = colors[ch]
				img.set_pixel(x, y, c)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


## Textura circular difuminada para luces y resplandores.
static func glow_tex() -> ImageTexture:
	if _glow != null:
		return _glow
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	_glow = ImageTexture.create_from_image(img)
	return _glow


## Tamano en pantalla de un sprite para un tamano de pixel dado.
static func size_of(sprite_name: String, px: float = 4.0) -> Vector2:
	var t: ImageTexture = tex(sprite_name)
	return Vector2(t.get_width(), t.get_height()) * px


## Dibuja un sprite. Solo puede llamarse dentro del _draw() de `ci`.
static func draw(ci: CanvasItem, sprite_name: String, pos: Vector2, px: float = 4.0, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	var t: ImageTexture = tex(sprite_name)
	var sz: Vector2 = Vector2(t.get_width(), t.get_height()) * px
	ci.draw_texture_rect(t, Rect2(pos, sz), false, modulate)


## Igual que draw() pero con un remapeo de colores.
static func draw_skin(ci: CanvasItem, sprite_name: String, pos: Vector2, px: float, modulate: Color, color_map: Dictionary, remap_key: String) -> void:
	var t: ImageTexture = tex(sprite_name, color_map, remap_key)
	var sz: Vector2 = Vector2(t.get_width(), t.get_height()) * px
	ci.draw_texture_rect(t, Rect2(pos, sz), false, modulate)


## Resplandor circular centrado en `center`.
static func draw_glow(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow_tex(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


## Sombra proyectada en el suelo: el mismo sprite aplastado e inclinado.
## `feet` es el punto de apoyo y `skew` la inclinacion (segun la hora).
## Deja la transformacion de dibujo restablecida.
static func draw_shadow(ci: CanvasItem, sprite_name: String, feet: Vector2, px: float, skew: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var t: ImageTexture = tex(sprite_name)
	var sz: Vector2 = Vector2(t.get_width(), t.get_height()) * px
	var xf: Transform2D = Transform2D(Vector2(1.0, 0.0), Vector2(-skew, -0.22), feet)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect(t, Rect2(Vector2(-sz.x * 0.5, -sz.y), sz), false, Color(0.0, 0.0, 0.0, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Numero pseudoaleatorio estable (0..1) a partir de dos enteros.
static func hash01(i: int, salt: int) -> float:
	var n: int = ((i * 73856093) ^ (salt * 19349663)) & 0xffffffff
	n = (((n >> 16) ^ n) * 0x45d9f3b) & 0xffffffff
	n = (((n >> 16) ^ n) * 0x45d9f3b) & 0xffffffff
	n = (n >> 16) ^ n
	return float(n % 10000) / 10000.0
