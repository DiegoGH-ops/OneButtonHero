extends Node2D
## Jefe final de un mundo. Combate de un solo boton por ciclos:
##   1. Anuncia cada ataque ("¡SALTA!" o "¡GOLPEA!") y lo lanza:
##      oleadas y muros que hay que saltar, y proyectiles que hay que
##      devolver de un golpe (con PERFECT o LEGENDARY le hacen dano).
##   2. Tras varios ataques se acerca agotado ("¡AHORA!"): cuanto mas se
##      apura el golpe, mas dano (1 normal, 2 PERFECT, 3 LEGENDARY).
## Cada tercio de vida cambia de fase: avisos mas cortos, mas ataques por
## ciclo, ataques nuevos y fintas. Los datos estan en campaign.gd (BOSSES).

signal struck
signal defeated

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Obstacle = preload("res://scripts/obstacle.gd")
const BossCore = preload("res://scripts/boss_core.gd")

enum State { ENTER, TELEGRAPH, WAIT, VULNERABLE, RETREAT, DEAD }

const GROUND_Y := 560.0
const FAR_OFFSET := 560.0

var hp: int = 10
var max_hp: int = 10
var phase: int = 0

var glow_radius: float = 170.0
var glow_color: Color = Pal.RED
var glow_day: float = 0.25

var _data: Dictionary = {}
var _generator: Node
var _core: BossCore
var _state: int = State.ENTER
var _timer: float = 1.6
var _offset: float = 980.0
var _target_offset: float = FAR_OFFSET
var _queue: Array = []
var _current: String = ""
var _label: String = ""
var _label_color: Color = Pal.YELLOW
var _time: float = 0.0
var _flash: float = 0.0
var _hit_cooldown: float = 0.0
var _reflects: int = 0
var _second_orb: float = -1.0
var _window: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Prepara al jefe del mundo indicado. Llamar despues de anadirlo al arbol.
func setup(world: int, generator: Node) -> void:
	_data = Campaign.BOSSES[clampi(world, 0, Campaign.BOSSES.size() - 1)]
	_generator = generator
	max_hp = int(_data["hp"])
	hp = max_hp
	glow_color = Color(String(_data["color"]))
	_rng.randomize()
	add_to_group("glow")
	_core = BossCore.new()
	_core.boss = self
	_core.collision_layer = 8
	_core.collision_mask = 0
	_core.monitoring = false
	_core.monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(24.0, 40.0)
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	_core.add_child(collider)
	add_child(_core)
	_core.position = Vector2(-80.0, 100.0)
	position = Vector2(Daylight.player_pos.x + _offset, GROUND_Y - 150.0)


func title() -> String:
	return String(_data.get("name", "JEFE"))


func _set_core_active(active: bool) -> void:
	_core.set_deferred("monitorable", active)
	if active:
		_core.add_to_group("enemies")
	elif _core.is_in_group("enemies"):
		_core.remove_from_group("enemies")


# ----------------------------------------------------------------- ciclo --

func _begin_cycle() -> void:
	var phases: Array = _data["phases"]
	var attacks: Array = phases[clampi(phase, 0, phases.size() - 1)]
	_queue = []
	for i in 2 + phase:
		_queue.append(attacks[_rng.randi() % attacks.size()])
	_reflects = 0
	_next_attack()


func _next_attack() -> void:
	if _queue.is_empty():
		# La emperatriz solo baja la guardia si le devuelven un proyectil.
		if bool(_data.get("needs_reflect", false)) and _reflects == 0:
			_queue.append("orb")
		else:
			_open_window()
			return
	_current = String(_queue.pop_front())
	_state = State.TELEGRAPH
	var tell: float = maxf(0.8 - 0.13 * float(phase), 0.42)
	var is_orb: bool = _current == "orb" or _current == "double_orb"
	_label = "¡GOLPEA!" if is_orb else "¡SALTA!"
	_label_color = Pal.RED if is_orb else Pal.YELLOW
	# Finta: el aviso dura mucho mas de lo normal para romper el ritmo.
	if _current == "feint":
		tell *= 2.3
	_timer = tell
	Sfx.play("hover" if is_orb else "click")


func _perform() -> void:
	var speed: float = maxf(Daylight.run_speed, 200.0)
	var px: float = Daylight.player_pos.x
	var wave_kind: int = int(_data["wave"])
	var wait: float = 820.0 / speed + 0.45
	if _current == "wave" or _current == "feint":
		_generator.call("spawn_obstacle", wave_kind, px + 800.0, 1 + mini(phase, 2))
	elif _current == "double_wave":
		_generator.call("spawn_obstacle", wave_kind, px + 800.0, 1)
		_generator.call("spawn_obstacle", wave_kind, px + 832.0 + speed * 0.66, 1)
		wait += 0.7
	elif _current == "wall":
		_generator.call("spawn_obstacle", Obstacle.Kind.TOTEM, px + 840.0, 1)
	elif _current == "boulder":
		_generator.call("spawn_obstacle", Obstacle.Kind.BOULDER, px + 1150.0, 1)
		wait += 0.5
	else:
		_spawn_orb()
		wait = 1.1
		if _current == "double_orb":
			_second_orb = 0.5
			wait = 1.7
	_state = State.WAIT
	_timer = wait
	_label = ""


