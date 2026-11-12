extends Area2D
## Criaturas del bestiario (bestiary.gd): 25 enemigos, cada uno con su
## propia IA, sus estados, su animacion y sus efectos. Ademas, las piezas que
## generan algunos de ellos (proyectiles, fuego, lanzas, ondas, bolas...).
##
## Regla del boton unico: el boton ATACA si hay delante un enemigo
## `targetable`; si no, SALTA. Por eso cada criatura decide en cada estado si
## se puede atacar (y hay que golpearla) o no (y hay que saltarla o pasar por
## debajo). Los peligros puros (fuego, lanzas clavadas, ondas, manos, bolas)
## estan en el grupo "hazards" y solo se esquivan.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Bestiary = preload("res://scripts/bestiary.gd")
const Fx = preload("res://scripts/fx.gd")

# Comportamientos (mismos valores que Bestiary.Behavior).
const BOAR_CHARGER := 0
const ROOT_SENTINEL := 1
const FROG_LEAPER := 2
const SPORE_SHOOTER := 3
const MOLE_POPPER := 4
const DEVIL_BULL := 5
const INFERNAL_BRUTE := 6
const WISP_SHIFTER := 7
const GARGOYLE_BOMBER := 8
const MAGMA_SPLITTER := 9
const PRISM_GUARDIAN := 10
const CRYSTAL_BLINKER := 11
const GOLEM_COLOSSUS := 12
const CRYSTAL_MIMIC := 13
const GEODE_BURSTER := 14
const WOLF_PACK := 15
const SKELETON_LANCER := 16
const YETI_POUNDER := 17
const SNOWMAN_ROLLER := 18
const ICE_WORM := 19
const DUNE_SERPENT := 20
const STALKER_SCORPION := 21
const GIANT_BEETLE := 22
const MUMMY_SUMMONER := 23
const LIVING_SAND := 24
# Piezas y elementos especiales.
const SPORE := 41
const FIREBALL := 42
const FLAME := 43
const SPEAR := 44
const SNOWBALL := 45
const SHOCKWAVE := 46
const SHARD := 47
const HAND := 48
const BALL := 49
const PACK_WOLF := 50
const MINI := 51

const GROUND_Y := 560.0
## Proyectiles que se pueden cortar: game.gd los reconoce por este `kind`.
const PROJECTILE_KIND := 109
const POINTS := [70, 90, 70, 70, 60, 90, 130, 80, 110, 60, 140, 110, 180, 110, 90, 70, 130, 170, 100, 120, 120, 140, 160, 150, 160]
const SPECIAL_POINTS := {SPORE: 20, SNOWBALL: 25, SHARD: 30, PACK_WOLF: 70, MINI: 40}
const PERFECT := 3

## Para game.gd: 200 + comportamiento (no se confunde con los enemigos
## clasicos ni con los proyectiles).
var kind: int = 200
var behavior: int = 0
var hp: int = 1
var dead: bool = false
## Acorazados: el heroe los golpea con pulsaciones muy seguidas.
var mash: bool = false
## Si es false, el boton salta en vez de atacar (hay que esquivarla).
var targetable: bool = true
var creature_name: String = ""

## Datos para lights.gd.
var glow_radius: float = 50.0
var glow_color: Color = Pal.YELLOW
var glow_day: float = 0.2

var _sprite: String = "boar"
var _remap: Dictionary = {}
var _remap_key: String = ""
var _px: float = 4.0
var _adj: float = 1.0
var _time: float = 0.0
var _state: int = 0
var _timer: float = 0.0
var _y: float = 0.0
var _vx: float = 0.0
var _vy: float = 0.0
var _flash: float = 0.0
var _blocked: float = 0.0
var _count: int = 0
var _active: bool = false
var _hazard: bool = false
var _passed: bool = false
var _max_hp: int = 1
var _origin_x: float = 0.0
var _size: float = 1.0
var _trigger: float = 650.0
## Color de las piezas que lanzan los jefes (esporas, ondas, cristales).
var _piece_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var _setup_done: bool = false
var _shape: RectangleShape2D
var _collider: CollisionShape2D


func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)


# ------------------------------------------------------------ configuracion --

## Configura la criatura `index` (0-4) del mundo `world`. `position` es su
## base en el suelo.
func setup(world: int, index: int) -> void:
	var data: Array = Bestiary.entry(world, index)
	creature_name = data[0]
	_sprite = data[2]
	_remap = data[3]
	_adj = data[4]
	_remap_key = "%d_%d" % [world, index]
	_begin(int(data[1]))
	_configure()
	_max_hp = hp
	_place()


## Piezas creadas por otras criaturas (proyectiles, peligros, crias).
func setup_special(type: int, data: Dictionary) -> void:
	_begin(type)
	_remap = data.get("remap", {})
	_remap_key = String(data.get("key", ""))
	_sprite = String(data.get("sprite", "blob"))
	_adj = float(data.get("adj", 1.0))
	_vx = float(data.get("vx", 0.0))
	_vy = float(data.get("vy", 0.0))
	_y = float(data.get("y", 0.0))
	_trigger = float(data.get("trigger", 650.0))
	_count = int(data.get("phase", 0))
	if data.has("color"):
		_piece_color = Color(String(data["color"]))
	match type:
		SPORE:
			_box(26.0, 20.0)
			glow_color = Pal.LIME
			add_to_group("glow")
		FIREBALL:
			_hazard = true
			_box(22.0, 22.0)
			glow_color = Pal.ORANGE
			glow_radius = 44.0
			add_to_group("glow")
		FLAME:
			_hazard = true
			_box(36.0, 42.0)
			_timer = 1.6
			glow_color = Pal.ORANGE
			glow_radius = 60.0
			add_to_group("glow")
		SPEAR:
			_hazard = true
			_box(10.0, 10.0)
		SNOWBALL:
			_size = 1.0
			_box(24.0, 24.0)
		SHOCKWAVE:
			_hazard = true
			_box(44.0, 22.0)
			glow_color = Pal.CYAN
			add_to_group("glow")
		SHARD:
			_box(24.0, 22.0)
			glow_color = Pal.PINK
			glow_radius = 30.0
			add_to_group("glow")
		HAND:
			_hazard = true
			_box(26.0, 38.0)
			_timer = 0.0
		BALL:
			_hazard = true
			_box(52.0, 52.0)
		PACK_WOLF:
			_box(44.0, 28.0)
		MINI:
			_px = 2.5
			_box(26.0, 20.0)
	_max_hp = hp
	if _hazard:
		collision_layer = 4
	# La mano se activa cuando surge del suelo; la lanza, al clavarse.
	_set_active(type != HAND and type != SPEAR)
	_place()


func _begin(type: int) -> void:
	behavior = type
	kind = 200 + type
	if type == SPORE or type == SNOWBALL or type == SHARD:
		kind = PROJECTILE_KIND
	_time = fposmod(position.x * 0.0071, 3.0)
	_origin_x = position.x
	_setup_done = true


