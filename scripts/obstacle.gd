extends Area2D
## Obstaculo que dana al heroe al tocarlo: pinchos, roca, totem alto,
## llamas (iluminan de noche) o roca rodante que avanza hacia el heroe.
## `position` es la esquina inferior izquierda apoyada en el suelo, salvo en
## la roca rodante, donde es el centro de su base.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")

enum Kind { SPIKES, ROCK, TOTEM, FLAMES, BOULDER, TRAP, CEILING, WALL, BOUNCE, PILLAR, LOW_CEILING,
	BRAMBLE, SPIRE, SAW, SHIFTER, BLINK, GEYSER, ICICLE, CANNON, CANNONBALL, PISTON }

## --- Obstaculos de la fase 4 -------------------------------------------------
## Los que se mueven NO dependen del reloj sino de la distancia al heroe
## (Daylight.player_pos): cuando el heroe llega, siempre estan en el mismo
## estado. Asi su ritmo se aprende y nunca es injusto con un solo boton.
##   BRAMBLE    zarzas muy bajas (14 px): salto minimo.
##   SPIRE      torre ancha de 205 px: salto mantenido al maximo.
##   SAW        sierra que sube y baja por un poste; llega ABAJO (saltar) o
##              ARRIBA (pasar por debajo sin saltar).
##   SHIFTER    bloque de cristal que se desliza hasta su sitio al acercarte.
##   BLINK      pinchos fantasma que se materializan al acercarte.
##   GEYSER     respiradero de lava con fases (dormido, burbujea, erupcion);
##              la columna se queda en una altura de 1 a 3 marcas.
##   ICICLE     carambano que cae delante del heroe y se clava en el suelo.
##   CANNON     canon que dispara una bola rodante y luego hay que saltarlo.
##   CANNONBALL la bola del canon.
##   PISTON     columna que sale de la arena justo antes de llegar.
const BRAMBLE_HEIGHT := 14.0
const SPIRE_HEIGHT := 205.0
const SPIRE_WIDTH := 56.0
const SAW_RADIUS := 22.0
const SAW_LOW_Y := 30.0
const SAW_HIGH_Y := 150.0
const SHIFTER_SIZE := Vector2(36.0, 56.0)
const ICICLE_TOP := 380.0
const ICICLE_LENGTH := 46.0
const CANNON_SIZE := Vector2(44.0, 40.0)
const BALL_RADIUS := 18.0
const BALL_SPEED := 170.0

## Columna de salto variable: su altura depende de `count` (1 a 5) y su
## remate tiene el MISMO color que la marca del medidor de salto del heroe
## que hace falta alcanzar (cian = toque ... rojo = pulsacion maxima).
const PILLAR_COLORS := ["73eff7", "a7f070", "ffcd75", "ef7d57", "b13e53"]
## Techo muy bajo: solo se pasa por debajo con un toque rapido.
const LOW_CEILING_GAP := 120.0

## Techo bajo: su borde inferior queda a esta altura sobre el suelo. Un
## salto corto pasa por debajo; uno largo choca (hay que soltar a tiempo).
const CEILING_GAP := 175.0
## Muro: mas alto que cualquier salto normal (maximo 235 px); solo se
## supera con trampolin.
const WALL_HEIGHT := 260.0

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