func _spawn_orb() -> void:
	var orb: Variant = _generator.call("spawn_enemy", Enemy.Kind.ORB, position.x - 70.0)
	if orb is Node:
		var node: Node = orb
		node.set("orb_color", glow_color)
	Sfx.play("attack", 0.7)


## Se acerca agotado: es el momento de golpearle.
func _open_window() -> void:
	_state = State.VULNERABLE
	_window = maxf(1.7 - 0.25 * float(phase), 1.0)
	_timer = _window
	_label = "¡AHORA!"
	_label_color = Pal.LIME
	_set_core_active(true)
	Sfx.play("level")


func _retreat() -> void:
	_state = State.RETREAT
	_timer = 0.9
	_label = ""
	_target_offset = FAR_OFFSET
	_set_core_active(false)


## Lo llama su punto debil al recibir un golpe del heroe.
func on_core_hit() -> void:
	if _state != State.VULNERABLE or _hit_cooldown > 0.0:
		return
	_hit_cooldown = 0.35
	struck.emit()
	if _state != State.DEAD:
		_retreat()


## Proyectil devuelto con un golpe perfecto.
func reflect() -> void:
	_reflects += 1
	damage(1)


func damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	hp = maxi(hp - amount, 0)
	_flash = 0.3
	var ratio: float = float(hp) / float(maxi(max_hp, 1))
	var new_phase: int = 0
	if ratio <= 0.33:
		new_phase = 2
	elif ratio <= 0.66:
		new_phase = 1
	if new_phase > phase:
		phase = new_phase
		Sfx.play("boss_hit", 0.7)
	if hp <= 0:
		_state = State.DEAD
		_timer = 1.8
		_label = ""
		_set_core_active(false)
		Sfx.play("boss_hit", 0.5)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_timer -= delta
	if _second_orb > 0.0:
		_second_orb -= delta
		if _second_orb <= 0.0 and _state != State.DEAD:
			_spawn_orb()

	if _state == State.ENTER:
		if _timer <= 0.0:
			_begin_cycle()
	elif _state == State.TELEGRAPH:
		if _timer <= 0.0:
			_perform()
	elif _state == State.WAIT:
		if _timer <= 0.0:
			_next_attack()
	elif _state == State.VULNERABLE:
		# Se va acercando: cuanto mas se espera, mejor golpe... y mas riesgo
		# de que la oportunidad se escape.
		_target_offset = lerpf(138.0, 230.0, clampf(_timer / _window, 0.0, 1.0))
		if _timer <= 0.0:
			_retreat()
	elif _state == State.RETREAT:
		if _timer <= 0.0:
			_begin_cycle()
	elif _state == State.DEAD:
		position.y += 160.0 * delta
		rotation += 0.6 * delta
		modulate.a = clampf(_timer / 1.8, 0.0, 1.0)
		if _timer <= 0.0:
			defeated.emit()
			queue_free()
		queue_redraw()
		return

	_offset = lerpf(_offset, _target_offset, minf(1.0, delta * 6.0))
	position = Vector2(Daylight.player_pos.x + _offset, GROUND_Y - 150.0 + sin(_time * 2.0) * 10.0)
	queue_redraw()


func _draw() -> void:
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _flash > 0.0:
		tint = Color(3.0, 2.0, 2.0, 1.0)
	elif _state == State.TELEGRAPH and int(_time * 12.0) % 2 == 0:
		tint = Color(1.6, 1.6, 1.2, 1.0)
	var shake: Vector2 = Vector2.ZERO
	if _state == State.DEAD or _flash > 0.0:
		shake = Vector2(sin(_time * 70.0) * 6.0, cos(_time * 55.0) * 4.0)
	var grow: float = 1.0 + (0.06 * sin(_time * 14.0) if _state == State.VULNERABLE else 0.0)
	draw_set_transform(shake, 0.0, Vector2(grow, grow))
	PixelArt.draw(self, String(_data.get("sprite", "boss_root")), Vector2(-80.0, -80.0), 10.0, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Punto debil a la vista mientras esta vulnerable.
	if _state == State.VULNERABLE:
		var beat: float = 18.0 + sin(_time * 16.0) * 5.0
		PixelArt.draw_glow(self, _core.position, beat + 16.0, Color(Pal.LIME, 0.8))
		draw_rect(Rect2(_core.position - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), Pal.WHITE)
	if _label != "":
		var w: float = PixelFont.text_width(_label, 4.0)
		var bounce: float = roundf(absf(sin(_time * 9.0)) * 6.0)
		PixelFont.draw_text_shadowed(self, _label, Vector2(roundf(-w * 0.5), -128.0 - bounce), 4.0, _label_color, Pal.INK, true)