## Ajustes iniciales de cada criatura del bestiario.
func _configure() -> void:
	var start_active: bool = true
	match behavior:
		BOAR_CHARGER:
			_box(44.0, 30.0)
			start_active = false
			targetable = false
		ROOT_SENTINEL:
			_box(36.0, 52.0)
		FROG_LEAPER:
			_box(40.0, 30.0)
		SPORE_SHOOTER:
			_box(40.0, 46.0)
		MOLE_POPPER:
			_box(34.0, 50.0)
			start_active = false
		DEVIL_BULL:
			_box(44.0, 30.0)
			glow_color = Pal.ORANGE
		INFERNAL_BRUTE:
			hp = int(roundf(4.0 * _adj))
			mash = true
			_px = 6.0
			_box(60.0, 120.0)
		WISP_SHIFTER:
			_box(34.0, 34.0)
			glow_color = Pal.ORANGE
			add_to_group("glow")
		GARGOYLE_BOMBER:
			_box(40.0, 34.0)
			_y = -250.0
			targetable = false
		MAGMA_SPLITTER:
			_box(44.0, 32.0)
			glow_color = Pal.ORANGE
			glow_radius = 40.0
			add_to_group("glow")
		PRISM_GUARDIAN:
			_box(36.0, 52.0)
			glow_color = Pal.PINK
			add_to_group("glow")
		CRYSTAL_BLINKER:
			_box(34.0, 36.0)
			glow_color = Pal.PINK
			add_to_group("glow")
		GOLEM_COLOSSUS:
			hp = int(roundf(6.0 * _adj))
			mash = true
			_px = 6.0
			_box(60.0, 120.0)
		CRYSTAL_MIMIC:
			_box(40.0, 30.0)
		GEODE_BURSTER:
			_px = 5.0
			_box(54.0, 40.0)
			glow_color = Pal.PINK
			add_to_group("glow")
		WOLF_PACK:
			_box(44.0, 28.0)
			_spawn_pack()
		SKELETON_LANCER:
			_box(36.0, 52.0)
			targetable = false
		YETI_POUNDER:
			hp = int(roundf(5.0 * _adj))
			mash = true
			_px = 6.0
			_box(60.0, 110.0)
		SNOWMAN_ROLLER:
			_box(40.0, 46.0)
		ICE_WORM:
			_box(34.0, 110.0)
			start_active = false
		DUNE_SERPENT:
			_box(44.0, 26.0)
		STALKER_SCORPION:
			_box(38.0, 40.0)
			start_active = false
		GIANT_BEETLE:
			hp = int(roundf(3.0 * _adj))
			mash = true
			_box(56.0, 56.0)
			_spawn_child(BALL, position.x - 130.0, {"trigger": 700.0})
		MUMMY_SUMMONER:
			_box(36.0, 52.0)
			targetable = false
		LIVING_SAND:
			hp = 3
			_box(44.0, 32.0)
	_set_active(start_active)


func _box(w: float, h: float) -> void:
	_shape.size = Vector2(w, h)
	_collider.position = Vector2(0.0, -h * 0.5)


func _place() -> void:
	_collider.position.y = _y - _shape.size.y * 0.5


## Activa o desactiva su presencia (los ocultos no danan ni se atacan).
func _set_active(value: bool) -> void:
	_active = value
	set_deferred("monitorable", value)
	var group: String = "hazards" if _hazard else "enemies"
	if value and not is_in_group(group):
		add_to_group(group)
	elif not value and is_in_group(group):
		remove_from_group(group)


## Aparicion con nube de polvo (criaturas que surgen de la nada).
func _appear(color: Color) -> void:
	_set_active(true)
	_flash = 0.2
	var parent: Node = get_parent()
	if parent != null:
		Fx.burst(parent, position + Vector2(0.0, _y - 14.0), color, 12, 220.0, 0.4, 6.0, 400.0, 160.0, Vector2.UP)


func get_points() -> int:
	if behavior < POINTS.size():
		return POINTS[behavior]
	return int(SPECIAL_POINTS.get(behavior, 30))


## Peligros estaticos: precision.gd los usa para puntuar los saltos.
func get_danger() -> Vector3:
	var x: float = global_position.x
	var half: float = _shape.size.x * 0.5
	return Vector3(x - half, x + half, -(_y - _shape.size.y))


# -------------------------------------------------------------------- golpe --

## Golpe del heroe. Puntos si muere, -1 si aguanta y 0 si lo bloquea.
func hit() -> int:
	if dead or not _active or _hazard:
		return 0
	match behavior:
		ROOT_SENTINEL:
			if _state != 2:
				# Rompeescudos: cada bloqueo acerca el momento de abrirse.
				_time += 0.2 * Daylight.shield_break
				return _block()
		INFERNAL_BRUTE:
			if _state == 1:
				return _block()
		PRISM_GUARDIAN:
			if Daylight.attack_rating < PERFECT:
				# Repele los golpes imprecisos y retrocede: otra oportunidad.
				if _count < 2:
					_count += 1
					position.x += 70.0
				_timer = 0.5
				return _block()
		SKELETON_LANCER, MUMMY_SUMMONER:
			if not targetable:
				return _block()
		YETI_POUNDER:
			if _state != 3:
				return _block()
		LIVING_SAND:
			if hp > 1:
				hp -= 1
				_state = 1
				_timer = 0.45
				_set_active(false)
				_burst(Pal.YELLOW, 16)
				Sfx.play("land", 0.8)
				return -1
	hp -= 1
	if hp > 0:
		_flash = 0.15
		if mash:
			# Cada golpe empuja un poco (pulsacion rapida).
			position.x += 26.0 * Daylight.mash_factor
		return -1
	_die()
	return get_points()


func _block() -> int:
	_blocked = 0.35
	Sfx.play("hit", 1.4)
	var parent: Node = get_parent()
	if parent != null:
		Fx.burst(parent, position + Vector2(-20.0, _y - 30.0), Pal.WHITE, 6, 260.0, 0.25, 5.0, 300.0, 60.0, Vector2.LEFT)
	return 0


func _die() -> void:
	dead = true
	_set_active(false)
	if behavior == MAGMA_SPLITTER and not Daylight.no_split:
		for offset in [120.0, 250.0]:
			_spawn_child(MINI, position.x + float(offset), {"remap": _remap, "key": _remap_key, "sprite": _sprite})
	queue_free()


func _burst(color: Color, amount: int) -> void:
	var parent: Node = get_parent()
	if parent != null:
		Fx.burst(parent, position + Vector2(0.0, _y - 16.0), color, amount, 260.0, 0.45, 6.0, 500.0, 180.0, Vector2.UP)


## Crea una pieza (proyectil, peligro o cria) en el mismo contenedor.
func _spawn_child(type: int, x: float, data: Dictionary) -> void:
	var piece: Area2D = get_script().new()
	piece.position = Vector2(x, GROUND_Y)
	var parent: Node = get_parent()
	if parent == null:
		# Aun no esta en el arbol (se configura antes de anadirse): espera.
		call_deferred("_adopt", piece, type, data)
		return
	parent.call_deferred("add_child", piece)
	piece.call_deferred("setup_special", type, data)


func _adopt(piece: Area2D, type: int, data: Dictionary) -> void:
	var parent: Node = get_parent()
	if parent == null:
		piece.queue_free()
		return
	parent.add_child(piece)
	piece.call("setup_special", type, data)


func _spawn_pack() -> void:
	for i in 2:
		var offset: float = 110.0 * float(i + 1)
		_spawn_child(PACK_WOLF, position.x + offset, {"remap": _remap, "key": _remap_key, "sprite": _sprite, "adj": _adj, "trigger": 650.0 + offset, "phase": i + 1})


# ------------------------------------------------------------------ logica --

