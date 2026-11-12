extends CharacterBody2D
## El heroe. Corre solo hacia la derecha y TODO se controla con un boton:
##   - Pulsar en el suelo: salto. Mantener: salto mas alto; soltar pronto:
##     salto corto (techos bajos).
##   - Pulsar con un enemigo delante: ataque. Contra enemigos acorazados
##     (brutos, golems...) cada pulsacion es un golpe: pulsacion rapida.
##   - Portal RAPID SIX: el heroe se detiene y hay que pulsar seis veces.
##   - Pulsar cayendo desde lo alto: pisoton (caida rapida que aplasta).
##   - Pisar un trampolin: rebote; pulsar justo al pisarlo: super rebote.
## Un solo golpe mata. Los buffs (cosmeticos, mejoras) se leen de buffs.gd.
##
## El origen del nodo esta en los pies del personaje.

signal jumped(pos: Vector2)
signal landed(pos: Vector2)
signal attacked(pos: Vector2)
signal pickup_collected(kind: int, value: int, pos: Vector2)
signal enemy_killed(points: int, pos: Vector2, kind: int)
signal enemy_hit(pos: Vector2)
signal stomped(pos: Vector2, kills: int)
signal bounced(pos: Vector2, perfect: bool)
signal damaged
signal fell

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Buffs = preload("res://scripts/buffs.gd")

## SALTO VARIABLE: la altura depende del tiempo que se mantiene el boton.
##   Impulso inicial JUMP_VELOCITY; mientras se mantiene (hasta MAX_HOLD_TIME)
##   la subida usa una gravedad muy baja (RISE_GRAVITY) y el heroe sigue
##   ganando altura; al soltar, la velocidad de subida se recorta
##   proporcionalmente (JUMP_RELEASE) y vuelve la gravedad normal.
##   Alturas aproximadas: toque 50 px, pulsacion corta 70, media 105,
##   larga 140, casi maxima 170 y maxima 235 (antes: entre 89 y 173).
const GRAVITY := 2900.0
const RISE_GRAVITY := 700.0
const JUMP_VELOCITY := -700.0
const MAX_HOLD_TIME := 0.34
const JUMP_RELEASE := 0.45
## Tiempo minimo de pulsacion (el toque mas corto posible).
const MIN_JUMP_TIME := 0.05
## Rebote tras aplastar a un enemigo con el pisoton.
const STOMP_BOUNCE := -560.0
const MAX_FALL_SPEED := 1500.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.14
const ATTACK_TIME := 0.30
## Pulsacion rapida: tiempo minimo entre golpes contra enemigos acorazados.
const MASH_INTERVAL := 0.06
## Pisoton: altura minima sobre el suelo y velocidad de caida.
const STOMP_MIN_HEIGHT := 70.0
const STOMP_SPEED := 1700.0
const STOMP_RADIUS := 70.0
## Trampolin: rebote normal y super rebote (pulsando justo al pisarlo).
const BOUNCE_VELOCITY := -1240.0
const SUPER_BOUNCE_VELOCITY := -1420.0
const GROUND_Y := 560.0
const FALL_LIMIT_Y := 820.0
const RUN_LEGS := ["hero_legs_0", "hero_legs_1", "hero_legs_2", "hero_legs_3"]
const RUN_CAPES := ["hero_cape_0", "hero_cape_1", "hero_cape_2", "hero_cape_1"]

## Velocidad horizontal base (la fija game.gd).
var run_speed: float = 340.0
var active: bool = false
var alive: bool = true
## Modo decorativo (menu): solo anima la carrera.
var demo_mode: bool = false
## Potencia del tajo en curso (0 normal, 1 good, 2 perfect, 3 legendary).
var slash_power: int = 0
## Nivel de combo (0-3): particulas de energia alrededor del heroe.
var combo_level: int = 0
## Ojo de halcon: X del mundo donde saltar para lograr PERFECT (INF = nada).
var hawk_x: float = INF

var _coyote: float = 0.0
var _buffer: float = 0.0
var _jump_time: float = 0.0
var _jumping: bool = false
var _attack_time: float = 0.0
var _last_mash: float = 0.0
var _swing_hits: Array = []
var _invulnerable: float = 0.0
var _hurt_time: float = 0.0
var _stomping: bool = false
var _anim: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _tilt: float = 0.0
var _was_on_floor: bool = true
var _fell_reported: bool = false
var _dust: CPUParticles2D
## Hielo (Frostfall): 0..1, acelera al heroe mientras corre sobre el.
var _ice: float = 0.0
## Estela de carrera: posiciones recientes en coordenadas del mundo.
var _trail: Array = []
var _trail_colors: Array = []
var _trail_sparkle: bool = false
## Aura con particulas flotantes (Aura del Abismo).
var _aura_particles: bool = false
var _aura_color: Color = Color(0.0, 0.0, 0.0, 0.0)

