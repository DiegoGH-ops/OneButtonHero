extends Node2D
## Escena principal de la partida. Coordina al heroe, el generador de nivel,
## la camara, el ciclo de dia y noche, la dificultad, los poderes, las
## mejoras de la tienda, los eventos aleatorios, la puntuacion y la interfaz.

const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Background = preload("res://scripts/background.gd")
const GroundRenderer = preload("res://scripts/ground_renderer.gd")
const LevelGenerator = preload("res://scripts/level_generator.gd")
const Lights = preload("res://scripts/lights.gd")
const Coin = preload("res://scripts/coin.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Precision = preload("res://scripts/precision.gd")
const Timing = preload("res://scripts/timing.gd")
const Boss = preload("res://scripts/boss.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Fx = preload("res://scripts/fx.gd")
const Pal = preload("res://scripts/palette.gd")

enum State { PLAYING, DYING, GAME_OVER }

const GROUND_Y := 560.0
const BASE_SPEED := 340.0
## Cada 20 segundos sube un nivel y la velocidad aumenta.
const LEVEL_SECONDS := 20.0
const SPEED_STEP := 38.0
const MAX_SPEED := 800.0
const MAX_LIVES := 3
const CAMERA_LEAD := 320.0
const PIXELS_PER_METER := 48.0
## Segundos que dura un ciclo completo de dia y noche.
const DAY_LENGTH := 110.0
## Cada cuantos metros hay una pequena recompensa.
const MILESTONE_METERS := 250
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MAGNET_RADII := [0.0, 100.0, 140.0, 180.0, 220.0, 260.0]
const SHIELD_REGEN := [0.0, 0.0, 60.0, 45.0, 32.0, 22.0]
## Musica de cada mundo de la campana.
const WORLD_TRACKS := ["forest", "inferno", "crystal", "frost", "desert"]
## Premio por alcanzar estos combos perfectos en una partida.
const COMBO_REWARDS := [10, 20, 30, 50]

const NEW_HAZARDS := {
	1: "NUEVO: HUECOS, LLAMAS Y DIABLILLOS",
	2: "NUEVO: TÓTEMS, PLATAFORMAS Y ESPECTROS",
	3: "NUEVO: ESCUDEROS Y ROCAS RODANTES",
	4: "NUEVO: COMBINACIONES",
	5: "NUEVO: ABISMOS ANCHOS",
}

var _state: int = State.PLAYING
var _speed: float = BASE_SPEED
var _target_speed: float = BASE_SPEED
var _level: int = 0
var _level_timer: float = 0.0
var _distance_px: float = 0.0
var _last_player_x: float = 0.0
var _points: float = 0.0
var _coins_f: float = 0.0
var _kills: int = 0
var _gems: int = 0
var _lives: int = MAX_LIVES
var _damage_taken: int = 0
## Modo campana: nivel con meta, velocidad propia y recorrido fijo.
var _level_mode: bool = false
var _def: Dictionary = {}
var _goal_x: float = INF
## Soul Reaper activado: el proximo ataque perfecto sera letal.
var _soul_ready: bool = false
var precision: Precision
## Jefe final (solo en el nivel 20 de cada mundo).
var _boss: Boss
## Herramientas de depuracion del timing (tecla F3).
var _debug: bool = false
var _shake: float = 0.0
var _zoom_punch: float = 0.0
var _next_milestone: int = MILESTONE_METERS
var _banked: bool = false
var _revive_used: bool = false
var _enemy_colors: Array = [Pal.GREEN, Pal.RED, Pal.PURPLE, Pal.STEEL, Pal.WHITE]

# Mejoras y objetos de la tienda.
var _magnet_base: float = 0.0
var _coin_mult: float = 1.0
var _score_mult: float = 1.0
var _bounty: int = 0
var _shield_regen: float = 0.0
var _shield_timer: float = 0.0
var _cooldown_factor: float = 1.0
var _perfect_mult: float = 1.0
var _combo_coins: int = 0
var _recovery: float = 0.0
var _jump_mult: float = 1.0
var _dodge_mult: float = 1.0
var _max_lives: int = MAX_LIVES
## Modo de dominio elegido en el mapa ("normal", "no_damage"...).
var _challenge: String = "normal"
var _run_time: float = 0.0
var _picked: int = 0
var _diamond_found: bool = false
var _combo_reward_index: int = 0
var _step_timer: float = 0.0
var _storm_timer: float = 20.0
var _storm: float = 0.0
var _double_coins: bool = false
var _magnet_boost: float = 0.0

# Dia y noche, eventos y poderes.
var _phase: int = -1
var _was_night: bool = false
var _event_timer: float = 30.0
var _gold_rush: float = 0.0
var _power_cooldowns: Array = [0.0, 0.0, 0.0]

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var background: Background = $BackgroundLayer/Background
@onready var world: Node2D = $World
@onready var ground: GroundRenderer = $World/Ground
@onready var spans_root: Node2D = $World/Spans
@onready var objects_root: Node2D = $World/Objects
@onready var fx_root: Node2D = $Fx
@onready var lights: Lights = $Lights
@onready var generator: LevelGenerator = $Generator
@onready var hud: Hud = $HUD


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	# Cada partida empieza a una hora distinta del dia.
	Daylight.time = randf_range(0.10, 0.50)
	Daylight.magnet_radius = 0.0
	Daylight.theme = Campaign.theme(0)
	Daylight.ice = []
	generator.setup(spans_root, objects_root)
	precision = Precision.new()
	add_child(precision)
	precision.rated.connect(_on_rated)
	if String(GameData.run.get("mode", "endless")) == "level":
		_level_mode = true
		_def = Campaign.level_def(int(GameData.run.get("world", 0)), int(GameData.run.get("level", 0)))
		Daylight.theme = Campaign.theme(int(_def["world"]))
		Daylight.time = float(_def["time"])
		_speed = float(_def["speed"])
		_target_speed = _speed + float(_def["speed_gain"])
		_goal_x = float(_def["goal_px"])
		_level = 5
		precision.window_scale = float(_def["window_scale"])
		generator.configure(_def)
		_challenge = String(GameData.run.get("challenge", "normal"))
		generator.diamond_available = not GameData.hidden_diamond_taken(int(_def["world"]), int(_def["level"]))
		if bool(_def["final"]):
			# Nivel de jefe: no hay meta; se gana derrotandolo.
			_goal_x = INF
			_boss = Boss.new()
			objects_root.add_child(_boss)
			_boss.setup(int(_def["world"]), generator)
			_boss.struck.connect(_on_boss_struck)
			_boss.defeated.connect(_level_complete)
	ground.holes = generator.holes
	Daylight.holes = generator.holes

	player.position = Vector2(0.0, GROUND_Y - 2.0)
	player.run_speed = _speed
	Daylight.player_pos = player.position
	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)
	player.attacked.connect(_on_player_attacked)
	player.pickup_collected.connect(_on_pickup_collected)
	player.enemy_killed.connect(_on_enemy_killed)
	player.enemy_hit.connect(_on_enemy_hit)
	player.hazard_smashed.connect(_on_hazard_smashed)
	player.shield_broken.connect(_on_shield_broken)
	player.soul_strike.connect(_on_soul_strike)
	player.damaged.connect(_on_player_damaged)
	player.fell.connect(_on_player_fell)
	_last_player_x = player.position.x

	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_go_to_menu)
	hud.power_pressed.connect(_use_power)
	hud.next_requested.connect(_next_level)
	if _level_mode and _boss == null:
		hud.set_level_name("NIVEL " + String(_def["name"]))
	hud.set_max_lives(MAX_LIVES)
	if _challenge != "normal":
		hud.toast("MODO: " + _challenge_name(), Pal.ORANGE)
	hud.set_high_score(GameData.high_score)

	_apply_shop_items()
	hud.set_max_lives(_max_lives)
	camera.make_current()
	_update_camera()
	_update_daylight(true)
	_update_hud()
	_event_timer = randf_range(28.0, 40.0)

	player.active = true
	hud.can_pause = true


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.set_intensity(0)