func _process(delta: float) -> void:
	if not _setup_done:
		return
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_blocked = maxf(_blocked - delta, 0.0)
	var hero: Vector2 = Daylight.player_pos
	var dx: float = global_position.x - hero.x
	var speed: float = Daylight.run_speed
	var warn: float = Daylight.warn_factor
	match behavior:
		BOAR_CHARGER:
			_tick_boar(dx, hero, speed, delta, warn)
		ROOT_SENTINEL:
			var cycle: float = 1.35 + 0.6 * Daylight.counter_factor / _adj
			var t: float = fposmod(_time, cycle)
			_state = 0 if t < 1.0 else (1 if t < 1.35 else 2)
			targetable = _state == 2
			if _state == 1:
				_shape.size = Vector2(96.0, 52.0)
				_collider.position = Vector2(-30.0, -26.0)
			else:
				_box(36.0, 52.0)
		FROG_LEAPER:
			_tick_frog(dx, delta, warn)
		SPORE_SHOOTER, SNOWMAN_ROLLER:
			_tick_shooter(dx, delta, warn)
		MOLE_POPPER:
			_tick_mole(dx, delta, warn)
		DEVIL_BULL:
			_tick_bull(dx, delta, warn)
		INFERNAL_BRUTE:
			if dx < 260.0 and hp > 0:
				position.x += (speed - 70.0 * _adj * Daylight.brute_factor) * delta
			# Guardia (garrote arriba, bloquea) y apertura alternas.
			var t2: float = fposmod(_time, 1.7 / _adj)
			_state = 1 if t2 < 0.7 / _adj else 0
		WISP_SHIFTER:
			var period: float = 1.4 / _adj
			_state = int(_time / period) % 2
			_y = -130.0 if _state == 1 else 0.0
			targetable = _state == 0
			_place()
		GARGOYLE_BOMBER:
			_tick_gargoyle(dx, hero, delta, warn)
		PRISM_GUARDIAN:
			_timer = maxf(_timer - delta, 0.0)
		CRYSTAL_BLINKER:
			_tick_blinker(dx, delta)
		GOLEM_COLOSSUS:
			var enraged: bool = hp * 2 <= _max_hp
			if enraged and _state == 0:
				_state = 1
				_flash = 0.3
				_burst(Pal.PINK, 22)
				Sfx.play("boss_hit", 0.7)
			var closing: float = (150.0 if enraged else 50.0) * _adj * Daylight.brute_factor
			if dx < 300.0 and hp > 0:
				position.x += (speed - closing) * delta
		CRYSTAL_MIMIC:
			_tick_mimic(dx, hero, delta, warn)
		GEODE_BURSTER:
			_tick_geode(dx, delta, warn)
		WOLF_PACK, PACK_WOLF:
			_tick_wolf(dx, delta, warn)
		SKELETON_LANCER:
			_tick_lancer(dx, hero, speed, delta, warn)
		YETI_POUNDER:
			_tick_yeti(dx, speed, delta, warn)
		ICE_WORM:
			_tick_worm(dx, delta, warn)
		DUNE_SERPENT:
			if dx < 800.0 * warn:
				position.x -= 90.0 * _adj * Daylight.chaser_factor * delta
			_y = -90.0 * (0.5 + 0.5 * sin(_time * 2.6 * _adj))
			targetable = _y > -45.0
			_place()
		STALKER_SCORPION:
			_tick_scorpion(dx, delta, warn)
		GIANT_BEETLE:
			_tick_beetle(dx, speed, delta, warn)
		MUMMY_SUMMONER:
			_tick_mummy(dx, hero, speed, delta, warn)
		LIVING_SAND:
			_tick_sand(dx, delta)
		SPORE:
			position.x -= 280.0 * Daylight.projectile_factor * delta
		SNOWBALL:
			position.x -= 235.0 * Daylight.projectile_factor * delta
			_size = minf(_size + delta * 1.2, 2.4)
			var r: float = 12.0 * _size
			_box(r * 2.0, r * 2.0)
			targetable = _size < 1.6
		FIREBALL:
			_vy += 1100.0 * delta
			_y = minf(_y + _vy * delta, 0.0)
			_place()
			if _y >= 0.0:
				_spawn_child(FLAME, position.x, {})
				_set_active(false)
				queue_free()
		FLAME:
			_timer -= delta
			if _timer <= 0.0:
				queue_free()
		SPEAR:
			_tick_spear(delta)
		SHOCKWAVE:
			position.x -= 345.0 * Daylight.projectile_factor * delta
		SHARD:
			position.x -= 175.0 * Daylight.projectile_factor * delta
			_y = -absf(sin(_time * 5.0 + float(_count) * 1.3)) * (60.0 + 20.0 * float(_count))
			targetable = _y > -40.0
			_place()
		HAND:
			_tick_hand(delta)
		BALL:
			if dx < _trigger * warn:
				position.x -= 185.0 * Daylight.projectile_factor * delta
	if _hazard or behavior == WISP_SHIFTER or behavior == MAGMA_SPLITTER or behavior == SPORE or behavior == SHARD:
		modulate = Daylight.unlit()
	else:
		modulate = Color(1.0, 1.0, 1.0)
	if dx < -900.0 and (behavior != BOAR_CHARGER or _passed):
		queue_free()
	queue_redraw()


func _tick_boar(dx: float, hero: Vector2, speed: float, delta: float, warn: float) -> void:
	if _state == 0:
		# Espera escondido; al pasar el heroe aparece detras de el.
		if dx < 0.0:
			_state = 1
			position.x = hero.x - 560.0 * warn
			_appear(Pal.BROWN)
			targetable = false
			Sfx.play("error", 0.7)
		return
	position.x += (speed + 200.0 * _adj * Daylight.chaser_factor) * delta
	if not _passed and global_position.x > hero.x + 60.0:
		_passed = true
		Daylight.dodges += 1


## Rana: avanza hacia el heroe a saltos; en el aire no se puede atacar.
func _tick_frog(dx: float, delta: float, warn: float) -> void:
	if _state == 0:
		if dx < 700.0 * warn:
			_state = 1
			_timer = 0.0
		return
	var period: float = 0.9 / _adj
	_timer += delta
	var t: float = fposmod(_timer, period) / period
	var hops: int = int(_timer / period)
	if hops >= 4:
		_y = 0.0
	elif t < 0.55:
		var air: float = t / 0.55
		_y = -130.0 * sin(air * PI)
		position.x -= 70.0 / (period * 0.55) * delta
	else:
		_y = 0.0
	targetable = _y > -40.0
	_place()


## Torretas (setas, munecos de nieve): cargan y disparan hacia el heroe.
func _tick_shooter(dx: float, delta: float, warn: float) -> void:
	_timer -= delta
	if dx > 300.0 and dx < 950.0 * warn and _count < 2 and _timer <= 0.0:
		if _state == 0:
			_state = 1
			_timer = 0.45
		else:
			_state = 0
			_timer = 1.7 / _adj
			_count += 1
			var type: int = SPORE if behavior == SPORE_SHOOTER else SNOWBALL
			_spawn_child(type, position.x - 40.0, {})
			Sfx.play("attack", 0.6)


## Topo: el monticulo tiembla y sale de golpe; al salir se puede golpear.
func _tick_mole(dx: float, delta: float, warn: float) -> void:
	if _state == 0 and dx < 300.0 * warn / _adj:
		_state = 1
		_timer = 0.18
		Sfx.play("land", 0.6)
	elif _state == 1:
		_timer -= delta
		if _timer <= 0.0:
			_state = 2
			_appear(Pal.BROWN)


## Diablo corredor: se acerca, escarba (aviso) y embiste muy rapido.
func _tick_bull(dx: float, delta: float, warn: float) -> void:
	match _state:
		0:
			if dx < 700.0 * warn:
				_state = 1
		1:
			position.x -= 110.0 * delta
			if dx < 380.0 * warn:
				_state = 2
				_timer = 0.55 / _adj
				Sfx.play("error", 0.6)
		2:
			_timer -= delta
			if _timer <= 0.0:
				_state = 3
				Sfx.play("attack", 0.5)
		_:
			position.x -= 420.0 * _adj * Daylight.chaser_factor * delta