# Valores con buffs aplicados (refresh_stats).
var _reach_mult: float = 1.0
var _jump_velocity: float = JUMP_VELOCITY
var _release: float = JUMP_RELEASE
## Tiempo que lleva pulsado el salto en curso (para el medidor de altura).
var _hold_shown: float = 0.0
## Portal RAPID SIX en curso (el heroe esta detenido delante).
var _rapid: Node2D = null
var _coyote_time: float = COYOTE_TIME
var _buffer_time: float = JUMP_BUFFER_TIME
var _ice_grip: float = 0.0
var _stomp_radius: float = STOMP_RADIUS
var _ledge: float = 14.0
## Mejoras del arbol: planeo, suspension, rebotes, velocidad y golpes dobles.
var _glide: float = 0.0
var _hang: float = 0.0
var _bounce_mult: float = 1.0
var _stomp_bounce: float = 1.0
var _speed_mult: float = 1.0
var _vreach: float = 1.0
var _crit: float = 0.0

var _skin: Dictionary = {}
var _top_sprite: String = "hero_top"
var _cape_prefix: String = "hero_cape_"
var _sword_sprite: String = "sword"
var _skin_key: String = ""
var _sword: Dictionary = {}
var _sword_key: String = ""
var _slash_a: Color = Pal.CYAN
var _slash_b: Color = Pal.WHITE

@onready var hurt_box: Area2D = $HurtBox
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	add_to_group("player")
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(-14.0, -2.0)
	_dust.local_coords = false
	_dust.direction = Vector2(-1.0, -0.6)
	_dust.spread = 25.0
	_dust.gravity = Vector2(0.0, 300.0)
	_dust.initial_velocity_min = 30.0
	_dust.initial_velocity_max = 90.0
	_dust.emitting = false
	_dust.show_behind_parent = true
	add_child(_dust)
	refresh_cosmetics()


## Aplica los buffs de cosmeticos equipados y del arbol de mejoras.
## Pequenos a proposito: ayudan, pero no sustituyen a la habilidad.
func refresh_stats() -> void:
	Buffs.invalidate()
	_reach_mult = Buffs.factor("reach")
	# La altura crece con el cuadrado de la velocidad: se aplica la raiz.
	_jump_velocity = JUMP_VELOCITY * sqrt(Buffs.factor("jump_height"))
	# Control de salto: al soltar se recorta aun mas (saltos cortos mas cortos).
	_release = JUMP_RELEASE * clampf(1.0 - Buffs.stat("jump_cut") / 100.0, 0.45, 1.0)
	_coyote_time = COYOTE_TIME + Buffs.stat("coyote") / 1000.0
	_buffer_time = JUMP_BUFFER_TIME + Buffs.stat("buffer") / 1000.0
	_ice_grip = clampf(Buffs.stat("ice_grip") / 100.0, 0.0, 0.8)
	_stomp_radius = STOMP_RADIUS + Buffs.stat("stomp")
	_ledge = 14.0 + Buffs.stat("ledge")
	_glide = clampf(Buffs.stat("glide") / 100.0, 0.0, 0.65)
	_hang = clampf(Buffs.stat("hang") / 100.0, 0.0, 0.6)
	_bounce_mult = Buffs.factor("bounce")
	_stomp_bounce = Buffs.factor("stomp_bounce")
	_speed_mult = clampf(Buffs.factor("run_speed"), 0.85, 1.2)
	_vreach = Buffs.factor("vreach")
	_crit = clampf(Buffs.stat("crit") / 100.0, 0.0, 0.6)
	# Silueta agil: cuerpo hasta 4 px mas estrecho para roces justos.
	var shrink: float = clampf(Buffs.stat("hitbox"), 0.0, 4.0)
	var hurt_shape: CollisionShape2D = hurt_box.get_node("CollisionShape2D")
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(20.0 - shrink * 2.0, 42.0 - shrink)
	hurt_shape.shape = rect
	# Tajo amplio: el area de ataque crece en vertical.
	var attack_shape: CollisionShape2D = attack_area.get_node("CollisionShape2D")
	var swing: RectangleShape2D = RectangleShape2D.new()
	swing.size = Vector2(130.0, 130.0 * _vreach)
	attack_shape.shape = swing