## Aplica mejoras permanentes, consumibles y cosmeticos comprados.
func _apply_shop_items() -> void:
	_magnet_base = MAGNET_RADII[clampi(GameData.upgrade_level("magnet"), 0, 5)]
	_coin_mult = 1.0 + 0.20 * float(GameData.upgrade_level("coin_mult"))
	_score_mult = 1.0 + 0.08 * float(GameData.upgrade_level("score"))
	_jump_mult = 1.0 + 0.25 * float(GameData.upgrade_level("jump_bonus"))
	_dodge_mult = 1.0 + 0.30 * float(GameData.upgrade_level("dodge_bonus"))
	_max_lives = MAX_LIVES + GameData.upgrade_level("armor")
	_lives = _max_lives
	_bounty = GameData.upgrade_level("bounty")
	_cooldown_factor = 1.0 - 0.10 * float(GameData.upgrade_level("energy"))
	_perfect_mult = 1.0 + 0.2 * float(GameData.upgrade_level("perfect"))
	_combo_coins = GameData.upgrade_level("combo_coins")
	_recovery = 0.4 * float(GameData.upgrade_level("recovery"))
	player.reach_bonus = 1.0 + 0.08 * float(GameData.upgrade_level("reach"))
	generator.gem_bonus = 0.04 * float(GameData.upgrade_level("lucky"))
	var shield_level: int = clampi(GameData.upgrade_level("shield"), 0, 5)
	player.shield_active = shield_level > 0
	_shield_regen = SHIELD_REGEN[shield_level]

	var used: PackedStringArray = PackedStringArray()
	if GameData.use_consumable("guard"):
		player.start_rage(15.0)
		used.append("PROTECCIÓN")
	if GameData.use_consumable("double"):
		_double_coins = true
		used.append("DOBLE BOTÍN")
	if GameData.use_consumable("magnet_boost"):
		_magnet_boost = 45.0
		used.append("SUPERIMÁN")
	if not used.is_empty():
		hud.toast("ACTIVO: " + ", ".join(used), Pal.CYAN)

	var aura: Dictionary = GameData.equipped_item("aura")
	var aura_hex: String = aura["color"]
	if aura_hex != "":
		lights.aura_color = Color(aura_hex)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		_debug = not _debug
		hud.set_debug("")
		return
	if _state != State.PLAYING:
		return
	if event.is_action_pressed(GameData.ACTION):
		player.press()
		return
	for i in GameData.POWER_ACTIONS.size():
		if event.is_action_pressed(String(GameData.POWER_ACTIONS[i])):
			_use_power(i)


func _process(delta: float) -> void:
	# Tiempo real: no le afecta el poder "Tiempo lento".
	var real_delta: float = delta / maxf(Engine.time_scale, 0.05)
	if _state == State.PLAYING:
		if _level_mode:
			# En campana la velocidad sube poco a poco hasta la meta.
			_speed = move_toward(_speed, _target_speed, 1.2 * delta)
		else:
			_level_timer += delta
			if _level_timer >= LEVEL_SECONDS:
				_level_timer -= LEVEL_SECONDS
				_level_up()
			_speed = move_toward(_speed, _target_speed, 24.0 * delta)
		player.run_speed = _speed
		Daylight.run_speed = player.get_speed()

		var moved: float = player.position.x - _last_player_x
		if moved > 0.0:
			_distance_px += moved
			_points += moved / PIXELS_PER_METER * _point_multiplier()
		_last_player_x = player.position.x

		_update_timers(delta, real_delta)
		_check_milestones()
		generator.heart_wanted = _lives < _max_lives
		_run_time += delta
		_update_feel(delta)
		generator.update(player.position.x, _speed, _level, delta)
		_update_camera()
		Daylight.time = fposmod(Daylight.time + delta / DAY_LENGTH, 1.0)
		_update_daylight(false)
		precision.update(player.position, delta)
		if _level_mode and player.position.x >= _goal_x:
			_level_complete()

	# Efectos de camara: temblor y pequeno golpe de zoom.
	if _shake > 0.0:
		_shake = maxf(_shake - real_delta * 2.5, 0.0)
		var strength: float = _shake * 14.0 if GameData.screen_shake else 0.0
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		camera.offset = Vector2.ZERO
	_zoom_punch = maxf(_zoom_punch - real_delta * 3.0, 0.0)
	var zoom: float = 1.0 + _zoom_punch * 0.05
	camera.zoom = Vector2(zoom, zoom)

	background.scroll_x = camera.position.x
	ground.view_left = camera.position.x - 640.0
	lights.camera_x = camera.position.x
	_update_hud()


