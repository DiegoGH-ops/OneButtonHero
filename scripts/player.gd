extends CharacterBody2D
## El heroe. Corre solo hacia la derecha; el boton principal llama a press():
## si hay un enemigo al alcance ataca y, si no, salta. Mantenerlo pulsado
## alarga el salto. Tambien gestiona escudo, turbo, estrella de poder y la
## apariencia comprada en la tienda (aspecto, espada, estela).
##
## El origen del nodo esta en los pies del personaje.

signal jumped(pos: Vector2)
signal landed(pos: Vector2)
signal attacked(pos: Vector2)
signal pickup_collected(kind: int, value: int, pos: Vector2)
signal enemy_killed(points: int, pos: Vector2, kind: int)
signal enemy_hit(pos: Vector2)
signal hazard_smashed(pos: Vector2)
signal soul_strike(pos: Vector2)
signal shield_broken
signal damaged
signal fell

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

const GRAVITY := 2500.0
const JUMP_VELOCITY := -930.0
## Al soltar el boton la velocidad de subida se recorta a este valor.
const JUMP_CUT_VELOCITY := -340.0
## Tiempo minimo antes de poder recortar el salto (altura del salto corto).
const MIN_JUMP_TIME := 0.08
const MAX_FALL_SPEED := 1500.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.14
const ATTACK_TIME := 0.30
const TURBO_MULT := 1.6
const GROUND_Y := 560.0
const FALL_LIMIT_Y := 820.0
const RUN_LEGS := ["hero_legs_0", "hero_legs_1", "hero_legs_2", "hero_legs_3"]
const RUN_CAPES := ["hero_cape_0", "hero_cape_1", "hero_cape_2", "hero_cape_1"]

## Velocidad horizontal base (la fija game.gd).
var run_speed: float = 340.0
var active: bool = false
var alive: bool = true
## Modo decorativo (menu y tienda): solo anima la carrera.
var demo_mode: bool = false
## Escudo comprado en la tienda: absorbe un golpe.
var shield_active: bool = false
## Soul Reaper: el proximo golpe elimina al enemigo al instante.
var soul_armed: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _jump_time: float = 0.0
var _jumping: bool = false
var _attack_time: float = 0.0
var _invulnerable: float = 0.0
var _turbo_time: float = 0.0
var _rage_time: float = 0.0
var _hurt_time: float = 0.0
var _anim: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _tilt: float = 0.0
var _was_on_floor: bool = true
var _fell_reported: bool = false
var _dust: CPUParticles2D

var _skin: Dictionary = {}
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


## Lee de GameData el aspecto, la espada y la estela equipados.
func refresh_cosmetics() -> void:
	var skin: Dictionary = GameData.equipped_item("skin")
	_skin = skin["remap"]
	_skin_key = String(skin["id"])
	var sword: Dictionary = GameData.equipped_item("sword")
	_sword = sword["remap"]
	_sword_key = String(sword["id"])
	var slash: Array = sword["slash"]
	_slash_a = Color(String(slash[0]))
	_slash_b = Color(String(slash[1]))
	var trail: Dictionary = GameData.equipped_item("trail")
	var colors: Array = trail["colors"]
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
	queue_redraw()


# ------------------------------------------------------------------ boton --

## Pulsacion del boton principal.
func press() -> void:
	if not active or not alive:
		return
	if _any_enemy_in_reach():
		if _attack_time <= 0.1:
			_start_attack()
	else:
		_buffer = JUMP_BUFFER_TIME


## Distancia a la que un enemigo convierte el boton en ataque.
func get_attack_range() -> float:
	return 105.0 + run_speed * 0.20


func is_enemy_in_reach(enemy: Node2D) -> bool:
	if not active or not alive:
		return false
	var dx: float = enemy.global_position.x - global_position.x
	var dy: float = absf(enemy.global_position.y - global_position.y)
	return dx > -30.0 and dx < get_attack_range() and dy < 120.0


func _any_enemy_in_reach() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if enemy != null and is_enemy_in_reach(enemy):
			return true
	return false


func _start_attack() -> void:
	_attack_time = ATTACK_TIME
	attacked.emit(global_position)


## Animacion de ataque sin comprobar enemigos (poder Onda).
func flourish() -> void:
	_attack_time = ATTACK_TIME


func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jumping = true
	_jump_time = 0.0
	_buffer = 0.0
	_coyote = 0.0
	_squash = Vector2(0.78, 1.25)
	jumped.emit(global_position)


# ----------------------------------------------------------------- estado --

func is_invulnerable() -> bool:
	return _invulnerable > 0.0 or _rage_time > 0.0