## Lee de GameData el aspecto, la espada y la estela equipados.
func refresh_cosmetics() -> void:
	var skin: Dictionary = GameData.equipped_item("skin")
	_skin = skin["remap"]
	_skin_key = String(skin["id"])
	# Algunos heroes tienen sprites propios (Caballero del Abismo).
	_top_sprite = String(skin.get("top", "hero_top"))
	_cape_prefix = String(skin.get("cape", "hero_cape_"))
	var sword: Dictionary = GameData.equipped_item("sword")
	_sword = sword["remap"]
	_sword_key = String(sword["id"])
	_sword_sprite = String(sword.get("sprite", "sword"))
	var slash: Array = sword["slash"]
	_slash_a = Color(String(slash[0]))
	_slash_b = Color(String(slash[1]))
	var trail: Dictionary = GameData.equipped_item("trail")
	var colors: Array = trail["colors"]
	_trail_sparkle = bool(trail.get("sparkle", false))
	_aura_particles = bool(GameData.equipped_item("aura").get("particles", false))
	_trail_colors = []
	for hex in colors:
		_trail_colors.append(Color(String(hex)))
	var aura: Dictionary = GameData.equipped_item("aura")
	var aura_hex: String = aura["color"]
	_aura_color = Color(aura_hex) if aura_hex != "" else Color(0.0, 0.0, 0.0, 0.0)
	var fancy: bool = colors.size() > 1
	_dust.amount = 18 if fancy else 10
	_dust.lifetime = 0.55 if fancy else 0.35
	_dust.scale_amount_min = 4.0 if fancy else 3.0
	_dust.scale_amount_max = 8.0 if fancy else 6.0
	_dust.color = Color(1.0, 1.0, 1.0, 0.85) if fancy else Color(Pal.WHITE, 0.7)
	if fancy:
		var ramp: Gradient = Gradient.new()
		var offsets: PackedFloat32Array = PackedFloat32Array()
		var ramp_colors: PackedColorArray = PackedColorArray()
		for i in colors.size():
			offsets.append(float(i) / float(colors.size() - 1))
			ramp_colors.append(Color(String(colors[i])))
		ramp.offsets = offsets
		ramp.colors = ramp_colors
		_dust.color_initial_ramp = ramp
	else:
		_dust.color_initial_ramp = null
	refresh_stats()
	queue_redraw()


# ------------------------------------------------------------------ boton --

## Pulsacion del unico boton.
func press() -> void:
	if not active or not alive:
		return
	# Portal RAPID SIX: cada pulsacion (con su liberacion) cuenta como golpe;
	# durante la onda de la variante Supervivencia, la pulsacion es un salto.
	if _rapid != null:
		if is_instance_valid(_rapid) and bool(_rapid.call("tap")):
			_squash = Vector2(1.15, 0.9)
			return
		if is_on_floor():
			_do_jump(_jump_velocity)
		return
	var target: Node2D = _nearest_enemy_in_reach()
	if target != null:
		# Contra enemigos acorazados cada pulsacion cuenta (pulsacion rapida).
		if target.get("mash") == true:
			var now: float = float(Time.get_ticks_msec()) / 1000.0
			if now - _last_mash >= MASH_INTERVAL:
				_last_mash = now
				_start_attack()
		elif _attack_time <= 0.1:
			_start_attack()
		return
	# En el aire, cayendo y con altura: pisoton.
	if not is_on_floor() and velocity.y > -150.0 and GROUND_Y - position.y > STOMP_MIN_HEIGHT and not _stomping:
		_stomping = true
		_jumping = false
		velocity.y = STOMP_SPEED
		_squash = Vector2(0.7, 1.35)
		return
	_buffer = _buffer_time


## Distancia a la que un enemigo convierte el boton en ataque.
func get_attack_range() -> float:
	return (105.0 + run_speed * 0.20) * _reach_mult


func is_enemy_in_reach(enemy: Node2D) -> bool:
	if not active or not alive:
		return false
	var dx: float = enemy.global_position.x - global_position.x
	var dy: float = absf(enemy.global_position.y - global_position.y)
	return dx > -30.0 and dx < get_attack_range() and dy < 120.0 * _vreach


func _nearest_enemy_in_reach() -> Node2D:
	var best: Node2D = null
	var best_dx: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		# Las criaturas no atacables en este momento se saltan, no se atacan.
		if enemy != null and enemy.get("targetable") == false:
			continue
		if enemy != null and is_enemy_in_reach(enemy):
			var dx: float = enemy.global_position.x - global_position.x
			if dx < best_dx:
				best_dx = dx
				best = enemy
	return best