## Datos extra de los obstaculos nuevos (los pone el generador antes de
## setup): "arrive" ("low"/"high"), "height" (marcas), "shift" (px),
## "speed" (velocidad del heroe al colocarlo).
var data: Dictionary = {}
## Estado de los obstaculos que cambian al acercarse el heroe.
var _state_y: float = 0.0
var _shift_now: float = 0.0
var _fallen: bool = false
var _fall_v: float = 0.0
var _fired: bool = false
var _shape: RectangleShape2D

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
	elif kind == Kind.LOW_CEILING:
		shape.size = Vector2(float(count) * TILE, 300.0)
		_collider.position = Vector2(float(count) * TILE * 0.5, -LOW_CEILING_GAP - 150.0)
	elif kind == Kind.PILLAR:
		count = clampi(count, 1, 5)
		shape.size = Vector2(28.0, pillar_height())
		_collider.position = Vector2(16.0, -pillar_height() * 0.5)
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
	elif kind == Kind.BRAMBLE:
		shape.size = Vector2(float(count) * TILE - 8.0, BRAMBLE_HEIGHT)
		_collider.position = Vector2(float(count) * TILE * 0.5, -BRAMBLE_HEIGHT * 0.5)
	elif kind == Kind.SPIRE:
		shape.size = Vector2(SPIRE_WIDTH - 4.0, SPIRE_HEIGHT)
		_collider.position = Vector2(SPIRE_WIDTH * 0.5, -SPIRE_HEIGHT * 0.5)
	elif kind == Kind.SAW:
		shape.size = Vector2(SAW_RADIUS * 1.6, SAW_RADIUS * 1.6)
		_state_y = _saw_arrival_y()
		_collider.position = Vector2(0.0, -_state_y)
	elif kind == Kind.SHIFTER:
		shape.size = SHIFTER_SIZE - Vector2(4.0, 4.0)
		_shift_now = float(data.get("shift", 140.0))
		_collider.position = Vector2(SHIFTER_SIZE.x * 0.5 + _shift_now, -SHIFTER_SIZE.y * 0.5)
	elif kind == Kind.BLINK:
		shape.size = Vector2(float(count) * TILE - 12.0, 18.0)
		_collider.position = Vector2(float(count) * TILE * 0.5, -9.0)
		remove_from_group("hazards")
	elif kind == Kind.GEYSER or kind == Kind.PISTON:
		shape.size = Vector2(28.0, 8.0)
		_collider.position = Vector2(16.0, -4.0)
	elif kind == Kind.ICICLE:
		shape.size = Vector2(18.0, ICICLE_LENGTH - 6.0)
		_state_y = ICICLE_TOP
		_collider.position = Vector2(0.0, -_state_y - ICICLE_LENGTH * 0.5)
	elif kind == Kind.CANNON:
		shape.size = CANNON_SIZE - Vector2(4.0, 2.0)
		_collider.position = Vector2(CANNON_SIZE.x * 0.5, -CANNON_SIZE.y * 0.5)
	elif kind == Kind.CANNONBALL:
		shape.size = Vector2(BALL_RADIUS * 1.6, BALL_RADIUS * 1.6)
		_collider.position = Vector2(0.0, -BALL_RADIUS)
	else:
		shape.size = Vector2(36.0, 36.0)
		_collider.position = Vector2(0.0, -22.0)
	_collider.shape = shape
	_shape = shape
	if kind == Kind.FLAMES:
		add_to_group("glow")
		glow_radius = 70.0 + float(count) * 16.0
	if kind == Kind.GEYSER:
		add_to_group("glow")
		glow_radius = 80.0
	var animated: Array = [Kind.FLAMES, Kind.BOULDER, Kind.TRAP, Kind.BOUNCE, Kind.SAW, Kind.SHIFTER, Kind.BLINK, Kind.GEYSER, Kind.ICICLE, Kind.CANNON, Kind.CANNONBALL, Kind.PISTON, Kind.BRAMBLE]
	set_process(animated.has(kind))
	queue_redraw()


## Centro del obstaculo (para efectos).
func get_center() -> Vector2:
	if kind == Kind.BOULDER:
		return global_position + Vector2(0.0, -22.0)
	return global_position + _collider.position


## Zona de peligro para el sistema de timing: Vector3(izquierda, derecha,
## altura) en coordenadas del mundo.
## Altura de la columna de salto variable.
func pillar_height() -> float:
	return 30.0 + 35.0 * float(count)


func get_danger() -> Vector3:
	var x: float = global_position.x
	match kind:
		Kind.BRAMBLE:
			return Vector3(x + 4.0, x + float(count) * TILE - 4.0, BRAMBLE_HEIGHT)
		Kind.SPIRE:
			return Vector3(x + 2.0, x + SPIRE_WIDTH - 2.0, SPIRE_HEIGHT)
		Kind.SAW:
			if String(data.get("arrive", "low")) == "high":
				return Vector3(INF, INF, 0.0)
			return Vector3(x - SAW_RADIUS, x + SAW_RADIUS, SAW_LOW_Y + SAW_RADIUS)
		Kind.SHIFTER:
			return Vector3(x + 2.0, x + SHIFTER_SIZE.x - 2.0, SHIFTER_SIZE.y)
		Kind.BLINK:
			return Vector3(x + 6.0, x + float(count) * TILE - 6.0, 18.0)
		Kind.GEYSER, Kind.PISTON:
			return Vector3(x + 2.0, x + 30.0, column_height())
		Kind.ICICLE:
			return Vector3(x - 10.0, x + 10.0, ICICLE_LENGTH)
		Kind.CANNON:
			return Vector3(x + 2.0, x + CANNON_SIZE.x - 2.0, CANNON_SIZE.y)
		Kind.CANNONBALL:
			return Vector3(x - BALL_RADIUS, x + BALL_RADIUS, BALL_RADIUS * 2.0)
	if kind == Kind.PILLAR:
		return Vector3(x + 2.0, x + 30.0, pillar_height())
	if kind == Kind.LOW_CEILING or kind == Kind.CEILING:
		# Los techos no se saltan: no cuentan para puntuar saltos.
		return Vector3(INF, INF, 0.0)
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
	if kind >= Kind.BRAMBLE:
		_process_new(delta)
	if kind == Kind.BOULDER and _rolled < ROLL_LIMIT:
		if global_position.x - Daylight.player_pos.x < ROLL_WAKE:
			var step: float = ROLL_SPEED * delta
			position.x -= step
			_rolled += step
	queue_redraw()


