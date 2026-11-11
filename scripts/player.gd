extends CharacterBody2D
## El heroe. Corre solo hacia la derecha; el unico boton del juego llama a
## press(): si hay un enemigo al alcance ataca, y si no, salta.
## Mantener el boton pulsado alarga el salto (salto de altura variable).
##
## El origen del nodo esta en los pies del personaje.

signal jumped(pos: Vector2)
signal landed(pos: Vector2)
signal attacked(pos: Vector2)
signal coin_collected(value: int, pos: Vector2, special: bool)
signal enemy_killed(points: int, pos: Vector2, kind: int)
signal damaged
signal fell

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

const GRAVITY := 2500.0
const JUMP_VELOCITY := -930.0
## Al soltar el boton la velocidad de subida se recorta a este valor.
const JUMP_CUT_VELOCITY := -340.0
## Tiempo minimo antes de poder recortar el salto (altura del salto corto).
const MIN_JUMP_TIME := 0.08
const MAX_FALL_SPEED := 1500.0
## Margen para saltar justo despues de abandonar una cornisa.
const COYOTE_TIME := 0.10
## Margen para pulsar un poco antes de tocar el suelo.
const JUMP_BUFFER_TIME := 0.14
const ATTACK_TIME := 0.30
const GROUND_Y := 560.0
const FALL_LIMIT_Y := 820.0
const RUN_FRAMES := ["hero_run_a", "hero_run_b", "hero_run_c", "hero_run_b"]

## Velocidad horizontal actual (la fija game.gd).
var run_speed: float = 340.0
## Solo se mueve y responde al boton cuando esta activo.
var active: bool = false
var alive: bool = true
## Modo decorativo para el menu principal: solo anima la carrera.
var demo_mode: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _jump_time: float = 0.0
var _jumping: bool = false
var _attack_time: float = 0.0
var _invulnerable: float = 0.0
var _anim: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _tilt: float = 0.0
var _was_on_floor: bool = true
var _fell_reported: bool = false
var _dust: CPUParticles2D

@onready var hurt_box: Area2D = $HurtBox
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	add_to_group("player")
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	_create_dust()


## Polvo continuo bajo los pies mientras corre.
func _create_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(-14.0, -2.0)
	_dust.amount = 10
	_dust.lifetime = 0.35
	_dust.local_coords = false
	_dust.direction = Vector2(-1.0, -0.6)
	_dust.spread = 25.0
	_dust.gravity = Vector2(0.0, 300.0)
	_dust.initial_velocity_min = 30.0
	_dust.initial_velocity_max = 90.0
	_dust.scale_amount_min = 3.0
	_dust.scale_amount_max = 6.0
	_dust.color = Color(Pal.WHITE, 0.7)
	_dust.emitting = false
	_dust.show_behind_parent = true
	add_child(_dust)


# ------------------------------------------------------------------ boton --

## Pulsacion del unico boton del juego.
func press() -> void:
	if not active or not alive:
		return
	if _any_enemy_in_reach():
		if _attack_time <= 0.1:
			_start_attack()
	else:
		_buffer = JUMP_BUFFER_TIME


## Distancia a la que un enemigo convierte el boton en ataque.
## Crece con la velocidad para que el tiempo de reaccion sea constante.
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
	return _invulnerable > 0.0


func start_invulnerability(seconds: float) -> void:
	_invulnerable = seconds


## Recoloca al heroe tras caer por un hueco.
func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_buffer = 0.0
	_jumping = false
	_fell_reported = false
	_was_on_floor = false


## Animacion de derrota: sale despedido y cae fuera de la pantalla.
func die() -> void:
	if not alive:
		return
	alive = false
	active = false
	collision_mask = 0
	velocity = Vector2(-150.0, -760.0)
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

	var on_floor: bool = is_on_floor()

	# Gravedad.
	if not on_floor:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	# Tiempo "coyote" y salto en espera.
	if on_floor:
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

	velocity.x = run_speed
	move_and_slide()

	# Ayuda en cornisas: si roza el borde de un hueco por muy poco, sube.
	if is_on_wall() and not is_on_floor() and velocity.y >= 0.0:
		if position.y > GROUND_Y and position.y < GROUND_Y + 14.0:
			position.y = GROUND_Y - 1.0
			velocity.y = 0.0

	# Aterrizaje.
	var now_on_floor: bool = is_on_floor()
	if now_on_floor and not _was_on_floor:
		_squash = Vector2(1.25, 0.75)
		landed.emit(global_position)
	_was_on_floor = now_on_floor

	# Ataque: mientras dura, cualquier enemigo dentro del area recibe el golpe.
	if _attack_time > 0.0:
		_attack_time -= delta
		_check_attack_hits()

	# Dano por contacto con pinchos, rocas o enemigos.
	if _invulnerable > 0.0:
		_invulnerable -= delta
	else:
		_check_hazards()

	# Caida por un hueco.
	if position.y > FALL_LIMIT_Y and not _fell_reported:
		_fell_reported = true
		fell.emit()