func _start_attack() -> void:
	_attack_time = ATTACK_TIME
	_swing_hits.clear()
	attacked.emit(global_position)


func _do_jump(velocity_y: float) -> void:
	velocity.y = velocity_y
	_hold_shown = 0.0
	_jumping = true
	_jump_time = 0.0
	_buffer = 0.0
	_coyote = 0.0
	_squash = Vector2(0.78, 1.25)
	jumped.emit(global_position)


# ----------------------------------------------------------------- estado --

func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func start_invulnerability(seconds: float) -> void:
	_invulnerable = maxf(_invulnerable, seconds)


func get_speed() -> float:
	return run_speed * _speed_mult * (1.0 + 0.3 * _ice * (1.0 - _ice_grip))


## Animacion de golpe (solo la usa la Pluma de Fenix al salvarte).
func play_hurt() -> void:
	_hurt_time = 0.4


## Recoloca al heroe (Pluma de Fenix tras caer por un hueco).
func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_buffer = 0.0
	_jumping = false
	_stomping = false
	_fell_reported = false
	_was_on_floor = false


## Animacion de derrota: sale despedido girando y cae fuera de la pantalla.
func die() -> void:
	if not alive:
		return
	alive = false
	active = false
	collision_mask = 0
	velocity = Vector2(-150.0, -760.0)
	_dust.emitting = false
	_trail.clear()


# ----------------------------------------------------------------- fisica --

func _physics_process(delta: float) -> void:
	if demo_mode:
		return
	if not alive:
		velocity.y += GRAVITY * delta
		position += velocity * delta
		_tilt -= 9.0 * delta
		return
	if not active:
		return
	_hurt_time = maxf(_hurt_time - delta, 0.0)

	var on_floor: bool = is_on_floor()
	if not on_floor:
		var fall_gravity: float = GRAVITY
		if _jumping:
			# Boton mantenido: la subida continua con gravedad reducida.
			fall_gravity = RISE_GRAVITY
		elif not _stomping:
			# Suspension: la gravedad afloja cerca del punto mas alto.
			if _hang > 0.0 and absf(velocity.y) < 170.0:
				fall_gravity *= 1.0 - _hang
			# Planeo: manteniendo el boton al caer se desciende mas despacio.
			elif _glide > 0.0 and velocity.y > 0.0 and Input.is_action_pressed(GameData.ACTION):
				fall_gravity *= 1.0 - _glide
		velocity.y = minf(velocity.y + fall_gravity * delta, STOMP_SPEED if _stomping else MAX_FALL_SPEED)

	if on_floor:
		_coyote = _coyote_time
	else:
		_coyote -= delta
	_buffer -= delta

	# Trampolin: al pisarlo rebota; pulsando justo antes, super rebote.
	if on_floor:
		var pad: Node2D = _pad_under()
		if pad != null:
			var perfect: bool = _buffer > 0.0
			_do_jump(SUPER_BOUNCE_VELOCITY * _bounce_mult if perfect else BOUNCE_VELOCITY)
			_jumping = false
			bounced.emit(global_position, perfect)
	if _buffer > 0.0 and _coyote > 0.0:
		_do_jump(_jump_velocity)

	# Salto de altura variable: al soltar el boton se recorta la subida.
	if _jumping:
		_jump_time += delta
		if velocity.y >= 0.0:
			_jumping = false
		elif _jump_time >= MIN_JUMP_TIME and not Input.is_action_pressed(GameData.ACTION):
			# Al soltar: recorte proporcional a la velocidad que quedaba.
			velocity.y = maxf(velocity.y, velocity.y * _release)
			_jumping = false
		elif _jump_time >= MAX_HOLD_TIME:
			# Tiempo maximo: sigue subiendo con la inercia y la gravedad normal.
			_jumping = false
		_hold_shown = _jump_time

	# Hielo: sobre el se acelera poco a poco; en el aire se conserva el impulso.
	if on_floor:
		var target_ice: float = 1.0 if Daylight.is_ice(global_position.x) else 0.0
		_ice = move_toward(_ice, target_ice, delta * (0.9 if target_ice > _ice else 2.5))
	_check_rapid_gate(delta)
	velocity.x = 0.0 if _rapid != null else get_speed()
	move_and_slide()

	# Ayuda en cornisas: si roza el borde de un hueco por muy poco, sube.
	if is_on_wall() and not is_on_floor() and velocity.y >= 0.0:
		if position.y > GROUND_Y and position.y < GROUND_Y + _ledge:
			position.y = GROUND_Y - 1.0
			velocity.y = 0.0

	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		_squash = Vector2(1.25, 0.75)
		if _stomping:
			_stomping = false
			_stomp_impact()
		landed.emit(global_position)
	_was_on_floor = now_on_floor

	if _attack_time > 0.0:
		_attack_time -= delta
		_check_attack_hits()

	if _invulnerable > 0.0:
		_invulnerable -= delta
	_check_contacts()

	Daylight.player_pos = global_position
	if position.y > FALL_LIMIT_Y and not _fell_reported:
		_fell_reported = true
		fell.emit()


