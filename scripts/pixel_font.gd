extends RefCounted
## Fuente bitmap 5x7 dibujada con rectangulos (no depende de ningun archivo de fuente).
## Uso:  PixelFont.draw_text(canvas_item, "TEXTO", posicion, tam_pixel, color)
## Solo puede llamarse desde el _draw() del CanvasItem que se pasa como primer argumento.

const GLYPH_W := 5
const GLYPH_H := 7
const ADVANCE := 6

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", ".##..", ".#..."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"¡": ["..#..", ".....", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"¿": ["..#..", ".....", "..#..", ".#...", "#....", "#...#", ".###."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
	")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
	">": ["#....", ".#...", "..#..", "...#.", "..#..", ".#...", "#...."],
	"<": ["....#", "...#.", "..#..", ".#...", "..#..", "...#.", "....#"],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	"|": ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"],
	"'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
}

## Letras acentuadas: se dibuja la letra base y se le agrega la tilde encima.
const ACCENTS := {
	"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N",
}

static var _runs_cache: Dictionary = {}


static func text_width(text: String, px: float) -> float:
	if text.is_empty():
		return 0.0
	return float(text.length() * ADVANCE - 1) * px


static func text_height(px: float) -> float:
	return float(GLYPH_H) * px


## Convierte un glifo en tramos horizontales (x, y, ancho) para dibujar menos rectangulos.
static func _glyph_runs(ch: String) -> Array:
	if _runs_cache.has(ch):
		return _runs_cache[ch]
	var runs: Array = []
	var base: String = ch
	var accented: bool = ACCENTS.has(ch)
	if accented:
		base = ACCENTS[ch]
	if GLYPHS.has(base):
		var rows: Array = GLYPHS[base]
		for y in rows.size():
			var row: String = rows[y]
			var x: int = 0
			while x < row.length():
				if row[x] == "#":
					var start: int = x
					while x < row.length() and row[x] == "#":
						x += 1
					runs.append(Vector3i(start, y, x - start))
				else:
					x += 1
	if accented:
		if ch == "Ñ":
			runs.append(Vector3i(1, -2, 3))
		elif ch == "Ü":
			runs.append(Vector3i(1, -2, 1))
			runs.append(Vector3i(3, -2, 1))
		else:
			runs.append(Vector3i(3, -3, 1))
			runs.append(Vector3i(2, -2, 1))
	_runs_cache[ch] = runs
	return runs


static func draw_text(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color) -> void:
	var cursor: float = pos.x
	for i in text.length():
		var ch: String = text[i]
		if ch != " ":
			var runs: Array = _glyph_runs(ch)
			for item in runs:
				var run: Vector3i = item
				ci.draw_rect(Rect2(cursor + run.x * px, pos.y + run.y * px, run.z * px, px), color)
		cursor += ADVANCE * px


## Texto con sombra (o contorno) para que se lea sobre cualquier fondo.
## `offset` es el grosor de la sombra; por defecto, un pixel de la fuente
## con un maximo de 4 para que los textos grandes no queden empastados.
static func draw_text_shadowed(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, shadow: Color, outline: bool = false, offset: float = -1.0) -> void:
	var o: float = offset
	if o < 0.0:
		o = minf(px, 4.0)
	if outline:
		draw_text(ci, text, pos + Vector2(-o, 0.0), px, shadow)
		draw_text(ci, text, pos + Vector2(o, 0.0), px, shadow)
		draw_text(ci, text, pos + Vector2(0.0, -o), px, shadow)
		draw_text(ci, text, pos + Vector2(0.0, o), px, shadow)
		draw_text(ci, text, pos + Vector2(o, o * 2.0), px, shadow)
	else:
		draw_text(ci, text, pos + Vector2(o, o), px, shadow)
	draw_text(ci, text, pos, px, color)
