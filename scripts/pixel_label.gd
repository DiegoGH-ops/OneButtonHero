extends Control
## Etiqueta de texto con la fuente pixel. Su `position` es el punto de anclaje:
## el texto se dibuja a la derecha (LEFT), centrado (CENTER) o a la izquierda (RIGHT).

const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

enum Align { LEFT, CENTER, RIGHT }

var text: String = "":
	set(value):
		if text != value:
			text = value
			queue_redraw()

var px: float = 4.0:
	set(value):
		px = value
		queue_redraw()

var color: Color = Pal.WHITE:
	set(value):
		color = value
		queue_redraw()

var shadow_color: Color = Pal.INK:
	set(value):
		shadow_color = value
		queue_redraw()

var align: int = Align.CENTER:
	set(value):
		align = value
		queue_redraw()

var outline: bool = false:
	set(value):
		outline = value
		queue_redraw()

## Grosor de la sombra en pixeles de pantalla (-1 = automatico).
var shadow_px: float = -1.0:
	set(value):
		shadow_px = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if text.is_empty():
		return
	var width: float = PixelFont.text_width(text, px)
	var x: float = 0.0
	if align == Align.CENTER:
		x = -roundf(width * 0.5)
	elif align == Align.RIGHT:
		x = -width
	PixelFont.draw_text_shadowed(self, text, Vector2(x, 0.0), px, color, shadow_color, outline, shadow_px)