## Portal RAPID SIX que esta a punto de alcanzar: el heroe se detiene
## delante y el portal empieza su cuenta atras.
func _check_rapid_gate(delta: float) -> void:
	if _rapid != null:
		if not is_instance_valid(_rapid):
			_rapid = null
		return
	for node in get_tree().get_nodes_in_group("rapid_six"):
		var gate: Node2D = node as Node2D
		if gate == null or int(gate.get("state")) != 0:
			continue
		var stop_x: float = gate.global_position.x - 60.0
		if global_position.x <= stop_x and global_position.x + get_speed() * delta >= stop_x:
			global_position.x = stop_x
			_rapid = gate
			gate.call("engage", self)
			return


## El portal se ha roto (o ha caido): el heroe vuelve a correr.
func release_rapid() -> void:
	_rapid = null


## El portal ha caido sobre el heroe (o la onda le ha alcanzado).
func rapid_hit() -> void:
	if alive and _invulnerable <= 0.0:
		damaged.emit()


func _pad_under() -> Node2D:
	for node in get_tree().get_nodes_in_group("pads"):
		var pad: Node2D = node as Node2D
		if pad != null and global_position.x > pad.global_position.x - 4.0 and global_position.x < pad.global_position.x + 40.0:
			return pad
	return null


## El pisoton aplasta a los enemigos de suelo cercanos al caer.
func _stomp_impact() -> void:
	var kills: int = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Area2D = node as Area2D
		if enemy == null or enemy.get("mash") == true:
			continue
		if absf(enemy.global_position.x - global_position.x) < _stomp_radius and absf(enemy.global_position.y - global_position.y) < 60.0:
			var before: int = int(enemy.get("hp")) if enemy.get("hp") != null else 1
			_strike(enemy)
			if before > 0:
				kills += 1
	stomped.emit(global_position, kills)


func _check_attack_hits() -> void:
	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("enemies") and area.has_method("hit") and not _swing_hits.has(area):
			_swing_hits.append(area)
			_strike(area)


## Golpea a un enemigo y avisa del resultado.
func _strike(area: Area2D) -> void:
	var kind: int = int(area.get("kind"))
	var hit_pos: Vector2 = area.global_position
	var result: int = int(area.call("hit"))
	# Golpe critico: contra acorazados el golpe puede contar doble.
	if result < 0 and _crit > 0.0 and area.get("mash") == true and randf() < _crit and is_instance_valid(area):
		result = int(area.call("hit"))
	if result > 0:
		enemy_killed.emit(result, hit_pos, kind)
	elif result < 0:
		enemy_hit.emit(hit_pos)


## Contacto con peligros o enemigos: un solo golpe mata. Si cae en picado
## sobre un enemigo (pisoton), lo aplasta en vez de morir.
func _check_contacts() -> void:
	if _invulnerable > 0.0:
		return
	for area in hurt_box.get_overlapping_areas():
		var is_enemy: bool = area.is_in_group("enemies")
		if not is_enemy and not area.is_in_group("hazards"):
			continue
		if is_enemy and _stomping and not area.get("mash") == true and area.global_position.y > global_position.y - 10.0:
			_strike(area)
			velocity.y = STOMP_BOUNCE * _stomp_bounce
			_stomping = false
			stomped.emit(global_position, 1)
			continue
		damaged.emit()
		return


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not alive or not area.is_in_group("coins"):
		return
	if bool(area.get("collected")):
		return
	var kind: int = int(area.get("kind"))
	var value: int = int(area.get("value"))
	var pos: Vector2 = area.global_position
	area.call("collect")
	pickup_collected.emit(kind, value, pos)


# -------------------------------------------------------------- animacion --

func _process(delta: float) -> void:
	_anim += delta * clampf(get_speed() / 340.0, 0.8, 2.0)
	# Estela: mas larga cuanto mas rapido se mueve.
	if alive and not demo_mode and active:
		_trail.push_front(global_position + Vector2(0.0, -30.0))
		var max_points: int = 14 + int(clampf((get_speed() - 340.0) / 25.0, 0.0, 14.0))
		while _trail.size() > max_points:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	var running: bool = alive and (demo_mode or (active and is_on_floor()))
	if _dust.emitting != running:
		_dust.emitting = running
	queue_redraw()