func start_invulnerability(seconds: float) -> void:
	_invulnerable = maxf(_invulnerable, seconds)


## Turbo: corre mas rapido, cruza los huecos y arrolla lo que toca.
func start_turbo(seconds: float) -> void:
	_turbo_time = seconds
	_rage_time = maxf(_rage_time, seconds + 0.6)


## Estrella de poder: invencible y arrolla enemigos y obstaculos.
func start_rage(seconds: float) -> void:
	_rage_time = maxf(_rage_time, seconds)


func is_turbo() -> bool:
	return _turbo_time > 0.0


func is_raging() -> bool:
	return _rage_time > 0.0


func get_speed() -> float:
	return run_speed * (TURBO_MULT if _turbo_time > 0.0 else 1.0)


## Animacion de dano (retroceso y destello).
func play_hurt() -> void:
	_hurt_time = 0.4


## Recoloca al heroe tras caer por un hueco o al revivir.
func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_buffer = 0.0
	_jumping = false
	_fell_reported = false
	_was_on_floor = false


## Vuelve a la vida (objeto Revivir).
func revive(pos: Vector2) -> void:
	alive = true
	active = true
	collision_mask = 1
	_tilt = 0.0
	respawn(pos)


## Animacion de derrota: sale despedido girando y cae fuera de la pantalla.
func die() -> void:
	if not alive:
		return
	alive = false
	active = false
	collision_mask = 0
	velocity = Vector2(-150.0, -760.0)
	_turbo_time = 0.0
	_rage_time = 0.0
	_dust.emitting = false


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

	if _turbo_time > 0.0:
		_turbo_time -= delta
		# El turbo nunca se acaba justo encima de un hueco.
		if _turbo_time <= 0.0 and not Daylight.is_ground(global_position.x + 24.0):
			_turbo_time = 0.1
	_rage_time = maxf(_rage_time - delta, 0.0)
	_hurt_time = maxf(_hurt_time - delta, 0.0)

	var on_floor: bool = is_on_floor()
	# Con turbo corre por encima de los huecos.
	var air_run: bool = _turbo_time > 0.0 and not on_floor and velocity.y >= 0.0 and position.y >= GROUND_Y - 2.0 and position.y < GROUND_Y + 30.0
	if air_run:
		position.y = GROUND_Y - 1.0
		velocity.y = 0.0
	elif not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if on_floor or air_run:
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
	_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		_do_jump()

	# Salto de altura variable: al soltar el boton se recorta la subida.
	if _jumping:
		_jump_time += delta
		if velocity.y >= 0.0:
			_jumping = false
		elif _jump_time >= MIN_JUMP_TIME and not Input.is_action_pressed(GameData.ACTION):
			if velocity.y < JUMP_CUT_VELOCITY:
				velocity.y = JUMP_CUT_VELOCITY
			_jumping = false

	velocity.x = get_speed()
	move_and_slide()

	# Ayuda en cornisas: si roza el borde de un hueco por muy poco, sube.
	if is_on_wall() and not is_on_floor() and velocity.y >= 0.0:
		if position.y > GROUND_Y and position.y < GROUND_Y + 14.0:
			position.y = GROUND_Y - 1.0
			velocity.y = 0.0

	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		_squash = Vector2(1.25, 0.75)
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


func _check_attack_hits() -> void:
	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("enemies") and area.has_method("hit"):
			_strike(area)


## Golpea a un enemigo y avisa del resultado.
func _strike(area: Area2D) -> void:
	var kind: int = int(area.get("kind"))
	var hit_pos: Vector2 = area.global_position
	var result: int = int(area.call("hit"))
	if soul_armed:
		# Golpe de Soul Reaper: remata aunque el enemigo tenga escudo.
		soul_armed = false
		var guard: int = 0
		while result < 0 and guard < 4:
			result = int(area.call("hit"))
			guard += 1
		soul_strike.emit(hit_pos)
	if result > 0:
		enemy_killed.emit(result, hit_pos, kind)
	elif result < 0:
		enemy_hit.emit(hit_pos)


## Contacto con peligros y enemigos: arrolla (turbo / estrella), gasta el
## escudo o recibe dano.
func _check_contacts() -> void:
	for area in hurt_box.get_overlapping_areas():
		var is_enemy: bool = area.is_in_group("enemies")
		var is_hazard: bool = area.is_in_group("hazards")
		if not is_enemy and not is_hazard:
			continue
		if _rage_time > 0.0:
			if is_enemy and area.has_method("hit"):
				_strike(area)
			elif is_hazard and area.has_method("destroy"):
				var center: Vector2 = area.call("get_center")
				if bool(area.call("destroy")):
					hazard_smashed.emit(center)
			continue
		if _invulnerable > 0.0:
			continue
		if shield_active:
			shield_active = false
			_invulnerable = 1.2
			shield_broken.emit()
		else:
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
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	var running: bool = alive and (demo_mode or (active and is_on_floor()) or _turbo_time > 0.0)
	if _dust.emitting != running:
		_dust.emitting = running
	queue_redraw()


