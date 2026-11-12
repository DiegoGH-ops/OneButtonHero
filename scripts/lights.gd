extends Node2D
## Luces del mundo dibujadas con mezcla aditiva: resplandor de monedas, gemas
## y llamas, halo del heroe y luciernagas. Ganan intensidad al anochecer.
## Cualquier nodo del grupo "glow" con las variables glow_radius, glow_color
## y glow_day (intensidad de dia) recibe su propio resplandor.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

const FIREFLIES := 16

## Centro de la camara en coordenadas del mundo.
var camera_x: float = 0.0
## Color del aura comprada en la tienda (transparente = sin aura).
var aura_color: Color = Color(0.0, 0.0, 0.0, 0.0)

var _time: float = 0.0


func _ready() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var dark: float = Daylight.darkness()
	for node in get_tree().get_nodes_in_group("glow"):
		var item: Node2D = node as Node2D
		if item == null or absf(item.global_position.x - camera_x) > 720.0:
			continue
		var strength: float = lerpf(float(item.get("glow_day")), 1.0, dark)
		if strength < 0.03:
			continue
		var color: Color = item.get("glow_color")
		var radius: float = float(item.get("glow_radius")) * (0.92 + 0.08 * sin(_time * 9.0 + item.global_position.x))
		PixelArt.draw_glow(self, item.global_position + Vector2(0.0, -6.0), radius, Color(color, 0.5 * strength))

	var hero: Vector2 = Daylight.player_pos + Vector2(0.0, -30.0)
	if dark > 0.05:
		PixelArt.draw_glow(self, hero, 200.0, Color(1.0, 0.82, 0.55, 0.30 * dark))
	if aura_color.a > 0.0:
		var pulse: float = 0.75 + 0.25 * sin(_time * 5.0)
		PixelArt.draw_glow(self, hero, 78.0 * pulse, Color(aura_color, 0.55))

	# Luciernagas: vagan por la pantalla durante la noche.
	if dark > 0.2:
		for i in FIREFLIES:
			var sx: float = fposmod(PixelArt.hash01(i, 31) * 1400.0 + sin(_time * 0.6 + float(i)) * 60.0 - camera_x * 0.15, 1400.0) - 60.0
			var sy: float = 300.0 + PixelArt.hash01(i, 32) * 230.0 + sin(_time * 1.3 + float(i) * 2.1) * 26.0
			var blink: float = 0.5 + 0.5 * sin(_time * 3.0 + float(i) * 1.7)
			var pos: Vector2 = Vector2(camera_x - 640.0 + sx, sy)
			PixelArt.draw_glow(self, pos, 12.0, Color(Pal.LIME, 0.8 * dark * blink))
			draw_rect(Rect2(pos - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(Pal.YELLOW, dark * blink))