## Medidor del salto variable: cinco marcas que se encienden mientras se
## mantiene el boton. Cada marca coincide con el color de la columna de
## salto (obstacle.gd, PILLAR) que permite superar: cian, lima, amarillo,
## naranja y rojo. Un toque sin marcas solo salta obstaculos bajos.
const METER_STEPS := [0.32, 0.5, 0.69, 0.88, 1.0]

func _draw_jump_meter() -> void:
	if not active or not alive or is_on_floor() or _hold_shown <= 0.0:
		return
	var ratio: float = clampf(_hold_shown / MAX_HOLD_TIME, 0.0, 1.0)
	var colors: Array = [Pal.CYAN, Pal.LIME, Pal.YELLOW, Pal.ORANGE, Pal.RED]
	for i in 5:
		var lit: bool = ratio >= float(METER_STEPS[i]) - 0.001
		var c: Color = colors[i] if lit else Color(Pal.INK, 0.5)
		draw_rect(Rect2(-26.0, -18.0 - float(i) * 9.0, 6.0, 7.0), c)


func _draw() -> void:
	_draw_jump_meter()
	var alpha: float = 1.0
	if alive and _invulnerable > 0.0 and int(_invulnerable * 14.0) % 2 == 0:
		alpha = 0.3
	var tint: Color = Color(1.0, 1.0, 1.0, alpha)
	if _hurt_time > 0.0:
		tint = Color(1.0, 0.45, 0.45, alpha)
	var on_floor: bool = demo_mode or is_on_floor()

	# Ojo de halcon: marca en el suelo el punto de salto PERFECT.
	if alive and hawk_x != INF:
		var mark: Vector2 = to_local(Vector2(hawk_x, GROUND_Y))
		var pulse: float = roundf(absf(sin(_anim * 8.0)) * 6.0)
		PixelArt.draw(self, "arrow_down", mark + Vector2(-12.0, -40.0 - pulse), 4.0, Color(1.0, 1.0, 1.0, 0.85))
		draw_rect(Rect2(mark + Vector2(-2.0, -12.0), Vector2(4.0, 12.0)), Color(Pal.YELLOW, 0.8))

	# Fotograma: piernas y capa cambian con la carrera, el salto y la caida.
	var legs: String = "hero_legs_fall"
	var cape: String = "hero_cape_2"
	var bob: float = 0.0
	if alive and _hurt_time <= 0.0:
		if not on_floor:
			legs = "hero_legs_jump" if velocity.y < 0.0 else "hero_legs_fall"
			cape = "hero_cape_0" if velocity.y < 0.0 else "hero_cape_2"
		else:
			var index: int = int(_anim * 11.0) % 4
			legs = RUN_LEGS[index]
			cape = RUN_CAPES[index]
			if index % 2 == 1:
				bob = -4.0

	# Sombra proyectada segun la posicion del sol.
	if alive and not demo_mode:
		var ground_gap: float = GROUND_Y - global_position.y
		if on_floor and ground_gap < 8.0:
			PixelArt.draw_shadow(self, "hero_top", Vector2(0.0, 0.0), 4.0, Daylight.shadow_skew(), Daylight.shadow_alpha())
		elif ground_gap > 0.0 and ground_gap < 320.0 and Daylight.is_ground(global_position.x):
			var shrink: float = 1.0 - ground_gap / 400.0
			draw_rect(Rect2(-22.0 * shrink, ground_gap - 2.0, 44.0 * shrink, 4.0), Color(0.0, 0.0, 0.0, Daylight.shadow_alpha()))
	elif demo_mode:
		draw_rect(Rect2(-22.0, -2.0, 44.0, 4.0), Color(0.0, 0.0, 0.0, 0.22))

	_draw_trail()
	if alive and combo_level > 0:
		_draw_combo_energy()
	if alive and _aura_particles:
		_draw_aura_particles()

	# Al morir gira sobre su centro; en vida se aplasta y estira desde los pies.
	var pivot: Vector2 = Vector2.ZERO if alive else Vector2(0.0, -34.0)
	var lean: float = _tilt
	if alive:
		if _hurt_time > 0.0:
			lean = -0.35 * (_hurt_time / 0.4)
		elif _stomping:
			lean = 0.0
		elif _attack_time > 0.0:
			lean = 0.10
	var body_xf: Transform2D = Transform2D(lean, _squash, 0.0, pivot)
	draw_set_transform_matrix(body_xf)
	cape = _cape_prefix + cape.substr(10)
	PixelArt.draw_skin(self, cape, Vector2(-38.0, -36.0 + bob) - pivot, 4.0, tint, _skin, _skin_key)
	PixelArt.draw_skin(self, legs, Vector2(-28.0, -16.0) - pivot, 4.0, tint, _skin, _skin_key)
	PixelArt.draw_skin(self, _top_sprite, Vector2(-28.0, -68.0 + bob) - pivot, 4.0, tint, _skin, _skin_key)
	if _top_sprite == "abyss_top":
		# Visor y nucleo de energia violeta que laten.
		var beat: float = 0.5 + 0.5 * sin(_anim * 6.0)
		PixelArt.draw_glow(self, Vector2(0.0, -50.0 + bob) - pivot, 26.0, Color(Pal.VIOLET, 0.45 + 0.3 * beat))

	# Espada: gira alrededor de la mano y deja una estela al atacar.
	var hand: Vector2 = Vector2(18.0, -26.0 + bob) - pivot
	var sword_angle: float = 0.55 + sin(_anim * 11.0) * 0.08
	if not alive:
		sword_angle = 2.4
	elif _attack_time > 0.0:
		var progress: float = 1.0 - _attack_time / ATTACK_TIME
		var swing: float = minf(progress / 0.45, 1.0)
		swing = 1.0 - (1.0 - swing) * (1.0 - swing)
		sword_angle = lerpf(-1.0, 2.3, swing)
		_draw_slash(hand, sword_angle, progress, alpha)
	elif _stomping:
		sword_angle = 3.1
	elif not on_floor:
		sword_angle = 0.2 if velocity.y < 0.0 else 0.95
	draw_set_transform_matrix(body_xf * Transform2D(sword_angle, hand))
	if _sword_sprite == "abyss_sword":
		PixelArt.draw_glow(self, Vector2(4.0, -24.0), 30.0, Color(Pal.VIOLET, 0.5))
		PixelArt.draw_skin(self, _sword_sprite, Vector2(-14.0, -48.0), 4.0, tint, _sword, _sword_key)
	else:
		PixelArt.draw_skin(self, _sword_sprite, Vector2(-10.0, -40.0), 4.0, tint, _sword, _sword_key)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Lineas de caida del pisoton.
	if _stomping:
		for i in 4:
			draw_rect(Rect2(-20.0 + float(i) * 12.0, -110.0 - fposmod(_anim * 300.0 + float(i) * 23.0, 50.0), 4.0, 30.0), Color(Pal.WHITE, 0.6))