func _draw() -> void:
	var alpha: float = 1.0
	if alive and _invulnerable > 0.0 and _rage_time <= 0.0 and int(_invulnerable * 14.0) % 2 == 0:
		alpha = 0.3
	var tint: Color = Color(1.0, 1.0, 1.0, alpha)
	if _hurt_time > 0.0:
		tint = Color(1.0, 0.45, 0.45, alpha)
	elif _rage_time > 0.0:
		# Destello dorado mientras es invencible.
		var glow: float = 0.75 + 0.25 * sin(_anim * 30.0)
		tint = Color(1.0, 0.95 * glow + 0.05, 0.55 * glow, alpha)
	var on_floor: bool = demo_mode or is_on_floor() or _turbo_time > 0.0

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

	# Al morir gira sobre su centro; en vida se aplasta y estira desde los pies.
	var pivot: Vector2 = Vector2.ZERO if alive else Vector2(0.0, -34.0)
	var lean: float = _tilt
	if alive:
		if _hurt_time > 0.0:
			lean = -0.35 * (_hurt_time / 0.4)
		elif _turbo_time > 0.0:
			lean = 0.22
		elif _attack_time > 0.0:
			lean = 0.10
	var body_xf: Transform2D = Transform2D(lean, _squash, 0.0, pivot)
	draw_set_transform_matrix(body_xf)
	PixelArt.draw_skin(self, cape, Vector2(-38.0, -36.0 + bob) - pivot, 4.0, tint, _skin, _skin_key)
	PixelArt.draw_skin(self, legs, Vector2(-28.0, -16.0) - pivot, 4.0, tint, _skin, _skin_key)
	PixelArt.draw_skin(self, "hero_top", Vector2(-28.0, -68.0 + bob) - pivot, 4.0, tint, _skin, _skin_key)

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
	elif _turbo_time > 0.0:
		sword_angle = 1.45
	elif not on_floor:
		sword_angle = 0.2 if velocity.y < 0.0 else 0.95
	draw_set_transform_matrix(body_xf * Transform2D(sword_angle, hand))
	PixelArt.draw_skin(self, "sword", Vector2(-10.0, -40.0), 4.0, tint, _sword, _sword_key)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Burbuja del escudo.
	if alive and shield_active:
		_draw_ring(Vector2(0.0, -32.0), 46.0, Pal.CYAN, 0.8)
	# Lineas de velocidad del turbo.
	if _turbo_time > 0.0:
		for i in 5:
			var ly: float = -8.0 - float(i) * 13.0
			var lx: float = -40.0 - fposmod(_anim * 400.0 + float(i) * 37.0, 90.0)
			draw_rect(Rect2(lx, ly, 34.0, 4.0), Color(Pal.WHITE, 0.6))


## Anillo de cuadraditos (escudo).
func _draw_ring(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var steps: int = 20
	for i in steps:
		var angle: float = float(i) / float(steps) * TAU + _anim * 1.5
		var p: Vector2 = center + Vector2(cos(angle), sin(angle) * 1.05) * radius
		var a: float = alpha * (0.5 + 0.5 * sin(angle * 2.0 + _anim * 6.0))
		draw_rect(Rect2(snappedf(p.x, 4.0) - 2.0, snappedf(p.y, 4.0) - 2.0, 4.0, 4.0), Color(color, a))


## Estela del tajo: cuadraditos a lo largo del arco que recorre la espada.
func _draw_slash(hand: Vector2, current_angle: float, progress: float, alpha: float) -> void:
	var fade: float = clampf(1.0 - progress, 0.0, 1.0) * alpha
	var angle: float = -1.0
	while angle < current_angle:
		var dir: Vector2 = Vector2(sin(angle), -cos(angle))
		var closeness: float = 1.0 - clampf((current_angle - angle) / 3.3, 0.0, 1.0)
		for ring in 3:
			var radius: float = 44.0 + float(ring) * 10.0
			var p: Vector2 = hand + dir * radius
			var color: Color = _slash_b if ring == 1 else _slash_a
			if soul_armed:
				color = Pal.PURPLE if ring != 1 else Pal.RED
			draw_rect(Rect2(snappedf(p.x, 4.0) - 4.0, snappedf(p.y, 4.0) - 4.0, 8.0, 8.0), Color(color, fade * closeness))
		angle += 0.16
