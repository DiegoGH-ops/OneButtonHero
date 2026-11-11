extends StaticBody2D
## Plataforma flotante. Usa colision de un solo sentido: el heroe puede
## atravesarla saltando desde abajo y aterrizar encima.

const PixelArt = preload("res://scripts/pixel_art.gd")

const TILE := 32.0

var width: float = 192.0


## `position` debe ser la esquina superior izquierda de la superficie.
func setup(p_width: float) -> void:
	width = maxf(p_width, TILE * 2.0)
	collision_layer = 1
	collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width, 20.0)
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(width * 0.5, 10.0)
	collider.one_way_collision = true
	collider.one_way_collision_margin = 6.0
	add_child(collider)
	queue_redraw()


func _draw() -> void:
	var tiles: int = int(width / TILE)
	for i in tiles:
		var sprite: String = "plat_m"
		if i == 0:
			sprite = "plat_l"
		elif i == tiles - 1:
			sprite = "plat_r"
		PixelArt.draw(self, sprite, Vector2(float(i) * TILE, 0.0), 4.0)
