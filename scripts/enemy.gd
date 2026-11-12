extends Area2D
## Enemigo. Cinco tipos con comportamientos distintos:
##   SLIME  - baba verde que brinca en su sitio.
##   GOBLIN - diablillo rojo que camina hacia el heroe.
##   BAT    - murcielago que vuela a la altura del pecho.
##   KNIGHT - escudero acorazado: el primer golpe le rompe el escudo y lo
##            empuja hacia atras; hace falta un segundo golpe.
##   GHOST  - espectro nocturno que carga contra el heroe.
## Todos danan al heroe si lo tocan.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

enum Kind { SLIME, GOBLIN, BAT, KNIGHT, GHOST }

const POINTS := [25, 40, 60, 90, 70]
## Distancia que recorre cada tipo hacia el heroe y a que velocidad.
const WALK_LIMITS := [0.0, 120.0, 0.0, 0.0, 240.0]
const WALK_SPEEDS := [0.0, 70.0, 0.0, 0.0, 150.0]
const WAKE_DISTANCE := 760.0

var kind: int = Kind.SLIME
var dead: bool = false
var hp: int = 1

## Datos para lights.gd (solo el espectro brilla).
var glow_radius: float = 60.0
var glow_color: Color = Pal.CYAN
var glow_day: float = 0.25

var _time: float = 0.0
var _walked: float = 0.0
var _base_y: float = 0.0
var _alert: bool = false
var _flash: float = 0.0
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
	hp = 2 if kind == Kind.KNIGHT else 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	if kind == Kind.SLIME:
		shape.size = Vector2(36.0, 26.0)
		_collider.position = Vector2(0.0, -13.0)
	elif kind == Kind.GOBLIN:
		shape.size = Vector2(34.0, 44.0)
		_collider.position = Vector2(0.0, -22.0)
	elif kind == Kind.KNIGHT:
		shape.size = Vector2(36.0, 50.0)
		_collider.position = Vector2(0.0, -25.0)
	else:
		shape.size = Vector2(40.0, 28.0)
		_collider.position = Vector2(0.0, 0.0)
	_collider.shape = shape
	if kind == Kind.GHOST:
		add_to_group("glow")
	queue_redraw()


func get_points() -> int:
	return POINTS[kind]


## Recibe un golpe. Devuelve los puntos si muere, -1 si sobrevive
## (escudo roto) y 0 si ya estaba muerto.
func hit() -> int:
	if dead:
		return 0
	hp -= 1
	if hp > 0:
		_flash = 0.25
		# Retrocede para dar tiempo al segundo golpe.
		position.x += 170.0 + Daylight.run_speed * 0.3
		return -1
	dead = true
	remove_from_group("enemies")
	set_deferred("monitorable", false)
	queue_free()
	return get_points()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_alert = false
	if is_instance_valid(_player):
		var dx: float = global_position.x - _player.global_position.x
		var limit: float = WALK_LIMITS[kind]
		if limit > 0.0 and dx < WAKE_DISTANCE and _walked < limit:
			var step: float = float(WALK_SPEEDS[kind]) * delta
			position.x -= step
			_walked += step
		if _player.has_method("is_enemy_in_reach"):
			_alert = bool(_player.call("is_enemy_in_reach", self))
	if kind == Kind.BAT or kind == Kind.GHOST:
		position.y = _base_y + sin(_time * 4.0) * 12.0
	if kind == Kind.GHOST:
		modulate = Daylight.unlit()
	queue_redraw()


func _draw() -> void:
	var top: float = -36.0
	var skew: float = Daylight.shadow_skew()
	var alpha: float = Daylight.shadow_alpha()
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _flash > 0.0:
		tint = Color(3.0, 3.0, 3.0, 1.0)
	if kind == Kind.SLIME:
		var s: float = sin(_time * 6.0)
		var hop: float = -absf(sin(_time * 3.0)) * 10.0
		PixelArt.draw_shadow(self, "slime", Vector2(0.0, 0.0), 4.0, skew, alpha)
		draw_set_transform(Vector2(0.0, roundf(hop)), 0.0, Vector2(1.0 + 0.08 * s, 1.0 - 0.08 * s))
		PixelArt.draw(self, "slime", Vector2(-24.0, -36.0), 4.0, tint)
		top = -36.0 + hop
	elif kind == Kind.GOBLIN:
		var walking: bool = _walked > 0.0 and _walked < float(WALK_LIMITS[kind])
		var frame: int = int(_time * 7.0) % 2 if walking else 0
		var bob: float = -4.0 if frame == 1 else 0.0
		PixelArt.draw_shadow(self, "goblin_a", Vector2(0.0, 0.0), 4.0, skew, alpha)
		PixelArt.draw(self, "goblin_b" if frame == 1 else "goblin_a", Vector2(-24.0, -52.0 + bob), 4.0, tint)
		top = -52.0
	elif kind == Kind.BAT:
		var flap: int = int(_time * 10.0) % 2
		PixelArt.draw(self, "bat_b" if flap == 1 else "bat_a", Vector2(-28.0, -16.0), 4.0, tint)
		top = -16.0
	elif kind == Kind.KNIGHT:
		var sprite: String = "knight_a" if hp > 1 else "knight_b"
		var sway: float = roundf(sin(_time * 5.0) * 2.0)
		PixelArt.draw_shadow(self, sprite, Vector2(0.0, 0.0), 4.0, skew, alpha)
		PixelArt.draw(self, sprite, Vector2(-26.0, -56.0 + sway), 4.0, tint)
		top = -56.0
	else:
		var fade: float = 0.65 + 0.25 * sin(_time * 5.0)
		PixelArt.draw(self, "ghost", Vector2(-24.0, -26.0), 4.0, Color(tint.r, tint.g, tint.b, fade))
		top = -26.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aviso "!": el boton atacara en lugar de saltar.
	if _alert and not dead:
		var bounce: float = roundf(absf(sin(_time * 10.0)) * 6.0)
		PixelFont.draw_text_shadowed(self, "!", Vector2(-10.0, top - 44.0 - bounce), 4.0, Pal.YELLOW, Pal.INK, true)
