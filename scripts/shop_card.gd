extends Button
## Tarjeta de un articulo de la tienda. Dibuja icono, nombre, estado y precio,
## y se anima al pasar el cursor, al comprar (pulso) o si faltan monedas
## (sacudida). shop.gd rellena sus datos con configure().

signal hovered(card: Button)

const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

## Categoria: "upgrade", "consumable", "skin", "sword", "trail" o "aura".
var category: String = ""
var item: Dictionary = {}
## Icono de la moneda con la que se paga ("coin_0" o "gem").
var currency_sprite: String = "coin_0"

var _title: String = ""
var _status: String = ""
var _price_text: String = ""
var _price_color: Color = Pal.YELLOW
var _show_coin: bool = false
var _level: int = -1
var _max_level: int = 0
var _highlight: bool = false
var _hover: float = 0.0
var _pulse: float = 0.0
var _shake: float = 0.0
var _time: float = 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)


func _ready() -> void:
	mouse_entered.connect(_on_hot)
	focus_entered.connect(_on_hot)


func _on_hot() -> void:
	Sfx.play("hover")
	hovered.emit(self)


## Actualiza los textos de la tarjeta.
func configure(title: String, status: String, price_text: String, price_color: Color, show_coin: bool, level: int, max_level: int, highlight: bool) -> void:
	_title = title
	_status = status
	_price_text = price_text
	_price_color = price_color
	_show_coin = show_coin
	_level = level
	_max_level = max_level
	_highlight = highlight
	queue_redraw()


## Animacion de compra realizada.
func pulse() -> void:
	_pulse = 1.0


## Animacion de "no tienes suficientes monedas".
func shake() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	_time += delta
	var hot: bool = is_hovered() or has_focus()
	_hover = move_toward(_hover, 1.0 if hot else 0.0, delta * 9.0)
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	_shake = maxf(_shake - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var offset: Vector2 = Vector2(sin(_time * 60.0) * 8.0 * _shake, -roundf(_hover * 6.0))
	var grow: float = 1.0 + 0.08 * _pulse
	draw_set_transform(Vector2(w * 0.5, h * 0.5) + offset, 0.0, Vector2(grow, grow))
	var o: Vector2 = Vector2(-w * 0.5, -h * 0.5)

	# Sombra, borde y fondo.
	draw_rect(Rect2(o + Vector2(6.0, 8.0) + Vector2(0.0, _hover * 6.0), Vector2(w, h)), Color(0.0, 0.0, 0.0, 0.35))
	var border: Color = Pal.INK
	if _highlight:
		border = Pal.LIME
	if _hover > 0.5:
		border = Pal.YELLOW
	draw_rect(Rect2(o, Vector2(w, h)), border)
	var fill: Color = Pal.NAVY.lerp(Pal.BLUE, _hover * 0.6).lerp(Pal.WHITE, _pulse * 0.6)
	draw_rect(Rect2(o + Vector2(4.0, 4.0), Vector2(w - 8.0, h - 8.0)), fill)
	draw_rect(Rect2(o + Vector2(4.0, 4.0), Vector2(w - 8.0, 84.0)), fill.darkened(0.25))

	_draw_icon(o + Vector2(w * 0.5, 46.0))

	var name_w: float = PixelFont.text_width(_title, 2.0)
	PixelFont.draw_text_shadowed(self, _title, o + Vector2(roundf((w - name_w) * 0.5), 100.0), 2.0, Pal.WHITE, Pal.INK)

	# Estado: nivel (pips), existencias o "EQUIPADO".
	if _level >= 0:
		var pip_w: float = 22.0
		var total: float = float(_max_level) * (pip_w + 6.0) - 6.0
		for i in _max_level:
			var color: Color = Pal.LIME if i < _level else Pal.SLATE
			draw_rect(Rect2(o + Vector2(roundf((w - total) * 0.5) + float(i) * (pip_w + 6.0), 126.0), Vector2(pip_w, 10.0)), Pal.INK)
			draw_rect(Rect2(o + Vector2(roundf((w - total) * 0.5) + float(i) * (pip_w + 6.0) + 2.0, 128.0), Vector2(pip_w - 4.0, 6.0)), color)
	elif _status != "":
		var status_w: float = PixelFont.text_width(_status, 2.0)
		PixelFont.draw_text_shadowed(self, _status, o + Vector2(roundf((w - status_w) * 0.5), 124.0), 2.0, _status_color(), Pal.INK)

	# Precio.
	var price_w: float = PixelFont.text_width(_price_text, 3.0)
	var coin_w: float = 30.0 if _show_coin else 0.0
	var px0: float = roundf((w - price_w - coin_w) * 0.5)
	draw_rect(Rect2(o + Vector2(12.0, 148.0), Vector2(w - 24.0, 38.0)), Color(Pal.INK, 0.55))
	if _show_coin:
		PixelArt.draw(self, currency_sprite, o + Vector2(px0, 155.0), 3.0)
	PixelFont.draw_text_shadowed(self, _price_text, o + Vector2(px0 + coin_w, 157.0), 3.0, _price_color, Pal.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Color del estado; las rarezas tienen el suyo.
func _status_color() -> Color:
	if _status == "RARE":
		return Pal.SKY
	if _status == "EPIC":
		return Pal.PINK
	if _status == "LEGENDARY":
		return Pal.ORANGE
	if _status == "MYTHIC":
		return Pal.RED
	return Pal.LIME if _highlight else Pal.SILVER


## Icono segun la categoria, centrado en `center`.
func _draw_icon(center: Vector2) -> void:
	var white: Color = Color(1.0, 1.0, 1.0, 1.0)
	if category == "skin":
		var remap: Dictionary = item["remap"]
		PixelArt.draw_skin(self, "hero_top", center + Vector2(-28.0, -30.0), 4.0, white, remap, String(item["id"]))
	elif category == "sword":
		var sword_remap: Dictionary = item["remap"]
		PixelArt.draw_skin(self, "sword", center + Vector2(-10.0, -32.0), 4.0, white, sword_remap, String(item["id"]))
	elif category == "trail":
		var colors: Array = item["colors"]
		for i in 7:
			var life: float = fposmod(_time * 1.4 + float(i) / 7.0, 1.0)
			var c: Color = Color(String(colors[i % colors.size()]))
			var sq: float = 14.0 - life * 9.0
			draw_rect(Rect2(center + Vector2(34.0 - life * 76.0, 12.0 - life * 26.0 - float(i % 3) * 6.0), Vector2(sq, sq)), Color(c, 1.0 - life * 0.8))
	elif category == "aura":
		var hex: String = item["color"]
		if hex == "":
			PixelFont.draw_text_shadowed(self, "-", center + Vector2(-10.0, -14.0), 4.0, Pal.SILVER, Pal.INK)
		else:
			var pulse_r: float = 34.0 + 5.0 * sin(_time * 5.0)
			PixelArt.draw_glow(self, center, pulse_r + 8.0, Color(Color(hex), 0.9))
			PixelArt.draw_glow(self, center, pulse_r * 0.5, Color(Pal.WHITE, 0.8))
	else:
		var sprite: String = item["icon"]
		var sz: Vector2 = PixelArt.size_of(sprite, 6.0)
		var scale_px: float = 6.0 if sz.y <= 66.0 else 4.0
		sz = PixelArt.size_of(sprite, scale_px)
		PixelArt.draw(self, sprite, center - sz * 0.5 + Vector2(0.0, roundf(sin(_time * 3.0) * 2.0)), scale_px)