func _update_camera() -> void:
	camera.position = Vector2(player.position.x + CAMERA_LEAD, 360.0)


## Temporizadores de efectos, escudo, poderes y eventos.
func _update_timers(delta: float, real_delta: float) -> void:
	_magnet_boost = maxf(_magnet_boost - delta, 0.0)
	_gold_rush = maxf(_gold_rush - delta, 0.0)
	var radius: float = _magnet_base
	if _magnet_boost > 0.0:
		radius = maxf(radius, 280.0)
	Daylight.magnet_radius = radius

	if _shield_regen > 0.0 and not player.shield_active:
		_shield_timer += delta
		if _shield_timer >= _shield_regen:
			_shield_timer = 0.0
			player.shield_active = true
			Sfx.play("heart")
			hud.toast("ESCUDO RECARGADO", Pal.CYAN)

	for i in _power_cooldowns.size():
		_power_cooldowns[i] = maxf(float(_power_cooldowns[i]) - real_delta, 0.0)
	# Ventisca / tormenta de arena: reduce la visibilidad un rato.
	var storm_hex: String = String(Daylight.theme.get("storm", ""))
	if storm_hex != "":
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_storm = 7.0
			_storm_timer = randf_range(22.0, 32.0)
			hud.toast("¡VENTISCA!" if bool(Daylight.theme.get("ice", false)) else "¡TORMENTA DE ARENA!", Color(storm_hex))
		_storm = maxf(_storm - delta, 0.0)
		var haze: float = clampf(minf(_storm, 7.0 - _storm) * 0.5, 0.0, 1.0) * 0.42 if _storm > 0.0 else 0.0
		hud.set_haze(Color(storm_hex), haze)
	_event_timer -= delta
	if _event_timer <= 0.0 and not _level_mode:
		_event_timer = randf_range(38.0, 55.0)
		_start_random_event()


# ---------------------------------------------------------- dia y noche --

func _update_daylight(first: bool) -> void:
	var ambient: Color = Daylight.ambient()
	world.modulate = ambient
	player.modulate = ambient.lerp(Color(1.0, 1.0, 1.0), 0.4)
	var phase: int = Daylight.phase()
	if phase == _phase:
		return
	var previous: int = _phase
	_phase = phase
	# Musica segun el mundo y la hora, con fundido cruzado.
	if _boss != null:
		Sfx.play_music("boss")
	elif _level_mode:
		var track: String = WORLD_TRACKS[clampi(int(_def["world"]), 0, WORLD_TRACKS.size() - 1)]
		Sfx.play_music(track + "_night" if phase == Daylight.Phase.NIGHT else track)
	elif phase == Daylight.Phase.NIGHT:
		Sfx.play_music("night")
	elif phase == Daylight.Phase.SUNSET:
		Sfx.play_music("sunset")
	else:
		Sfx.play_music("day")
	if first:
		_was_night = phase == Daylight.Phase.NIGHT
		return
	if _level_mode:
		return
	if phase == Daylight.Phase.NIGHT:
		_was_night = true
		hud.show_banner("CAE LA NOCHE", "PUNTOS X1.5 - CUIDADO CON LOS ESPECTROS")
	elif phase == Daylight.Phase.SUNSET:
		hud.toast("ATARDECER", Pal.ORANGE)
	elif phase == Daylight.Phase.DAWN and previous == Daylight.Phase.NIGHT:
		hud.show_banner("AMANECE", "HAS SOBREVIVIDO A LA NOCHE: +30 MONEDAS")
		if _was_night:
			_add_coins(30.0, false)
			GameData.add_stat("nights_survived", 1)
			GameData.add_mission_progress("nights", 1)
			GameData.check_achievements()
			Sfx.play("mission")
	else:
		hud.toast(Daylight.phase_name(), Pal.WHITE)


## Sensacion de juego: pasos, energia del combo, intensidad de la musica y
## premios por combos largos.
func _update_feel(delta: float) -> void:
	if player.is_on_floor():
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.26 * 340.0 / maxf(player.get_speed(), 1.0)
			Sfx.play("step", randf_range(0.9, 1.1))
	var mult: float = precision.multiplier()
	var level: int = 0
	if mult >= 4.0:
		level = 3
	elif mult >= 2.0:
		level = 2
	elif mult > 1.0:
		level = 1
	if level != player.combo_level:
		if level > player.combo_level:
			Sfx.play("combo")
			Fx.ring(fx_root, player.position + Vector2(0.0, -32.0), Pal.YELLOW, 70.0 + 20.0 * float(level))
		player.combo_level = level
		Sfx.set_intensity(level)
	if _combo_reward_index < COMBO_REWARDS.size() and precision.perfects >= int(COMBO_REWARDS[_combo_reward_index]):
		var target: int = COMBO_REWARDS[_combo_reward_index]
		_combo_reward_index += 1
		_add_coins(float(target), false)
		hud.toast("COMBO %d: +%d MONEDAS" % [target, target], Pal.ORANGE)