## Estela de carrera: cuadraditos que siguen el recorrido del heroe y se
## desvanecen. Toma los colores de la estela equipada mezclados con el aura.
func _draw_trail() -> void:
	var count: int = _trail.size()
	if count < 3 or _trail_colors.is_empty():
		return
	var fast: float = clampf((get_speed() - 340.0) / 300.0, 0.0, 1.0)
	for i in range(count - 1, 0, -1):
		var t: float = 1.0 - float(i) / float(count)
		var p: Vector2 = to_local(_trail[i])
		var c: Color = _trail_colors[i % _trail_colors.size()]
		if _aura_color.a > 0.0:
			c = c.lerp(_aura_color, 0.45)
		var size: float = snappedf(6.0 + 14.0 * t + 8.0 * fast, 2.0)
		draw_rect(Rect2(snappedf(p.x, 2.0) - size * 0.5, snappedf(p.y, 2.0) - size * 0.5, size, size), Color(c, (0.15 + 0.45 * t) * (0.6 + 0.4 * fast)))
	# Estela con destellos (Abismo y similares): chispas que titilan.
	if _trail_sparkle:
		for k in 5:
			var index2: int = mini(count - 1, 2 + k * 3)
			var sq: Vector2 = to_local(_trail[index2]) + Vector2(sin(_anim * 7.0 + float(k) * 2.0) * 12.0, cos(_anim * 5.0 + float(k)) * 12.0)
			var blink: float = maxf(sin(_anim * 12.0 + float(k) * 1.7), 0.0)
			draw_rect(Rect2(snappedf(sq.x, 2.0) - 2.0, snappedf(sq.y, 2.0) - 6.0, 4.0, 12.0), Color(Pal.WHITE, blink * 0.8))
			draw_rect(Rect2(snappedf(sq.x, 2.0) - 6.0, snappedf(sq.y, 2.0) - 2.0, 12.0, 4.0), Color(Pal.VIOLET, blink * 0.8))
	# Chispas sueltas en la cola.
	for k in 3:
		var index: int = mini(count - 1, 4 + k * 3)
		var q: Vector2 = to_local(_trail[index]) + Vector2(0.0, sin(_anim * 9.0 + float(k)) * 10.0)
		draw_rect(Rect2(snappedf(q.x, 2.0), snappedf(q.y, 2.0), 4.0, 4.0), Color(Pal.WHITE, 0.6))