func _check_attack_hits() -> void:
	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("enemies") and area.has_method("kill"):
			var kind: int = int(area.get("kind"))
			var hit_pos: Vector2 = area.global_position
			var points: int = int(area.call("kill"))
			if points > 0:
				enemy_killed.emit(points, hit_pos, kind)


func _check_hazards() -> void:
	for area in hurt_box.get_overlapping_areas():
		if area.is_in_group("hazards") or area.is_in_group("enemies"):
			damaged.emit()
			return


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not alive or not area.is_in_group("coins"):
		return
	if bool(area.get("collected")):
		return
	var value: int = int(area.get("value"))
	var special: bool = bool(area.get("special"))
	var pos: Vector2 = area.global_position
	area.call("collect")
	coin_collected.emit(value, pos, special)


# -------------------------------------------------------------- animacion --

func _process(delta: float) -> void:
	_anim += delta * clampf(run_speed / 340.0, 0.8, 1.8)
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	var running: bool = alive and (demo_mode or (active and is_on_floor()))
	if _dust.emitting != running:
		_dust.emitting = running
	queue_redraw()


func _draw() -> void:
	var alpha: float = 1.0
	if alive and _invulnerable > 0.0 and int(_invulnerable * 14.0) % 2 == 0:
		alpha = 0.3
	var tint: Color = Color(1.0, 1.0, 1.0, alpha)
	var on_floor: bool = demo_mode or is_on_floor()

	# Sombra en el suelo.
	if alive and on_floor:
		draw_rect(Rect2(-20.0, -2.0, 40.0, 4.0), Color(0.0, 0.0, 0.0, 0.22))

	# Fotograma del cuerpo.
	var frame: String = "hero_run_a"
	var bob: float = 0.0
	if not alive:
		frame = "hero_fall"
	elif not on_floor:
		frame = "hero_jump" if velocity.y < 0.0 else "hero_fall"
	else:
		var index: int = int(_anim * 11.0) % 4
		frame = RUN_FRAMES[index]
		if index % 2 == 1:
			bob = -4.0

	# Al morir gira sobre su centro; en vida se aplasta y estira desde los pies.
	var pivot: Vector2 = Vector2.ZERO if alive else Vector2(0.0, -30.0)
	var body_xf: Transform2D = Transform2D(_tilt, _squash, 0.0, pivot)
	draw_set_transform_matrix(body_xf)
	PixelArt.draw(self, frame, Vector2(-24.0, -60.0 + bob) - pivot, 4.0, tint)

	# Espada: gira alrededor de la mano.
	var hand: Vector2 = Vector2(16.0, -22.0 + bob) - pivot
	var sword_angle: float = 0.55 + sin(_anim * 11.0) * 0.08
	if not alive:
		sword_angle = 2.4
	elif _attack_time > 0.0:
		var progress: float = 1.0 - _attack_time / ATTACK_TIME
		var swing: float = minf(progress / 0.45, 1.0)
		swing = 1.0 - (1.0 - swing) * (1.0 - swing)
		sword_angle = lerpf(-1.0, 2.3, swing)
		_draw_slash(hand, sword_angle, progress, alpha)
	elif not on_floor:
		sword_angle = 0.2 if velocity.y < 0.0 else 0.95
	draw_set_transform_matrix(body_xf * Transform2D(sword_angle, hand))
	PixelArt.draw(self, "sword", Vector2(-10.0, -40.0), 4.0, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
			var color: Color = Pal.WHITE if ring == 1 else Pal.CYAN
			draw_rect(Rect2(snappedf(p.x, 4.0) - 4.0, snappedf(p.y, 4.0) - 4.0, 8.0, 8.0), Color(color, fade * closeness))
		angle += 0.16