# ------------------------------------------------- obstaculos que se mueven --

## Distancia del heroe al obstaculo (positiva mientras se acerca).
func _approach() -> float:
	return global_position.x - Daylight.player_pos.x


## Velocidad del heroe con la que se calcularon los tiempos.
func _hero_speed() -> float:
	return maxf(float(data.get("speed", 400.0)), 200.0)


## Altura final de la columna del geiser o del piston (como las columnas).
func column_height() -> float:
	return 30.0 + 35.0 * float(clampi(int(data.get("height", 2)), 1, 4))


func _saw_arrival_y() -> float:
	return SAW_HIGH_Y if String(data.get("arrive", "low")) == "high" else SAW_LOW_Y


func _process_new(delta: float) -> void:
	var d: float = _approach()
	var speed: float = _hero_speed()
	match kind:
		Kind.SAW:
			# Oscila entre arriba y abajo; en el ultimo tramo queda fija en su
			# posicion de llegada (siempre la misma).
			var arrive: float = _saw_arrival_y()
			var other: float = SAW_HIGH_Y if arrive == SAW_LOW_Y else SAW_LOW_Y
			var lock: float = speed * 0.45
			var k: float = 0.0
			if d > lock:
				k = 0.5 - 0.5 * cos((d - lock) / (speed * 0.9) * TAU)
			_state_y = lerpf(arrive, other, k)
			_collider.position = Vector2(0.0, -_state_y)
		Kind.SHIFTER:
			# Se desliza hasta su sitio entre 1.4 s y 0.6 s antes de llegar.
			var shift: float = float(data.get("shift", 140.0))
			var t: float = clampf((d - speed * 0.6) / (speed * 0.8), 0.0, 1.0)
			_shift_now = shift * t * t
			_collider.position = Vector2(SHIFTER_SIZE.x * 0.5 + _shift_now, -SHIFTER_SIZE.y * 0.5)
		Kind.BLINK:
			var solid: bool = d < speed * 0.75
			if solid and not is_in_group("hazards") and not destroyed:
				add_to_group("hazards")
			elif not solid and is_in_group("hazards"):
				remove_from_group("hazards")
		Kind.GEYSER, Kind.PISTON:
			# Fases: dormido -> aviso -> sube a su altura (y se queda).
			var target: float = column_height()
			var rise_at: float = speed * (0.9 if kind == Kind.GEYSER else 0.7)
			var h: float = 0.0
			if d < rise_at:
				h = target * clampf((rise_at - d) / (speed * 0.2), 0.0, 1.0)
			elif kind == Kind.GEYSER and d < rise_at + speed * 0.8:
				# Burbujeo: pequenos saltos de lava que avisan de la erupcion.
				h = 12.0 + 10.0 * absf(sin(_time * 9.0))
			_state_y = h
			_shape.size = Vector2(28.0, maxf(h, 4.0))
			_collider.position = Vector2(16.0, -maxf(h, 4.0) * 0.5)
		Kind.ICICLE:
			if not _fallen and d < speed * 1.0:
				_fall_v += 2600.0 * delta
				_state_y = maxf(_state_y - _fall_v * delta, 0.0)
				if _state_y <= 0.0:
					_fallen = true
					Sfx.play("hit", 0.6)
			_collider.position = Vector2(0.0, -_state_y - ICICLE_LENGTH * 0.5)
		Kind.CANNON:
			# Dispara para que la bola llegue al heroe 0.75 s antes que el canon.
			if not _fired and not destroyed:
				var meet: float = speed * 0.75
				var fire_at: float = meet * (speed + BALL_SPEED) / BALL_SPEED
				if d < fire_at:
					_fired = true
					_fire_ball()
		Kind.CANNONBALL:
			position.x -= BALL_SPEED * delta
			_rolled += BALL_SPEED * delta
			if _rolled > 2400.0:
				destroy()


