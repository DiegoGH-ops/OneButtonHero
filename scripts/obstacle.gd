extends Area2D
## Obstaculo que dana al heroe al tocarlo: pinchos, roca, totem alto,
## llamas (iluminan de noche) o roca rodante que avanza hacia el heroe.
## `position` es la esquina inferior izquierda apoyada en el suelo, salvo en
## la roca rodante, donde es el centro de su base.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

enum Kind { SPIKES, ROCK, TOTEM, FLAMES, BOULDER }

const TILE := 32.0
const ROLL_SPEED := 130.0
const ROLL_LIMIT := 300.0
const ROLL_WAKE := 820.0

var kind: int = Kind.SPIKES
var count: int = 1
var destroyed: bool = false

## Datos para lights.gd (solo las llamas emiten luz).
var glow_radius: float = 90.0
var glow_color: Color = Pal.ORANGE
var glow_day: float = 0.3

var _time: float = 0.0
var _rolled: float = 0.0

@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("hazards")
	set_process(false)


## Configura el tipo. Debe llamarse despues de anadir el nodo al arbol.
func setup(p_kind: int, p_count: int = 1) -> void:
	kind = p_kind
	count = maxi(p_count, 1)
	var shape: RectangleShape2D = RectangleShape2D.new()
	if kind == Kind.SPIKES or kind == Kind.FLAMES:
		shape.size = Vector2(float(count) * TILE - 12.0, 18.0)
		_collider.position = Vector2(float(count) * TILE * 0.5, -9.0)
	elif kind == Kind.ROCK:
		shape.size = Vector2(40.0, 34.0)
		_collider.position = Vector2(28.0, -17.0)
	elif kind == Kind.TOTEM:
		shape.size = Vector2(30.0, 98.0)
		_collider.position = Vector2(24.0, -49.0)
	else:
		shape.size = Vector2(36.0, 36.0)
		_collider.position = Vector2(0.0, -22.0)
	_collider.shape = shape
	if kind == Kind.FLAMES:
		add_to_group("glow")
		glow_radius = 70.0 + float(count) * 16.0
	set_process(kind == Kind.FLAMES or kind == Kind.BOULDER)
	queue_redraw()


## Centro del obstaculo (para efectos).
func get_center() -> Vector2:
	if kind == Kind.BOULDER:
		return global_position + Vector2(0.0, -22.0)
	return global_position + _collider.position


## Zona de peligro para el sistema de timing: Vector3(izquierda, derecha,
## altura) en coordenadas del mundo.
func get_danger() -> Vector3:
	var x: float = global_position.x
	if kind == Kind.SPIKES or kind == Kind.FLAMES:
		return Vector3(x + 6.0, x + float(count) * TILE - 6.0, 18.0)
	if kind == Kind.ROCK:
		return Vector3(x + 8.0, x + 48.0, 34.0)
	if kind == Kind.TOTEM:
		return Vector3(x + 9.0, x + 39.0, 98.0)
	return Vector3(x - 18.0, x + 18.0, 40.0)


## Lo destruye (poderes Turbo y Onda). Devuelve false si ya no existia.
func destroy() -> bool:
	if destroyed:
		return false
	destroyed = true
	remove_from_group("hazards")
	set_deferred("monitorable", false)
	queue_free()
	return true


func _process(delta: float) -> void:
	_time += delta
	if kind == Kind.FLAMES:
		modulate = Daylight.unlit()
	if kind == Kind.BOULDER and _rolled < ROLL_LIMIT:
		if global_position.x - Daylight.player_pos.x < ROLL_WAKE:
			var step: float = ROLL_SPEED * delta
			position.x -= step
			_rolled += step
	queue_redraw()


func _draw() -> void:
	var skew: float = Daylight.shadow_skew()
	var alpha: float = Daylight.shadow_alpha()
	if kind == Kind.SPIKES:
		for i in count:
			PixelArt.draw(self, "spike", Vector2(float(i) * TILE, -28.0), 4.0)
	elif kind == Kind.FLAMES:
		for i in count:
			var frame: int = (int(_time * 9.0) + i) % 2
			PixelArt.draw(self, "flame_b" if frame == 1 else "flame_a", Vector2(float(i) * TILE, -32.0), 4.0)
	elif kind == Kind.ROCK:
		PixelArt.draw_shadow(self, "rock", Vector2(28.0, 0.0), 4.0, skew, alpha)
		PixelArt.draw(self, "rock", Vector2(0.0, -44.0), 4.0)
	elif kind == Kind.TOTEM:
		PixelArt.draw_shadow(self, "totem", Vector2(24.0, 0.0), 4.0, skew, alpha)
		PixelArt.draw(self, "totem", Vector2(0.0, -108.0), 4.0)
	else:
		PixelArt.draw_shadow(self, "rock", Vector2(0.0, 0.0), 4.0, skew, alpha)
		# La roca gira sobre su centro mientras rueda.
		draw_set_transform(Vector2(0.0, -24.0), -_rolled / 24.0, Vector2.ONE)
		PixelArt.draw(self, "rock", Vector2(-28.0, -24.0), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
