extends Area2D
## Obstaculo que dana al heroe al tocarlo: pinchos, roca, totem alto,
## llamas (iluminan de noche) o roca rodante que avanza hacia el heroe.
## `position` es la esquina inferior izquierda apoyada en el suelo, salvo en
## la roca rodante, donde es el centro de su base.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

enum Kind { SPIKES, ROCK, TOTEM, FLAMES, BOULDER, TRAP, CEILING, WALL, BOUNCE }

## Techo bajo: su borde inferior queda a esta altura sobre el suelo. Un
## salto corto pasa por debajo; uno largo choca (hay que soltar a tiempo).
const CEILING_GAP := 175.0
## Muro: mas alto que cualquier salto normal; solo se supera con trampolin.
const WALL_HEIGHT := 200.0

## Trampa ritmica: los pinchos suben y bajan con este periodo (segundos).
const TRAP_PERIOD := 1.5

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
	if kind == Kind.SPIKES or kind == Kind.FLAMES or kind == Kind.TRAP:
		shape.size = Vector2(float(count) * TILE - 12.0, 18.0)
		_collider.position = Vector2(float(count) * TILE * 0.5, -9.0)
	elif kind == Kind.CEILING:
		shape.size = Vector2(float(count) * TILE, 300.0)
		_collider.position = Vector2(float(count) * TILE * 0.5, -CEILING_GAP - 150.0)
	elif kind == Kind.WALL:
		shape.size = Vector2(40.0, WALL_HEIGHT)
		_collider.position = Vector2(24.0, -WALL_HEIGHT * 0.5)
	elif kind == Kind.BOUNCE:
		# El trampolin no hace dano: lo detecta el heroe al pisarlo.
		shape.size = Vector2(36.0, 8.0)
		_collider.position = Vector2(18.0, -4.0)
		remove_from_group("hazards")
		add_to_group("pads")
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
	set_process(kind == Kind.FLAMES or kind == Kind.BOULDER or kind == Kind.TRAP or kind == Kind.BOUNCE)
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
	if kind == Kind.SPIKES or kind == Kind.FLAMES or kind == Kind.TRAP:
		return Vector3(x + 6.0, x + float(count) * TILE - 6.0, 18.0)
	if kind == Kind.ROCK:
		return Vector3(x + 8.0, x + 48.0, 34.0)
	if kind == Kind.WALL:
		return Vector3(x + 4.0, x + 44.0, WALL_HEIGHT)
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
	if kind == Kind.TRAP and not destroyed:
		# Solo es peligrosa con los pinchos fuera (mitad del ciclo).
		var up: bool = _trap_height() > 0.5
		if up and not is_in_group("hazards"):
			add_to_group("hazards")
		elif not up and is_in_group("hazards"):
			remove_from_group("hazards")
	if kind == Kind.BOULDER and _rolled < ROLL_LIMIT:
		if global_position.x - Daylight.player_pos.x < ROLL_WAKE:
			var step: float = ROLL_SPEED * delta
			position.x -= step
			_rolled += step
	queue_redraw()


## Altura de los pinchos de la trampa (0 escondidos, 1 fuera).
func _trap_height() -> float:
	var t: float = fposmod(_time, TRAP_PERIOD) / TRAP_PERIOD
	if t < 0.45:
		return 1.0
	if t < 0.55:
		return 1.0 - (t - 0.45) * 10.0
	if t < 0.9:
		return 0.0
	return (t - 0.9) * 10.0