func _challenge_name() -> String:
	for item in Campaign.MODES:
		var mode: Dictionary = item
		if String(mode["id"]) == _challenge:
			return String(mode["name"])
	return ""


## Comprueba al final si se cumplio el modo de dominio elegido.
func _challenge_met() -> bool:
	var world: int = int(_def["world"])
	var level: int = int(_def["level"])
	if _challenge == "precision":
		return precision.precision_percent() >= Campaign.mode_target(_challenge, world, level)
	if _challenge == "no_damage":
		return _damage_taken == 0
	if _challenge == "perfect_combo":
		return precision.best_combo >= Campaign.mode_target(_challenge, world, level)
	if _challenge == "speed":
		return _run_time <= float(Campaign.mode_target(_challenge, world, level))
	if _challenge == "legendary_only":
		return precision.non_legendary_kills == 0 and int(precision.counts[4]) >= 3
	return false


# -------------------------------------------------- puntos, monedas, hud --

func _combo_multiplier() -> float:
	return precision.multiplier()


func _point_multiplier() -> float:
	return _score_mult * Daylight.score_multiplier() * _combo_multiplier()


func _add_points(base: float) -> int:
	var gained: float = base * _point_multiplier()
	_points += gained
	return int(roundf(gained))


## Suma monedas a la partida. `boosted` aplica los multiplicadores.
func _add_coins(amount: float, boosted: bool = true) -> void:
	var total: float = amount
	if boosted:
		total *= _coin_mult
		if _double_coins:
			total *= 2.0
		if _gold_rush > 0.0:
			total *= 2.0
	_coins_f += total


func _score() -> int:
	return int(_points)


func _meters() -> int:
	return int(_distance_px / PIXELS_PER_METER)


func _update_hud() -> void:
	var ratio: float = clampf((_speed - BASE_SPEED) / (MAX_SPEED - BASE_SPEED), 0.0, 1.0)
	var pips: int = 1 + int(roundf(ratio * 9.0))
	hud.set_stats(_score(), int(_coins_f), _lives, _level + 1, pips, int(roundf(player.get_speed() / PIXELS_PER_METER)))

	var mult: float = _point_multiplier()
	var mult_text: String = ""
	if mult > 1.04:
		mult_text = "PUNTOS X%.1f" % mult
	var effects: PackedStringArray = PackedStringArray()
	if player.is_turbo():
		effects.append("TURBO")
	elif player.is_raging():
		effects.append("INVENCIBLE")
	if _soul_ready:
		effects.append("SOUL REAPER LISTO")
	if _gold_rush > 0.0:
		effects.append("FIEBRE DEL ORO %d" % int(ceilf(_gold_rush)))
	if _double_coins:
		effects.append("MONEDAS X2")
	if _magnet_boost > 0.0:
		effects.append("SUPERIMÁN %d" % int(ceilf(_magnet_boost)))
	hud.set_status(Daylight.phase_name(), Daylight.darkness() > 0.5, mult_text, player.shield_active, "\n".join(effects))

	for i in Catalog.POWERS.size():
		var power: Dictionary = Catalog.POWERS[i]
		if i == 2:
			# Soul Reaper se carga con acciones perfectas, no con el tiempo.
			hud.set_power(i, 1.0 - precision.soul, _soul_ready)
			continue
		var total: float = float(power["cooldown"]) * _cooldown_factor
		hud.set_power(i, float(_power_cooldowns[i]) / total, i == 0 and player.is_turbo())
	hud.set_combo(precision.perfects, precision.multiplier())
	if _debug:
		var danger: Vector2 = precision.next_danger(player.position, player.get_speed())
		var lines: PackedStringArray = PackedStringArray()
		lines.append("ULTIMA ACCION: %s  MARGEN %d MS" % [String(Timing.NAMES[precision.last_rating]) if precision.last_rating >= 2 else "NORMAL", int(precision.last_slack * 1000.0)])
		lines.append("VENTANAS MS: L %d  P %d  G %d" % [int(Timing.LEGENDARY_WINDOW * precision.window_scale * 1000.0), int(Timing.PERFECT_WINDOW * precision.window_scale * 1000.0), int(Timing.GOOD_WINDOW * precision.window_scale * 1000.0)])
		if danger.x == INF:
			lines.append("PELIGRO: NINGUNO")
		else:
			lines.append("PELIGRO A %d PX  %d MS" % [int(danger.x), int(danger.y * 1000.0)])
		lines.append("COMBO %d  X%.1f  VELOCIDAD %d" % [precision.perfects, precision.multiplier(), int(player.get_speed())])
		lines.append("DIFICULTAD %.2f" % (float(_def.get("difficulty", clampf(float(_level) / 9.0, 0.0, 1.0)))))
		hud.set_debug("\n".join(lines))
	if _boss != null and is_instance_valid(_boss):
		hud.set_boss(_boss.title(), float(_boss.hp) / float(maxi(_boss.max_hp, 1)))
	elif _level_mode and _goal_x != INF:
		hud.set_progress(clampf(player.position.x / _goal_x, 0.0, 1.0))


## Pequenas recompensas por distancia recorrida.
func _check_milestones() -> void:
	if _meters() < _next_milestone:
		return
	var reward: int = 10 + int(_next_milestone / float(MILESTONE_METERS)) * 2
	_add_coins(float(reward), false)
	hud.toast("%d M: +%d MONEDAS" % [_next_milestone, reward], Pal.YELLOW)
	Sfx.play("coin")
	_next_milestone += MILESTONE_METERS


# -------------------------------------------------------------- dificultad --

func _level_up() -> void:
	_level += 1
	_target_speed = minf(BASE_SPEED + SPEED_STEP * float(_level), MAX_SPEED)
	var subtitle: String = "¡MÁS RÁPIDO!"
	if NEW_HAZARDS.has(_level):
		subtitle = NEW_HAZARDS[_level]
	hud.show_banner("NIVEL %d" % (_level + 1), subtitle)
	_zoom_punch = 1.0
	Sfx.play("level")