## Gargola: suelta dos bolas de fuego desde arriba y despues se lanza en
## picado a la altura del heroe (solo entonces se puede atacar).
func _tick_gargoyle(dx: float, hero: Vector2, delta: float, warn: float) -> void:
	match _state:
		0:
			_y = -250.0 + sin(_time * 3.0) * 8.0
			if dx < 620.0 * warn:
				_state = 1
				_timer = 0.0
		1:
			_y = -250.0 + sin(_time * 3.0) * 8.0
			position.x -= 60.0 * delta
			_timer -= delta
			if _timer <= 0.0 and _count < 2:
				_count += 1
				_timer = 0.5
				_spawn_child(FIREBALL, position.x, {"y": _y + 10.0})
				Sfx.play("attack", 0.5)
			elif _count >= 2 and _timer <= 0.0:
				_state = 2
		2:
			# Espera a que el heroe deje atras el fuego antes del picado.
			_y = -250.0 + sin(_time * 3.0) * 8.0
			if dx < 320.0 or hero.x > _origin_x - 300.0:
				_state = 3
				Sfx.play("error", 1.2)
		_:
			_y = move_toward(_y, -40.0, 600.0 * delta)
			position.x -= 240.0 * Daylight.chaser_factor * delta
	targetable = _state >= 3 and _y > -100.0
	_place()


## Espiritu de cristal: se teletransporta (con imagen previa) y solo se
## puede golpear mientras esta materializado.
func _tick_blinker(dx: float, delta: float) -> void:
	if dx > 820.0:
		return
	_timer += delta
	var visible_time: float = 0.75 / _adj
	match _state:
		0:
			if _timer > visible_time and dx > 170.0 and _count < 3:
				_state = 1
				_timer = 0.0
		1:
			if _timer > 0.3:
				_state = 2
				_timer = 0.0
				_set_active(false)
		_:
			if _timer > 0.22:
				var offsets: Array = [-120.0, 70.0, -60.0]
				position.x += float(offsets[_count % offsets.size()])
				_count += 1
				_state = 0
				_timer = 0.0
				_appear(Pal.PINK)


## Saltacristal: imita los saltos del heroe con un pequeno retraso.
func _tick_mimic(dx: float, hero: Vector2, delta: float, warn: float) -> void:
	if dx < 700.0 * warn and dx > -60.0:
		position.x -= 60.0 * delta
	var airborne: bool = _y < 0.0 or _vy < 0.0
	if not airborne:
		if _timer > 0.0:
			_timer -= delta
			if _timer <= 0.0:
				_vy = -720.0
				Sfx.play("jump", 1.4)
		elif hero.y < GROUND_Y - 12.0 and dx < 420.0 and dx > 0.0:
			_timer = 0.12
	if _y < 0.0 or _vy < 0.0:
		_vy += 2000.0 * delta
		_y = minf(_y + _vy * delta, 0.0)
		if _y >= 0.0:
			_vy = 0.0
	targetable = _y > -30.0
	_place()


## Geoda: se agrieta al acercarte y estalla en tres cristales saltarines.
func _tick_geode(dx: float, delta: float, warn: float) -> void:
	if _state == 0 and dx < 430.0 * warn:
		_state = 1
		_timer = 0.55 / _adj
		Sfx.play("hit", 0.5)
	elif _state == 1:
		_timer -= delta
		if _timer <= 0.0:
			for i in 3:
				_spawn_child(SHARD, position.x + float(i) * 44.0, {"phase": i})
			_burst(Pal.PINK, 20)
			Sfx.play("boss_hit", 1.3)
			dead = true
			_set_active(false)
			queue_free()


## Lobos: la manada (lider y dos seguidores) aulla y carga en fila.
func _tick_wolf(dx: float, delta: float, warn: float) -> void:
	if _state == 0:
		if dx < _trigger * warn:
			_state = 1
			_timer = 0.5
			_flash = 0.15
			if behavior == WOLF_PACK:
				Sfx.play("error", 0.5)
		return
	if _state == 1:
		_timer -= delta
		if _timer <= 0.0:
			_state = 2
		return
	position.x -= 160.0 * _adj * Daylight.chaser_factor * delta
	_y = -absf(sin(_time * 9.0)) * 6.0
	_place()


## Lancero: con el escudo alzado lanza jabalinas en arco que se clavan
## delante del heroe; al recargar (o si llegas a su lado) es vulnerable.
func _tick_lancer(dx: float, hero: Vector2, speed: float, delta: float, warn: float) -> void:
	_timer -= delta
	if dx < 260.0:
		_state = 2
	match _state:
		0:
			if dx < 900.0 * warn and _timer <= 0.0:
				_state = 1
				_timer = 0.4
		1:
			if _timer <= 0.0:
				var target_x: float = hero.x + speed * 0.9
				var flight: float = 0.68
				var vx: float = (target_x - position.x) / flight
				_spawn_child(SPEAR, position.x - 20.0, {"vx": vx, "vy": -560.0, "y": -50.0})
				Sfx.play("attack", 0.7)
				_count += 1
				if _count % 2 == 0:
					_state = 2
					_timer = 1.3 / _adj
				else:
					_state = 0
					_timer = 0.7
		_:
			if _timer <= 0.0 and dx >= 260.0:
				_state = 0
	targetable = _state == 2


## Yeti: levanta los brazos (bloquea), golpea el suelo (onda que hay que
## saltar) y queda aturdido: solo entonces cuentan las pulsaciones.
func _tick_yeti(dx: float, speed: float, delta: float, warn: float) -> void:
	if dx < 300.0 and hp > 0:
		position.x += (speed - 40.0 * _adj * Daylight.brute_factor) * delta
	if dx > 700.0 * warn:
		return
	_timer -= delta
	match _state:
		0:
			_state = 1
			_timer = 0.6 / _adj
		1:
			if _timer <= 0.0:
				_state = 2
				_timer = 0.15
				_spawn_child(SHOCKWAVE, position.x - 50.0, {})
				Sfx.play("boss_hit", 0.6)
				var parent: Node = get_parent()
				if parent != null:
					Fx.ring(parent, position + Vector2(-20.0, 0.0), Pal.CYAN, 70.0)
		2:
			if _timer <= 0.0:
				_state = 3
				_timer = 1.3 * Daylight.counter_factor
		_:
			if _timer <= 0.0:
				_state = 1
				_timer = 0.6 / _adj


## Gusano: excava hacia ti (el monticulo se mueve), tiembla y emerge.
func _tick_worm(dx: float, delta: float, warn: float) -> void:
	match _state:
		0:
			if dx < 900.0 * warn:
				_state = 1
		1:
			position.x -= 120.0 * _adj * delta
			if dx < 260.0 * warn:
				_state = 2
				_timer = 0.35
				Sfx.play("land", 0.5)
		2:
			_timer -= delta
			if _timer <= 0.0:
				_state = 3
				_timer = 0.8
				_appear(Pal.CYAN)
		3:
			_timer -= delta
			if _timer <= 0.0:
				_state = 4
				_timer = 0.5
				_set_active(false)
		_:
			_timer -= delta
			if _timer <= 0.0 and dx > 300.0:
				_state = 1


## Escorpion: emerge, carga el aguijon, lo lanza hacia delante (golpe
## largo) y queda expuesto. Se le puede atacar desde lejos mientras carga.
func _tick_scorpion(dx: float, delta: float, warn: float) -> void:
	_timer -= delta
	match _state:
		0:
			if dx < 420.0 * warn:
				_state = 1
				_timer = 0.3
				Sfx.play("land", 0.7)
		1:
			if _timer <= 0.0:
				_state = 2
				_timer = 0.5 / _adj
				_appear(Pal.ORANGE)
		2:
			if _timer <= 0.0:
				_state = 3
				_timer = 0.3
				_shape.size = Vector2(150.0, 40.0)
				_collider.position = Vector2(-56.0, -20.0)
				Sfx.play("attack", 0.8)
		3:
			if _timer <= 0.0:
				_state = 4
				_timer = 0.9 * Daylight.counter_factor
				_box(38.0, 40.0)
		_:
			if _timer <= 0.0:
				_state = 2
				_timer = 0.5 / _adj


