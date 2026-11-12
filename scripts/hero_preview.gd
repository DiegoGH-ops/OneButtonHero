extends Control
## Vista previa animada del heroe con el aspecto, la espada, la estela y el
## aura equipados. Se usa en la tienda y en la seleccion de personaje.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

const RUN_LEGS := ["hero_legs_0", "hero_legs_1", "hero_legs_2", "hero_legs_3"]
const RUN_CAPES := ["hero_cape_0", "hero_cape_1", "hero_cape_2", "hero_cape_1"]

## Tamano del pixel (4 = tamano de juego).
var px: float = 8.0
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Dibuja al heroe con los pies en (0, 0) de este control.
func _draw() -> void:
	var skin: Dictionary = GameData.equipped_item("skin")
	var sword: Dictionary = GameData.equipped_item("sword")
	var trail: Dictionary = GameData.equipped_item("trail")
	var aura: Dictionary = GameData.equipped_item("aura")
	var color_map: Dictionary = skin["remap"]
	var skin_key: String = skin["id"]
	var s: float = px / 4.0
	var white: Color = Color(1.0, 1.0, 1.0, 1.0)

	var aura_hex: String = aura["color"]
	if aura_hex != "":
		var pulse: float = 0.8 + 0.2 * sin(_time * 5.0)
		PixelArt.draw_glow(self, Vector2(0.0, -32.0 * s), 90.0 * s * pulse, Color(Color(aura_hex), 0.55))

	# Estela: cuadraditos que salen de los pies hacia atras.
	var colors: Array = trail["colors"]
	for i in 9:
		var life: float = fposmod(_time * 1.6 + float(i) / 9.0, 1.0)
		var c: Color = Color(String(colors[i % colors.size()]))
		var pos: Vector2 = Vector2(-18.0 - life * 40.0, -4.0 - life * 22.0 - float(i % 3) * 5.0) * s
		var sq: float = (6.0 - life * 4.0) * s
		draw_rect(Rect2(pos, Vector2(sq, sq)), Color(c, 1.0 - life))

	draw_rect(Rect2(-24.0 * s, -2.0 * s, 48.0 * s, 4.0 * s), Color(0.0, 0.0, 0.0, 0.25))
	var index: int = int(_time * 9.0) % 4
	var bob: float = -4.0 * s if index % 2 == 1 else 0.0
	var legs: String = RUN_LEGS[index]
	var cape: String = RUN_CAPES[index]
	PixelArt.draw_skin(self, cape, Vector2(-38.0 * s, -36.0 * s + bob), px, white, color_map, skin_key)
	PixelArt.draw_skin(self, legs, Vector2(-28.0 * s, -16.0 * s), px, white, color_map, skin_key)
	PixelArt.draw_skin(self, "hero_top", Vector2(-28.0 * s, -68.0 * s + bob), px, white, color_map, skin_key)
	var sword_remap: Dictionary = sword["remap"]
	var sword_key: String = sword["id"]
	draw_set_transform(Vector2(18.0 * s, -26.0 * s + bob), 0.55 + sin(_time * 9.0) * 0.08, Vector2.ONE)
	PixelArt.draw_skin(self, "sword", Vector2(-10.0 * s, -40.0 * s), px, white, sword_remap, sword_key)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
