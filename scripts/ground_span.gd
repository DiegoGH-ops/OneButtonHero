extends StaticBody2D
## Tramo solido de suelo entre dos huecos. Tiene un unico rectangulo de
## colision (sin juntas) que el generador va alargando hacia la derecha.

const GROUND_Y := 560.0
const DEPTH := 400.0

var start_x: float = 0.0
var end_x: float = 0.0

var _shape: RectangleShape2D
var _collider: CollisionShape2D


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)


## Define el tramo [from_x, to_x] en coordenadas del mundo.
func set_range(from_x: float, to_x: float) -> void:
	start_x = from_x
	end_x = maxf(to_x, from_x + 8.0)
	var width: float = end_x - start_x
	_shape.size = Vector2(width, DEPTH)
	_collider.position = Vector2(start_x + width * 0.5, GROUND_Y + DEPTH * 0.5)