## Aura con particulas: motas de energia oscura que suben y orbitan.
func _draw_aura_particles() -> void:
	for k in 10:
		var phase: float = _anim * 0.9 + float(k) * 0.37
		var rise: float = fposmod(phase, 1.0)
		var angle: float = float(k) * 2.4 + _anim * 1.5
		var p: Vector2 = Vector2(cos(angle) * (20.0 + 10.0 * sin(phase * 3.0)), -10.0 - rise * 70.0)
		var c: Color = Pal.VIOLET if k % 3 != 0 else Pal.WHITE
		draw_rect(Rect2(snappedf(p.x, 2.0) - 2.0, snappedf(p.y, 2.0) - 2.0, 4.0, 4.0), Color(c, 0.85 * (1.0 - rise)))


## Energia de combo: chispas que orbitan al heroe (mas con mas combo).
func _draw_combo_energy() -> void:
	var colors: Array = [Pal.LIME, Pal.YELLOW, Pal.ORANGE]
	var c: Color = colors[clampi(combo_level - 1, 0, 2)]
	for i in combo_level * 4:
		var angle: float = _anim * (3.0 + float(combo_level)) + float(i) * TAU / float(combo_level * 4)
		var p: Vector2 = Vector2(cos(angle) * 40.0, -32.0 + sin(angle) * 46.0)
		draw_rect(Rect2(snappedf(p.x, 2.0) - 3.0, snappedf(p.y, 2.0) - 3.0, 6.0, 6.0), Color(c, 0.85))


## Tajo de la espada: arco de energia con los colores de la espada equipada.
## Crece con la precision: PERFECT anade lineas de movimiento y un destello
## en la punta; LEGENDARY, un segundo arco exterior y chispas.
func _draw_slash(hand: Vector2, current_angle: float, progress: float, alpha: float) -> void:
	var power: int = slash_power
	var fade: float = clampf(1.0 - progress, 0.0, 1.0) * alpha
	var rings: int = 3 + power
	var block: float = 8.0 + float(power) * 2.0
	var angle: float = -1.0 - 0.15 * float(power)
	while angle < current_angle:
		var dir: Vector2 = Vector2(sin(angle), -cos(angle))
		var closeness: float = 1.0 - clampf((current_angle - angle) / 3.3, 0.0, 1.0)
		for ring in rings:
			var radius: float = 40.0 + float(ring) * 10.0
			var p: Vector2 = hand + dir * radius
			var color: Color = _slash_b if ring % 2 == 1 else _slash_a
			draw_rect(Rect2(snappedf(p.x, 2.0) - block * 0.5, snappedf(p.y, 2.0) - block * 0.5, block, block), Color(color, fade * closeness))
		angle += 0.13
	var tip: Vector2 = hand + Vector2(sin(current_angle), -cos(current_angle)) * (44.0 + float(rings) * 10.0)
	if power >= 2:
		# Lineas de movimiento y destello en la punta.
		for k in 4:
			var ly: float = hand.y - 50.0 + float(k) * 26.0
			draw_rect(Rect2(hand.x + 30.0 + float(k % 2) * 20.0, ly, 50.0 + float(power) * 14.0, 4.0), Color(_slash_b, fade * 0.7))
		PixelArt.draw_glow(self, tip, 24.0 + float(power) * 12.0, Color(_slash_b, fade * 0.9))
	if power >= 3:
		var outer: float = -1.4
		while outer < current_angle:
			var odir: Vector2 = Vector2(sin(outer), -cos(outer))
			var op: Vector2 = hand + odir * (110.0 + sin(outer * 6.0 + _anim * 20.0) * 6.0)
			draw_rect(Rect2(snappedf(op.x, 2.0) - 5.0, snappedf(op.y, 2.0) - 5.0, 10.0, 10.0), Color(Pal.WHITE, fade))
			outer += 0.2
		for k in 8:
			var sp: Vector2 = tip + Vector2(cos(float(k) * 0.8 + _anim * 12.0), sin(float(k) * 1.3 + _anim * 9.0)) * (20.0 + float(k) * 6.0)
			draw_rect(Rect2(snappedf(sp.x, 2.0), snappedf(sp.y, 2.0), 6.0, 6.0), Color(Pal.YELLOW if k % 2 == 0 else _slash_a, fade))
