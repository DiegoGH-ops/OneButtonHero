extends Node
## Generador procedural del nivel infinito.
##
## El mundo se construye por "patrones" (pinchos, roca, hueco, enemigo,
## plataforma, combinaciones...) colocados uno tras otro delante del jugador.
## Todas las distancias se miden en TIEMPO (segundos a la velocidad actual),
## asi el reto es justo a cualquier velocidad:
##   - Entre dos peligros siempre queda suelo libre para aterrizar y reaccionar.
##   - Los huecos y las filas de pinchos nunca superan lo que cubre un salto.
##   - Delante de cada enemigo hay una zona despejada mayor que su alcance,
##     de modo que el boton nunca "ataca" cuando hacia falta saltar.
## Los patrones nuevos se desbloquean al subir de nivel.

const Obstacle = preload("res://scripts/obstacle.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Coin = preload("res://scripts/coin.gd")
const GroundSpan = preload("res://scripts/ground_span.gd")
const Platform = preload("res://scripts/platform.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Goal = preload("res://scripts/goal.gd")
const Creature = preload("res://scripts/creature.gd")
const Bestiary = preload("res://scripts/bestiary.gd")
const RapidSix = preload("res://scripts/rapid_six.gd")
const ObstacleScene: PackedScene = preload("res://scenes/obstacle.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")
const CoinScene: PackedScene = preload("res://scenes/coin.tscn")

const GROUND_Y := 560.0
const TILE := 32.0
## Cuanto mundo se genera por delante y cuanto se conserva por detras.
const AHEAD := 2000.0
const BEHIND := 1000.0
const PLATFORM_HEIGHT := 112.0

enum Pattern {
	COINS, SPIKES, ROCK, SLIME, HOLE, GOBLIN, TOTEM, PLATFORM,
	BAT, DOUBLE_SPIKES, DOUBLE_ENEMY, SPIKES_HOLE, WIDE_HOLE,
	KNIGHT, GHOST, BOULDER, COINS_RICH, ROUTE, TRAP,
	CHAIN, CEILING, RAPID_SIX, BOUNCE, CREATURE,
	JUMP_DRILL, ENCOUNTER,
}

## [patron, peso, nivel minimo]
const TABLE := [
	[Pattern.COINS, 3, 0],
	[Pattern.SPIKES, 4, 0],
	[Pattern.ROCK, 3, 0],
	[Pattern.SLIME, 3, 0],
	[Pattern.HOLE, 3, 1],
	[Pattern.GOBLIN, 3, 1],
	[Pattern.TOTEM, 2, 2],
	[Pattern.PLATFORM, 2, 2],
	[Pattern.BAT, 2, 3],
	[Pattern.DOUBLE_SPIKES, 2, 3],
	[Pattern.DOUBLE_ENEMY, 2, 4],
	[Pattern.SPIKES_HOLE, 2, 4],
	[Pattern.WIDE_HOLE, 2, 5],
	[Pattern.GHOST, 2, 2],
	[Pattern.KNIGHT, 2, 3],
	[Pattern.BOULDER, 2, 3],
	[Pattern.ROUTE, 2, 2],
	[Pattern.TRAP, 2, 4],
	[Pattern.CHAIN, 2, 1],
	[Pattern.CEILING, 2, 2],
	[Pattern.RAPID_SIX, 1, 3],
	[Pattern.JUMP_DRILL, 4, 1],
	[Pattern.ENCOUNTER, 2, 5],
	[Pattern.BOUNCE, 2, 4],
	[Pattern.CREATURE, 4, 0],
]

## Patrones de menor a mayor dureza: los niveles de campana los desbloquean
## en este orden (ver campaign.gd).
const HARDNESS := [
	Pattern.COINS, Pattern.SPIKES, Pattern.ROCK, Pattern.SLIME, Pattern.HOLE,
	Pattern.GOBLIN, Pattern.ROUTE, Pattern.TOTEM, Pattern.PLATFORM, Pattern.BAT,
	Pattern.DOUBLE_SPIKES, Pattern.TRAP, Pattern.KNIGHT, Pattern.BOULDER,
	Pattern.DOUBLE_ENEMY, Pattern.SPIKES_HOLE, Pattern.WIDE_HOLE, Pattern.GHOST, Pattern.ROUTE,
]
## Mecanicas de un boton y el nivel (del mundo 1) en que se estrenan. En los
## mundos siguientes ya estan todas disponibles desde el primer nivel.
const MECHANICS := [
	[Pattern.CHAIN, 1, "SALTOS ENCADENADOS", "TRES SALTOS PERFECTOS SEGUIDOS DAN PREMIO"],
	[Pattern.CEILING, 3, "TECHO BAJO", "TOCA Y SUELTA RÁPIDO: SALTO CORTO"],
	[Pattern.RAPID_SIX, 6, "RAPID SIX", "TE DETIENES: SEIS PULSACIONES ANTES DE QUE SE ACABE EL TIEMPO"],
	[Pattern.BOUNCE, 10, "TRAMPOLÍN", "NO SALTES: PÍSALO. PULSA AL PISARLO PARA SUPER REBOTE"],
]

## Pista libre que se deja antes de la meta.
const GOAL_RUNWAY := 1500.0

## Posicion de la meta (INF en el modo infinito).
var goal_x: float = INF
var _allowed: Array = []
var _fixed_difficulty: float = -1.0
var _goal_placed: bool = false
## Nivel de jefe: suelo liso, sin patrones ni meta.
var _arena: bool = false

## Huecos como Vector2(inicio, fin). ground_renderer.gd comparte esta lista.
var holes: Array = []

var _spans: Array = []
var _current_span: GroundSpan
var _spans_root: Node2D
var _objects_root: Node2D
var _gen_x: float = 0.0
var _speed: float = 340.0
var _level: int = 0
var _difficulty: float = 0.0
var _last_pattern: int = -1
var _cleanup_timer: float = 0.0
## Patrones obligatorios pendientes (eventos como la lluvia de monedas).
var _forced: Array = []
## game.gd lo activa cuando al heroe le falta alguna vida.
## Mundo cuyas criaturas aparecen y cuales estan desbloqueadas.
var _creature_world: int = 0
var _creatures: Array = []
## Criaturas que se estrenan en este nivel (salen mas a menudo).
var _newest: Array = []
## Mejora "Fortuna": probabilidad extra de que una moneda sea un rubi.
var gem_bonus: float = 0.0
## Contadores para el rango: enemigos y recompensas generados.
var enemies_spawned: int = 0
## Encuentros multiples generados (estadistica para misiones).
var enemies_encounters: int = 0
var pickups_spawned: int = 0
## Diamante oculto de la ruta arriesgada (solo campana, una vez por nivel).
var diamond_available: bool = false
## Probabilidad de que la ruta alta lleve el diamante (mejora Ojo de joyero: 1).
var diamond_chance: float = 0.6
var _diamond_placed: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Prepara el generador y crea la zona inicial segura.
func setup(spans_root: Node2D, objects_root: Node2D) -> void:
	_spans_root = spans_root
	_objects_root = objects_root
	_rng.randomize()
	_current_span = _new_span(-900.0)
	_gen_x = 760.0
	_current_span.set_range(_current_span.start_x, _gen_x)
	# Monedas de bienvenida para aprender a moverse.
	for i in 6:
		_add_coin(Vector2(330.0 + float(i) * 48.0, GROUND_Y - 36.0), false)


## Partida de prueba del panel de administrador: solo un enemigo del mundo,
## solo un patron o, si ambos son -1, todo mezclado.
var test_creature: int = -1


func configure_test(world: int, creature: int, pattern: int) -> void:
	_fixed_difficulty = 0.6
	_creature_world = world
	_creatures = [0, 1, 2, 3, 4]
	_allowed = []
	if creature >= 0:
		test_creature = creature
		_allowed = [Pattern.CREATURE]
	elif pattern >= 0:
		_allowed = [pattern]
	else:
		for entry in TABLE:
			_allowed.append(entry[0])
	if bool(Daylight.theme.get("traps", false)):
		_allowed.append(Pattern.TRAP)


## Configura un nivel de campana (llamar despues de setup). La semilla fija
## hace que el recorrido sea siempre el mismo y se pueda aprender.
func configure(def: Dictionary) -> void:
	_rng.seed = int(def["seed"])
	_fixed_difficulty = float(def["difficulty"])
	goal_x = float(def["goal_px"])
	if bool(def.get("final", false)):
		_arena = true
		goal_x = INF
	_allowed = []
	var unlocked: int = clampi(int(def["unlocked"]), 1, HARDNESS.size())
	var focus: Array = def["focus"]
	for i in unlocked:
		# Los patrones protagonistas del nivel salen mucho mas a menudo.
		var weight: int = 2
		if i == 0:
			weight = 1
		elif focus.has(i):
			weight = 6
		for n in weight:
			_allowed.append(HARDNESS[i])
	# Mecanicas de un boton desbloqueadas (introduccion progresiva).
	var world: int = int(def["world"])
	var level: int = int(def["level"])
	for item in MECHANICS:
		var mechanic: Array = item
		if world > 0 or level >= int(mechanic[1]):
			var weight_m: int = 6 if (world == 0 and level == int(mechanic[1])) else 2
			for n in weight_m:
				_allowed.append(mechanic[0])
	# Criaturas del mundo: cada una se estrena en su nivel y despues se mezclan.
	_creature_world = world
	_creatures = Bestiary.unlocked(world, level)
	_newest = Bestiary.introduced_list(level)
	# Secuencias de salto variable: cada vez mas presentes.
	for n in 3 + int(def.get("band", 0)):
		_allowed.append(Pattern.JUMP_DRILL)
	configure_encounters(def.get("encounters", {}))
	for n in 2 + _creatures.size() * 2:
		_allowed.append(Pattern.CREATURE)
	# Solaris: las trampas antiguas son su seña de identidad.
	if bool(Daylight.theme.get("traps", false)):
		for n in 4:
			_allowed.append(Pattern.TRAP)


## Tramo final: suelo despejado y la bandera de meta.
func _finish_track() -> void:
	if not _goal_placed:
		_goal_placed = true
		var goal: Goal = Goal.new()
		goal.position = Vector2(goal_x, GROUND_Y)
		_objects_root.add_child(goal)
	_gen_x += 600.0


## Llamar cada fotograma: genera por delante y limpia por detras.
func update(player_x: float, speed: float, level: int, delta: float) -> void:
	_speed = speed
	_level = level
	_difficulty = clampf(float(level) / 9.0, 0.0, 1.0)
	if _fixed_difficulty >= 0.0:
		_difficulty = _fixed_difficulty
	var guard: int = 0
	while _gen_x < player_x + AHEAD and guard < 40:
		if _arena:
			_gen_x += 600.0
		elif _gen_x > goal_x - GOAL_RUNWAY:
			_finish_track()
		else:
			# Frostfall: algunos tramos son de hielo (el heroe acelera).
			var ice_from: float = _gen_x
			# Director de encuentros: reparte los encuentros multiples del
			# nivel a lo largo del recorrido.
			if _enc_left > 0 and _gen_x >= _enc_next:
				_enc_left -= 1
				_enc_next += _enc_interval
				_forced.append(Pattern.ENCOUNTER)
			_spawn_pattern()
			if bool(Daylight.theme.get("ice", false)) and _rng.randf() < 0.4:
				Daylight.ice.append(Vector2(ice_from, _gen_x))
		_current_span.set_range(_current_span.start_x, _gen_x)
		guard += 1
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = 0.5
		_cleanup(player_x)


## Punto seguro donde reaparecer tras caer por un hueco: el inicio del
## primer tramo de suelo que queda por delante.
func get_respawn_x(player_x: float) -> float:
	var best: float = INF
	for item in _spans:
		var span: GroundSpan = item
		if span.start_x >= player_x - 16.0 and span.start_x < best:
			best = span.start_x
	if best == INF:
		return player_x + 240.0
	return best + 80.0


# --------------------------------------------------------------- patrones --

func _pick_pattern() -> int:
	if not _forced.is_empty():
		var forced: int = _forced.pop_front()
		return forced
	var pool: Array = []
	if not _allowed.is_empty():
		pool = _allowed
	for entry in TABLE:
		if not _allowed.is_empty():
			break
		var pattern: int = entry[0]
		var weight: int = entry[1]
		var min_level: int = entry[2]
		if _level < min_level:
			continue
		# Con la dificultad hay menos tramos de descanso (solo monedas).
		if pattern == Pattern.COINS and _difficulty > 0.5:
			weight = 1
		for n in weight:
			pool.append(pattern)
	var choice: int = pool[_rng.randi() % pool.size()]
	var tries: int = 0
	while choice == _last_pattern and tries < 4:
		choice = pool[_rng.randi() % pool.size()]
		tries += 1
	return choice


func _spawn_pattern() -> void:
	var pattern: int = _pick_pattern()
	_last_pattern = pattern
	match pattern:
		Pattern.COINS:
			_pattern_coins()
		Pattern.SPIKES:
			_pattern_spikes()
		Pattern.ROCK:
			_pattern_rock()
		Pattern.SLIME:
			_pattern_enemy(Enemy.Kind.SLIME)
		Pattern.HOLE:
			_pattern_hole(false)
		Pattern.GOBLIN:
			_pattern_enemy(Enemy.Kind.GOBLIN)
		Pattern.TOTEM:
			_pattern_totem()
		Pattern.PLATFORM:
			_pattern_platform()
		Pattern.BAT:
			_pattern_enemy(Enemy.Kind.BAT)
		Pattern.DOUBLE_SPIKES:
			_pattern_double_spikes()
		Pattern.DOUBLE_ENEMY:
			_pattern_double_enemy()
		Pattern.SPIKES_HOLE:
			_pattern_spikes_hole()
		Pattern.KNIGHT:
			_pattern_knight()
		Pattern.GHOST:
			_pattern_ghost()
		Pattern.BOULDER:
			_pattern_boulder()
		Pattern.COINS_RICH:
			_pattern_coins_rich()
		Pattern.ROUTE:
			_pattern_route()
		Pattern.TRAP:
			_pattern_trap()
		Pattern.CHAIN:
			_pattern_chain()
		Pattern.CEILING:
			_pattern_ceiling()
		Pattern.RAPID_SIX:
			_pattern_rapid_six()
		Pattern.JUMP_DRILL:
			_pattern_jump_drill()
		Pattern.ENCOUNTER:
			_pattern_encounter()
		Pattern.BOUNCE:
			_pattern_bounce()
		Pattern.CREATURE:
			_pattern_creature()
		_:
			_pattern_hole(true)


## Suelo libre antes del siguiente peligro (se acorta con la dificultad).
func _gap() -> float:
	# Mas obstaculos por nivel, pero siempre con tiempo de reaccion.
	var lo: float = lerpf(1.0, 0.78, _difficulty)
	var hi: float = lerpf(1.5, 1.08, _difficulty)
	return _speed * _rng.randf_range(lo, hi)


## Alcance del ataque del heroe (misma formula que player.gd, con margen
## por si la velocidad sube antes de que el jugador llegue).
func _attack_reach() -> float:
	return 105.0 + (_speed + 45.0) * 0.20


func _max_spikes() -> int:
	return clampi(int(_speed * 0.22 / TILE), 1, 4)


func _pattern_coins() -> void:
	_gen_x += _gap() * 0.5
	var count: int = _rng.randi_range(5, 8)
	var wave: bool = _rng.randf() < 0.4
	for i in count:
		var lift: float = 36.0
		if wave:
			lift += 26.0 * absf(sin(float(i) * 0.9))
		_add_coin(Vector2(_gen_x + float(i) * 46.0, GROUND_Y - lift), false)
	_gen_x += float(count) * 46.0
	_bonus_pickup()


func _pattern_spikes() -> void:
	_gen_x += _gap()
	var count: int = _rng.randi_range(1, _max_spikes())
	# A partir del nivel 2 los pinchos pueden ser llamas.
	var spikes_kind: int = Obstacle.Kind.SPIKES
	if _level >= 1 and _rng.randf() < 0.35:
		spikes_kind = Obstacle.Kind.FLAMES
	_add_obstacle(spikes_kind, _gen_x, count)
	var width: float = float(count) * TILE
	_coin_arc(_gen_x + width * 0.5, 3, false)
	_gen_x += width


func _pattern_rock() -> void:
	_gen_x += _gap()
	_add_obstacle(Obstacle.Kind.ROCK, _gen_x, 1)
	_coin_arc(_gen_x + 28.0, 5, false)
	_gen_x += 56.0


## Totem alto: exige mantener pulsado. Premia con una gema en lo mas alto.
func _pattern_totem() -> void:
	_gen_x += _gap()
	_add_obstacle(Obstacle.Kind.TOTEM, _gen_x, 1)
	_add_coin(Vector2(_gen_x + 24.0, GROUND_Y - 184.0), true)
	_gen_x += 48.0


func _pattern_enemy(base_kind: int) -> void:
	var kind: int = _themed(base_kind)
	_gen_x += _enemy_gap(kind)
	_add_enemy(kind, _gen_x)
	_gen_x += 40.0


## Zona despejada delante de un enemigo: mayor que su alcance de ataque.
func _enemy_gap(kind: int) -> float:
	var walk: float = float(Enemy.WALK_LIMITS[kind]) * 1.15
	return maxf(_gap(), _attack_reach() + walk + 90.0)


func _pattern_double_enemy() -> void:
	_gen_x += _enemy_gap(Enemy.Kind.SLIME)
	_add_enemy(Enemy.Kind.SLIME, _gen_x)
	_gen_x += maxf(_speed * 0.75, _attack_reach() + 110.0)
	var second: int = _themed(Enemy.Kind.BAT) if _rng.randf() < 0.5 else Enemy.Kind.SLIME
	_add_enemy(second, _gen_x)
	_gen_x += 40.0


func _pattern_hole(wide: bool) -> void:
	_gen_x += _gap()
	var factor: float = _rng.randf_range(0.44, 0.52) if wide else _rng.randf_range(0.30, 0.40)
	var width: float = clampf(snappedf(_speed * factor, TILE), TILE * 4.0, TILE * 14.0)
	var start: float = snappedf(_gen_x, TILE)
	_coin_arc(start + width * 0.5, 5, wide)
	_add_hole(start, width)


## Dos filas de pinchos seguidas: pide dos saltos cortos y precisos.
func _pattern_double_spikes() -> void:
	_gen_x += _gap()
	var first: int = _rng.randi_range(1, 2)
	_add_obstacle(Obstacle.Kind.SPIKES, _gen_x, first)
	_coin_arc(_gen_x + float(first) * TILE * 0.5, 3, false)
	_gen_x += float(first) * TILE + _speed * 0.66
	var second: int = _rng.randi_range(1, 2)
	_add_obstacle(Obstacle.Kind.SPIKES, _gen_x, second)
	_coin_arc(_gen_x + float(second) * TILE * 0.5, 3, false)
	_gen_x += float(second) * TILE


## Pinchos pegados al borde de un hueco: un unico salto largo los supera.
func _pattern_spikes_hole() -> void:
	_gen_x += _gap()
	var start: float = snappedf(_gen_x, TILE)
	var spikes: int = _rng.randi_range(1, 2)
	_add_obstacle(Obstacle.Kind.SPIKES, start, spikes)
	var hole_start: float = start + float(spikes) * TILE
	var width: float = clampf(snappedf(_speed * 0.27, TILE), TILE * 4.0, TILE * 8.0)
	_coin_arc(hole_start + width * 0.5 - float(spikes) * TILE * 0.5, 5, true)
	_add_hole(hole_start, width)


## Escudero: necesita dos golpes y retrocede tras el primero, por eso se
## deja libre la zona a la que es empujado.
func _pattern_knight() -> void:
	var kind: int = _themed(Enemy.Kind.KNIGHT)
	_gen_x += _enemy_gap(kind)
	_add_enemy(kind, _gen_x)
	_gen_x += 240.0 + _speed * 0.35


## Espectro: solo aparece de noche (de dia lo sustituye un murcielago).
func _pattern_ghost() -> void:
	var kind: int = _themed(Enemy.Kind.GHOST)
	if kind == Enemy.Kind.GHOST and Daylight.darkness() <= 0.5:
		kind = _themed(Enemy.Kind.BAT)
	_gen_x += _enemy_gap(kind)
	_add_enemy(kind, _gen_x)
	_gen_x += 40.0


## Roca rodante: avanza hacia el heroe, asi que se deja pista libre delante.
func _pattern_boulder() -> void:
	_gen_x += _gap() + Obstacle.ROLL_LIMIT + 40.0
	_add_obstacle(Obstacle.Kind.BOULDER, _gen_x, 1)
	_gen_x += 48.0


## Tramo cargado de monedas, rubies y gemas (evento "lluvia de monedas").
func _pattern_coins_rich() -> void:
	_gen_x += _speed * 0.35
	var count: int = _rng.randi_range(8, 11)
	for i in count:
		var lift: float = 40.0 + 70.0 * absf(sin(float(i) * 0.7))
		var kind: int = Coin.Kind.COIN
		if i % 5 == 4:
			kind = Coin.Kind.GEM
		elif i % 3 == 2:
			kind = Coin.Kind.RUBY
		_add_pickup(Vector2(_gen_x + float(i) * 44.0, GROUND_Y - lift), kind)
	_gen_x += float(count) * 44.0


## Dos caminos: abajo, la ruta segura (un solo salto y nada mas); arriba,
## la ruta arriesgada (plataforma propia del mundo, un peligro encima y
## muchas monedas, gemas y a veces el diamante oculto del nivel).
func _pattern_route() -> void:
	_gen_x += _gap()
	var start: float = snappedf(_gen_x + _speed * 0.15, TILE)
	var tiles: int = clampi(int(_speed * 1.7 / TILE), 10, 28)
	var width: float = float(tiles) * TILE
	var top: float = GROUND_Y - PLATFORM_HEIGHT - 16.0
	_add_platform(start, top, width, String(Daylight.theme.get("platform", "normal")))
	var count: int = int(width / 44.0)
	var hazard_at: int = int(float(count) * 0.55)
	for i in count:
		if absi(i - hazard_at) <= 1:
			continue
		var kind: int = Coin.Kind.COIN
		if i % 6 == 3:
			kind = Coin.Kind.GEM
		elif i % 4 == 1:
			kind = Coin.Kind.RUBY
		_add_pickup(Vector2(start + 30.0 + float(i) * 44.0, top - 40.0), kind)
	var hazard_x: float = start + 30.0 + float(hazard_at) * 44.0
	if _level >= 3 and _rng.randf() < 0.5:
		_add_enemy_at(Enemy.Kind.SLIME, hazard_x, top)
	else:
		_add_obstacle_at(Obstacle.Kind.SPIKES, hazard_x - 16.0, top, 1)
	if diamond_available and not _diamond_placed and _rng.randf() < diamond_chance:
		_diamond_placed = true
		_add_pickup(Vector2(start + width - 40.0, top - 70.0), Coin.Kind.DIAMOND)
	# Ruta segura: un unico salto, sin recompensas.
	_add_obstacle(Obstacle.Kind.SPIKES, start + snappedf(width * 0.5, TILE), 1)
	_gen_x = start + width + _speed * 0.5


## Trampa ritmica: hay que leer el ritmo de los pinchos (o saltarlos).
func _pattern_trap() -> void:
	_gen_x += _gap()
	var count: int = _rng.randi_range(2, mini(3, _max_spikes() + 1))
	_add_obstacle(Obstacle.Kind.TRAP, _gen_x, count)
	_coin_arc(_gen_x + float(count) * TILE * 0.5, 3, false)
	_gen_x += float(count) * TILE


func _add_enemy_at(kind: int, x: float, y: float) -> void:
	var enemy: Enemy = EnemyScene.instantiate()
	enemies_spawned += 1
	enemy.position = Vector2(x, y)
	_objects_root.add_child(enemy)
	enemy.setup(kind)


func _add_obstacle_at(kind: int, x: float, y: float, count: int) -> void:
	var obstacle: Obstacle = ObstacleScene.instantiate()
	obstacle.position = Vector2(x, y)
	_objects_root.add_child(obstacle)
	obstacle.setup(kind, count)


# ------------------------------------------------ mecanicas de un boton --

## Cadena: tres grupos de pinchos a ritmo fijo (premio si los tres son
## saltos perfectos).
func _pattern_chain() -> void:
	_gen_x += _gap()
	var step: float = _speed * 0.72
	for i in 3:
		_add_obstacle(Obstacle.Kind.SPIKES, _gen_x, 1)
		_coin_arc(_gen_x + 16.0, 3, false)
		_gen_x += step
	_gen_x += 32.0


## Techo bajo sobre pinchos: solo pasa un salto corto (soltar a tiempo).
func _pattern_ceiling() -> void:
	_gen_x += _gap()
	var x: float = snappedf(_gen_x, TILE)
	_add_obstacle(Obstacle.Kind.SPIKES, x + TILE, 2)
	_add_obstacle(Obstacle.Kind.CEILING, x - TILE, 6)
	_coin_arc(x + TILE * 2.0, 3, false)
	_gen_x = x + TILE * 6.0


## RAPID SIX: portal que detiene al heroe hasta que pulsa seis veces.
## Las variantes se desbloquean poco a poco y la ventana se acorta con la
## dificultad (2.5 s al principio, 1.3 s al final; 1.0 s la extrema).
func _pattern_rapid_six() -> void:
	_gen_x += maxf(_gap(), _attack_reach() + 220.0)
	var variants: Array = [RapidSix.Variant.NORMAL]
	var progress: float = _difficulty
	if progress >= 0.30:
		variants.append(RapidSix.Variant.PRESSURE)
	if progress >= 0.38:
		variants.append(RapidSix.Variant.COMBO)
	if progress >= 0.55:
		variants.append(RapidSix.Variant.DOUBLE)
	if progress >= 0.70:
		variants.append(RapidSix.Variant.EXTREME)
	if progress >= 0.80:
		variants.append(RapidSix.Variant.SURVIVAL)
	var variant: int = variants[_rng.randi() % variants.size()]
	if forced_rapid_variant >= 0:
		variant = forced_rapid_variant
	var window: float = lerpf(2.5, 1.3, clampf((_difficulty - 0.2) / 0.75, 0.0, 1.0))
	if variant == RapidSix.Variant.EXTREME:
		window = 1.0
	elif variant == RapidSix.Variant.SURVIVAL or variant == RapidSix.Variant.DOUBLE:
		window += 0.2
	_add_rapid(_gen_x, variant, window)
	if variant == RapidSix.Variant.COMBO:
		# Pinchos justo detras: hay que saltar nada mas romper el portal.
		_add_obstacle(Obstacle.Kind.SPIKES, _gen_x + 90.0, 2)
		_gen_x += 90.0 + TILE * 2.0
	elif variant == RapidSix.Variant.DOUBLE:
		_gen_x += 380.0
		_add_rapid(_gen_x, variant, window)
	_gen_x += 240.0 + _speed * 0.3


func _add_rapid(x: float, variant: int, window: float) -> void:
	var gate: RapidSix = RapidSix.new()
	gate.position = Vector2(x, GROUND_Y)
	gate.variant = variant
	gate.window = window
	# Variante bajo presion: la amenaza es el bruto de este mundo.
	for i in 5:
		var data: Array = Bestiary.entry(_creature_world, i)
		if String(data[5]) == "mash":
			gate.threat_sprite = String(data[2])
			gate.threat_remap = data[3]
			gate.threat_key = "%d_%d" % [_creature_world, i]
			break
	_objects_root.add_child(gate)


# --------------------------------------------------- salto variable --

## Pasos de salto: cada uno exige una altura de salto concreta.
##   tap      techo muy bajo sobre un pincho: solo un toque.
##   low      roca o pincho: cualquier salto.
##   mid      columna de altura 2 (pulsacion media).
##   high     columna de altura 3-4 (pulsacion larga).
##   max      columna de altura 5 (pulsacion maxima).
##   ceiling  techo normal sobre pinchos: corto o medio, nunca largo.
##   long     hueco ancho: hay que mantener casi al maximo.
##   landing  pinchos justo donde se aterriza: saltar al tocar el suelo.
## Tiempos de vuelo aproximados (s) segun la pulsacion necesaria.
const STEP_AIR := {"tap": 0.34, "low": 0.40, "mid": 0.55, "high": 0.66, "max": 0.80, "ceiling": 0.48, "long": 0.80, "landing": 0.40}

## Secuencias por dificultad. Mezclan saltos pequenos y grandes para que
## mantener el boton todo el rato no sirva.
const DRILLS := [
	[["low", "mid", "low"], ["tap", "low"], ["mid", "mid"], ["low", "ceiling"]],
	[["tap", "high", "tap"], ["long", "tap"], ["low", "ceiling", "high"], ["mid", "landing", "low"], ["high", "low", "mid"]],
	[["tap", "high", "tap", "long", "low"], ["high", "tap", "high"], ["long", "landing", "tap"], ["ceiling", "max"], ["mid", "high", "max"]],
	[["max", "tap", "long", "tap", "high"], ["tap", "tap", "high", "long", "ceiling"], ["long", "landing", "max", "tap"], ["high", "ceiling", "high", "tap"]],
]


## Tiempo de reaccion (s de juego) entre aterrizar y el siguiente paso.
func _reaction() -> float:
	return lerpf(0.55, 0.30, _difficulty)


func _pattern_jump_drill() -> void:
	var tier: int = clampi(int(_difficulty * 4.0), 0, DRILLS.size() - 1)
	# A veces una secuencia del nivel anterior, para variar.
	if tier > 0 and _rng.randf() < 0.3:
		tier -= 1
	var options: Array = DRILLS[tier]
	var drill: Array = options[_rng.randi() % options.size()]
	_gen_x += _gap()
	for i in drill.size():
		_jump_step(String(drill[i]))
		if i < drill.size() - 1:
			_gen_x += _speed * _reaction()


## Coloca un paso de salto en _gen_x y avanza hasta donde aterriza el heroe.
func _jump_step(step: String) -> void:
	var air: float = float(STEP_AIR.get(step, 0.5))
	var x: float = snappedf(_gen_x, TILE)
	var width: float = TILE
	match step:
		"tap":
			_add_obstacle(Obstacle.Kind.SPIKES, x + TILE, 1)
			_add_obstacle(Obstacle.Kind.LOW_CEILING, x - TILE, 4)
			width = TILE * 3.0
		"low":
			if _rng.randf() < 0.5:
				_add_obstacle(Obstacle.Kind.ROCK, x, 1)
				width = 56.0
			else:
				_add_obstacle(Obstacle.Kind.SPIKES, x, 1)
		"mid":
			_add_obstacle(Obstacle.Kind.PILLAR, x, 2)
			_add_coin(Vector2(x + 16.0, GROUND_Y - 140.0), false)
		"high":
			_add_obstacle(Obstacle.Kind.PILLAR, x, 3 if _rng.randf() < 0.6 else 4)
			_add_coin(Vector2(x + 16.0, GROUND_Y - 210.0), true)
		"max":
			_add_obstacle(Obstacle.Kind.PILLAR, x, 5)
			_add_coin(Vector2(x + 16.0, GROUND_Y - 250.0), true)
		"ceiling":
			_add_obstacle(Obstacle.Kind.SPIKES, x + TILE, 2)
			_add_obstacle(Obstacle.Kind.CEILING, x - TILE, 5)
			width = TILE * 4.0
		"long":
			var hole: float = clampf(snappedf(_speed * 0.55, TILE), TILE * 5.0, TILE * 15.0)
			_coin_arc(x + hole * 0.5, 5, true)
			_add_hole(x, hole)
			width = hole
		"landing":
			# Un hueco corto y pinchos justo donde se aterriza.
			var short_hole: float = clampf(snappedf(_speed * 0.3, TILE), TILE * 3.0, TILE * 8.0)
			_add_hole(x, short_hole)
			_add_obstacle(Obstacle.Kind.SPIKES, x + short_hole + _speed * 0.20, 1)
			width = short_hole + _speed * 0.20 + TILE
	# El heroe aterriza mas o menos a medio vuelo pasado el obstaculo.
	_gen_x = x + width + _speed * air * 0.5


# ------------------------------------------------- director de encuentros --

## Encuentros especiales del nivel (ver Campaign.encounters): varias
## criaturas del mundo UNA DETRAS DE OTRA (nunca todas a la vez en
## pantalla), a veces con un salto o un portal entre medias.
var _enc_count: int = 0
var _enc_left: int = 0
var _enc_interval: float = INF
var _enc_next: float = INF
var _enc_len: Vector2i = Vector2i(2, 2)
var _enc_gap: float = 1.0
var _enc_combo: float = 0.3
## Admin: variante de RAPID SIX forzada en las pruebas (-1 = al azar).
var forced_rapid_variant: int = -1


func configure_encounters(config: Dictionary) -> void:
	_enc_count = int(config.get("count", 0))
	_enc_left = _enc_count
	_enc_len = Vector2i(int(config.get("min", 2)), int(config.get("max", 2)))
	_enc_gap = float(config.get("gap", 1.0))
	_enc_combo = float(config.get("combo", 0.3))
	if _enc_count > 0 and goal_x != INF:
		_enc_interval = (goal_x - GOAL_RUNWAY) / float(_enc_count + 1)
		_enc_next = _enc_interval


func _pattern_encounter() -> void:
	if _creatures.is_empty():
		_creatures = [0]
	var pool: Array = _creatures.duplicate()
	# Mezcla con la semilla del nivel (recorrido siempre igual).
	for i in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var length: int = _rng.randi_range(_enc_len.x, maxi(_enc_len.x, _enc_len.y))
	for i in length:
		if i > 0 and _rng.randf() < _enc_combo:
			# Entre dos criaturas, un salto que exige otra altura.
			_gen_x += _speed * _reaction()
			var steps: Array = ["tap", "mid", "high", "low", "ceiling"]
			_jump_step(String(steps[_rng.randi() % steps.size()]))
		_place_creature(int(pool[i % pool.size()]), _enc_gap if i > 0 else 1.0)
	enemies_encounters += 1


## Trampolin y muro: hay que pisar el trampolin (y no saltar antes).
func _pattern_bounce() -> void:
	_gen_x += _gap()
	_add_obstacle(Obstacle.Kind.BOUNCE, _gen_x, 1)
	_add_obstacle(Obstacle.Kind.WALL, _gen_x + 150.0, 1)
	_add_pickup(Vector2(_gen_x + 170.0, GROUND_Y - 280.0), Coin.Kind.GEM)
	_gen_x += 150.0 + _speed * 0.9


## Una criatura del mundo, con el espacio que necesita su comportamiento.
func _pattern_creature() -> void:
	if _creatures.is_empty():
		_creatures = [0]
	var index: int = _creatures[_rng.randi() % _creatures.size()]
	# La recien estrenada sale mas a menudo en su nivel de presentacion.
	if not _newest.is_empty() and _rng.randf() < 0.6:
		index = int(_newest[_rng.randi() % _newest.size()])
	if test_creature >= 0:
		index = test_creature
	_place_creature(index, 1.0)


## Coloca una criatura con el espacio que necesita su comportamiento.
## `pressure` < 1 acerca la criatura a lo anterior (encuentros seguidos),
## sin bajar nunca del margen minimo de su ataque.
func _place_creature(index: int, pressure: float) -> void:
	var data: Array = Bestiary.entry(_creature_world, index)
	var space: String = data[5]
	if space == "chase":
		_gen_x += _gap() * pressure
		_add_creature(index, _gen_x)
		_gen_x += _speed * 3.6
	elif space == "mash":
		_gen_x += maxf(_gap() * pressure, _attack_reach() + 200.0)
		_add_creature(index, _gen_x)
		_gen_x += _speed * 2.6 + 260.0
	elif space == "ranged":
		_gen_x += _speed * 2.0 * maxf(pressure, 0.8) + 300.0
		_add_creature(index, _gen_x)
		_gen_x += 120.0
	elif space == "split":
		_gen_x += maxf(_gap() * pressure, _attack_reach() + 90.0)
		_add_creature(index, _gen_x)
		_gen_x += 460.0
	elif space == "wide":
		_gen_x += maxf(_gap() * pressure, _attack_reach() + 260.0)
		_add_creature(index, _gen_x)
		_gen_x += _speed * 1.5 + 520.0
	elif space == "mover":
		_gen_x += maxf(_gap() * pressure, _attack_reach() + 340.0)
		_add_creature(index, _gen_x)
		_gen_x += 160.0
	else:
		_gen_x += maxf(_gap() * pressure, _attack_reach() + 120.0)
		_add_creature(index, _gen_x)
		_gen_x += 120.0


func _add_creature(index: int, x: float) -> void:
	var creature: Creature = Creature.new()
	creature.position = Vector2(x, GROUND_Y)
	_objects_root.add_child(creature)
	creature.setup(_creature_world, index)
	enemies_spawned += 1


## En el modo infinito las criaturas del bosque se van sumando por nivel.
func set_endless_creatures(level: int) -> void:
	_creatures = []
	for i in mini(level + 1, Bestiary.INTRO_LEVELS.size()):
		_creatures.append(i)


## Encola un evento: "coins" (lluvia de monedas) u "horde" (horda).
func start_event(event: String) -> void:
	if event == "coins":
		_forced = [Pattern.COINS_RICH, Pattern.COINS_RICH, Pattern.COINS_RICH, Pattern.COINS_RICH]
	elif event == "horde":
		_forced = [Pattern.SLIME, Pattern.GOBLIN, Pattern.SLIME, Pattern.BAT, Pattern.GOBLIN]


## Plataforma flotante con monedas y una gema; debajo, unos pinchos.
func _pattern_platform() -> void:
	_gen_x += _gap()
	var start: float = snappedf(_gen_x + _speed * 0.2, TILE)
	var tiles: int = clampi(int(_speed * 1.3 / TILE), 8, 22)
	var width: float = float(tiles) * TILE
	var top: float = GROUND_Y - PLATFORM_HEIGHT
	_add_platform(start, top, width)
	var coins: int = int(width / 64.0)
	for i in coins:
		_add_coin(Vector2(start + 32.0 + float(i) * 64.0, top - 38.0), i == coins - 1)
	_add_obstacle(Obstacle.Kind.SPIKES, start + snappedf(width * 0.5, TILE), mini(2, _max_spikes()))
	# Margen extra: desde la plataforma se cae (o se salta) mas lejos.
	_gen_x = start + width + _speed * 0.45


# ------------------------------------------------------------ construccion --

## Monedas siguiendo la trayectoria de un salto centrado en `center_x`.
func _coin_arc(center_x: float, count: int, gem_on_top: bool) -> void:
	var half: float = _speed * 0.30
	var middle: int = int(float(count) * 0.5)
	for i in count:
		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1) * 2.0 - 1.0
		var pos: Vector2 = Vector2(center_x + t * half, GROUND_Y - 44.0 - 80.0 * (1.0 - t * t))
		_add_coin(pos, gem_on_top and i == middle)


func _add_coin(pos: Vector2, special: bool) -> void:
	var kind: int = Coin.Kind.COIN
	if special:
		kind = Coin.Kind.RUBY if _rng.randf() < 0.3 else Coin.Kind.GEM
	elif gem_bonus > 0.0 and randf() < gem_bonus:
		kind = Coin.Kind.RUBY
	_add_pickup(pos, kind)


func _add_pickup(pos: Vector2, kind: int) -> void:
	if kind != Coin.Kind.HEART and kind != Coin.Kind.STAR:
		pickups_spawned += 1
	var coin: Coin = CoinScene.instantiate()
	coin.position = pos
	coin.setup(kind)
	_objects_root.add_child(coin)


## Recompensa especial ocasional: un cofre.
func _bonus_pickup() -> void:
	if _rng.randf() >= 0.25:
		return
	_add_pickup(Vector2(_gen_x + 70.0, GROUND_Y), Coin.Kind.CHEST)
	_gen_x += 110.0


func _add_obstacle(kind: int, x: float, count: int) -> void:
	var obstacle: Obstacle = ObstacleScene.instantiate()
	obstacle.position = Vector2(x, GROUND_Y)
	_objects_root.add_child(obstacle)
	obstacle.setup(kind, count)


func _add_enemy(kind: int, x: float) -> void:
	var enemy: Enemy = EnemyScene.instantiate()
	if kind != Enemy.Kind.ORB:
		enemies_spawned += 1
	var flying: bool = kind == Enemy.Kind.BAT or kind == Enemy.Kind.GHOST or kind == Enemy.Kind.ORB or kind == Enemy.Kind.FIREBAT or kind == Enemy.Kind.WRAITH
	var y: float = GROUND_Y - 52.0 if flying else GROUND_Y
	enemy.position = Vector2(x, y)
	_objects_root.add_child(enemy)
	enemy.setup(kind)


## Criatura propia del mundo actual que sustituye a una basica
## (lobos en el bosque, murcielagos de fuego en el infierno...).
func _themed(kind: int) -> int:
	var swaps: Dictionary = Daylight.theme.get("swap", {})
	if swaps.has(kind):
		var entry: Array = swaps[kind]
		if _rng.randf() < float(entry[1]):
			return int(entry[0])
	return kind


## Acceso para los jefes: colocan obstaculos y proyectiles en la pista.
func spawn_obstacle(kind: int, x: float, count: int) -> void:
	_add_obstacle(kind, x, count)


## Acceso para los jefes: piezas tematicas (fuego, lanzas, ondas...).
func spawn_piece(type: int, x: float, data: Dictionary) -> void:
	var piece: Creature = Creature.new()
	piece.position = Vector2(x, GROUND_Y)
	_objects_root.add_child(piece)
	piece.setup_special(type, data)


## Acceso para los jefes: un portal de pulsaciones con sus reglas.
func spawn_rapid(x: float, variant: int, window: float, taps: int, title: String) -> void:
	var gate: RapidSix = RapidSix.new()
	gate.position = Vector2(x, GROUND_Y)
	gate.variant = variant
	gate.window = window
	gate.taps_needed = taps
	gate.title = title
	gate.from_boss = true
	_objects_root.add_child(gate)


## Acceso para los jefes: un paso de salto variable en la posicion dada.
## Devuelve la X donde aterriza el heroe tras ese paso.
func spawn_step(step: String, x: float) -> float:
	var saved: float = _gen_x
	_gen_x = x
	_jump_step(step)
	var landing: float = _gen_x
	_gen_x = maxf(saved, _gen_x)
	return landing


## Acceso para los jefes: una criatura del bestiario.
func spawn_creature(world: int, index: int, x: float) -> void:
	var saved_world: int = _creature_world
	_creature_world = world
	_add_creature(index, x)
	_creature_world = saved_world


func spawn_enemy(kind: int, x: float) -> Node:
	_add_enemy(kind, x)
	return _objects_root.get_child(_objects_root.get_child_count() - 1)


func _add_platform(x: float, y: float, width: float, mode: String = "normal") -> void:
	var platform: Platform = Platform.new()
	platform.position = Vector2(x, y)
	_objects_root.add_child(platform)
	platform.setup(width, mode)


func _new_span(x: float) -> GroundSpan:
	var span: GroundSpan = GroundSpan.new()
	_spans_root.add_child(span)
	span.set_range(x, x + TILE)
	_spans.append(span)
	return span


## Cierra el tramo de suelo actual, deja un hueco y abre un tramo nuevo.
func _add_hole(start: float, width: float) -> void:
	_current_span.set_range(_current_span.start_x, start)
	holes.append(Vector2(start, start + width))
	_gen_x = start + width
	_current_span = _new_span(_gen_x)


## Libera todo lo que quedo muy por detras del jugador.
func _cleanup(player_x: float) -> void:
	var limit: float = player_x - BEHIND
	for child in _objects_root.get_children():
		var node: Node2D = child as Node2D
		if node != null and node.position.x < limit - 800.0:
			node.queue_free()
	for i in range(_spans.size() - 1, -1, -1):
		var span: GroundSpan = _spans[i]
		if span != _current_span and span.end_x < limit:
			_spans.remove_at(i)
			span.queue_free()
	while not Daylight.ice.is_empty():
		var span: Vector2 = Daylight.ice[0]
		if span.y >= limit:
			break
		Daylight.ice.remove_at(0)
	while not holes.is_empty():
		var hole: Vector2 = holes[0]
		if hole.y >= limit:
			break
		holes.remove_at(0)
