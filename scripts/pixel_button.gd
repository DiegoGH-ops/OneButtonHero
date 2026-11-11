extends Button
## Boton con aspecto pixel art. Hereda de Button para conservar foco, teclado,
## raton y pantalla tactil; solo se reemplaza el dibujado.

const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

var caption: String = "":
	set(value):
		caption = value
		queue_redraw()

var px: float = 4.0:
	set(value):
		px = value
		queue_redraw()

var fill: Color = Pal.BLUE:
	set(value):
		fill = value
		queue_redraw()

var fill_hot: Color = Pal.SKY
var text_color: Color = Pal.WHITE


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	Sfx.play("click")


func _draw() -> void:
	var mode: int = get_draw_mode()
	var down: bool = mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var hot: bool = mode == BaseButton.DRAW_HOVER or has_focus()
	var w: float = size.x
	var h: float = size.y
	var drop: float = px * 2.0
	var body_h: float = h - drop
	var body_y: float = drop if down else 0.0

	# Base oscura: da sensacion de volumen cuando el boton esta levantado.
	draw_rect(Rect2(0.0, drop, w, body_h), Pal.INK)
	# Borde (amarillo si tiene el foco o el raton encima).
	draw_rect(Rect2(0.0, body_y, w, body_h), Pal.YELLOW if hot else Pal.INK)
	# Relleno, brillo superior y sombra inferior.
	var c: Color = fill_hot if hot else fill
	if disabled:
		c = Pal.SLATE
	draw_rect(Rect2(px, body_y + px, w - px * 2.0, body_h - px * 2.0), c)
	draw_rect(Rect2(px, body_y + px, w - px * 2.0, px), c.lightened(0.35))
	draw_rect(Rect2(px, body_y + body_h - px * 2.0, w - px * 2.0, px), c.darkened(0.3))

	var text_w: float = PixelFont.text_width(caption, px)
	var text_pos: Vector2 = Vector2(roundf((w - text_w) * 0.5), body_y + roundf((body_h - PixelFont.text_height(px)) * 0.5))
	PixelFont.draw_text_shadowed(self, caption, text_pos, px, text_color, Pal.INK)
