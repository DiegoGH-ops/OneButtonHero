extends Control
## Vista previa animada del heroe con el aspecto, la espada, la estela y el
## aura equipados. Se usa en la tienda y en la seleccion de personaje.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

const RUN_LEGS := ["hero_legs_0", "hero_legs_1", "hero_legs_2", "hero_legs_3"]
const RUN_CAPES := ["hero_cape_0", "hero_cape_1", "hero_cape_2", "hero_cape_1"]

## Tamano del pixel (4 = tamano de juego).
var px: float = 8.0
## Objetos a mostrar en lugar de los equipados (ranura -> entrada del catalogo).
var override: Dictionary = {}
## Ranuras que no se dibujan todavia (para presentaciones por partes).
var hidden: Dictionary = {}
var _time: float = 0.0


func _item(slot: String) -> Dictionary:
	if override.has(slot):
		return override[slot]
	return GameData.equipped_item(slot)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Dibuja al heroe con los pies en (0, 0) de este control.
func _draw() -> void:
	var skin: Dictionary = _item("skin")
	var sword: Dictionary = _item("sword")
	var trail: Dictionary = _item("trail")
	var aura: Dictionary = _item("aura")
	var color_map: Dictionary = skin["remap"]
	var skin_key: String = skin["id"]
	var s: float = px / 4.0
	var white: Color = Color(1.0, 1.0, 1.0, 1.0)

	var aura_hex: String = aura["color"]
	if aura_hex != "" and not hidden.has("aura"):
		var pulse: float = 0.8 + 0.2 * sin(_time * 5.0)
		PixelArt.draw_glow(self, Vector2(0.0, -32.0 * s), 90.0 * s * pulse, Color(Color(aura_hex), 0.55))
		if bool(aura.get("particles", false)):
			for i in 10:
				var t: float = fposmod(_time * 0.5 + float(i) * 0.1, 1.0)
				var ax: float = sin(float(i) * 2.4 + _time) * 34.0 * s
				var ay: float = (-10.0 - t * 80.0) * s
				var size: float = (4.0 - t * 2.0) * s
				draw_rect(Rect2(Vector2(ax, ay), Vector2(size, size)), Color(Color(aura_hex).lightened(0.3), 1.0 - t))

	# Estela: cuadraditos que salen de los pies hacia atras.
	var colors: Array = trail["colors"]
	var trail_count: int = 0 if hidden.has("trail") else 9
	for i in trail_count:
		var life: float = fposmod(_time * 1.6 + float(i) / 9.0, 1.0)
		var c: Color = Color(String(colors[i % colors.size()]))
		var pos: Vector2 = Vector2(-18.0 - life * 40.0, -4.0 - life * 22.0 - float(i % 3) * 5.0) * s
		var sq: float = (6.0 - life * 4.0) * s
		draw_rect(Rect2(pos, Vector2(sq, sq)), Color(c, 1.0 - life))
		if bool(trail.get("sparkle", false)) and i % 3 == 0:
			draw_rect(Rect2(pos + Vector2(sq * 0.5 - s, -3.0 * s), Vector2(2.0 * s, sq + 6.0 * s)), Color(1.0, 1.0, 1.0, (1.0 - life) * 0.7))

	draw_rect(Rect2(-24.0 * s, -2.0 * s, 48.0 * s, 4.0 * s), Color(0.0, 0.0, 0.0, 0.25))
	var index: int = int(_time * 9.0) % 4
	var bob: float = -4.0 * s if index % 2 == 1 else 0.0
	var legs: String = RUN_LEGS[index]
	var cape: String = String(skin.get("cape", "hero_cape_")) + String(RUN_CAPES[index]).substr(10)
	PixelArt.draw_skin(self, cape, Vector2(-38.0 * s, -36.0 * s + bob), px, white, color_map, skin_key)
	PixelArt.draw_skin(self, legs, Vector2(-28.0 * s, -16.0 * s), px, white, color_map, skin_key)
	PixelArt.draw_skin(self, String(skin.get("top", "hero_top")), Vector2(-28.0 * s, -68.0 * s + bob), px, white, color_map, skin_key)
	if hidden.has("sword"):
		return
	var sword_remap: Dictionary = sword["remap"]
	var sword_key: String = sword["id"]
	draw_set_transform(Vector2(18.0 * s, -26.0 * s + bob), 0.55 + sin(_time * 9.0) * 0.08, Vector2.ONE)
	PixelArt.draw_skin(self, String(sword.get("sprite", "sword")), Vector2(-10.0 * s, -40.0 * s), px, white, sword_remap, sword_key)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
