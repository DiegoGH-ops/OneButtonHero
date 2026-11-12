extends Button
## Boton con aspecto pixel art. Hereda de Button para conservar foco, teclado,
## raton y pantalla tactil; solo se reemplaza el dibujado. Se eleva y se
## ilumina con una animacion suave al pasar el cursor y se hunde al pulsarlo.

const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
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
## Sprite opcional que se dibuja a la izquierda del texto.
var icon_sprite: String = "":
	set(value):
		icon_sprite = value
		queue_redraw()
## Marca el boton como seleccionado (pestanas).
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _hover: float = 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)


func _on_pressed() -> void:
	Sfx.play("click")


func _on_mouse_entered() -> void:
	if not disabled:
		Sfx.play("hover")


func _is_hot() -> bool:
	var mode: int = get_draw_mode()
	return not disabled and (mode == BaseButton.DRAW_HOVER or mode == BaseButton.DRAW_HOVER_PRESSED or has_focus())


func _process(delta: float) -> void:
	var target: float = 1.0 if _is_hot() else 0.0
	if not is_equal_approx(_hover, target):
		_hover = move_toward(_hover, target, delta * 9.0)
		queue_redraw()


func _draw() -> void:
	var mode: int = get_draw_mode()
	var down: bool = mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var hot: bool = _is_hot() or selected
	var w: float = size.x
	var h: float = size.y
	var drop: float = px * 2.0
	var body_h: float = h - drop
	# Al pasar el cursor el boton se eleva; al pulsarlo se hunde.
	var lift: float = roundf(_hover * px)
	var body_y: float = drop if down else -lift

	draw_rect(Rect2(0.0, drop, w, body_h), Pal.INK)
	draw_rect(Rect2(0.0, body_y, w, body_h), Pal.YELLOW if hot else Pal.INK)
	var c: Color = fill.lerp(fill_hot, maxf(_hover, 1.0 if selected else 0.0))
	if disabled:
		c = Pal.SLATE
	draw_rect(Rect2(px, body_y + px, w - px * 2.0, body_h - px * 2.0), c)
	draw_rect(Rect2(px, body_y + px, w - px * 2.0, px), c.lightened(0.35))
	draw_rect(Rect2(px, body_y + body_h - px * 2.0, w - px * 2.0, px), c.darkened(0.3))

	var text_w: float = PixelFont.text_width(caption, px)
	var icon_w: float = 0.0
	var icon_size: Vector2 = Vector2.ZERO
	if icon_sprite != "":
		icon_size = PixelArt.size_of(icon_sprite, px)
		icon_w = icon_size.x + (px * 3.0 if caption != "" else 0.0)
	var start_x: float = roundf((w - text_w - icon_w) * 0.5)
	if icon_sprite != "":
		PixelArt.draw(self, icon_sprite, Vector2(start_x, body_y + roundf((body_h - icon_size.y) * 0.5)), px)
	var text_pos: Vector2 = Vector2(start_x + icon_w, body_y + roundf((body_h - PixelFont.text_height(px)) * 0.5))
	PixelFont.draw_text_shadowed(self, caption, text_pos, px, text_color if not disabled else Pal.SILVER, Pal.INK)