## Eventos aleatorios que rompen la rutina de la partida.
func _start_random_event() -> void:
	var roll: int = randi() % 3
	if roll == 0:
		generator.start_event("coins")
		hud.show_banner("LLUVIA DE MONEDAS", "¡RECÓGELAS TODAS!")
	elif roll == 1:
		generator.start_event("horde")
		hud.show_banner("¡HORDA!", "ENEMIGOS EN CADENA: SUBE TU COMBO")
	else:
		_gold_rush = 12.0
		hud.show_banner("FIEBRE DEL ORO", "MONEDAS X2 DURANTE 12 SEGUNDOS")
	Sfx.play("level")


# ----------------------------------------------------------------- poderes --

func _use_power(index: int) -> void:
	if _state != State.PLAYING or index < 0 or index >= Catalog.POWERS.size():
		return
	if index == 2:
		_arm_soul_reaper()
		return
	if float(_power_cooldowns[index]) > 0.0:
		Sfx.play("error")
		return
	var power: Dictionary = Catalog.POWERS[index]
	_power_cooldowns[index] = float(power["cooldown"]) * _cooldown_factor
	GameData.add_stat("powers_used", 1)
	GameData.add_mission_progress("powers", 1)
	if index == 0:
		# Turbo: corre mas, cruza huecos y arrolla lo que encuentra.
		player.start_turbo(float(power["duration"]))
		Sfx.play("power_turbo")
		hud.flash(Pal.YELLOW, 0.25)
		_zoom_punch = 1.0
	elif index == 1:
		_shockwave()


## Soul Reaper: se activa cuando esta cargado (acciones perfectas) y hace
## letal el siguiente ataque PERFECT o LEGENDARY.
func _arm_soul_reaper() -> void:
	if _soul_ready:
		return
	if precision.soul < 1.0:
		Sfx.play("error")
		hud.toast("SOUL REAPER SE CARGA CON ACCIONES PERFECTAS", Pal.PURPLE)
		return
	precision.soul = 0.0
	_soul_ready = true
	GameData.add_stat("powers_used", 1)
	GameData.add_mission_progress("powers", 1)
	Sfx.play("soul")
	hud.flash(Pal.PURPLE, 0.35)
	hud.show_banner("SOUL REAPER", "TU PRÓXIMO ATAQUE PERFECTO SERÁ LETAL")


func _on_soul_strike(pos: Vector2) -> void:
	_soul_ready = false
	if _boss != null and is_instance_valid(_boss):
		_boss.damage(4)
	Sfx.play("soul")
	_shake = maxf(_shake, 0.9)
	_zoom_punch = 1.0
	hud.flash(Pal.PURPLE, 0.4)
	var gained: int = _add_points(150.0)
	Fx.burst(fx_root, pos + Vector2(0.0, -24.0), Pal.PURPLE, 34, 520.0, 0.7, 10.0, 300.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, pos + Vector2(0.0, -24.0), Pal.RED, 18, 380.0, 0.5, 7.0, 0.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, pos + Vector2(0.0, -24.0), Pal.WHITE, 12, 640.0, 0.3, 5.0, 0.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, pos + Vector2(0.0, -100.0), "SOUL REAPER +%d" % gained, Pal.PURPLE, 4.0)


## Golpe al punto debil del jefe: el dano depende del timing.
func _on_boss_struck() -> void:
	var rating: int = precision.consume_attack()
	var amount: int = 1
	if rating == Timing.Rating.LEGENDARY:
		amount = 3
	elif rating == Timing.Rating.PERFECT:
		amount = 2
	if rating >= Timing.Rating.GOOD:
		var label: String = "LAST SECOND" if rating == Timing.Rating.LEGENDARY else String(Timing.NAMES[rating])
		precision.register(rating, label, _boss.position)
	_boss.damage(amount)
	_add_points(60.0 * float(amount))
	Sfx.play("boss_hit")
	_shake = maxf(_shake, 0.6)
	Fx.burst(fx_root, _boss.position + Vector2(-80.0, 100.0), Pal.WHITE, 20, 420.0, 0.5, 8.0, 500.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, _boss.position + Vector2(0.0, -150.0), "-%d" % amount, Pal.RED, 5.0)


## Respuesta a una accion evaluada: puntos, texto, sonido y efectos propios
## de cada categoria.
func _on_rated(rating: int, label: String, _pos: Vector2) -> void:
	var bonus: float = float(Timing.BONUS[rating])
	if rating >= Timing.Rating.PERFECT:
		if precision.last_kind == "attack":
			bonus *= _perfect_mult
		elif precision.last_kind == "dodge" or label == "LAST SECOND":
			bonus *= _dodge_mult
		else:
			bonus *= _jump_mult
		if _combo_coins > 0:
			_add_coins(float(_combo_coins))
	var gained: int = _add_points(bonus)
	var where: Vector2 = player.position + Vector2(0.0, -34.0)
	var color: Color = Pal.LIME
	var size: float = 3.0
	if rating == Timing.Rating.LEGENDARY:
		color = Pal.ORANGE
		size = 5.0
		Sfx.play("legendary")
		_zoom_punch = 1.0
		Fx.ring(fx_root, where, Pal.ORANGE, 120.0)
		_shake = maxf(_shake, 0.45)
		hud.flash(Pal.WHITE, 0.22)
		Fx.burst(fx_root, where, Pal.ORANGE, 28, 460.0, 0.6, 9.0, 300.0, 180.0, Vector2.UP)
		Fx.burst(fx_root, where, Pal.WHITE, 14, 620.0, 0.3, 5.0, 0.0, 180.0, Vector2.UP)
	elif rating == Timing.Rating.PERFECT:
		color = Pal.YELLOW
		size = 4.0
		Sfx.play("perfect")
		_zoom_punch = maxf(_zoom_punch, 0.4)
		Fx.burst(fx_root, where, Pal.YELLOW, 14, 320.0, 0.45, 7.0, 300.0, 180.0, Vector2.UP)
	else:
		Sfx.play("good")
	if precision.last_kind == "dodge":
		Sfx.play("dodge")
		Fx.burst(fx_root, where, Pal.LIME, 6, 200.0, 0.3, 5.0, 300.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, player.position + Vector2(40.0, -120.0), "%s +%d" % [label, gained], color, size)