func _fire_ball() -> void:
	# load (no preload): la escena usa este mismo script.
	var scene: PackedScene = load("res://scenes/obstacle.tscn")
	if scene == null or get_parent() == null:
		return
	var ball: Area2D = scene.instantiate()
	ball.set("data", {"speed": _hero_speed()})
	ball.position = position + Vector2(-6.0, 0.0)
	get_parent().add_child(ball)
	ball.call("setup", Kind.CANNONBALL, 1)
	Sfx.play("boss_hit", 0.7)


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
	if kind >= Kind.BRAMBLE:
		_draw_new(spike_remap, spike_key, shadow_skew, alpha)
		return
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
	elif kind == Kind.LOW_CEILING:
		var lw: float = float(count) * TILE
		draw_rect(Rect2(0.0, -560.0, lw, 560.0 - LOW_CEILING_GAP - 24.0), Pal.NAVY)
		draw_rect(Rect2(0.0, -LOW_CEILING_GAP - 28.0, lw, 8.0), Pal.CYAN)
		for i in count:
			draw_set_transform(Vector2(float(i) * TILE + TILE, -LOW_CEILING_GAP - 28.0), PI, Vector2.ONE)
			PixelArt.draw_skin(self, "spike", Vector2(0.0, -28.0), 4.0, Color(1.0, 1.0, 1.0, 1.0), spike_remap, spike_key)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		PixelFont.draw_text_shadowed(self, "TOQUE", Vector2(lw * 0.5 - 30.0, -LOW_CEILING_GAP - 66.0), 2.0, Pal.CYAN, Pal.INK, true)
	elif kind == Kind.PILLAR:
		var h: float = pillar_height()
		var cap: Color = Color(String(PILLAR_COLORS[clampi(count - 1, 0, 4)]))
		PixelArt.draw_shadow(self, "totem", Vector2(16.0, 0.0), 3.0, shadow_skew, alpha * 0.8)
		var blocks: int = int(ceilf(h / 24.0))
		for b in blocks:
			var by: float = -float(b + 1) * 24.0
			var bh: float = 24.0 if b < blocks - 1 else h - float(b) * 24.0
			draw_rect(Rect2(2.0, maxf(by, -h), 28.0, bh), Pal.STEEL if b % 2 == 0 else Pal.SLATE)
			draw_rect(Rect2(2.0, maxf(by, -h), 28.0, 3.0), Pal.SILVER)
		draw_rect(Rect2(0.0, -h - 8.0, 32.0, 10.0), cap)
		draw_rect(Rect2(4.0, -h - 6.0, 24.0, 3.0), cap.lightened(0.4))
		# Marcas de altura: tantas como la columna exige.
		for m in count:
			draw_rect(Rect2(-8.0, -12.0 - float(m) * 9.0, 5.0, 6.0), cap)
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


# ------------------------------------------------- dibujo de los nuevos --