## Escarabajo: empuja una bola hacia ti, la suelta y se planta (pulsacion
## rapida para derribarlo).
func _tick_beetle(dx: float, speed: float, delta: float, warn: float) -> void:
	match _state:
		0:
			if dx < 700.0 * warn:
				_state = 1
		1:
			position.x -= 160.0 * Daylight.projectile_factor * delta
			if dx < 520.0:
				_state = 2
				Sfx.play("hit", 0.6)
		_:
			if dx < 260.0 and hp > 0:
				position.x += (speed - 60.0 * _adj * Daylight.brute_factor) * delta


## Momia: vendada (invulnerable) invoca manos que surgen del suelo delante
## del heroe; despues se desvenda y se puede golpear.
func _tick_mummy(dx: float, hero: Vector2, speed: float, delta: float, warn: float) -> void:
	_timer -= delta
	if dx < 230.0 and _state != 2:
		_state = 2
		_timer = 9.0
	match _state:
		0:
			if dx < 760.0 * warn:
				_state = 1
				_count = 0
				_timer = 0.2
		1:
			if _timer <= 0.0:
				if _count < 3:
					_spawn_child(HAND, hero.x + speed * 0.75, {})
					_count += 1
					_timer = 0.6 / _adj
				else:
					_state = 2
					_timer = 1.4 * Daylight.counter_factor
					Sfx.play("unlock", 0.6)
		_:
			if _timer <= 0.0:
				_state = 0
	targetable = _state == 2


## Arena viviente: al golpearla se deshace y se rehace mas adelante; cerca
## del heroe acelera hacia el.
func _tick_sand(dx: float, delta: float) -> void:
	if _state == 1:
		_timer -= delta
		if _timer <= 0.0:
			_state = 0
			position.x += 240.0
			_appear(Pal.YELLOW)
		return
	if dx < 320.0 and dx > 0.0:
		position.x -= 110.0 * _adj * delta


func _tick_spear(delta: float) -> void:
	if _state == 0:
		_vy += 1400.0 * delta
		position.x += _vx * delta
		_y = minf(_y + _vy * delta, 0.0)
		if _y >= 0.0:
			# Clavada en el suelo: un poste que hay que saltar.
			_state = 1
			_timer = 1.2
			_box(12.0, 44.0)
			_set_active(true)
			Sfx.play("land", 1.3)
		_place()
		return
	_timer -= delta
	if _timer <= 0.0:
		queue_free()


## Mano de momia: grieta (aviso, inofensiva), surge, se queda y se hunde.
func _tick_hand(delta: float) -> void:
	_timer += delta
	if _state == 0 and _timer > 0.3:
		_state = 1
		_set_active(true)
	elif _state == 1 and _timer > 0.85:
		_state = 2
		_set_active(false)
	elif _state == 2 and _timer > 1.1:
		queue_free()


# ------------------------------------------------------------------- dibujo --