## Onda expansiva: elimina enemigos y obstaculos cercanos.
func _shockwave() -> void:
	Sfx.play("power_wave")
	hud.flash(Pal.CYAN, 0.35)
	_shake = maxf(_shake, 0.8)
	player.flourish()
	var origin: Vector2 = player.position + Vector2(0.0, -30.0)
	Fx.burst(fx_root, origin, Pal.CYAN, 40, 900.0, 0.5, 9.0, 0.0, 180.0, Vector2.RIGHT)
	Fx.burst(fx_root, origin, Pal.WHITE, 20, 600.0, 0.4, 6.0, 0.0, 180.0, Vector2.RIGHT)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not _in_wave_range(enemy.global_position.x):
			continue
		var kind: int = int(enemy.get("kind"))
		var pos: Vector2 = enemy.global_position
		var result: int = -1
		var guard: int = 0
		while result < 0 and guard < 4:
			result = int(enemy.call("hit"))
			guard += 1
		if result > 0:
			_on_enemy_killed(result, pos, kind)
	for node in get_tree().get_nodes_in_group("hazards"):
		var hazard: Node2D = node as Node2D
		if hazard == null or not _in_wave_range(hazard.global_position.x):
			continue
		var center: Vector2 = hazard.call("get_center")
		if bool(hazard.call("destroy")):
			_on_hazard_smashed(center)


func _in_wave_range(x: float) -> bool:
	var dx: float = x - player.position.x
	return dx > -200.0 and dx < 820.0


# ----------------------------------------------------------------- senales --

func _on_player_jumped(pos: Vector2) -> void:
	Sfx.play("jump", randf_range(0.95, 1.05))
	if not player.is_raging():
		precision.on_jump(pos, player.get_speed())
	Fx.burst(fx_root, pos, Color(Pal.WHITE, 0.8), 6, 130.0, 0.3, 5.0, 300.0, 70.0, Vector2.UP)


func _on_player_landed(pos: Vector2) -> void:
	Sfx.play("land")
	if _state == State.PLAYING:
		precision.on_land(pos, player.get_speed())
	Fx.burst(fx_root, pos + Vector2(-10.0, 0.0), Color(Pal.WHITE, 0.7), 4, 120.0, 0.25, 5.0, 300.0, 40.0, Vector2(-1.0, -0.5))
	Fx.burst(fx_root, pos + Vector2(10.0, 0.0), Color(Pal.WHITE, 0.7), 4, 120.0, 0.25, 5.0, 300.0, 40.0, Vector2(1.0, -0.5))


func _on_player_attacked(pos: Vector2) -> void:
	Sfx.play("attack", randf_range(0.92, 1.08))
	var rating: int = precision.on_attack(pos, player.get_speed())
	if _soul_ready and rating >= Timing.Rating.PERFECT:
		player.soul_armed = true
	# El tajo crece con la precision del ataque.
	player.slash_power = clampi(rating - 1, 0, 3)
	if rating >= Timing.Rating.PERFECT:
		Sfx.play("slash_heavy")
	Fx.burst(fx_root, pos + Vector2(60.0, -34.0), Pal.CYAN, 6, 260.0, 0.22, 5.0, 0.0, 35.0, Vector2.RIGHT)


func _on_pickup_collected(kind: int, value: int, pos: Vector2) -> void:
	if kind != Coin.Kind.HEART and kind != Coin.Kind.STAR:
		_picked += 1
	if kind == Coin.Kind.DIAMOND:
		_diamond_found = true
		Sfx.play("diamond")
		_zoom_punch = 1.0
		hud.show_banner("¡DIAMANTE OCULTO!", "RECOMPENSA DE LA RUTA ARRIESGADA")
		Fx.burst(fx_root, pos, Pal.WHITE, 30, 420.0, 0.7, 8.0, 300.0, 180.0, Vector2.UP)
		Fx.ring(fx_root, pos, Pal.CYAN, 110.0)
	elif kind == Coin.Kind.COIN:
		_add_coins(1.0)
		_add_points(float(value))
		GameData.add_mission_progress("coins", 1)
		Sfx.play("coin", randf_range(0.97, 1.06))
		Fx.burst(fx_root, pos, Pal.YELLOW, 8, 200.0, 0.4, 5.0, 500.0, 180.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -26.0), "+%d" % value, Pal.YELLOW, 3.0)
	elif kind == Coin.Kind.GEM or kind == Coin.Kind.RUBY:
		var is_gem: bool = kind == Coin.Kind.GEM
		_add_coins(5.0 if is_gem else 3.0)
		var gained: int = _add_points(float(value))
		GameData.add_mission_progress("coins", 5 if is_gem else 3)
		if is_gem:
			_gems += 1
			GameData.add_mission_progress("gems", 1)
		Sfx.play("gem")
		var color: Color = Pal.CYAN if is_gem else Pal.RED
		Fx.burst(fx_root, pos, color, 16, 280.0, 0.5, 7.0, 500.0, 180.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -30.0), "+%d" % gained, color, 4.0)
	elif kind == Coin.Kind.HEART:
		Sfx.play("heart")
		if _lives < _max_lives:
			_lives += 1
			Fx.popup(fx_root, pos + Vector2(0.0, -30.0), "+1 VIDA", Pal.RED, 4.0)
		else:
			Fx.popup(fx_root, pos + Vector2(0.0, -30.0), "+%d" % _add_points(50.0), Pal.RED, 4.0)
		Fx.burst(fx_root, pos, Pal.RED, 16, 260.0, 0.5, 7.0, 300.0, 180.0, Vector2.UP)
	elif kind == Coin.Kind.STAR:
		Sfx.play("power_turbo")
		player.start_rage(8.0)
		_magnet_boost = maxf(_magnet_boost, 8.0)
		hud.show_banner("¡ESTRELLA!", "INVENCIBLE DURANTE 8 SEGUNDOS")
		hud.flash(Pal.YELLOW, 0.3)
		Fx.burst(fx_root, pos, Pal.YELLOW, 24, 380.0, 0.6, 8.0, 300.0, 180.0, Vector2.UP)
	else:
		# Cofre del tesoro.
		_add_coins(25.0)
		GameData.add_mission_progress("coins", 25)
		Sfx.play("buy")
		_zoom_punch = 0.6
		Fx.burst(fx_root, pos + Vector2(0.0, -20.0), Pal.YELLOW, 30, 420.0, 0.7, 8.0, 900.0, 70.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -60.0), "¡COFRE! +25", Pal.YELLOW, 4.0)