func _draw_new(spike_remap: Dictionary, spike_key: String, shadow_skew: float, alpha: float) -> void:
	match kind:
		Kind.BRAMBLE:
			# Zarzas: matas bajas con espinas que se mecen un poco.
			for i in count:
				var bx: float = float(i) * TILE
				var sway: float = sin(_time * 3.0 + float(i)) * 1.5
				draw_rect(Rect2(bx + 2.0, -8.0, TILE - 4.0, 8.0), Pal.DARK_BROWN)
				draw_rect(Rect2(bx + 4.0, -12.0, TILE - 8.0, 6.0), Pal.GREEN.darkened(0.3))
				for t in 4:
					var tx: float = bx + 4.0 + float(t) * 7.0 + sway
					draw_rect(Rect2(tx, -16.0 + float(t % 2) * 3.0, 3.0, 4.0), Pal.WHITE.darkened(0.15))
				draw_rect(Rect2(bx + 10.0 + sway, -14.0, 4.0, 3.0), Pal.RED)
		Kind.SPIRE:
			# Torre antigua ancha: hay que mantener el salto al maximo.
			PixelArt.draw_shadow(self, "totem", Vector2(SPIRE_WIDTH * 0.5, 0.0), 5.0, shadow_skew, alpha)
			var rows: int = int(ceilf(SPIRE_HEIGHT / 26.0))
			for r in rows:
				var ry: float = -float(r + 1) * 26.0
				var rh: float = 26.0 if r < rows - 1 else SPIRE_HEIGHT - float(r) * 26.0
				var top: float = maxf(ry, -SPIRE_HEIGHT)
				draw_rect(Rect2(0.0, top, SPIRE_WIDTH, rh), Pal.SLATE if r % 2 == 0 else Pal.STEEL.darkened(0.2))
				draw_rect(Rect2(0.0, top, SPIRE_WIDTH, 3.0), Pal.STEEL)
				draw_rect(Rect2(float((r * 13) % 40) + 4.0, top + 8.0, 8.0, 3.0), Pal.INK)
			var cap: Color = Color(String(PILLAR_COLORS[4]))
			draw_rect(Rect2(-4.0, -SPIRE_HEIGHT - 10.0, SPIRE_WIDTH + 8.0, 12.0), cap)
			draw_rect(Rect2(4.0, -SPIRE_HEIGHT - 18.0, 10.0, 8.0), cap)
			draw_rect(Rect2(SPIRE_WIDTH - 14.0, -SPIRE_HEIGHT - 18.0, 10.0, 8.0), cap)
			for m in 5:
				draw_rect(Rect2(-10.0, -12.0 - float(m) * 9.0, 5.0, 6.0), cap)
		Kind.SAW:
			# Poste con guia y sierra giratoria.
			draw_rect(Rect2(-3.0, -SAW_HIGH_Y - 40.0, 6.0, SAW_HIGH_Y + 40.0), Pal.SLATE)
			draw_rect(Rect2(-8.0, -4.0, 16.0, 4.0), Pal.INK)
			var center: Vector2 = Vector2(0.0, -_state_y)
			var turn: float = _time * 14.0
			draw_circle(center, SAW_RADIUS, Pal.SILVER)
			for t in 8:
				var a: float = turn + float(t) * TAU / 8.0
				var tip: Vector2 = center + Vector2(cos(a), sin(a)) * (SAW_RADIUS + 6.0)
				var b1: Vector2 = center + Vector2(cos(a - 0.3), sin(a - 0.3)) * SAW_RADIUS
				var b2: Vector2 = center + Vector2(cos(a + 0.3), sin(a + 0.3)) * SAW_RADIUS
				draw_colored_polygon(PackedVector2Array([b1, tip, b2]), Pal.WHITE)
			draw_circle(center, 7.0, Pal.INK)
			# Indicador de llegada: abajo = saltar, arriba = pasar por debajo.
			var low: bool = String(data.get("arrive", "low")) == "low"
			var mark: Color = Pal.YELLOW if low else Pal.CYAN
			draw_rect(Rect2(10.0, -(SAW_LOW_Y if low else SAW_HIGH_Y) - 3.0, 10.0, 6.0), mark)
		Kind.SHIFTER:
			# Silueta del sitio final y bloque de cristal deslizandose.
			var ghost: Color = Color(Pal.PINK, 0.25 + 0.15 * sin(_time * 6.0))
			draw_rect(Rect2(0.0, -SHIFTER_SIZE.y, SHIFTER_SIZE.x, SHIFTER_SIZE.y), ghost, false, 2.0)
			var bx: float = _shift_now
			draw_rect(Rect2(bx, -SHIFTER_SIZE.y, SHIFTER_SIZE.x, SHIFTER_SIZE.y), Pal.RED.darkened(0.1))
			draw_rect(Rect2(bx + 4.0, -SHIFTER_SIZE.y + 4.0, SHIFTER_SIZE.x - 8.0, SHIFTER_SIZE.y - 8.0), Pal.PINK)
			draw_rect(Rect2(bx + 8.0, -SHIFTER_SIZE.y + 8.0, 6.0, 20.0), Pal.WHITE)
			if _shift_now > 2.0:
				draw_rect(Rect2(bx + SHIFTER_SIZE.x, -10.0, 12.0, 4.0), Color(Pal.WHITE, 0.5))
		Kind.BLINK:
			var solid: bool = is_in_group("hazards")
			for i in count:
				var flicker: float = 0.25 + 0.2 * sin(_time * 12.0 + float(i))
				PixelArt.draw_skin(self, "spike", Vector2(float(i) * TILE, -28.0), 4.0, Color(1.0, 1.0, 1.0, 1.0 if solid else flicker), spike_remap, spike_key)
			if not solid:
				draw_rect(Rect2(0.0, -30.0, float(count) * TILE, 30.0), Color(Pal.CYAN, 0.6), false, 2.0)
		Kind.GEYSER:
			# Boca de lava y columna de fuego (altura con el color de la marca).
			var target_index: int = clampi(int(data.get("height", 2)), 1, 4)
			var cap: Color = Color(String(PILLAR_COLORS[target_index - 1]))
			draw_rect(Rect2(-4.0, -8.0, 40.0, 8.0), Pal.DARK_BROWN)
			draw_rect(Rect2(2.0, -10.0, 28.0, 4.0), Pal.ORANGE)
			if _state_y > 1.0:
				draw_rect(Rect2(4.0, -_state_y, 24.0, _state_y), Pal.ORANGE)
				draw_rect(Rect2(9.0, -_state_y, 14.0, _state_y), Pal.YELLOW)
				for f in 3:
					var fy: float = -_state_y - 6.0 - absf(sin(_time * 10.0 + float(f))) * 10.0
					draw_rect(Rect2(6.0 + float(f) * 8.0, fy, 6.0, 6.0), Pal.YELLOW)
			# Marcas de la altura que alcanzara.
			for m in target_index:
				draw_rect(Rect2(-12.0, -12.0 - float(m) * 9.0, 5.0, 6.0), cap)
		Kind.PISTON:
			var piston_index: int = clampi(int(data.get("height", 2)), 1, 4)
			var piston_cap: Color = Color(String(PILLAR_COLORS[piston_index - 1]))
			# Antes de salir: arena que tiembla y marcas de altura.
			if _state_y < 2.0:
				var shake: float = sin(_time * 30.0) * 2.0
				draw_rect(Rect2(0.0 + shake, -6.0, 32.0, 6.0), Pal.YELLOW.darkened(0.3))
			else:
				draw_rect(Rect2(2.0, -_state_y, 28.0, _state_y), Pal.BROWN)
				draw_rect(Rect2(6.0, -_state_y, 6.0, _state_y), Pal.YELLOW.darkened(0.2))
				draw_rect(Rect2(0.0, -_state_y - 8.0, 32.0, 10.0), piston_cap)
			for m in piston_index:
				draw_rect(Rect2(-12.0, -12.0 - float(m) * 9.0, 5.0, 6.0), piston_cap)
		Kind.ICICLE:
			var y: float = -_state_y
			if not _fallen:
				# Sombra en el suelo donde caera.
				draw_rect(Rect2(-12.0, -3.0, 24.0, 3.0), Color(0.0, 0.0, 0.0, 0.35))
			var pts: PackedVector2Array = PackedVector2Array([Vector2(-11.0, y - ICICLE_LENGTH), Vector2(11.0, y - ICICLE_LENGTH), Vector2(0.0, y)])
			if _fallen:
				pts = PackedVector2Array([Vector2(-11.0, y), Vector2(11.0, y), Vector2(0.0, y - ICICLE_LENGTH)])
			draw_colored_polygon(pts, Pal.CYAN)
			draw_line(pts[0].lerp(pts[2], 0.2), pts[2].lerp(pts[0], 0.1), Pal.WHITE, 2.0)
		Kind.CANNON:
			draw_rect(Rect2(0.0, -CANNON_SIZE.y + 10.0, CANNON_SIZE.x, CANNON_SIZE.y - 10.0), Pal.SLATE)
			draw_rect(Rect2(-12.0, -CANNON_SIZE.y, 34.0, 16.0), Pal.INK)
			draw_rect(Rect2(-14.0, -CANNON_SIZE.y + 2.0, 6.0, 12.0), Pal.STEEL)
			draw_circle(Vector2(CANNON_SIZE.x * 0.5, -10.0), 10.0, Pal.DARK_BROWN)
			if _fired:
				var smoke: float = clampf(1.0 - _time * 0.0, 0.0, 1.0)
				draw_circle(Vector2(-20.0, -CANNON_SIZE.y + 8.0), 6.0, Color(Pal.SILVER, 0.4 * smoke))
		Kind.CANNONBALL:
			draw_set_transform(Vector2(0.0, -BALL_RADIUS), -_rolled / BALL_RADIUS, Vector2.ONE)
			draw_circle(Vector2.ZERO, BALL_RADIUS, Pal.INK)
			draw_rect(Rect2(-4.0, -BALL_RADIUS + 3.0, 8.0, 8.0), Pal.STEEL)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
