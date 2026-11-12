extends Node
## Autoload "Loc": idioma del juego (21 idiomas, ingles por defecto).
##
## - Las traducciones viven en translations/strings.csv (una columna por
##   idioma, claves como MENU_PLAY). Godot las importa como Translation.
## - El juego esta escrito con textos en espanol; LocKeys.SOURCE relaciona
##   cada texto espanol con su clave. Loc.s("JUGAR") devuelve el texto en el
##   idioma actual. PixelFont traduce ademas al dibujar cualquier texto que
##   coincida exactamente con un texto de origen (red de seguridad).
## - Fuentes: los idiomas con alfabeto latino o cirilico usan la fuente
##   pixel del juego; el resto, fuentes vectoriales (Unifont, de estilo
##   pixel, para chino, japones, coreano y vietnamita; fuentes del sistema
##   con Unifont de respaldo para las escrituras indias y el arabe).
## - Arabe y urdu se escriben de derecha a izquierda (ver is_rtl()).

signal language_changed

const LocKeys = preload("res://scripts/loc_keys.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

## [codigo de Godot, nombre en su propia escritura]
const LANGUAGES := [
	["en", "English"], ["es", "Español"], ["zh_CN", "简体中文"], ["hi", "हिन्दी"],
	["ar", "العربية"], ["pt", "Português"], ["bn", "বাংলা"], ["fr", "Français"],
	["ru", "Русский"], ["id", "Bahasa Indonesia"], ["ur", "اردو"], ["de", "Deutsch"],
	["ja", "日本語"], ["pa", "ਪੰਜਾਬੀ"], ["mr", "मराठी"], ["te", "తెలుగు"],
	["tr", "Türkçe"], ["ko", "한국어"], ["ta", "தமிழ்"], ["vi", "Tiếng Việt"],
	["it", "Italiano"],
]
const DEFAULT_LANGUAGE := "en"
const RTL_LANGUAGES := ["ar", "ur"]
## Idiomas que se dibujan con fuente vectorial (su escritura no cabe en la
## fuente pixel 5x7).
const VECTOR_LANGUAGES := ["zh_CN", "ja", "ko", "vi", "hi", "mr", "bn", "pa", "te", "ta", "ar", "ur"]
## Fuentes del sistema preferidas por escritura (la primera que exista).
const SYSTEM_FONTS := {
	"hi": ["Nirmala UI", "Noto Sans Devanagari", "Mangal", "Kohinoor Devanagari", "Devanagari Sangam MN", "Lohit Devanagari"],
	"mr": ["Nirmala UI", "Noto Sans Devanagari", "Mangal", "Kohinoor Devanagari", "Devanagari Sangam MN", "Lohit Devanagari"],
	"bn": ["Nirmala UI", "Noto Sans Bengali", "Vrinda", "Kohinoor Bangla", "Bangla Sangam MN", "Lohit Bengali"],
	"pa": ["Nirmala UI", "Noto Sans Gurmukhi", "Raavi", "Gurmukhi MN", "Lohit Gurmukhi"],
	"te": ["Nirmala UI", "Noto Sans Telugu", "Gautami", "Kohinoor Telugu", "Telugu Sangam MN", "Lohit Telugu"],
	"ta": ["Nirmala UI", "Noto Sans Tamil", "Latha", "Tamil Sangam MN", "Lohit Tamil"],
	"ar": ["Segoe UI", "Noto Sans Arabic", "Noto Naskh Arabic", "Geeza Pro", "Tahoma", "Arial"],
	"ur": ["Noto Nastaliq Urdu", "Urdu Typesetting", "Segoe UI", "Noto Naskh Arabic", "Geeza Pro", "Arial"],
}
const PIXEL_FONT_PATH := "res://fonts/unifont.otf"

var language: String = DEFAULT_LANGUAGE
var _vector: bool = false
var _rtl: bool = false
var _unifont: Font
var _font: Font
## Textos ya resueltos (origen -> traduccion) del idioma actual.
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_unifont = load(PIXEL_FONT_PATH) as Font
	set_language(String(GameData.language), false)


func language_name(code: String) -> String:
	for item in LANGUAGES:
		var entry: Array = item
		if String(entry[0]) == code:
			return String(entry[1])
	return code


func is_rtl() -> bool:
	return _rtl


func uses_vector() -> bool:
	return _vector


## Cambia el idioma al instante y guarda la preferencia (ajustes, no progreso).
func set_language(code: String, save: bool = true) -> void:
	var valid: bool = false
	for item in LANGUAGES:
		if String(Array(item)[0]) == code:
			valid = true
	if not valid:
		code = DEFAULT_LANGUAGE
	language = code
	TranslationServer.set_locale(code)
	_vector = VECTOR_LANGUAGES.has(code)
	_rtl = RTL_LANGUAGES.has(code)
	_font = _make_font(code)
	_cache.clear()
	if save:
		GameData.language = code
		GameData.apply_settings()
	language_changed.emit()
	# Todo lo que esta en pantalla se vuelve a dibujar en el idioma nuevo.
	if is_inside_tree():
		get_tree().root.propagate_call("queue_redraw")


func _make_font(code: String) -> Font:
	if not SYSTEM_FONTS.has(code):
		return _unifont
	var system: SystemFont = SystemFont.new()
	system.font_names = PackedStringArray(SYSTEM_FONTS[code])
	system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	if _unifont != null:
		system.fallbacks = [_unifont]
	return system


## Traduce un texto de origen (espanol). Si no es un texto conocido se
## devuelve tal cual (numeros, nombres ya traducidos...).
func s(text: String) -> String:
	if text.is_empty():
		return text
	if _cache.has(text):
		return _cache[text]
	var result: String = text
	var key: String = String(LocKeys.SOURCE.get(text, ""))
	if key != "":
		var translated: String = String(TranslationServer.translate(key))
		if translated != key and translated != "":
			result = translated
		elif language == "es":
			result = text
	_cache[text] = result
	return result


## Traduce por clave (MENU_PLAY...).
func k(key: String) -> String:
	return String(TranslationServer.translate(key))


## Texto con formato: Loc.f("RECOGE %d MONEDAS", [80]).
func f(text: String, args: Array) -> String:
	return s(text) % args


# ---------------------------------------------------- fuentes vectoriales --

func font() -> Font:
	return _font if _font != null else _unifont


func fallback_font() -> Font:
	return _unifont


## Tamano de letra vectorial equivalente a un texto pixel de tamano `px`.
## Unifont se ve nitido en multiplos de 16.
func font_size(px: float, use_unifont: bool) -> int:
	if use_unifont:
		return 16 * maxi(1, int(roundf(px * 0.5)))
	return maxi(12, int(roundf(px * 8.5)))


func is_unifont(fnt: Font) -> bool:
	return fnt == _unifont


## Ancho de un texto dibujado con la fuente vectorial.
func vector_width(text: String, px: float, fnt: Font) -> float:
	var size: int = font_size(px, is_unifont(fnt))
	return fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Dibuja con la fuente vectorial ocupando la misma caja que un texto pixel
## de 7 filas (pos = esquina superior izquierda).
func draw_vector(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, fnt: Font) -> void:
	var size: int = font_size(px, is_unifont(fnt))
	var box: float = 7.0 * px
	var ascent: float = fnt.get_ascent(size)
	var descent: float = fnt.get_descent(size)
	var baseline: float = pos.y + roundf((box - (ascent + descent)) * 0.5 + ascent)
	ci.draw_string(fnt, Vector2(roundf(pos.x), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func draw_vector_outline(ci: CanvasItem, text: String, pos: Vector2, px: float, color: Color, outline: float, fnt: Font) -> void:
	var size: int = font_size(px, is_unifont(fnt))
	var box: float = 7.0 * px
	var ascent: float = fnt.get_ascent(size)
	var descent: float = fnt.get_descent(size)
	var baseline: float = pos.y + roundf((box - (ascent + descent)) * 0.5 + ascent)
	ci.draw_string_outline(fnt, Vector2(roundf(pos.x), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, int(outline), color)


## Idiomas que no separan las palabras con espacios.
const NO_SPACES := ["zh_CN", "ja"]


## Traduce un texto y lo corta en lineas de unas `chars` letras de la fuente
## pixel (medidas a tamano 2, asi vale tambien para las otras escrituras).
func wrap(text: String, chars: int) -> Array:
	var source: String = s(text)
	var budget: float = float(chars) * 12.0
	var lines: Array = []
	if NO_SPACES.has(language):
		var line: String = ""
		for i in source.length():
			var ch: String = source[i]
			if line != "" and PixelFont.text_width(line + ch, 2.0) > budget:
				lines.append(line)
				line = ch.strip_edges() if ch == " " else ch
			else:
				line += ch
		if line.strip_edges() != "":
			lines.append(line)
		return lines
	var current: String = ""
	for word in source.split(" ", false):
		var candidate: String = word if current == "" else current + " " + word
		if current != "" and PixelFont.text_width(candidate, 2.0) > budget:
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return lines


# ------------------------------------------------- nombres de los idiomas --

var _native_fonts: Dictionary = {}


## Fuente con la que se escribe el nombre de un idioma en el selector
## (cada uno en su propia escritura, sea cual sea el idioma actual).
func _native_font(code: String) -> Font:
	if not SYSTEM_FONTS.has(code):
		return _unifont
	if not _native_fonts.has(code):
		_native_fonts[code] = _make_font(code)
	return _native_fonts[code]


func native_width(code: String, px: float) -> float:
	var label: String = language_name(code)
	var pixel: float = PixelFont.pixel_only_width(label, px)
	if pixel >= 0.0 and not SYSTEM_FONTS.has(code):
		return pixel
	return vector_width(label, px, _native_font(code))


func draw_native(ci: CanvasItem, code: String, pos: Vector2, px: float, color: Color) -> void:
	var label: String = language_name(code)
	if not SYSTEM_FONTS.has(code) and PixelFont.draw_pixel_only(ci, label, pos, px, color, Color("1a1c2c")):
		return
	var fnt: Font = _native_font(code)
	draw_vector(ci, label, pos + Vector2(2.0, 2.0), px, Color("1a1c2c"), fnt)
	draw_vector(ci, label, pos, px, color, fnt)