func _on_enemy_killed(points: int, pos: Vector2, kind: int) -> void:
	_kills += 1
	# Si el golpe venia de un ataque bien medido, se premia su categoria.
	var rating: int = precision.consume_attack()
	if rating >= Timing.Rating.GOOD:
		var label: String = "LAST SECOND" if rating == Timing.Rating.LEGENDARY else String(Timing.NAMES[rating])
		precision.register(rating, label, pos)
	if rating != Timing.Rating.LEGENDARY and kind != Enemy.Kind.ORB:
		precision.non_legendary_kills += 1
	# Impacto con los colores de la espada equipada; mayor cuanto mejor el golpe.
	var sword: Dictionary = GameData.equipped_item("sword")
	var slash: Array = sword["slash"]
	var impact: Color = Color(String(slash[0]))
	Fx.burst(fx_root, pos + Vector2(0.0, -24.0), impact, 10 + maxi(rating - 1, 0) * 10, 300.0 + float(rating) * 60.0, 0.45, 7.0, 200.0, 180.0, Vector2.UP)
	if rating >= Timing.Rating.PERFECT:
		Fx.ring(fx_root, pos + Vector2(0.0, -24.0), Color(String(slash[1])), 60.0 + float(rating) * 15.0)
	# Proyectil de jefe devuelto con un golpe perfecto: contraataque.
	if kind == Enemy.Kind.ORB and _boss != null and is_instance_valid(_boss) and rating >= Timing.Rating.PERFECT:
		_boss.reflect()
		Fx.popup(fx_root, _boss.position + Vector2(0.0, -150.0), "¡CONTRAATAQUE! -1", Pal.LIME, 4.0)
	var gained: int = _add_points(float(points))
	if _bounty > 0:
		_add_coins(float(_bounty))
	GameData.add_mission_progress("kills", 1)
	_shake = maxf(_shake, 0.35)
	Sfx.play("kill")
	var color: Color = _enemy_colors[clampi(kind, 0, _enemy_colors.size() - 1)]
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), color, 18, 340.0, 0.55, 8.0, 700.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), Pal.WHITE, 10, 260.0, 0.3, 6.0, 0.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, pos + Vector2(0.0, -60.0), "+%d" % gained, Pal.WHITE, 4.0)


## Golpe que no mata (escudo del escudero roto).
func _on_enemy_hit(pos: Vector2) -> void:
	Sfx.play("hit")
	_shake = maxf(_shake, 0.25)
	Fx.burst(fx_root, pos + Vector2(-10.0, -30.0), Pal.SKY, 12, 320.0, 0.4, 6.0, 600.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, pos + Vector2(0.0, -70.0), "¡ESCUDO ROTO!", Pal.SKY, 2.0)


func _on_hazard_smashed(pos: Vector2) -> void:
	_add_points(15.0)
	Sfx.play("hit")
	_shake = maxf(_shake, 0.3)
	Fx.burst(fx_root, pos, Pal.SILVER, 14, 360.0, 0.5, 8.0, 800.0, 180.0, Vector2.UP)


func _on_shield_broken() -> void:
	Sfx.play("shield")
	_shield_timer = 0.0
	_shake = maxf(_shake, 0.5)
	hud.flash(Pal.CYAN, 0.3)
	hud.toast("EL ESCUDO TE HA SALVADO", Pal.CYAN)
	Fx.burst(fx_root, player.position + Vector2(0.0, -30.0), Pal.CYAN, 20, 340.0, 0.5, 7.0, 400.0, 180.0, Vector2.UP)


func _on_player_damaged() -> void:
	_lose_life(false)


func _on_player_fell() -> void:
	_lose_life(true)


func _lose_life(fell_in_hole: bool) -> void:
	if _state != State.PLAYING:
		return
	_lives -= 1
	_damage_taken += 1
	precision.on_damage()
	# Modo "Sin dano": el primer golpe termina el intento.
	if _challenge == "no_damage":
		_lives = 0
		hud.show_banner("RETO FALLADO", "MODO SIN DAÑO")
	_shake = 1.0
	Sfx.play("hurt")
	hud.flash(Pal.RED, 0.45)
	player.play_hurt()
	if not fell_in_hole:
		Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.RED, 14, 300.0, 0.5, 7.0, 700.0, 180.0, Vector2.UP)
	if _lives <= 0:
		# Objeto "Revivir": se gasta solo, una vez por partida.
		if _challenge != "no_damage" and not _revive_used and GameData.use_consumable("revive"):
			_revive_used = true
			_lives = 2
			if fell_in_hole:
				_respawn_player()
			player.start_rage(3.0)
			Sfx.play("revive")
			hud.show_banner("¡HAS REVIVIDO!", "OBJETO REVIVIR GASTADO")
			hud.flash(Pal.WHITE, 0.6)
			return
		_game_over()
		return
	if fell_in_hole:
		_respawn_player()
		player.start_invulnerability(2.2 + _recovery)
	else:
		player.start_invulnerability(1.6 + _recovery)


