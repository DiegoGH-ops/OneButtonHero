extends Node2D
## Jefe final de un mundo. Cada jefe pelea con los ataques de SU mundo
## (campaign.gd, BOSSES) y tiene de 3 a 4 fases que cambian por tramos de
## vida. Combate de un solo boton por ciclos:
##   1. Anuncia cada ataque con un aviso propio ("¡SALTA!", "¡TOQUE CORTO!",
##      "¡FUEGO DEL CIELO!"...) y lo lanza: oleadas, columnas de alturas
##      mezcladas (salto variable), techos muy bajos, piezas tematicas
##      (raices, lluvia de fuego, cristales, lanzas, manos...) y proyectiles
##      que hay que devolver de un golpe.
##   2. Pruebas de pulsaciones (RAPID SIX del jefe): pulsar N veces en un
##      tiempo que se acorta con cada fase; algunas obligan a saltar entre
##      medias. Superarla le aturde, le hace dano y abre su guardia.
##   3. Tras varios ataques se acerca agotado ("¡AHORA!"): cuanto mas se
##      apura el golpe, mas dano (1 normal, 2 PERFECT, 3 LEGENDARY).
## Al cambiar de fase ruge, se vuelve mas rapido y combina mas ataques.

signal struck
signal defeated

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Obstacle = preload("res://scripts/obstacle.gd")
const Creature = preload("res://scripts/creature.gd")
const BossCore = preload("res://scripts/boss_core.gd")

enum State { ENTER, TELEGRAPH, WAIT, VULNERABLE, RETREAT, PHASE_SHIFT, DEAD }

const GROUND_Y := 560.0
const FAR_OFFSET := 560.0
## Avisos de cada ataque: [texto, color]. Todos llegan con tiempo de sobra
## para reaccionar (se acortan un poco en cada fase).
const TELLS := {
	"wave": ["¡SALTA!", "ffcd75"], "double_wave": ["¡DOS SALTOS!", "ffcd75"], "wall": ["¡SALTO LARGO!", "ef7d57"],
	"boulder": ["¡ROCA!", "ffcd75"], "orb": ["¡GOLPEA!", "b13e53"], "double_orb": ["¡GOLPEA DOS VECES!", "b13e53"],
	"feint": ["...", "94b0c2"], "pillars": ["¡CONTROLA EL SALTO!", "73eff7"], "tap": ["¡TOQUE CORTO!", "73eff7"],
	"rapid": ["¡PREPÁRATE PARA PULSAR!", "ef7d57"],
	"roots": ["¡RAÍCES!", "38b764"], "spores": ["¡ESPORAS!", "a7f070"],
	"fire_rain": ["¡FUEGO DEL CIELO!", "ef7d57"], "geysers": ["¡GÉISERES!", "ef7d57"], "magma_wave": ["¡ONDA DE MAGMA!", "b13e53"],
	"shards": ["¡CRISTALES!", "f29cb5"], "mirror": ["¡DEVUÉLVELO!", "f29cb5"],
	"spears": ["¡LANZAS DE HIELO!", "73eff7"], "avalanche": ["¡ALUD!", "f4f4f4"], "quake": ["¡TERREMOTO!", "73eff7"],
	"hands": ["¡MIRA EL SUELO!", "ffcd75"], "burrow": ["¡SE ENTIERRA!", "8a5a44"], "sandstorm": ["¡TORMENTA DE ARENA!", "ffcd75"],
}
## Columnas del ataque "pillars" por fase (salto variable puro).
const PILLAR_DRILLS := [["mid", "tap"], ["tap", "high", "tap"], ["high", "tap", "max"], ["max", "tap", "high", "tap"]]

var hp: int = 10
var max_hp: int = 10
var phase: int = 0
var world: int = 0

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
var _dip: float = 0.0
var _queue: Array = []
var _current: String = ""
var _label: String = ""
var _label_color: Color = Pal.YELLOW
var _time: float = 0.0
var _flash: float = 0.0
var _hit_cooldown: float = 0.0
var _reflects: int = 0
var _window: float = 1.0
var _cycles: int = 0
## Ataques programados: [segundos que faltan, nombre, dato].
var _scheduled: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Prepara al jefe del mundo indicado. Llamar despues de anadirlo al arbol.
func setup(p_world: int, generator: Node) -> void:
	world = clampi(p_world, 0, Campaign.BOSSES.size() - 1)
	_data = Campaign.BOSSES[world]
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


