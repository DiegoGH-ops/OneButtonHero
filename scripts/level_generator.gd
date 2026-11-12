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
	KNIGHT, GHOST, BOULDER, COINS_RICH,
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
]

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
var heart_wanted: bool = false
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


## Llamar cada fotograma: genera por delante y limpia por detras.
func update(player_x: float, speed: float, level: int, delta: float) -> void:
	_speed = speed
	_level = level
	_difficulty = clampf(float(level) / 9.0, 0.0, 1.0)
	var guard: int = 0
	while _gen_x < player_x + AHEAD and guard < 40:
		_spawn_pattern()
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
	for entry in TABLE:
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
		_:
			_pattern_hole(true)


## Suelo libre antes del siguiente peligro (se acorta con la dificultad).
func _gap() -> float:
	var lo: float = lerpf(1.15, 0.85, _difficulty)
	var hi: float = lerpf(1.80, 1.25, _difficulty)
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


func _pattern_enemy(kind: int) -> void:
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
	var second: int = Enemy.Kind.BAT if _rng.randf() < 0.5 else Enemy.Kind.SLIME
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
	_gen_x += _enemy_gap(Enemy.Kind.KNIGHT)
	_add_enemy(Enemy.Kind.KNIGHT, _gen_x)
	_gen_x += 240.0 + _speed * 0.35


## Espectro: solo aparece de noche (de dia lo sustituye un murcielago).
func _pattern_ghost() -> void:
	var kind: int = Enemy.Kind.GHOST if Daylight.darkness() > 0.5 else Enemy.Kind.BAT
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
	_add_pickup(pos, kind)


func _add_pickup(pos: Vector2, kind: int) -> void:
	var coin: Coin = CoinScene.instantiate()
	coin.position = pos
	coin.setup(kind)
	_objects_root.add_child(coin)


## Recompensas especiales ocasionales: corazon, estrella o cofre.
func _bonus_pickup() -> void:
	var roll: float = _rng.randf()
	var x: float = _gen_x + 70.0
	if heart_wanted and roll < 0.22:
		_add_pickup(Vector2(x, GROUND_Y - 96.0), Coin.Kind.HEART)
	elif roll < 0.30:
		_add_pickup(Vector2(x, GROUND_Y), Coin.Kind.CHEST)
	elif roll < 0.38:
		_add_pickup(Vector2(x, GROUND_Y - 96.0), Coin.Kind.STAR)
	else:
		return
	_gen_x += 110.0


func _add_obstacle(kind: int, x: float, count: int) -> void:
	var obstacle: Obstacle = ObstacleScene.instantiate()
	obstacle.position = Vector2(x, GROUND_Y)
	_objects_root.add_child(obstacle)
	obstacle.setup(kind, count)


func _add_enemy(kind: int, x: float) -> void:
	var enemy: Enemy = EnemyScene.instantiate()
	var y: float = GROUND_Y - 52.0 if (kind == Enemy.Kind.BAT or kind == Enemy.Kind.GHOST) else GROUND_Y
	enemy.position = Vector2(x, y)
	_objects_root.add_child(enemy)
	enemy.setup(kind)


func _add_platform(x: float, y: float, width: float) -> void:
	var platform: Platform = Platform.new()
	platform.position = Vector2(x, y)
	_objects_root.add_child(platform)
	platform.setup(width)


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
	while not holes.is_empty():
		var hole: Vector2 = holes[0]
		if hole.y >= limit:
			break
		holes.remove_at(0)
