extends Area2D
## Enemigo. Tres tipos visualmente distintos:
##   SLIME  - baba verde que brinca en su sitio.
##   GOBLIN - diablillo rojo que camina hacia el heroe.
##   BAT    - murcielago que vuela a la altura del pecho.
## Todos se eliminan con un golpe de espada y danan al heroe si lo tocan.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")

enum Kind { SLIME, GOBLIN, BAT }

const POINTS := [25, 40, 60]
const WALK_SPEED := 70.0
const WALK_LIMIT := 120.0
const WAKE_DISTANCE := 760.0

var kind: int = Kind.SLIME
var dead: bool = false

var _time: float = 0.0
var _walked: float = 0.0
var _base_y: float = 0.0
var _alert: bool = false
var _player: Node2D

@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_time = randf() * 6.0


## Configura el tipo. Debe llamarse despues de anadir el nodo al arbol
## y de asignarle su posicion.
func setup(p_kind: int) -> void:
	kind = clampi(p_kind, 0, POINTS.size() - 1)
	_base_y = position.y
	var shape: RectangleShape2D = RectangleShape2D.new()
	match kind:
		Kind.SLIME:
			shape.size = Vector2(36.0, 26.0)
			_collider.position = Vector2(0.0, -13.0)
		Kind.GOBLIN:
			shape.size = Vector2(34.0, 44.0)
			_collider.position = Vector2(0.0, -22.0)
		_:
			shape.size = Vector2(40.0, 24.0)
			_collider.position = Vector2(0.0, 0.0)
	_collider.shape = shape
	queue_redraw()


func get_points() -> int:
	return POINTS[kind]


## Elimina al enemigo. Devuelve los puntos que otorga (0 si ya estaba muerto).
func kill() -> int:
	if dead:
		return 0
	dead = true
	remove_from_group("enemies")
	set_deferred("monitorable", false)
	queue_free()
	return get_points()


func _process(delta: float) -> void:
	_time += delta
	_alert = false
	if is_instance_valid(_player):
		var dx: float = global_position.x - _player.global_position.x
		if kind == Kind.GOBLIN and dx < WAKE_DISTANCE and _walked < WALK_LIMIT:
			var step: float = WALK_SPEED * delta
			position.x -= step
			_walked += step
		if _player.has_method("is_enemy_in_reach"):
			_alert = bool(_player.call("is_enemy_in_reach", self))
	if kind == Kind.BAT:
		position.y = _base_y + sin(_time * 4.0) * 12.0
	queue_redraw()


func _draw() -> void:
	var top: float = -36.0
	match kind:
		Kind.SLIME:
			var s: float = sin(_time * 6.0)
			var hop: float = -absf(sin(_time * 3.0)) * 10.0
			draw_set_transform(Vector2(0.0, roundf(hop)), 0.0, Vector2(1.0 + 0.08 * s, 1.0 - 0.08 * s))
			PixelArt.draw(self, "slime", Vector2(-24.0, -36.0), 4.0)
			top = -36.0 + hop
		Kind.GOBLIN:
			var walking: bool = _walked > 0.0 and _walked < WALK_LIMIT
			var frame: int = int(_time * 7.0) % 2 if walking else 0
			var bob: float = -4.0 if frame == 1 else 0.0
			PixelArt.draw(self, "goblin_b" if frame == 1 else "goblin_a", Vector2(-24.0, -52.0 + bob), 4.0)
			top = -52.0
		_:
			var flap: int = int(_time * 10.0) % 2
			PixelArt.draw(self, "bat_b" if flap == 1 else "bat_a", Vector2(-28.0, -16.0), 4.0)
			top = -16.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aviso "!": el boton atacara en lugar de saltar.
	if _alert and not dead:
		var bounce: float = roundf(absf(sin(_time * 10.0)) * 6.0)
		PixelFont.draw_text_shadowed(self, "!", Vector2(-10.0, top - 44.0 - bounce), 4.0, Pal.YELLOW, Pal.INK, true)