func phase_count() -> int:
	var phases: Array = _data["phases"]
	return phases.size()


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
	_cycles += 1
	var count: int = 2 + phase
	var last: String = ""
	var used_rapid: bool = false
	for i in count:
		var pick: String = String(attacks[_rng.randi() % attacks.size()])
		var tries: int = 0
		# Sin repetir el mismo ataque seguido; una prueba de pulsaciones por
		# ciclo como mucho (y nunca en el primer ciclo).
		while tries < 6 and (pick == last or (pick == "rapid" and (used_rapid or _cycles == 1))):
			pick = String(attacks[_rng.randi() % attacks.size()])
			tries += 1
		if pick == "rapid" and (used_rapid or _cycles == 1):
			pick = "wave"
		used_rapid = used_rapid or pick == "rapid"
		_queue.append(pick)
		last = pick
	_reflects = 0
	_next_attack()


func _next_attack() -> void:
	if _queue.is_empty():
		# La emperatriz solo baja la guardia si le devuelven un proyectil.
		if bool(_data.get("needs_reflect", false)) and _reflects == 0:
			_queue.append("mirror")
		else:
			_open_window()
			return
	_current = String(_queue.pop_front())
	_state = State.TELEGRAPH
	var tell: float = maxf(0.85 - 0.12 * float(phase), 0.45)
	var info: Array = TELLS.get(_current, ["¡SALTA!", "ffcd75"])
	_label = String(info[0])
	_label_color = Color(String(info[1]))
	# Finta: el aviso dura mucho mas de lo normal para romper el ritmo.
	if _current == "feint":
		tell *= 2.3
	elif _current == "rapid":
		tell += 0.3
	_timer = tell
	Sfx.play("hover" if _current.contains("orb") or _current == "mirror" else "click")


## Lanza el ataque anunciado. Las distancias se miden en tiempo (velocidad
## del heroe), asi el reto es justo a cualquier velocidad.
func _perform() -> void:
	var speed: float = maxf(Daylight.run_speed, 200.0)
	var px: float = Daylight.player_pos.x
	var wave_kind: int = int(_data["wave"])
	var wait: float = 820.0 / speed + 0.45
	match _current:
		"wave", "feint":
			_generator.call("spawn_obstacle", wave_kind, px + 800.0, 1 + mini(phase, 2))
		"double_wave":
			_generator.call("spawn_obstacle", wave_kind, px + 800.0, 1)
			_generator.call("spawn_obstacle", wave_kind, px + 832.0 + speed * 0.66, 1)
			wait += 0.7
		"wall":
			_generator.call("spawn_obstacle", Obstacle.Kind.TOTEM, px + 840.0, 1)
		"boulder":
			_generator.call("spawn_obstacle", Obstacle.Kind.BOULDER, px + 1150.0, 1)
			wait += 0.5
		"orb", "mirror":
			_spawn_orb()
			wait = 1.1
		"double_orb":
			_spawn_orb()
			_schedule(0.5, "orb_extra", 0.0)
			wait = 1.7
		"pillars":
			var drill: Array = PILLAR_DRILLS[clampi(phase, 0, PILLAR_DRILLS.size() - 1)]
			var x: float = px + 820.0
			for step in drill:
				x = float(_generator.call("spawn_step", String(step), x)) + speed * 0.4
			wait = (x - px) / speed + 0.2
		"tap":
			_generator.call("spawn_step", "tap", px + 820.0)
		"rapid":
			var mash: Array = _data["mash"]
			var rule: Array = mash[clampi(phase, 0, mash.size() - 1)]
			_generator.call("spawn_rapid", px + speed * 1.5, int(rule[2]), float(rule[1]), int(rule[0]), String(_data.get("mash_name", "RAPID SIX")))
			wait = 1.5 + float(rule[1]) + 1.6
		# --- Verdantia: raices que brotan con alturas distintas y esporas.
		"roots":
			var heights: Array = [[1, 2, 1], [2, 4, 1], [3, 1, 5]][clampi(phase, 0, 2)]
			for i in heights.size():
				_generator.call("spawn_obstacle", Obstacle.Kind.PILLAR, px + 820.0 + float(i) * speed * 0.75, int(heights[i]))
			wait += 1.5
		"spores":
			for i in 2 + mini(phase, 1):
				_schedule(0.38 * float(i), "spore", 0.0)
			wait = 1.6
		# --- Infernus: lluvia de fuego, geiseres y ondas de magma.
		"fire_rain":
			for i in 2 + mini(phase, 2):
				var target: float = px + speed * (0.95 + 0.45 * float(i))
				_generator.call("spawn_piece", Creature.FIREBALL, target, {"y": -440.0})
			wait = 2.0 + 0.3 * float(phase)
		"geysers":
			_generator.call("spawn_piece", Creature.FLAME, px + speed * 1.0, {})
			_generator.call("spawn_piece", Creature.FLAME, px + speed * 1.55, {})
			if phase >= 2:
				_generator.call("spawn_piece", Creature.FLAME, px + speed * 2.1, {})
			wait = 2.2
		"magma_wave":
			_schedule(0.0, "wave_piece", 0.0)
			_schedule(0.6, "wave_piece", 0.0)
			wait = 2.0
		# --- Amethystia: cristales saltarines.
		"shards":
			for i in 3:
				_generator.call("spawn_piece", Creature.SHARD, position.x - 90.0 + float(i) * 44.0, {"phase": i})
			wait = 2.0
		# --- Frostfall: lanzas en arco, aludes y terremotos.
		"spears":
			for i in 2 + mini(phase, 1):
				_schedule(0.4 * float(i), "spear", float(i))
			wait = 2.0
		"avalanche":
			_schedule(0.0, "snowball", 0.0)
			_schedule(0.7, "snowball", 0.0)
			wait = 2.4
		"quake":
			for i in 1 + int(float(phase) / 2.0) + 1:
				_schedule(0.55 * float(i), "quake_piece", 0.0)
			wait = 1.8
		# --- Solaris: manos que surgen, se entierra y tormenta de arena.
		"hands":
			for i in 3:
				_schedule(0.45 * float(i), "hand", float(i))
			wait = 2.2
		"burrow":
			_dip = 1.0
			_generator.call("spawn_creature", 4, 1, px + speed * 1.3)
			wait = 2.4
		"sandstorm":
			for i in 3 + mini(phase, 1):
				_schedule(0.32 * float(i), "sand", 0.0)
			wait = 2.0
	_state = State.WAIT
	_timer = wait
	_label = ""


