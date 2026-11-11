extends Area2D
## Obstaculo fijo que dana al heroe al tocarlo: pinchos, roca o totem alto.
## `position` es la esquina inferior izquierda, apoyada sobre el suelo.

const PixelArt = preload("res://scripts/pixel_art.gd")

enum Kind { SPIKES, ROCK, TOTEM }

const TILE := 32.0

var kind: int = Kind.SPIKES
var count: int = 1

@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("hazards")


## Configura el tipo. Debe llamarse despues de anadir el nodo al arbol.
func setup(p_kind: int, p_count: int = 1) -> void:
	kind = p_kind
	count = maxi(p_count, 1)
	var shape: RectangleShape2D = RectangleShape2D.new()
	match kind:
		Kind.SPIKES:
			shape.size = Vector2(float(count) * TILE - 12.0, 18.0)
			_collider.position = Vector2(float(count) * TILE * 0.5, -9.0)
		Kind.ROCK:
			shape.size = Vector2(40.0, 34.0)
			_collider.position = Vector2(28.0, -17.0)
		_:
			shape.size = Vector2(30.0, 98.0)
			_collider.position = Vector2(24.0, -49.0)
	_collider.shape = shape
	queue_redraw()


## Ancho visual del obstaculo en pixeles.
func get_width() -> float:
	if kind == Kind.SPIKES:
		return float(count) * TILE
	if kind == Kind.ROCK:
		return 56.0
	return 48.0


func _draw() -> void:
	match kind:
		Kind.SPIKES:
			for i in count:
				PixelArt.draw(self, "spike", Vector2(float(i) * TILE, -28.0), 4.0)
		Kind.ROCK:
			PixelArt.draw(self, "rock", Vector2(0.0, -44.0), 4.0)
		_:
			PixelArt.draw(self, "totem", Vector2(0.0, -108.0), 4.0)
