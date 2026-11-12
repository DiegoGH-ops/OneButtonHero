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
## Destello de luz de los eventos importantes (LEGENDARY, meta, jefe...).
var _flash_color: Color = Color(1.0, 1.0, 1.0, 0.0)
var _flash: float = 0.0
var _flash_time: float = 0.3


## Ilumina toda la escena un instante (se desvanece solo).
func flash(color: Color, strength: float = 0.5, duration: float = 0.35) -> void:
	_flash_color = color
	_flash = strength
	_flash_time = maxf(duration, 0.05)


func _ready() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta / _flash_time * 0.5, 0.0)
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
	# Halo suave tambien de dia: separa al heroe del fondo (contraste).
	PixelArt.draw_glow(self, hero, 70.0, Color(1.0, 0.95, 0.85, 0.10))
	if dark > 0.05:
		PixelArt.draw_glow(self, hero, 200.0, Color(1.0, 0.82, 0.55, 0.30 * dark))
	_draw_world_lights(dark)
	if _flash > 0.01:
		draw_rect(Rect2(camera_x - 700.0, -100.0, 1400.0, 900.0), Color(_flash_color, _flash * 0.6))
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


## Luces propias de cada mundo: lava que alumbra desde los abismos en
## Infernus, destellos de cristal en Amethystia, frio azulado en Frostfall y
## reflejos dorados en Solaris. Son pocas y se recortan a la camara.
func _draw_world_lights(dark: float) -> void:
	var style: String = String(Daylight.theme.get("style", "forest"))
	var left: float = camera_x - 700.0
	var right: float = camera_x + 700.0
	match style:
		"inferno":
			for item in Daylight.holes:
				var hole: Vector2 = item
				if hole.y < left or hole.x > right:
					continue
				var mid: float = (hole.x + hole.y) * 0.5
				var pulse: float = 0.8 + 0.2 * sin(_time * 3.0 + mid)
				PixelArt.draw_glow(self, Vector2(mid, Daylight.GROUND_Y + 40.0), (hole.y - hole.x) * 0.9 + 60.0, Color(Pal.ORANGE, 0.45 * pulse))
			# Brasas que iluminan el suelo.
			var base: float = floor(left / 1400.0) * 1400.0
			for rep in 2:
				for i in 5:
					var x: float = base + float(rep) * 1400.0 + PixelArt.hash01(i, 33) * 1400.0
					if x > left and x < right:
						PixelArt.draw_glow(self, Vector2(x, Daylight.GROUND_Y), 90.0, Color(Pal.RED, 0.18 + 0.08 * sin(_time * 4.0 + float(i))))
		"crystal":
			for i in 10:
				var sx: float = fposmod(PixelArt.hash01(i, 34) * 1400.0 - camera_x * 0.2, 1400.0) - 60.0
				var sy: float = 260.0 + PixelArt.hash01(i, 35) * 260.0
				var twinkle: float = maxf(sin(_time * 2.5 + float(i) * 1.9), 0.0)
				PixelArt.draw_glow(self, Vector2(camera_x - 640.0 + sx, sy), 26.0, Color(Pal.PINK if i % 2 == 0 else Pal.CYAN, 0.55 * twinkle))
		"frost":
			PixelArt.draw_glow(self, Daylight.player_pos + Vector2(0.0, -30.0), 120.0, Color(Pal.CYAN, 0.08 + 0.12 * dark))
		"desert":
			if dark < 0.5:
				PixelArt.draw_glow(self, Vector2(camera_x + 400.0, 120.0), 420.0, Color(Pal.YELLOW, 0.10 * (1.0 - dark)))