func _tint() -> Color:
	if _flash > 0.0:
		return Color(3.0, 3.0, 3.0, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


func _skin(offset: Vector2, px: float = 4.0, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	PixelArt.draw_skin(self, _sprite, offset, px, tint * _tint(), _remap, _remap_key)


func _ground_shadow(width: float) -> void:
	var shrink: float = clampf(1.0 + _y / 260.0, 0.35, 1.0)
	draw_rect(Rect2(-width * 0.5 * shrink, -4.0, width * shrink, 4.0), Color(0.0, 0.0, 0.0, 0.3))


func _say(text: String, y: float, color: Color, px: float = 3.0) -> void:
	PixelFont.draw_text_shadowed(self, text, Vector2(-PixelFont.text_width(text, px) * 0.5, y), px, color, Pal.INK, true)


func _draw() -> void:
	if not _setup_done:
		return
	var top: float = _y - _shape.size.y
	match behavior:
		BOAR_CHARGER:
			_draw_boar()
		ROOT_SENTINEL:
			_draw_sentinel()
		FROG_LEAPER, CRYSTAL_MIMIC:
			_draw_hopper()
		SPORE_SHOOTER, SNOWMAN_ROLLER:
			var aim: Color = Color(2.0, 1.4, 1.0, 1.0) if _state == 1 else Color(1.0, 1.0, 1.0, 1.0)
			var bob: float = roundf(sin(_time * 4.0) * 2.0)
			_skin(Vector2(-24.0, -48.0 + bob), 4.0, aim)
			if _state == 1:
				PixelArt.draw_glow(self, Vector2(-30.0, -20.0), 30.0, Color(Pal.LIME if behavior == SPORE_SHOOTER else Pal.WHITE, 0.8))
		MOLE_POPPER:
			_draw_mound(_state < 2, 520.0)
			if _state == 2:
				_skin(Vector2(-20.0, -48.0))
				for k in 3:
					draw_rect(Rect2(-16.0 + float(k) * 12.0, -54.0, 4.0, 8.0), Pal.WHITE)
		DEVIL_BULL:
			_draw_bull()
		INFERNAL_BRUTE:
			_draw_brute(_state == 1)
		WISP_SHIFTER:
			var period: float = 1.4 / _adj
			var left: float = period - fposmod(_time, period)
			if left < 0.4:
				var next_y: float = 0.0 if _state == 1 else -130.0
				_skin(Vector2(-20.0, next_y - 40.0), 4.0, Color(1.0, 1.0, 1.0, 0.3))
			draw_rect(Rect2(-18.0, -4.0, 36.0, 4.0), Color(0.0, 0.0, 0.0, 0.3))
			_skin(Vector2(-20.0, _y - 40.0 + sin(_time * 6.0) * 3.0))
		GARGOYLE_BOMBER:
			_draw_gargoyle()
		MAGMA_SPLITTER, MINI:
			var squash: float = 1.0 + 0.08 * sin(_time * 8.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, 2.0 - squash))
			_skin(Vector2(-6.0 * _px, -9.0 * _px), _px)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if behavior == MAGMA_SPLITTER:
				draw_rect(Rect2(-12.0, -6.0, 24.0, 4.0), Color(Pal.ORANGE, 0.6 + 0.4 * sin(_time * 7.0)))
		PRISM_GUARDIAN:
			_draw_prism()
		CRYSTAL_BLINKER:
			_draw_blinker()
		GOLEM_COLOSSUS:
			_draw_golem()
		GEODE_BURSTER:
			_draw_geode()
		WOLF_PACK, PACK_WOLF:
			_ground_shadow(48.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
			_skin(Vector2(-28.0, _y - 36.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if _state == 1:
				_say("AUUU", -78.0 - float(_count) * 6.0, Pal.CYAN, 2.0)
		SKELETON_LANCER:
			_draw_lancer()
		YETI_POUNDER:
			_draw_yeti()
		ICE_WORM:
			_draw_worm()
		DUNE_SERPENT:
			_ground_shadow(48.0)
			var wiggle: float = sin(_time * 10.0) * 3.0
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
			_skin(Vector2(-28.0, _y - 36.0 + wiggle))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# Cola que sigue la ondulacion.
			for k in 4:
				var tail_y: float = -90.0 * (0.5 + 0.5 * sin((_time - 0.08 * float(k + 1)) * 2.6 * _adj))
				draw_rect(Rect2(26.0 + float(k) * 12.0, tail_y - 16.0, 12.0, 10.0), Color(Pal.YELLOW, 0.9 - float(k) * 0.18))
		STALKER_SCORPION:
			_draw_scorpion()
		GIANT_BEETLE:
			_draw_beetle()
		MUMMY_SUMMONER:
			_draw_mummy()
		LIVING_SAND:
			_draw_sand()
		_:
			_draw_piece()
	# Aviso "!" cuando el boton atacara a esta criatura.
	var player: Node = get_tree().get_first_node_in_group("player")
	if _active and not dead and not _hazard and targetable and player != null and not mash and player.has_method("is_enemy_in_reach"):
		if bool(player.call("is_enemy_in_reach", self)):
			PixelFont.draw_text_shadowed(self, "!", Vector2(-10.0, top - 44.0), 4.0, Pal.YELLOW, Pal.INK, true)


## Proyectiles, peligros y piezas.
func _draw_piece() -> void:
	match behavior:
		SPORE:
			draw_set_transform(Vector2(0.0, -12.0), _time * 10.0, Vector2.ONE)
			var spore: Color = _piece_color if _piece_color.a > 0.0 else Pal.LIME
			draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), spore.darkened(0.3))
			draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), spore)
			draw_rect(Rect2(-2.0, -10.0, 4.0, 4.0), Pal.YELLOW)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		SNOWBALL:
			var r: float = 12.0 * _size
			draw_set_transform(Vector2(0.0, -r), _time * 6.0, Vector2.ONE)
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Pal.WHITE)
			draw_rect(Rect2(-r * 0.5, -r, r, r * 0.5), Pal.SILVER)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if not targetable:
				_say("¡SALTA!", -r * 2.0 - 30.0, Pal.CYAN, 2.0)
		FIREBALL:
			PixelArt.draw_glow(self, Vector2(0.0, _y - 11.0), 30.0, Color(Pal.ORANGE, 0.8))
			draw_rect(Rect2(-10.0, _y - 22.0, 20.0, 22.0), Pal.ORANGE)
			draw_rect(Rect2(-6.0, _y - 16.0, 12.0, 12.0), Pal.YELLOW)
			for k in 3:
				draw_rect(Rect2(-4.0, _y - 34.0 - float(k) * 10.0, 8.0, 8.0), Color(Pal.RED, 0.7 - float(k) * 0.2))
			# Marca en el suelo donde va a caer.
			draw_rect(Rect2(-18.0, -4.0, 36.0, 4.0), Color(Pal.RED, 0.5 + 0.5 * sin(_time * 20.0)))
		FLAME:
			for k in 3:
				var flick: float = sin(_time * 18.0 + float(k) * 2.0) * 6.0
				var h: float = 36.0 + flick
				draw_rect(Rect2(-18.0 + float(k) * 12.0, -h, 12.0, h), Pal.ORANGE if k != 1 else Pal.RED)
				draw_rect(Rect2(-15.0 + float(k) * 12.0, -h * 0.6, 6.0, h * 0.6), Pal.YELLOW)
		SPEAR:
			var angle: float = atan2(_vy, _vx) if _state == 0 else -PI * 0.5 + 0.25
			draw_set_transform(Vector2(0.0, _y - (22.0 if _state == 1 else 0.0)), angle, Vector2.ONE)
			draw_rect(Rect2(-28.0, -2.0, 56.0, 4.0), Pal.BROWN)
			draw_rect(Rect2(20.0, -5.0, 12.0, 10.0), Pal.SILVER)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		SHOCKWAVE:
			for k in 3:
				var w: float = 44.0 - float(k) * 12.0
				var wave_color: Color = _piece_color if _piece_color.a > 0.0 else Pal.CYAN
				draw_rect(Rect2(-w * 0.5 + float(k) * 10.0, -8.0 - float(k) * 7.0, w, 8.0), Color(wave_color if k % 2 == 0 else Pal.WHITE, 0.9 - float(k) * 0.2))
		SHARD:
			draw_rect(Rect2(-4.0, -4.0, 8.0, 4.0), Color(0.0, 0.0, 0.0, 0.3))
			draw_set_transform(Vector2(0.0, _y - 11.0), _time * 4.0, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -12.0), Vector2(10.0, 0.0), Vector2(0.0, 12.0), Vector2(-10.0, 0.0)]), Pal.PINK)
			draw_rect(Rect2(-3.0, -6.0, 4.0, 6.0), Pal.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		HAND:
			_draw_hand()
		BALL:
			draw_rect(Rect2(-26.0, -4.0, 52.0, 4.0), Color(0.0, 0.0, 0.0, 0.3))
			draw_set_transform(Vector2(0.0, -26.0), -_time * 5.0, Vector2.ONE)
			draw_rect(Rect2(-26.0, -26.0, 52.0, 52.0), Pal.BROWN)
			draw_rect(Rect2(-18.0, -26.0, 12.0, 52.0), Pal.DARK_BROWN)
			draw_rect(Rect2(8.0, -16.0, 10.0, 10.0), Pal.DARK_BROWN)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp_bar(top: float, label: String) -> void:
	PixelFont.draw_text_shadowed(self, label, Vector2(-PixelFont.text_width(label, 2.0) * 0.5, top - 30.0), 2.0, Pal.YELLOW if int(_time * 6.0) % 2 == 0 else Pal.ORANGE, Pal.INK, true)
	for i in _max_hp:
		draw_rect(Rect2(-float(_max_hp) * 7.0 + float(i) * 14.0, top - 10.0, 10.0, 6.0), Pal.RED if i < hp else Pal.SLATE)


## Monticulo de tierra que tiembla cuando el heroe se acerca.
func _draw_mound(shaking: bool, near_distance: float) -> void:
	var hero_x: float = Daylight.player_pos.x
	var near: bool = shaking and global_position.x - hero_x < near_distance * Daylight.warn_factor
	var shake: float = sin(_time * 40.0) * 2.0 if near else 0.0
	draw_rect(Rect2(-22.0 + shake, -10.0, 44.0, 10.0), Pal.BROWN)
	draw_rect(Rect2(-14.0 + shake, -16.0, 28.0, 6.0), Pal.DARK_BROWN)
	if near:
		PixelFont.draw_text_shadowed(self, "!", Vector2(-6.0, -60.0), 4.0, Pal.RED, Pal.INK, true)
		for k in 3:
			var dust: float = fposmod(_time * 3.0 + float(k) * 0.33, 1.0)
			draw_rect(Rect2(-20.0 + float(k) * 16.0, -16.0 - dust * 26.0, 6.0, 6.0), Color(Pal.SILVER, 1.0 - dust))


func _draw_boar() -> void:
	if _state == 0:
		return
	var lift: float = roundf(absf(sin(_time * 16.0)) * -4.0)
	_skin(Vector2(-28.0, -36.0 + lift))
	# Polvo que levanta al correr.
	for k in 3:
		var d: float = fposmod(_time * 4.0 + float(k) * 0.33, 1.0)
		draw_rect(Rect2(-36.0 - d * 30.0, -8.0 - d * 12.0, 6.0, 6.0), Color(Pal.SILVER, 0.8 - d))
	if not _passed:
		var hero_x: float = Daylight.player_pos.x
		var screen_left: float = hero_x - 300.0 - global_position.x
		if screen_left > 0.0:
			var gap: float = hero_x - global_position.x
			var blink: bool = gap < 160.0 or int(_time * 8.0) % 2 == 0
			var arrow: String = "<<" if gap > 160.0 else "¡SALTA!"
			PixelFont.draw_text_shadowed(self, arrow, Vector2(screen_left, -120.0), 4.0, Pal.RED if blink else Pal.YELLOW, Pal.INK, true)


func _draw_sentinel() -> void:
	_skin(Vector2(-24.0, -52.0))
	var spear_len: float = 60.0 if _state == 1 else 18.0
	draw_rect(Rect2(-18.0 - spear_len, -34.0, spear_len, 6.0), Pal.SILVER)
	draw_rect(Rect2(-26.0 - spear_len, -36.0, 10.0, 10.0), Pal.WHITE)
	if _state == 2:
		PixelArt.draw_glow(self, Vector2(0.0, -26.0), 56.0, Color(Pal.LIME, 0.7))
		_say("¡AHORA!", -96.0, Pal.LIME)
	else:
		draw_rect(Rect2(-24.0, -48.0, 10.0, 40.0), Pal.YELLOW if _blocked > 0.0 else Pal.STEEL)
		if _state == 0:
			_say("SALTA", -86.0, Pal.SILVER, 2.0)


## Rana y saltacristal: estiramiento al saltar y sombra que se encoge.
func _draw_hopper() -> void:
	_ground_shadow(40.0)
	var stretch: float = 1.0 + clampf(-_y / 400.0, 0.0, 0.25)
	draw_set_transform(Vector2(0.0, _y), 0.0, Vector2(2.0 - stretch, stretch))
	_skin(Vector2(-24.0, -36.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if behavior == CRYSTAL_MIMIC:
		# Ojos que brillan cuando esta a punto de imitarte.
		var eye: Color = Pal.PINK if _timer > 0.0 or _y < 0.0 else Pal.WHITE
		draw_rect(Rect2(-14.0, _y - 30.0, 6.0, 6.0), eye)
		draw_rect(Rect2(6.0, _y - 30.0, 6.0, 6.0), eye)
		if _timer > 0.0:
			_say("¡IMITA!", _y - 74.0, Pal.PINK, 2.0)
	elif _y < -40.0:
		_say("POR DEBAJO", _y - 70.0, Pal.LIME, 2.0)


func _draw_bull() -> void:
	var lift: float = roundf(absf(sin(_time * (20.0 if _state == 3 else 8.0))) * -4.0)
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _state == 2:
		tint = Color(1.8, 1.0, 0.8, 1.0) if int(_time * 12.0) % 2 == 0 else Color(1.0, 1.0, 1.0, 1.0)
		# Escarba: polvo detras de las pezunas.
		for k in 4:
			var d: float = fposmod(_time * 5.0 + float(k) * 0.25, 1.0)
			draw_rect(Rect2(24.0 + d * 30.0, -8.0 - d * 20.0, 6.0, 6.0), Color(Pal.BROWN, 1.0 - d))
		_say("¡CARGA!", -80.0, Pal.ORANGE, 2.0)
	if _state == 3:
		PixelArt.draw_glow(self, Vector2(-10.0, -18.0), 40.0, Color(Pal.ORANGE, 0.6))
		for k in 3:
			draw_rect(Rect2(30.0 + float(k) * 16.0, -26.0 + float(k) * 6.0, 14.0, 4.0), Color(Pal.ORANGE, 0.8 - float(k) * 0.25))
	# Mira hacia el heroe (izquierda).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	_skin(Vector2(-28.0, -36.0 + lift), 4.0, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_brute(guard: bool) -> void:
	_skin(Vector2(-42.0, -78.0), _px)
	var club_y: float = -150.0 if guard else -124.0
	draw_rect(Rect2(-6.0, club_y, 12.0, 48.0), Pal.BROWN)
	draw_rect(Rect2(-12.0, club_y - 8.0, 24.0, 18.0), Pal.DARK_BROWN)
	if guard:
		draw_rect(Rect2(-52.0, -100.0, 12.0, 70.0), Pal.YELLOW if _blocked > 0.0 else Pal.STEEL)
		_draw_hp_bar(-150.0, "¡ESPERA!")
	else:
		PixelArt.draw_glow(self, Vector2(0.0, -60.0), 70.0, Color(Pal.ORANGE, 0.35))
		_draw_hp_bar(-150.0, "¡PULSA RÁPIDO! x%d" % hp)


func _draw_gargoyle() -> void:
	draw_rect(Rect2(-20.0, -4.0, 40.0, 4.0), Color(0.0, 0.0, 0.0, 0.2))
	var flap: float = sin(_time * 14.0) * 10.0
	# Alas.
	draw_rect(Rect2(-44.0, _y - 40.0 + flap, 24.0, 10.0), Pal.SLATE)
	draw_rect(Rect2(20.0, _y - 40.0 + flap, 24.0, 10.0), Pal.SLATE)
	_skin(Vector2(-24.0, _y - 48.0))
	if _state == 1:
		PixelArt.draw_glow(self, Vector2(0.0, _y - 10.0), 28.0, Color(Pal.ORANGE, 0.8))
	elif _state >= 3:
		PixelArt.draw_glow(self, Vector2(0.0, _y - 24.0), 44.0, Color(Pal.RED, 0.5))
	elif _state == 2:
		_say("¡PICADO!", _y - 80.0, Pal.ORANGE, 2.0)


func _draw_prism() -> void:
	_skin(Vector2(-24.0, -52.0))
	# Escudo de cristal que refleja: brilla y destella al repeler.
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	var shield: Color = Pal.WHITE if _blocked > 0.0 else Pal.PINK.lerp(Pal.CYAN, pulse)
	draw_colored_polygon(PackedVector2Array([Vector2(-30.0, -54.0), Vector2(-18.0, -60.0), Vector2(-18.0, -4.0), Vector2(-30.0, -10.0)]), Color(shield, 0.85))
	PixelArt.draw_glow(self, Vector2(-24.0, -32.0), 40.0, Color(shield, 0.35))
	if _timer > 0.0:
		_say("¡MÁS CERCA!", -96.0, Pal.PINK, 2.0)
	else:
		_say("PERFECT", -90.0, Color(Pal.CYAN, 0.6 + 0.4 * pulse), 2.0)


func _draw_blinker() -> void:
	match _state:
		0:
			_skin(Vector2(-20.0, -44.0 + sin(_time * 6.0) * 4.0))
		1:
			# Se desvanece y deja ver donde reaparecera.
			var fade: float = 1.0 - clampf(_timer / 0.3, 0.0, 1.0)
			_skin(Vector2(-20.0, -44.0), 4.0, Color(1.0, 1.0, 1.0, fade))
			var offsets: Array = [-120.0, 70.0, -60.0]
			var next_x: float = float(offsets[_count % offsets.size()])
			_skin(Vector2(-20.0 + next_x, -44.0), 4.0, Color(1.0, 1.0, 1.0, 0.25 + 0.25 * sin(_time * 30.0)))
			for k in 4:
				draw_rect(Rect2(next_x * float(k) / 4.0 - 4.0, -26.0, 8.0, 8.0), Color(Pal.PINK, 0.5))
		_:
			for k in 6:
				var a: float = float(k) / 6.0 * TAU + _time * 8.0
				draw_rect(Rect2(cos(a) * 18.0 - 3.0, -26.0 + sin(a) * 18.0 - 3.0, 6.0, 6.0), Color(Pal.PINK, 0.8))


func _draw_golem() -> void:
	var enraged: bool = _state == 1
	var shake: float = sin(_time * 50.0) * 3.0 if enraged else 0.0
	var tint: Color = Color(1.6, 0.8, 1.2, 1.0) if enraged else Color(1.0, 1.0, 1.0, 1.0)
	_skin(Vector2(-42.0 + shake, -78.0), _px, tint)
	# Grietas que crecen con el dano.
	var cracks: int = _max_hp - hp
	for k in cracks:
		draw_rect(Rect2(-30.0 + float(k * 13 % 50), -70.0 + float(k * 17 % 50), 4.0, 14.0), Pal.WHITE)
	if enraged:
		PixelArt.draw_glow(self, Vector2(0.0, -50.0), 80.0, Color(Pal.PINK, 0.4))
		for k in 3:
			var d: float = fposmod(_time * 2.0 + float(k) * 0.33, 1.0)
			draw_rect(Rect2(-30.0 + float(k) * 26.0, -90.0 - d * 50.0, 6.0, 6.0), Color(Pal.CYAN, 1.0 - d))
	_draw_hp_bar(-150.0, ("¡FURIA! x%d" % hp) if enraged else ("¡PULSA RÁPIDO! x%d" % hp))


func _draw_geode() -> void:
	var shake: float = sin(_time * 50.0) * 2.0 if _state == 1 else 0.0
	_skin(Vector2(-6.0 * _px + shake, -9.0 * _px), _px)
	if _state == 1:
		var crack: float = 1.0 - clampf(_timer / (0.55 / _adj), 0.0, 1.0)
		for k in 4:
			draw_rect(Rect2(-20.0 + float(k) * 12.0, -40.0 + float(k % 2) * 8.0, 4.0, 18.0 * crack), Pal.WHITE)
		PixelArt.draw_glow(self, Vector2(0.0, -20.0), 40.0 + 30.0 * crack, Color(Pal.PINK, 0.6 * crack))
		_say("¡VA A ESTALLAR!", -84.0, Pal.PINK, 2.0)


func _draw_lancer() -> void:
	_skin(Vector2(-24.0, -52.0))
	if _state == 2:
		PixelArt.draw_glow(self, Vector2(0.0, -26.0), 56.0, Color(Pal.LIME, 0.6))
		_say("¡RECARGA!", -96.0, Pal.LIME, 2.0)
	else:
		draw_rect(Rect2(-24.0, -48.0, 12.0, 42.0), Pal.YELLOW if _blocked > 0.0 else Pal.SILVER)
		# Jabalina preparada sobre el hombro.
		var raise: float = -14.0 if _state == 1 else 0.0
		draw_rect(Rect2(-4.0, -64.0 + raise, 44.0, 4.0), Pal.BROWN)
		draw_rect(Rect2(-12.0, -66.0 + raise, 10.0, 8.0), Pal.SILVER)


func _draw_yeti() -> void:
	var raise: float = -26.0 if _state == 1 else 0.0
	_skin(Vector2(-42.0, -78.0), _px)
	# Brazos.
	draw_rect(Rect2(-50.0, -96.0 + raise, 14.0, 40.0), Pal.WHITE)
	draw_rect(Rect2(36.0, -96.0 + raise, 14.0, 40.0), Pal.WHITE)
	if _state == 3:
		for k in 3:
			var a: float = _time * 6.0 + float(k) * TAU / 3.0
			PixelArt.draw(self, "star", Vector2(cos(a) * 30.0 - 9.0, -118.0 + sin(a) * 8.0), 2.0)
		_draw_hp_bar(-150.0, "¡ATURDIDO! x%d" % hp)
	else:
		_draw_hp_bar(-150.0, "¡SALTA LA ONDA!" if _state == 1 else "x%d" % hp)


func _draw_worm() -> void:
	match _state:
		0, 1, 2:
			_draw_mound(true, 700.0)
			if _state == 1:
				for k in 3:
					var d: float = fposmod(_time * 4.0 + float(k) * 0.33, 1.0)
					draw_rect(Rect2(14.0 + d * 30.0, -10.0 - d * 10.0, 6.0, 6.0), Color(Pal.WHITE, 1.0 - d))
		3:
			# Columna del gusano asomando.
			var rise: float = clampf((0.8 - _timer) / 0.15, 0.0, 1.0)
			var h: float = 110.0 * rise
			draw_rect(Rect2(-16.0, -h, 32.0, h), Pal.SKY)
			for k in int(h / 18.0):
				draw_rect(Rect2(-16.0, -float(k) * 18.0 - 6.0, 32.0, 4.0), Pal.CYAN)
			_skin(Vector2(-20.0, -h - 30.0))
		_:
			draw_rect(Rect2(-22.0, -6.0, 44.0, 6.0), Pal.BROWN)


func _draw_scorpion() -> void:
	if _state <= 1:
		_draw_mound(_state == 1, 520.0)
		return
	_skin(Vector2(-20.0, -44.0))
	# Cola y aguijon: arriba al cargar, extendida al atacar.
	if _state == 2:
		var tremble: float = sin(_time * 30.0) * 2.0
		draw_rect(Rect2(10.0, -70.0 + tremble, 8.0, 34.0), Pal.ORANGE)
		draw_rect(Rect2(4.0, -78.0 + tremble, 14.0, 10.0), Pal.RED)
		_say("¡AGUIJÓN!", -100.0, Pal.ORANGE, 2.0)
	elif _state == 3:
		draw_rect(Rect2(-130.0, -26.0, 112.0, 8.0), Pal.ORANGE)
		draw_rect(Rect2(-140.0, -30.0, 14.0, 16.0), Pal.RED)
	else:
		draw_rect(Rect2(10.0, -30.0, 30.0, 8.0), Pal.ORANGE)
		PixelArt.draw_glow(self, Vector2(0.0, -22.0), 50.0, Color(Pal.LIME, 0.5))
		_say("¡AHORA!", -90.0, Pal.LIME, 2.0)


func _draw_beetle() -> void:
	var push: float = sin(_time * 10.0) * 2.0 if _state == 1 else 0.0
	_skin(Vector2(-28.0 + push, -52.0), 4.0)
	draw_rect(Rect2(-30.0, -60.0, 60.0, 10.0), Color(Pal.TEAL, 0.9))
	if _state >= 2:
		_draw_hp_bar(-56.0, "¡PULSA RÁPIDO! x%d" % hp)


func _draw_mummy() -> void:
	_skin(Vector2(-24.0, -52.0))
	if _state == 2:
		PixelArt.draw_glow(self, Vector2(0.0, -26.0), 56.0, Color(Pal.YELLOW, 0.5))
		_say("¡AHORA!", -96.0, Pal.YELLOW, 2.0)
	else:
		# Vendas que la envuelven y giran.
		for k in 5:
			var y: float = -48.0 + float(k) * 9.0 + fposmod(_time * 20.0, 9.0)
			draw_rect(Rect2(-26.0, y, 52.0, 3.0), Color(Pal.WHITE, 0.85))
		if _state == 1:
			_say("INVOCA", -90.0, Pal.ORANGE, 2.0)


func _draw_hand() -> void:
	match _state:
		0:
			# Grieta en el suelo: aviso de que surgira una mano.
			var pulse: float = 0.5 + 0.5 * sin(_time * 30.0)
			draw_rect(Rect2(-16.0, -4.0, 32.0, 4.0), Color(Pal.ORANGE, pulse))
			draw_rect(Rect2(-4.0, -10.0, 8.0, 6.0), Color(Pal.DARK_BROWN, pulse))
		1:
			draw_rect(Rect2(-10.0, -38.0, 20.0, 38.0), Pal.WHITE)
			for k in 3:
				draw_rect(Rect2(-10.0 + float(k) * 7.0, -48.0, 5.0, 12.0), Pal.WHITE)
			draw_rect(Rect2(-10.0, -24.0, 20.0, 3.0), Pal.SILVER)
		_:
			var sink: float = clampf((_timer - 0.85) / 0.25, 0.0, 1.0)
			draw_rect(Rect2(-10.0, -38.0 * (1.0 - sink), 20.0, 38.0 * (1.0 - sink)), Color(Pal.WHITE, 0.6))


func _draw_sand() -> void:
	if _state == 1:
		var k: float = 1.0 - clampf(_timer / 0.45, 0.0, 1.0)
		draw_rect(Rect2(-26.0, -6.0, 52.0, 6.0), Pal.YELLOW.darkened(0.2))
		# Remolino de arena que viaja al punto donde se rehara.
		for i in 6:
			var x: float = lerpf(0.0, 240.0, k) + sin(_time * 20.0 + float(i)) * 10.0
			draw_rect(Rect2(x - 4.0, -10.0 - float(i) * 6.0, 8.0, 6.0), Color(Pal.YELLOW, 0.7))
		return
	var squash: float = 1.0 + 0.1 * sin(_time * 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, 2.0 - squash))
	_skin(Vector2(-24.0, -36.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		draw_rect(Rect2(-14.0 + float(i) * 12.0, -50.0, 8.0, 6.0), Pal.YELLOW if i < hp else Pal.SLATE)
