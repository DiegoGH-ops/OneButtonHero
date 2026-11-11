extends RefCounted
## Convierte los sprites de texto (sprites.gd) en texturas reales y las dibuja.
## Las texturas se crean una sola vez y quedan en cache.

const Pal = preload("res://scripts/palette.gd")
const Sprites = preload("res://scripts/sprites.gd")

static var _colors: Dictionary = {}
static var _cache: Dictionary = {}


static func _color_table() -> Dictionary:
	if _colors.is_empty():
		_colors = {
			"k": Pal.INK, "p": Pal.PURPLE, "r": Pal.RED, "o": Pal.ORANGE,
			"y": Pal.YELLOW, "L": Pal.LIME, "G": Pal.GREEN, "t": Pal.TEAL,
			"n": Pal.NAVY, "b": Pal.BLUE, "B": Pal.SKY, "c": Pal.CYAN,
			"w": Pal.WHITE, "l": Pal.SILVER, "g": Pal.STEEL, "d": Pal.SLATE,
			"h": Pal.SKIN,
		}
	return _colors


## Devuelve la textura de un sprite (la genera la primera vez).
static func tex(sprite_name: String) -> ImageTexture:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
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
			if colors.has(ch):
				var c: Color = colors[ch]
				img.set_pixel(x, y, c)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_cache[sprite_name] = texture
	return texture


## Tamano en pantalla de un sprite para un tamano de pixel dado.
static func size_of(sprite_name: String, px: float = 4.0) -> Vector2:
	var t: ImageTexture = tex(sprite_name)
	return Vector2(t.get_width(), t.get_height()) * px


## Dibuja un sprite. Solo puede llamarse dentro del _draw() de `ci`.
static func draw(ci: CanvasItem, sprite_name: String, pos: Vector2, px: float = 4.0, modulate: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	var t: ImageTexture = tex(sprite_name)
	var sz: Vector2 = Vector2(t.get_width(), t.get_height()) * px
	ci.draw_texture_rect(t, Rect2(pos, sz), false, modulate)


## Numero pseudoaleatorio estable (0..1) a partir de dos enteros.
## Sirve para decorar el mundo siempre igual sin guardar nada en memoria.
static func hash01(i: int, salt: int) -> float:
	var n: int = ((i * 73856093) ^ (salt * 19349663)) & 0xffffffff
	n = (((n >> 16) ^ n) * 0x45d9f3b) & 0xffffffff
	n = (((n >> 16) ^ n) * 0x45d9f3b) & 0xffffffff
	n = (n >> 16) ^ n
	return float(n % 10000) / 10000.0
