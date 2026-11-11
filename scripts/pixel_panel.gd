extends Control
## Panel decorativo con borde pixel art. Se usa como fondo de menus y avisos.

const Pal = preload("res://scripts/palette.gd")

var px: float = 4.0
var fill: Color = Pal.NAVY
var border: Color = Pal.INK
var accent: Color = Pal.BLUE


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Sombra proyectada.
	draw_rect(Rect2(px * 2.0, px * 2.0, w, h), Color(0.0, 0.0, 0.0, 0.35))
	# Borde exterior con las esquinas recortadas (aspecto pixelado),
	# filete de color y relleno.
	draw_rect(Rect2(px, 0.0, w - px * 2.0, h), border)
	draw_rect(Rect2(0.0, px, w, h - px * 2.0), border)
	draw_rect(Rect2(px, px, w - px * 2.0, h - px * 2.0), accent)
	draw_rect(Rect2(px * 2.0, px * 2.0, w - px * 4.0, h - px * 4.0), fill)
	# Brillo superior.
	draw_rect(Rect2(px * 2.0, px * 2.0, w - px * 4.0, px), fill.lightened(0.15))
