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
	# Degradado vertical suave dentro del panel.
	var bands: int = 6
	var inner_h: float = h - px * 4.0
	for i in bands:
		var t: float = float(i) / float(bands)
		draw_rect(Rect2(px * 2.0, px * 2.0 + inner_h * t, w - px * 4.0, inner_h / float(bands) + 1.0), Color(fill.lightened(0.08), 0.35 * (1.0 - t)))
	# Bisel: brillo arriba e izquierda, sombra abajo y derecha.
	draw_rect(Rect2(px * 2.0, px * 2.0, w - px * 4.0, px), fill.lightened(0.18))
	draw_rect(Rect2(px * 2.0, px * 2.0, px, h - px * 4.0), fill.lightened(0.1))
	draw_rect(Rect2(px * 2.0, h - px * 3.0, w - px * 4.0, px), fill.darkened(0.25))
	draw_rect(Rect2(w - px * 3.0, px * 2.0, px, h - px * 4.0), fill.darkened(0.2))
	# Remaches en las esquinas.
	if w > px * 16.0 and h > px * 16.0:
		var rivet: Color = accent.lightened(0.35)
		for corner in [Vector2(px * 3.0, px * 3.0), Vector2(w - px * 5.0, px * 3.0), Vector2(px * 3.0, h - px * 5.0), Vector2(w - px * 5.0, h - px * 5.0)]:
			draw_rect(Rect2(corner, Vector2(px * 2.0, px * 2.0)), rivet)
			draw_rect(Rect2(corner + Vector2(px, px), Vector2(px, px)), accent.darkened(0.3))
