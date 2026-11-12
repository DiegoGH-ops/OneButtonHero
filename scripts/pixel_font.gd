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
	"\"": [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", "....."],
	";": [".....", ".##..", ".##..", ".....", ".##..", ".##..", ".#..."],
	"«": [".....", "..#.#", ".#.#.", "#.#..", ".#.#.", "..#.#", "....."],
	"»": [".....", "#.#..", ".#.#.", "..#.#", ".#.#.", "#.#..", "....."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"#": [".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	# Cirilico (ruso). Las letras iguales a las latinas usan su glifo.
	"Б": ["#####", "#....", "#....", "####.", "#...#", "#...#", "####."],
	"Г": ["#####", "#....", "#....", "#....", "#....", "#....", "#...."],
	"Д": [".###.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"],
	"Ж": ["#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "#.#.#"],
	"З": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	"И": ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
	"Л": ["..###", ".#..#", ".#..#", ".#..#", ".#..#", ".#..#", "#...#"],
	"П": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"],
	"У": ["#...#", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"Ф": ["..#..", ".###.", "#.#.#", "#.#.#", ".###.", "..#..", "..#.."],
	"Ц": ["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####", "....#"],
	"Ч": ["#...#", "#...#", "#...#", ".####", "....#", "....#", "....#"],
	"Ш": ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"],
	"Щ": ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####", "....#"],
	"Ъ": ["##...", ".#...", ".#...", ".###.", ".#..#", ".#..#", ".###."],
	"Ы": ["#...#", "#...#", "#...#", "##..#", "#.#.#", "#.#.#", "##..#"],
	"Ь": ["#....", "#....", "#....", "####.", "#...#", "#...#", "####."],
	"Э": [".###.", "#...#", "....#", ".####", "....#", "#...#", ".###."],
	"Ю": ["#..#.", "#.#.#", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."],
	"Я": [".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"],
}

## Letras cirilicas que se dibujan igual que una latina.
const SAME_AS := {
	"А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O",
	"Р": "P", "С": "C", "Т": "T", "Х": "X",
}

## Letras con signos de otros idiomas (frances, portugues, aleman, italiano,
## turco, ruso): letra base + signo. Los signos estan en MARKS.
const COMPOSE := {
	"À": ["A", "grave"], "Â": ["A", "circ"], "Ä": ["A", "diaer"], "Ã": ["A", "tilde"],
	"Ç": ["C", "cedilla"], "È": ["E", "grave"], "Ê": ["E", "circ"], "Ë": ["E", "diaer"],
	"Ì": ["I", "grave"], "Î": ["I", "circ"], "Ï": ["I", "diaer"], "İ": ["I", "dot"],
	"Ò": ["O", "grave"], "Ô": ["O", "circ"], "Ö": ["O", "diaer"], "Õ": ["O", "tilde"],
	"Ù": ["U", "grave"], "Û": ["U", "circ"], "Ÿ": ["Y", "diaer"], "Ğ": ["G", "breve"],
	"Ş": ["S", "cedilla"], "Ё": ["E", "diaer"], "Й": ["И", "breve"],
}
const MARKS := {
	"grave": [Vector3i(1, -3, 1), Vector3i(2, -2, 1)],
	"circ": [Vector3i(2, -3, 1), Vector3i(1, -2, 1), Vector3i(3, -2, 1)],
	"diaer": [Vector3i(1, -2, 1), Vector3i(3, -2, 1)],
	"tilde": [Vector3i(0, -2, 1), Vector3i(1, -3, 1), Vector3i(2, -2, 1), Vector3i(3, -3, 1)],
	"cedilla": [Vector3i(2, 7, 1), Vector3i(1, 8, 2)],
	"breve": [Vector3i(1, -3, 1), Vector3i(3, -3, 1), Vector3i(2, -2, 1)],
	"dot": [Vector3i(2, -2, 1)],
}

## Letras acentuadas: se dibuja la letra base y se le agrega la tilde encima.
const ACCENTS := {
	"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N",
}

static var _runs_cache: Dictionary = {}


static var _pixel_cache: Dictionary = {}


## Texto en el idioma actual (si es un texto de origen conocido).
static func resolve(text: String) -> String:
	return Loc.s(text)


static func supports(ch: String) -> bool:
	return ch == " " or GLYPHS.has(ch) or ACCENTS.has(ch) or COMPOSE.has(ch) or SAME_AS.has(ch)


## Version del texto para la fuente pixel (mayusculas) o "" si tiene letras
## que la fuente pixel no tiene (chino, hindi...): entonces va en vectorial.
static func pixel_form(text: String) -> String:
	if _pixel_cache.has(text):
		return _pixel_cache[text]
	var out: String = ""
	var ok: bool = true
	for i in text.length():
		var ch: String = text[i]
		if not supports(ch):
			var upper: String = ch.to_upper()
			if supports(upper):
				ch = upper
			else:
				ok = false
				break
		out += ch
	if not ok:
		out = ""
	if _pixel_cache.size() > 4000:
		_pixel_cache.clear()
	_pixel_cache[text] = out
	return out


## true si este texto (ya traducido) se dibuja con fuente vectorial.
static func needs_vector(text: String) -> bool:
	if text.is_empty():
		return false
	return Loc.uses_vector() or pixel_form(text) == ""


static func _vector_font() -> Font:
	return Loc.font() if Loc.uses_vector() else Loc.fallback_font()


static func text_width(text: String, px: float) -> float:
	if text.is_empty():
		return 0.0
	var t: String = resolve(text)
	if needs_vector(t):
		return Loc.vector_width(t, px, _vector_font())
	return float(pixel_form(t).length() * ADVANCE - 1) * px


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
	var marks: Array = []
	if COMPOSE.has(ch):
		var parts: Array = COMPOSE[ch]
		base = String(parts[0])
		marks = MARKS.get(String(parts[1]), [])
	if SAME_AS.has(base):
		base = SAME_AS[base]
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
	for mark in marks:
		runs.append(mark)
	_runs_cache[ch] = runs
	return runs


static func draw_text(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color) -> void:
	_draw_resolved(ci, resolve(text), pos, px, color)


static func _draw_resolved(ci: CanvasItem, translated: String, pos: Vector2, px: float, color: Color) -> void:
	if needs_vector(translated):
		Loc.draw_vector(ci, translated, pos, px, color, _vector_font())
		return
	var text: String = pixel_form(translated)
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
	var t: String = resolve(text)
	if needs_vector(t):
		# Fuente vectorial: contorno real o sombra desplazada.
		var vf: Font = _vector_font()
		if outline:
			Loc.draw_vector_outline(ci, t, pos, px, shadow, maxf(o * 2.0, 4.0), vf)
		elif shadow.a > 0.0:
			Loc.draw_vector(ci, t, pos + Vector2(o, o), px, shadow, vf)
		Loc.draw_vector(ci, t, pos, px, color, vf)
		return
	if outline:
		_draw_resolved(ci, t, pos + Vector2(-o, 0.0), px, shadow)
		_draw_resolved(ci, t, pos + Vector2(o, 0.0), px, shadow)
		_draw_resolved(ci, t, pos + Vector2(0.0, -o), px, shadow)
		_draw_resolved(ci, t, pos + Vector2(0.0, o), px, shadow)
		_draw_resolved(ci, t, pos + Vector2(o, o * 2.0), px, shadow)
	elif shadow.a > 0.0:
		_draw_resolved(ci, t, pos + Vector2(o, o), px, shadow)
	_draw_resolved(ci, t, pos, px, color)


## Dibuja con la fuente pixel sin traducir ni cambiar de fuente (nombres de
## idioma en el selector). Devuelve false si el texto no cabe en ella.
static func draw_pixel_only(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, shadow: Color) -> bool:
	var form: String = pixel_form(text)
	if form == "":
		return false
	for pass_index in 2:
		var tint: Color = shadow if pass_index == 0 else color
		var off: float = minf(px, 4.0) if pass_index == 0 else 0.0
		var cursor: float = pos.x + off
		for i in form.length():
			var ch: String = form[i]
			if ch != " ":
				for item in _glyph_runs(ch):
					var run: Vector3i = item
					ci.draw_rect(Rect2(cursor + run.x * px, pos.y + off + run.y * px, run.z * px, px), tint)
			cursor += ADVANCE * px
	return true


static func pixel_only_width(text: String, px: float) -> float:
	var form: String = pixel_form(text)
	return float(form.length() * ADVANCE - 1) * px if form != "" else -1.0
