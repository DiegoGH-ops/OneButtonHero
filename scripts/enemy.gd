extends Area2D
## Enemigo. Cada tipo tiene aspecto y comportamiento propios:
##   SLIME   - baba que brinca en su sitio.
##   GOBLIN  - diablillo que camina hacia el heroe.
##   BAT     - murcielago a la altura del pecho.
##   KNIGHT  - escudero: dos golpes; retrocede tras el primero.
##   GHOST   - espectro nocturno que carga.
##   ORB     - proyectil de los jefes: hay que devolverlo de un golpe.
##   WOLF    - lobo: embiste muy rapido desde lejos.
##   GOLEM   - golem de cristal: dos golpes, como el escudero.
##   MUMMY   - momia: dos golpes seguidos, apenas retrocede.
##   FIREBAT - murcielago de fuego: baja en picado al acercarse.
##   WRAITH  - espiritu de ventisca: intangible a ratos; un ataque
##             anticipado lo atraviesa sin hacerle nada.
## Todos danan al heroe si lo tocan.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

enum Kind { SLIME, GOBLIN, BAT, KNIGHT, GHOST, ORB, WOLF, GOLEM, MUMMY, FIREBAT, WRAITH }

const POINTS := [25, 40, 60, 90, 70, 20, 55, 110, 80, 65, 85]
## Distancia que recorre cada tipo hacia el heroe y a que velocidad.
const WALK_LIMITS := [0.0, 120.0, 0.0, 0.0, 240.0, 6000.0, 300.0, 0.0, 90.0, 0.0, 240.0]
## El proyectil de los jefes (ORB) va algo mas rapido que antes (260 -> 300).
const WALK_SPEEDS := [0.0, 70.0, 0.0, 0.0, 150.0, 300.0, 210.0, 0.0, 40.0, 0.0, 150.0]
const HIT_POINTS := [1, 1, 1, 2, 1, 1, 1, 2, 2, 1, 1]
const WAKE_DISTANCE := 760.0
const FIRE_REMAP := {"p": "r", "k": "e"}
const FROST_REMAP := {"w": "c", "l": "B"}

var kind: int = Kind.SLIME
var dead: bool = false
var hp: int = 1
## Color del proyectil (lo fija el jefe que lo lanza).
var orb_color: Color = Pal.PURPLE

## Datos para lights.gd (espectros, proyectiles y murcielagos de fuego).
var glow_radius: float = 60.0
var glow_color: Color = Pal.CYAN
var glow_day: float = 0.25

var _time: float = 0.0
var _walked: float = 0.0
var _base_y: float = 0.0
var _alert: bool = false
var _flash: float = 0.0
var _intangible: bool = false
var _player: Node2D

@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_time = randf() * 6.0


func _is_flying() -> bool:
	return kind == Kind.BAT or kind == Kind.GHOST or kind == Kind.FIREBAT or kind == Kind.WRAITH


## Configura el tipo. Debe llamarse despues de anadir el nodo al arbol
## y de asignarle su posicion.
func setup(p_kind: int) -> void:
	kind = clampi(p_kind, 0, POINTS.size() - 1)
	_base_y = position.y
	hp = HIT_POINTS[kind]
	var shape: RectangleShape2D = RectangleShape2D.new()
	if kind == Kind.SLIME:
		shape.size = Vector2(36.0, 26.0)
		_collider.position = Vector2(0.0, -13.0)
	elif kind == Kind.GOBLIN:
		shape.size = Vector2(34.0, 44.0)
		_collider.position = Vector2(0.0, -22.0)
	elif kind == Kind.KNIGHT or kind == Kind.GOLEM or kind == Kind.MUMMY:
		shape.size = Vector2(36.0, 50.0)
		_collider.position = Vector2(0.0, -25.0)
	elif kind == Kind.WOLF:
		shape.size = Vector2(44.0, 28.0)
		_collider.position = Vector2(0.0, -14.0)
	elif kind == Kind.ORB:
		shape.size = Vector2(28.0, 28.0)
		_collider.position = Vector2(0.0, 0.0)
	else:
		shape.size = Vector2(40.0, 28.0)
		_collider.position = Vector2(0.0, 0.0)
	_collider.shape = shape
	if kind == Kind.GHOST or kind == Kind.WRAITH or kind == Kind.ORB or kind == Kind.FIREBAT:
		add_to_group("glow")
	if kind == Kind.FIREBAT:
		glow_color = Pal.ORANGE
	queue_redraw()


func get_points() -> int:
	return POINTS[kind]


## Recibe un golpe. Devuelve los puntos si muere, -1 si sobrevive
## (primer golpe a un enemigo acorazado) y 0 si no le afecta.
func hit() -> int:
	if dead or _intangible:
		return 0
	hp -= 1
	if hp > 0:
		_flash = 0.25
		# Retrocede para dar tiempo al segundo golpe.
		if kind == Kind.MUMMY:
			position.x += 80.0 + Daylight.run_speed * 0.15
		else:
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
	var dx: float = 9999.0
	if is_instance_valid(_player):
		dx = global_position.x - _player.global_position.x
		var limit: float = WALK_LIMITS[kind]
		if limit > 0.0 and (dx < WAKE_DISTANCE or kind == Kind.ORB) and _walked < limit:
			var step: float = float(WALK_SPEEDS[kind]) * delta
			position.x -= step
			_walked += step
		if _player.has_method("is_enemy_in_reach"):
			_alert = bool(_player.call("is_enemy_in_reach", self))
	if kind == Kind.FIREBAT:
		# Vuela alto y baja en picado al acercarse.
		position.y = _base_y - 110.0 * clampf((dx - 260.0) / 300.0, 0.0, 1.0) + sin(_time * 5.0) * 8.0
	elif _is_flying():
		position.y = _base_y + sin(_time * 4.0) * 12.0
	if kind == Kind.WRAITH:
		# Intangible a ratos; siempre solido cuando ya esta encima.
		_intangible = cos(_time * 3.0) > 0.2 and dx > 150.0
	if kind == Kind.ORB:
		glow_color = orb_color
	if kind == Kind.GHOST or kind == Kind.WRAITH or kind == Kind.ORB or kind == Kind.FIREBAT:
		modulate = Daylight.unlit()
	queue_redraw()