## Reaparece al otro lado del hueco.
func _respawn_player() -> void:
	var x: float = generator.get_respawn_x(player.position.x)
	player.respawn(Vector2(x, GROUND_Y - 150.0))
	_last_player_x = player.position.x
	_update_camera()


## Guarda en el perfil los resultados de la partida (una sola vez).
func _bank_run() -> bool:
	if _banked:
		return false
	_banked = true
	GameData.add_mission_progress("distance", _meters())
	if _diamond_found and _level_mode:
		GameData.claim_hidden_diamond(int(_def["world"]), int(_def["level"]))
	GameData.stats["best_combo"] = maxi(int(GameData.stats.get("best_combo", 0)), precision.best_combo)
	GameData.add_stat("perfects", int(precision.counts[3]))
	GameData.add_stat("legendaries", int(precision.counts[4]))
	return GameData.finish_run(_score(), int(_coins_f), _kills, _gems, _meters())


func _game_over() -> void:
	_state = State.DYING
	_lives = 0
	hud.can_pause = false
	player.die()
	Sfx.set_intensity(0)
	Sfx.play("gameover")
	Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.WHITE, 24, 420.0, 0.7, 8.0, 600.0, 180.0, Vector2.UP)
	_update_hud()
	await get_tree().create_timer(1.3, true, false, true).timeout
	if not is_inside_tree():
		return
	Engine.time_scale = 1.0
	_state = State.GAME_OVER
	var final_score: int = _score()
	var is_record: bool = _bank_run()
	Sfx.play_music("gameover")
	hud.show_game_over(final_score, GameData.high_score, is_record, int(_coins_f), _kills, _meters())


## Meta alcanzada: calcula rango y estrellas, entrega recompensas y
## muestra la pantalla de victoria.
func _level_complete() -> void:
	_state = State.GAME_OVER
	hud.can_pause = false
	player.active = false
	var info: Dictionary = {
		"damage": _damage_taken, "kills": _kills, "enemies": generator.enemies_spawned,
		"picked": _picked, "pickups": generator.pickups_spawned, "coins": int(_coins_f),
		"time": _run_time, "par": float(_def.get("par_time", 0)) / 0.93,
	}
	var grade: float = precision.grade(info)
	var rank: int = Timing.rank_for(grade)
	# Estrellas: 1 por llegar, 2 con rango B o mejor, 3 con rango A o mejor
	# y como mucho un golpe recibido.
	var stars: int = 1
	if rank >= 2:
		stars += 1
	if rank >= 3 and _damage_taken <= 1:
		stars += 1
	var world: int = int(_def["world"])
	var level: int = int(_def["level"])
	var final_score: int = _score()
	var rewards: Dictionary = GameData.complete_level(world, level, stars, rank, final_score)
	# Retos opcionales del nivel.
	var challenge_list: Array = Campaign.challenges(world, level)
	var challenge_texts: Array = []
	var challenge_results: Array = []
	for item in challenge_list:
		var challenge: Dictionary = item
		challenge_texts.append(String(challenge["text"]))
		challenge_results.append(precision.challenge_done(challenge, info))
	var extra: Dictionary = GameData.complete_challenges(world, level, challenge_results)
	# Modo de dominio.
	var mode_line: String = ""
	if _challenge != "normal":
		if _challenge_met():
			var paid: Dictionary = GameData.complete_mode(world, level, _challenge)
			extra["coins"] = int(extra["coins"]) + int(paid["coins"])
			extra["diamonds"] = int(extra["diamonds"]) + int(paid["diamonds"])
			mode_line = "MODO %s SUPERADO" % _challenge_name()
		else:
			mode_line = "MODO %s NO SUPERADO" % _challenge_name()
	var items: Array = rewards.get("items", [])
	if not items.is_empty():
		Sfx.play("unlock")
		hud.toast("DESBLOQUEADO: " + ", ".join(PackedStringArray(items)), Pal.CYAN)
	_bank_run()
	GameData.check_achievements()
	Sfx.play("victory")
	Sfx.play_music("victory")
	Sfx.set_intensity(0)
	hud.flash(Pal.WHITE, 0.4)
	Fx.burst(fx_root, player.position + Vector2(0.0, -40.0), Pal.YELLOW, 40, 520.0, 0.9, 9.0, 600.0, 180.0, Vector2.UP)
	var has_next: bool = level < Campaign.LEVELS_PER_WORLD - 1 or world < Campaign.world_count() - 1
	hud.show_victory({
		"name": String(_def["name"]), "rank": rank, "stars": stars, "score": final_score,
		"perfect": int(precision.counts[3]), "legendary": int(precision.counts[4]),
		"combo": precision.best_combo, "damage": _damage_taken,
		"coins": int(_coins_f) + int(rewards["coins"]) + int(extra["coins"]), "diamonds": int(rewards["diamonds"]) + int(extra["diamonds"]),
		"challenges": challenge_texts, "results": challenge_results, "mode": mode_line,
		"has_next": has_next,
	})


## Pasa al siguiente nivel de la campana (o al primero del mundo siguiente).
func _next_level() -> void:
	var world: int = int(_def.get("world", 0))
	var level: int = int(_def.get("level", 0)) + 1
	if level >= Campaign.LEVELS_PER_WORLD:
		level = 0
		world += 1
	if world >= Campaign.world_count():
		_go_to_menu()
		return
	GameData.run = {"mode": "level", "world": world, "level": level}
	Transition.reload()


func _restart() -> void:
	_bank_run()
	Transition.reload()


func _go_to_menu() -> void:
	_bank_run()
	Transition.change_scene(MENU_SCENE)