func _schedule(delay: float, action: String, value: float) -> void:
	_scheduled.append([delay, action, value])


func _run_scheduled(action: String, value: float) -> void:
	var speed: float = maxf(Daylight.run_speed, 200.0)
	var px: float = Daylight.player_pos.x
	match action:
		"orb_extra":
			_spawn_orb()
		"spore":
			_generator.call("spawn_piece", Creature.SPORE, position.x - 80.0, {})
			Sfx.play("attack", 0.8)
		"wave_piece":
			_generator.call("spawn_piece", Creature.SHOCKWAVE, position.x - 80.0, {"color": "ef7d57"})
			Sfx.play("boss_hit", 0.7)
		"quake_piece":
			_generator.call("spawn_piece", Creature.SHOCKWAVE, position.x - 80.0, {})
			Sfx.play("boss_hit", 0.6)
		"spear":
			var target_x: float = px + speed * (0.9 + 0.2 * value)
			var vx: float = (target_x - (position.x - 60.0)) / 0.68
			_generator.call("spawn_piece", Creature.SPEAR, position.x - 60.0, {"vx": vx, "vy": -560.0, "y": -90.0})
			Sfx.play("attack", 0.7)
		"snowball":
			_generator.call("spawn_piece", Creature.SNOWBALL, position.x - 80.0, {})
		"hand":
			_generator.call("spawn_piece", Creature.HAND, px + speed * (0.75 + 0.1 * value), {})
		"sand":
			_generator.call("spawn_piece", Creature.SPORE, position.x - 80.0, {"color": "ffcd75"})


func _spawn_orb() -> void:
	var orb: Variant = _generator.call("spawn_enemy", Enemy.Kind.ORB, position.x - 70.0)
	if orb is Node:
		var node: Node = orb
		node.set("orb_color", glow_color)
	Sfx.play("attack", 0.7)


## Se acerca agotado: es el momento de golpearle.
func _open_window(bonus: float = 0.0) -> void:
	_state = State.VULNERABLE
	_window = maxf(1.7 - 0.22 * float(phase), 1.0) + bonus
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
	if _state != State.DEAD and _state != State.PHASE_SHIFT:
		_retreat()


## Prueba de pulsaciones superada: el jefe queda aturdido, recibe dano y
## abre la guardia un poco mas de lo normal.
func on_rapid_success() -> void:
	if _state == State.DEAD:
		return
	damage(1)
	if _state != State.DEAD and _state != State.PHASE_SHIFT:
		_queue = []
		_scheduled = []
		_open_window(0.5)
		_label = "¡ATURDIDO!"


## Proyectil devuelto con un golpe perfecto.
func reflect() -> void:
	_reflects += 1
	damage(1)


func damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	hp = maxi(hp - amount, 0)
	_flash = 0.3
	var count: int = phase_count()
	var ratio: float = float(hp) / float(maxi(max_hp, 1))
	var new_phase: int = clampi(int((1.0 - ratio) * float(count)), 0, count - 1)
	if hp <= 0:
		_state = State.DEAD
		_timer = 2.2
		_label = ""
		_scheduled = []
		_set_core_active(false)
		Sfx.play("boss_hit", 0.5)
		return
	if new_phase > phase:
		phase = new_phase
		# Cambio de fase: ruge, se retira y vuelve con mas ataques.
		_state = State.PHASE_SHIFT
		_timer = 1.5
		_queue = []
		_scheduled = []
		_label = Loc.s("FASE %d") % (phase + 1)
		_label_color = Pal.RED
		_target_offset = FAR_OFFSET + 60.0
		_set_core_active(false)
		Sfx.play("boss_hit", 0.7)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_dip = maxf(_dip - delta * 0.6, 0.0)
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_timer -= delta
	for i in range(_scheduled.size() - 1, -1, -1):
		var job: Array = _scheduled[i]
		job[0] = float(job[0]) - delta
		if float(job[0]) <= 0.0 and _state != State.DEAD:
			_scheduled.remove_at(i)
			_run_scheduled(String(job[1]), float(job[2]))

	match _state:
		State.ENTER:
			if _timer <= 0.0:
				_begin_cycle()
		State.TELEGRAPH:
			if _timer <= 0.0:
				_perform()
		State.WAIT:
			if _timer <= 0.0:
				_next_attack()
		State.VULNERABLE:
			# Se va acercando: cuanto mas se espera, mejor golpe... y mas riesgo
			# de que la oportunidad se escape.
			_target_offset = lerpf(138.0, 230.0, clampf(_timer / _window, 0.0, 1.0))
			if _timer <= 0.0:
				_retreat()
		State.RETREAT, State.PHASE_SHIFT:
			if _timer <= 0.0:
				_target_offset = FAR_OFFSET
				_begin_cycle()
		State.DEAD:
			position.y += 160.0 * delta
			rotation += 0.6 * delta
			modulate.a = clampf(_timer / 2.2, 0.0, 1.0)
			if _timer <= 0.0:
				defeated.emit()
				queue_free()
			queue_redraw()
			return

	_offset = lerpf(_offset, _target_offset, minf(1.0, delta * 6.0))
	position = Vector2(Daylight.player_pos.x + _offset, GROUND_Y - 150.0 + sin(_time * 2.0) * 10.0 + _dip * 260.0)
	queue_redraw()


func _draw() -> void:
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _flash > 0.0:
		tint = Color(3.0, 2.0, 2.0, 1.0)
	elif _state == State.TELEGRAPH and int(_time * 12.0) % 2 == 0:
		tint = Color(1.6, 1.6, 1.2, 1.0)
	elif _state == State.PHASE_SHIFT:
		tint = Color(1.8, 0.8, 0.8, 1.0) if int(_time * 16.0) % 2 == 0 else Color(1.0, 1.0, 1.0, 1.0)
	var shake: Vector2 = Vector2.ZERO
	if _state == State.DEAD or _flash > 0.0 or _state == State.PHASE_SHIFT:
		shake = Vector2(sin(_time * 70.0) * 6.0, cos(_time * 55.0) * 4.0)
	# Aura de su mundo, mas intensa en cada fase.
	PixelArt.draw_glow(self, Vector2.ZERO, 150.0 + 30.0 * float(phase), Color(glow_color, 0.18 + 0.08 * float(phase)))
	var grow: float = 1.0 + (0.06 * sin(_time * 14.0) if _state == State.VULNERABLE else 0.0)
	draw_set_transform(shake, 0.0, Vector2(grow, grow))
	PixelArt.draw(self, String(_data.get("sprite", "boss_root")), Vector2(-80.0, -80.0), 10.0, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Marcas de fase bajo el jefe.
	for i in phase_count():
		var on: bool = i <= phase
		draw_rect(Rect2(-float(phase_count()) * 12.0 + float(i) * 24.0, 96.0, 16.0, 8.0), glow_color if on else Pal.SLATE)
	# Punto debil a la vista mientras esta vulnerable.
	if _state == State.VULNERABLE:
		var beat: float = 18.0 + sin(_time * 16.0) * 5.0
		PixelArt.draw_glow(self, _core.position, beat + 16.0, Color(Pal.LIME, 0.8))
		draw_rect(Rect2(_core.position - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), Pal.WHITE)
	if _label != "":
		var w: float = PixelFont.text_width(_label, 4.0)
		var bounce: float = roundf(absf(sin(_time * 9.0)) * 6.0)
		PixelFont.draw_text_shadowed(self, _label, Vector2(roundf(-w * 0.5), -128.0 - bounce), 4.0, _label_color, Pal.INK, true)