func _draw() -> void:
	var spike_remap: Dictionary = Daylight.theme.get("spike_remap", {})
	var spike_key: String = String(Daylight.theme.get("ground_key", "")) + "_spike"
	var shadow_skew: float = Daylight.shadow_skew()
	var alpha: float = Daylight.shadow_alpha()
	if kind == Kind.SPIKES:
		for i in count:
			PixelArt.draw_skin(self, "spike", Vector2(float(i) * TILE, -28.0), 4.0, Color(1.0, 1.0, 1.0, 1.0), spike_remap, spike_key)
	elif kind == Kind.TRAP:
		# Losas de piedra con pinchos que asoman al ritmo de la trampa.
		var rise: float = _trap_height()
		for i in count:
			PixelArt.draw_skin(self, "spike", Vector2(float(i) * TILE, -28.0 + (1.0 - rise) * 22.0), 4.0, Color(1.0, 1.0, 1.0, 0.2 + 0.8 * rise), spike_remap, spike_key)
		draw_rect(Rect2(0.0, -4.0, float(count) * TILE, 8.0), Pal.INK)
		draw_rect(Rect2(2.0, -2.0, float(count) * TILE - 4.0, 4.0), Pal.RED if rise > 0.5 else Pal.STEEL)
	elif kind == Kind.FLAMES:
		for i in count:
			var frame: int = (int(_time * 9.0) + i) % 2
			PixelArt.draw(self, "flame_b" if frame == 1 else "flame_a", Vector2(float(i) * TILE, -32.0), 4.0)
	elif kind == Kind.CEILING:
		# Barra colgante con pinchos hacia abajo y aviso de salto corto.
		var w: float = float(count) * TILE
		draw_rect(Rect2(0.0, -560.0, w, 560.0 - CEILING_GAP - 24.0), Pal.SLATE)
		draw_rect(Rect2(0.0, -CEILING_GAP - 28.0, w, 8.0), Pal.INK)
		for i in count:
			draw_set_transform(Vector2(float(i) * TILE + TILE, -CEILING_GAP - 28.0), PI, Vector2.ONE)
			PixelArt.draw_skin(self, "spike", Vector2(0.0, -28.0), 4.0, Color(1.0, 1.0, 1.0, 1.0), spike_remap, spike_key)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		PixelFont.draw_text_shadowed(self, "SALTO CORTO", Vector2(w * 0.5 - 64.0, -CEILING_GAP - 70.0), 2.0, Pal.YELLOW, Pal.INK, true)
	elif kind == Kind.WALL:
		var rows: int = int(WALL_HEIGHT / 32.0)
		for r in rows:
			PixelArt.draw(self, "rock", Vector2(-4.0, -float(r + 1) * 32.0 - 12.0), 4.0, Color(0.8, 0.8, 0.9, 1.0))
		PixelFont.draw_text_shadowed(self, "TRAMPOLÍN", Vector2(-50.0, -WALL_HEIGHT - 40.0), 2.0, Pal.YELLOW, Pal.INK, true)
	elif kind == Kind.BOUNCE:
		var squash: float = 1.0 + 0.1 * sin(_time * 10.0)
		draw_set_transform(Vector2(0.0, 0.0), 0.0, Vector2(1.0, squash))
		PixelArt.draw(self, "pad", Vector2(0.0, -20.0), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bob: float = roundf(absf(sin(_time * 5.0)) * -8.0)
		PixelArt.draw(self, "arrow_down", Vector2(6.0, -64.0 + bob), 4.0)
	elif kind == Kind.ROCK:
		PixelArt.draw_shadow(self, "rock", Vector2(28.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw(self, "rock", Vector2(0.0, -44.0), 4.0)
	elif kind == Kind.TOTEM:
		PixelArt.draw_shadow(self, "totem", Vector2(24.0, 0.0), 4.0, shadow_skew, alpha)
		PixelArt.draw(self, "totem", Vector2(0.0, -108.0), 4.0)
	else:
		PixelArt.draw_shadow(self, "rock", Vector2(0.0, 0.0), 4.0, shadow_skew, alpha)
		# La roca gira sobre su centro mientras rueda.
		draw_set_transform(Vector2(0.0, -24.0), -_rolled / 24.0, Vector2.ONE)
		PixelArt.draw(self, "rock", Vector2(-28.0, -24.0), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