func _draw() -> void:
	var top: float = -36.0
	var shadow_skew: float = Daylight.shadow_skew()
	var alpha: float = Daylight.shadow_alpha()
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _flash > 0.0:
		tint = Color(3.0, 3.0, 3.0, 1.0)
	# Cada mundo recolorea las criaturas basicas.
	var color_map: Dictionary = Daylight.theme.get("enemy_remap", {})
	var remap_key: String = String(Daylight.theme.get("ground_key", ""))
	if kind == Kind.SLIME:
		var s: float = sin(_time * 6.0)
		var hop: float = -absf(sin(_time * 3.0)) * 10.0
		PixelArt.draw_shadow(self, "slime", Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		draw_set_transform(Vector2(0.0, roundf(hop)), 0.0, Vector2(1.0 + 0.08 * s, 1.0 - 0.08 * s))
		PixelArt.draw_skin(self, "slime", Vector2(-24.0, -36.0), 4.0, tint, color_map, remap_key)
		top = -36.0 + hop
	elif kind == Kind.GOBLIN:
		var walking: bool = _walked > 0.0 and _walked < float(WALK_LIMITS[kind])
		var frame: int = int(_time * 7.0) % 2 if walking else 0
		var bob: float = -4.0 if frame == 1 else 0.0
		PixelArt.draw_shadow(self, "goblin_a", Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw(self, "goblin_b" if frame == 1 else "goblin_a", Vector2(-24.0, -52.0 + bob), 4.0, tint)
		top = -52.0
	elif kind == Kind.BAT or kind == Kind.FIREBAT:
		var flap: int = int(_time * 10.0) % 2
		var bat: String = "bat_b" if flap == 1 else "bat_a"
		if kind == Kind.FIREBAT:
			for i in 4:
				var life: float = fposmod(_time * 2.0 + float(i) * 0.25, 1.0)
				draw_rect(Rect2(20.0 + life * 40.0, -6.0 - life * 14.0, 8.0 - life * 6.0, 8.0 - life * 6.0), Color(Pal.ORANGE if i % 2 == 0 else Pal.YELLOW, 1.0 - life))
			PixelArt.draw_skin(self, bat, Vector2(-28.0, -16.0), 4.0, tint, FIRE_REMAP, "fire")
		else:
			PixelArt.draw(self, bat, Vector2(-28.0, -16.0), 4.0, tint)
		top = -16.0
	elif kind == Kind.KNIGHT:
		var sprite: String = "knight_a" if hp > 1 else "knight_b"
		PixelArt.draw_shadow(self, sprite, Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw(self, sprite, Vector2(-26.0, -56.0 + roundf(sin(_time * 5.0) * 2.0)), 4.0, tint)
		top = -56.0
	elif kind == Kind.GOLEM or kind == Kind.MUMMY:
		var body: String = "golem" if kind == Kind.GOLEM else "mummy"
		var hurt: Color = tint if hp > 1 else Color(tint.r, tint.g * 0.7, tint.b * 0.7, 1.0)
		PixelArt.draw_shadow(self, body, Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw(self, body, Vector2(-26.0, -56.0 + roundf(absf(sin(_time * 4.0)) * -3.0)), 4.0, hurt)
		top = -56.0
	elif kind == Kind.WOLF:
		var run: float = roundf(absf(sin(_time * 14.0)) * -4.0) if _walked > 0.0 and _walked < 300.0 else 0.0
		PixelArt.draw_shadow(self, "wolf", Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw_skin(self, "wolf", Vector2(-28.0, -36.0 + run), 4.0, tint, color_map, remap_key)
		top = -36.0
	elif kind == Kind.ORB:
		var pulse: float = 14.0 + sin(_time * 12.0) * 3.0
		PixelArt.draw_glow(self, Vector2.ZERO, pulse + 14.0, orb_color)
		for y in range(-3, 4):
			var half: int = int(sqrt(float(9 - y * y)))
			draw_rect(Rect2(-float(half) * 4.0 - 2.0, float(y) * 4.0 - 2.0, float(half * 2 + 1) * 4.0, 4.0), orb_color.lightened(0.3 if absi(y) < 2 else 0.0))
		top = -14.0
	else:
		var fade: float = 0.65 + 0.25 * sin(_time * 5.0)
		if _intangible:
			fade = 0.22
		if kind == Kind.WRAITH:
			PixelArt.draw_skin(self, "ghost", Vector2(-24.0, -26.0), 4.0, Color(tint.r, tint.g, tint.b, fade), FROST_REMAP, "frost")
		else:
			PixelArt.draw(self, "ghost", Vector2(-24.0, -26.0), 4.0, Color(tint.r, tint.g, tint.b, fade))
		top = -26.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aviso "!": el boton atacara en lugar de saltar.
	if _alert and not dead:
		var bounce: float = roundf(absf(sin(_time * 10.0)) * 6.0)
		PixelFont.draw_text_shadowed(self, "!", Vector2(-10.0, top - 44.0 - bounce), 4.0, Pal.SILVER if _intangible else Pal.YELLOW, Pal.INK, true)
