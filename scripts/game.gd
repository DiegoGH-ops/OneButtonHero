extends Node2D
## Escena principal de la partida. Coordina al heroe, el generador de nivel,
## la camara, el ciclo de dia y noche, la dificultad, la puntuacion, los
## buffs (cosmeticos, power-ups de tienda y arbol de mejoras) y la interfaz.
##
## Reglas: UN SOLO GOLPE MATA. No hay vidas ni poderes activables; todo se
## juega con un unico boton (saltar, salto corto/largo, atacar, pulsacion
## rapida, pisoton y trampolin).

const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Background = preload("res://scripts/background.gd")
const GroundRenderer = preload("res://scripts/ground_renderer.gd")
const LevelGenerator = preload("res://scripts/level_generator.gd")
const Lights = preload("res://scripts/lights.gd")
const Coin = preload("res://scripts/coin.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Precision = preload("res://scripts/precision.gd")
const Timing = preload("res://scripts/timing.gd")
const Boss = preload("res://scripts/boss.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Bestiary = preload("res://scripts/bestiary.gd")
const Creature = preload("res://scripts/creature.gd")
const Buffs = preload("res://scripts/buffs.gd")
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
const CAMERA_LEAD := 320.0
const PIXELS_PER_METER := 48.0
## Segundos que dura un ciclo completo de dia y noche.
const DAY_LENGTH := 110.0
## Cada cuantos metros hay una pequena recompensa.
const MILESTONE_METERS := 250
const MENU_SCENE := "res://scenes/main_menu.tscn"
## Musica de cada mundo de la campana.
const WORLD_TRACKS := ["forest", "inferno", "crystal", "frost", "desert"]
## Premio por alcanzar estos combos perfectos en una partida.
const COMBO_REWARDS := [10, 20, 30, 50]

const NEW_HAZARDS := {
	1: "NUEVO: HUECOS, LLAMAS Y SALTOS ENCADENADOS",
	2: "NUEVO: TECHOS BAJOS Y PLATAFORMAS",
	3: "NUEVO: BARRICADAS Y ESCUDEROS",
	4: "NUEVO: TRAMPOLINES Y TRAMPAS",
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
var _shake: float = 0.0
var _zoom_punch: float = 0.0
var _next_milestone: int = MILESTONE_METERS
var _banked: bool = false
var _enemy_colors: Array = [Pal.GREEN, Pal.RED, Pal.PURPLE, Pal.STEEL, Pal.WHITE]
## Veces que algo te habria matado (solo posible con la Pluma de Fenix).
var _damage_taken: int = 0
var _phoenix_used: bool = false
## Modo campana: nivel con meta, velocidad propia y recorrido fijo.
var _level_mode: bool = false
## Partida de prueba del panel de administrador: no guarda nada.
var _test_mode: bool = false
var _def: Dictionary = {}
var _goal_x: float = INF
var precision: Precision
## Jefe final (solo en el nivel 20 de cada mundo).
var _boss: Boss
## Herramientas de depuracion del timing (tecla F3).
var _debug: bool = false
## Modo de dominio elegido en el mapa ("normal", "precision"...).
var _challenge: String = "normal"
var _run_time: float = 0.0
var _picked: int = 0
var _diamond_found: bool = false
var _combo_reward_index: int = 0
var _jump_chain: int = 0
var _step_timer: float = 0.0
var _storm_timer: float = 20.0
var _storm: float = 0.0
var _death_time: float = 0.0
var _endless_creatures: int = 0
## Multiplicador de las monedas de esta partida (economia por mundos).
var _coin_factor: float = 1.0
## Tiempo bala (mejora del arbol): segundos reales que quedan.
var _slowmo: float = 0.0
## Luz dinamica del heroe (PointLight2D): alumbra el mundo a su alrededor
## de noche y en los mundos oscuros.
var _hero_light: PointLight2D

# Dia y noche y eventos.
var _phase: int = -1
var _was_night: bool = false
var _event_timer: float = 30.0
var _gold_rush: float = 0.0

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
	Daylight.dodges = 0
	Buffs.invalidate()
	Daylight.warn_factor = Buffs.factor("warn")
	Daylight.mash_factor = Buffs.factor("mash")
	Daylight.counter_factor = Buffs.factor("counter")
	Daylight.magnet_radius = Buffs.stat("magnet")
	Daylight.projectile_factor = clampf(1.0 - Buffs.stat("projectile_slow") / 100.0, 0.35, 1.0)
	Daylight.chaser_factor = clampf(1.0 - Buffs.stat("chaser_slow") / 100.0, 0.5, 1.0)
	Daylight.brute_factor = clampf(1.0 - Buffs.stat("brute_slow") / 100.0, 0.5, 1.0)
	Daylight.shield_break = Buffs.stat("shield_break")
	Daylight.no_split = Buffs.has("no_split")
	Daylight.hole_sight = Buffs.has("hole_sight")
	Daylight.attack_rating = 0
	Daylight.reflected = 0
	Daylight.invincible = false
	generator.setup(spans_root, objects_root)
	precision = Precision.new()
	add_child(precision)
	precision.rated.connect(_on_rated)
	precision.bonus = Vector3(Buffs.factor("legend"), Buffs.factor("perfect"), Buffs.factor("good"))
	precision.land_bonus = Buffs.factor("land")
	precision.methodical = Buffs.has("methodical")
	precision.perfects = int(Buffs.stat("combo_start"))
	generator.gem_bonus = Buffs.stat("gems") / 100.0
	if Buffs.has("diamond_sense"):
		generator.diamond_chance = 1.0
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
		# Modo Velocidad: el nivel entero un 15% mas rapido.
		if _challenge == "speed" and not bool(_def["final"]):
			_speed *= 1.15
			_target_speed *= 1.15
		generator.diamond_available = not GameData.hidden_diamond_taken(int(_def["world"]), int(_def["level"]))
		if bool(_def["final"]):
			# Nivel de jefe: no hay meta; se gana derrotandolo.
			_goal_x = INF
			_boss = Boss.new()
			objects_root.add_child(_boss)
			_boss.setup(int(_def["world"]), generator)
			_boss.struck.connect(_on_boss_struck)
			_boss.defeated.connect(_level_complete)
		_coin_factor = GameData.run_coin_factor(int(_def["world"]))
	elif String(GameData.run.get("mode", "endless")) == "test":
		_setup_test()
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
	player.stomped.connect(_on_stomped)
	player.bounced.connect(_on_bounced)
	player.damaged.connect(_on_player_damaged)
	player.fell.connect(_on_player_fell)
	_last_player_x = player.position.x

	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_go_to_menu)
	hud.next_requested.connect(_next_level)
	if _level_mode and _boss == null:
		hud.set_level_name("NIVEL " + String(_def["name"]))
	hud.set_max_lives(0)
	if _challenge != "normal":
		hud.toast("MODO: " + _challenge_name(), Pal.ORANGE)
	hud.set_high_score(GameData.high_score)

	_announce_new_content()
	if Buffs.has("phoenix"):
		hud.toast("PLUMA DE FÉNIX ACTIVA", Pal.ORANGE)
	if not GameData.trial.is_empty():
		hud.toast("ASPECTO DE PRUEBA (ADMIN) ACTIVO", Pal.ORANGE)
	if _level_mode and not is_equal_approx(_coin_factor, 1.0):
		var conquered: bool = int(_def["world"]) < GameData.highest_world()
		hud.toast(("MUNDO SUPERADO: MONEDAS X%.1f" if conquered else "MONEDAS DEL MUNDO X%.1f") % _coin_factor, Pal.YELLOW)
	_create_hero_light()
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


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		_debug = not _debug
		hud.set_debug("")
		return
	if event.is_action_pressed(GameData.ACTION):
		if _state == State.PLAYING:
			player.press()
		elif Buffs.has("quick_retry") and _state != State.PLAYING and _death_time > 0.35 and not _level_mode_won():
			# Mejora "Reintento rapido": pulsar tras morir reinicia al instante.
			_restart()


func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.05)
	# Tiempo bala: se cuenta en tiempo real y devuelve el ritmo normal.
	if _slowmo > 0.0:
		_slowmo -= real_delta
		if _slowmo <= 0.0:
			Engine.time_scale = 1.0
	if _state == State.PLAYING:
		if _level_mode or _test_mode:
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

		_update_timers(delta)
		_check_milestones()
		if not _level_mode and not _test_mode:
			generator.set_endless_creatures(_endless_creatures)
		_run_time += delta
		_update_feel(delta)
		_check_dodges()
		player.hawk_x = precision.perfect_jump_x(player.position, player.get_speed()) if Buffs.has("hawk") else INF
		generator.update(player.position.x, _speed, _level, delta)
		_update_camera()
		Daylight.time = fposmod(Daylight.time + delta / DAY_LENGTH, 1.0)
		_update_daylight(false)
		precision.update(player.position, delta)
		if _level_mode and player.position.x >= _goal_x:
			_level_complete()
	else:
		_death_time += delta

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


## Temporizadores de efectos, tormentas y eventos.
func _update_timers(delta: float) -> void:
	_gold_rush = maxf(_gold_rush - delta, 0.0)
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
		haze *= clampf(1.0 - Buffs.stat("storm_clear") / 100.0, 0.1, 1.0)
		hud.set_haze(Color(storm_hex), haze)
	_event_timer -= delta
	if _event_timer <= 0.0 and not _level_mode and not _test_mode:
		_event_timer = randf_range(38.0, 55.0)
		_start_random_event()


# ---------------------------------------------------------- dia y noche --

func _update_daylight(first: bool) -> void:
	var ambient: Color = Daylight.ambient()
	world.modulate = ambient
	player.modulate = ambient.lerp(Color(1.0, 1.0, 1.0), 0.4)
	if _hero_light != null:
		var dark: float = Daylight.darkness()
		var style: String = String(Daylight.theme.get("style", "forest"))
		var base: float = 0.12 if style == "inferno" or style == "crystal" else 0.0
		_hero_light.energy = base + 0.55 * dark
		_hero_light.visible = _hero_light.energy > 0.02
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
	if _level_mode or _test_mode:
		return
	if phase == Daylight.Phase.NIGHT:
		_was_night = true
		hud.show_banner("CAE LA NOCHE", "PUNTOS X1.5 - CUIDADO CON LOS ESPECTROS")
	elif phase == Daylight.Phase.SUNSET:
		hud.toast("ATARDECER", Pal.ORANGE)
	elif phase == Daylight.Phase.DAWN and previous == Daylight.Phase.NIGHT:
		var night_prize: float = 30.0 * Buffs.factor("night_coins")
		hud.show_banner("AMANECE", "HAS SOBREVIVIDO A LA NOCHE: +%d MONEDAS" % int(night_prize * _coin_factor))
		if _was_night:
			_add_coins(night_prize, false)
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
		var combo_prize: float = float(target) * Buffs.factor("combo_reward")
		_add_coins(combo_prize, false)
		hud.toast("COMBO %d: +%d MONEDAS" % [target, int(combo_prize * _coin_factor)], Pal.ORANGE)


func _challenge_name() -> String:
	for item in Campaign.MODES:
		var mode: Dictionary = item
		if String(mode["id"]) == _challenge:
			return String(mode["name"])
	return ""


## Comprueba al final si se cumplio el modo de dominio elegido.
func _challenge_met() -> bool:
	var world_index: int = int(_def["world"])
	var level: int = int(_def["level"])
	if _challenge == "precision":
		return precision.precision_percent() >= Campaign.mode_target(_challenge, world_index, level)
	if _challenge == "no_damage":
		return _damage_taken == 0 and int(precision.counts[1]) == 0
	if _challenge == "perfect_combo":
		return precision.best_combo >= Campaign.mode_target(_challenge, world_index, level)
	if _challenge == "speed":
		if bool(_def["final"]):
			return _run_time <= float(Campaign.mode_target(_challenge, world_index, level))
		return true
	if _challenge == "legendary_only":
		return precision.non_legendary_kills == 0 and int(precision.counts[4]) >= 3
	return false


# -------------------------------------------------- puntos, monedas, hud --

## Multiplicador de valentia (acciones perfectas seguidas), ampliado por el
## buff "puntos de combo".
func _combo_multiplier() -> float:
	var base: float = precision.multiplier()
	return 1.0 + (base - 1.0) * Buffs.factor("combo_points")


func _point_multiplier() -> float:
	return Buffs.factor("points") * Daylight.score_multiplier() * _combo_multiplier()


func _add_points(base: float) -> int:
	var gained: float = base * _point_multiplier()
	_points += gained
	return int(roundf(gained))


## Suma monedas a la partida. `boosted` aplica los multiplicadores.
func _add_coins(amount: float, boosted: bool = true) -> void:
	var total: float = amount * _coin_factor
	if boosted:
		total *= Buffs.factor("coins")
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
	hud.set_stats(_score(), int(_coins_f), 0, _level + 1, pips, int(roundf(player.get_speed() / PIXELS_PER_METER)))

	var mult: float = _point_multiplier()
	var mult_text: String = ""
	if mult > 1.04:
		mult_text = "PUNTOS X%.1f" % mult
	var effects: PackedStringArray = PackedStringArray()
	if Buffs.has("phoenix"):
		effects.append("FÉNIX USADO" if _phoenix_used else "FÉNIX LISTO")
	if _gold_rush > 0.0:
		effects.append("FIEBRE DEL ORO %d" % int(ceilf(_gold_rush)))
	if _jump_chain > 0:
		effects.append("CADENA %d/3" % (_jump_chain % 3))
	hud.set_status(Daylight.phase_name(), Daylight.darkness() > 0.5, mult_text, "\n".join(effects))
	hud.set_combo(precision.perfects, precision.multiplier())
	if _debug:
		var danger: Vector2 = precision.next_danger(player.position, player.get_speed())
		var lines: PackedStringArray = PackedStringArray()
		lines.append("ULTIMA ACCION: %s  MARGEN %d MS" % [String(Timing.NAMES[precision.last_rating]) if precision.last_rating >= 2 else "NORMAL", int(precision.last_slack * 1000.0)])
		lines.append("VENTANAS MS: L %d  P %d  G %d" % [int(Timing.LEGENDARY_WINDOW * precision.window_scale * precision.bonus.x * 1000.0), int(Timing.PERFECT_WINDOW * precision.window_scale * precision.bonus.y * 1000.0), int(Timing.GOOD_WINDOW * precision.window_scale * precision.bonus.z * 1000.0)])
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
	var reward: float = (10.0 + float(int(_next_milestone / float(MILESTONE_METERS)) * 2)) * Buffs.factor("milestone")
	_add_coins(reward, false)
	hud.toast("%d M: +%d MONEDAS" % [_next_milestone, int(reward * _coin_factor)], Pal.YELLOW)
	Sfx.play("coin")
	_next_milestone += MILESTONE_METERS


# -------------------------------------------------------------- dificultad --

func _level_up() -> void:
	_level += 1
	_target_speed = minf(BASE_SPEED + SPEED_STEP * float(_level), MAX_SPEED)
	var subtitle: String = "¡MÁS RÁPIDO!"
	if NEW_HAZARDS.has(_level):
		subtitle = NEW_HAZARDS[_level]
	# Modo infinito: cada nivel suma una criatura del bosque.
	if _endless_creatures < Bestiary.INTRO_LEVELS.size() - 1:
		_endless_creatures += 1
		var data: Array = Bestiary.entry(0, _endless_creatures)
		subtitle = "NUEVO ENEMIGO: " + String(data[0])
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
		_gold_rush = 12.0 + Buffs.stat("rush")
		hud.show_banner("FIEBRE DEL ORO", "MONEDAS X2 DURANTE %d SEGUNDOS" % int(_gold_rush))
	Sfx.play("level")


# ----------------------------------------------------------------- poderes --

## Golpe al punto debil del jefe: el dano depende del timing.
func _on_boss_struck() -> void:
	var rating: int = precision.consume_attack()
	var amount: int = 1
	if rating == Timing.Rating.LEGENDARY:
		amount = 3
	elif rating == Timing.Rating.PERFECT:
		amount = 2
	# Cazador de jefes: probabilidad de un punto de dano extra.
	if randf() * 100.0 < Buffs.stat("boss_damage"):
		amount += 1
		Fx.popup(fx_root, _boss.position + Vector2(40.0, -190.0), "¡CRÍTICO!", Pal.ORANGE, 3.0)
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
## de cada categoria. Aplica buffs y especializaciones.
func _on_rated(rating: int, label: String, _pos: Vector2) -> void:
	var kind: String = precision.last_kind
	var bonus: float = float(Timing.BONUS[rating])
	var is_jump: bool = kind == "jump" or kind == "dodge" or kind == "land"
	if rating >= Timing.Rating.PERFECT:
		if kind == "attack":
			bonus *= Buffs.factor("attack_points")
		else:
			bonus *= Buffs.factor("jump_points")
		if kind == "land":
			bonus *= Buffs.factor("land_points")
		elif kind == "dodge":
			bonus *= Buffs.factor("dodge_points")
	if rating == Timing.Rating.LEGENDARY:
		bonus *= Buffs.factor("legend_points")
		# Tiempo bala: un instante a camara lenta tras cada LEGENDARY.
		if Buffs.stat("slowmo") > 0.0 and _state == State.PLAYING:
			_slowmo = 0.10 + 0.08 * Buffs.stat("slowmo")
			Engine.time_scale = 0.55
		if Buffs.stat("combo_coins") > 0.0:
			_add_coins(Buffs.stat("combo_coins"))
	# Especializaciones del arbol (excluyentes entre si).
	if Buffs.has("daredevil"):
		if rating == Timing.Rating.LEGENDARY:
			bonus *= 2.0
		elif rating == Timing.Rating.GOOD:
			bonus = 0.0
	if Buffs.has("methodical") and rating == Timing.Rating.LEGENDARY:
		bonus *= 0.5
	if is_jump and rating >= Timing.Rating.PERFECT:
		if Buffs.has("zen"):
			bonus *= 2.0
		if Buffs.has("fury"):
			bonus *= 0.5
	var gained: int = _add_points(bonus)
	var where: Vector2 = player.position + Vector2(0.0, -34.0)
	var color: Color = Pal.LIME
	var size: float = 3.0
	if rating == Timing.Rating.LEGENDARY:
		color = Pal.ORANGE
		size = 5.0
		Sfx.play("legendary")
		lights.flash(Pal.ORANGE, 0.35, 0.3)
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
		Fx.burst(fx_root, where, Pal.LIME, 6, 200.0, 0.3, 5.0, 300.0, 180.0, Vector2.UP)
	if kind == "dodge":
		Sfx.play("dodge")
	Fx.popup(fx_root, player.position + Vector2(40.0, -120.0), "%s +%d" % [label, gained], color, size)
	# Saltos encadenados: tres saltos perfectos seguidos dan premio.
	if is_jump:
		if rating >= Timing.Rating.PERFECT:
			_jump_chain += 1
			if _jump_chain % 3 == 0:
				var chain_points: int = _add_points(120.0 * Buffs.factor("chain"))
				Sfx.play("combo")
				Fx.ring(fx_root, where, Pal.CYAN, 90.0)
				hud.toast("¡CADENA PERFECTA! +%d" % chain_points, Pal.CYAN)
		else:
			_jump_chain = 0


# ----------------------------------------------------------------- senales --

func _on_player_jumped(pos: Vector2) -> void:
	Sfx.play("jump", randf_range(0.95, 1.05))
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
	Daylight.attack_rating = rating
	# El tajo crece con la precision del ataque.
	player.slash_power = clampi(rating - 1, 0, 3)
	if rating >= Timing.Rating.PERFECT:
		Sfx.play("slash_heavy")
	Fx.burst(fx_root, pos + Vector2(60.0, -34.0), Pal.CYAN, 6, 260.0, 0.22, 5.0, 0.0, 35.0, Vector2.RIGHT)


func _on_pickup_collected(kind: int, value: int, pos: Vector2) -> void:
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
		_add_coins((5.0 if is_gem else 3.0) + Buffs.stat("gem_coins"))
		var gained: int = _add_points(float(value))
		GameData.add_mission_progress("coins", 5 if is_gem else 3)
		if is_gem:
			_gems += 1
			GameData.add_mission_progress("gems", 1)
		Sfx.play("gem")
		var color: Color = Pal.CYAN if is_gem else Pal.RED
		Fx.burst(fx_root, pos, color, 16, 280.0, 0.5, 7.0, 500.0, 180.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -30.0), "+%d" % gained, color, 4.0)
	else:
		# Cofre del tesoro.
		var chest_coins: float = 25.0 * Buffs.factor("chest")
		_add_coins(chest_coins)
		GameData.add_mission_progress("coins", 25)
		Sfx.play("buy")
		_zoom_punch = 0.6
		Fx.burst(fx_root, pos + Vector2(0.0, -20.0), Pal.YELLOW, 30, 420.0, 0.7, 8.0, 900.0, 70.0, Vector2.UP)
		Fx.ring(fx_root, pos + Vector2(0.0, -20.0), Pal.YELLOW, 80.0)
		Fx.popup(fx_root, pos + Vector2(0.0, -60.0), "¡COFRE! +%d" % int(chest_coins * _coin_factor * Buffs.factor("coins")), Pal.YELLOW, 4.0)


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
	# Proyectil de jefe devuelto con un golpe perfecto (o GOOD con la mejora
	# "Devolucion facil"): contraataque.
	var reflect_rating: int = Timing.Rating.GOOD if Buffs.has("boss_reflect") else Timing.Rating.PERFECT
	if kind == Enemy.Kind.ORB and _boss != null and is_instance_valid(_boss) and rating >= reflect_rating:
		_boss.reflect()
		Fx.popup(fx_root, _boss.position + Vector2(0.0, -150.0), "¡CONTRAATAQUE! -1", Pal.LIME, 4.0)
	var kill_points: float = float(points)
	if Buffs.has("fury"):
		kill_points *= 2.0
	if Buffs.has("zen"):
		kill_points *= 0.5
	# Proyectiles cortados: mejoras "Devolver" y "Espejo de acero".
	if kind == Enemy.Kind.ORB or kind == Creature.PROJECTILE_KIND:
		kill_points = (kill_points + 20.0) * Buffs.factor("reflect_points")
		if Buffs.stat("reflect_coins") > 0.0:
			_add_coins(Buffs.stat("reflect_coins"))
	var gained: int = _add_points(kill_points)
	if Buffs.stat("bounty") > 0.0:
		_add_coins(Buffs.stat("bounty"))
	GameData.add_mission_progress("kills", 1)
	_shake = maxf(_shake, 0.35)
	Sfx.play("kill")
	var color: Color = _enemy_colors[clampi(kind, 0, _enemy_colors.size() - 1)]
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), color, 18, 340.0, 0.55, 8.0, 700.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), Pal.WHITE, 10, 260.0, 0.3, 6.0, 0.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, pos + Vector2(0.0, -60.0), "+%d" % gained, Pal.WHITE, 4.0)


## Golpe que no mata (acorazados: pulsacion rapida, escudero).
func _on_enemy_hit(pos: Vector2) -> void:
	Sfx.play("hit", randf_range(0.9, 1.2))
	_shake = maxf(_shake, 0.2)
	_add_points(5.0)
	Fx.burst(fx_root, pos + Vector2(-10.0, -40.0), Pal.YELLOW, 8, 300.0, 0.3, 6.0, 600.0, 120.0, Vector2.UP)


## Pisoton: aplasta lo que hay debajo.
func _on_stomped(pos: Vector2, kills: int) -> void:
	Sfx.play("boss_hit", 1.4)
	_shake = maxf(_shake, 0.4)
	Fx.ring(fx_root, pos, Pal.WHITE, 70.0 + Buffs.stat("stomp"))
	Fx.burst(fx_root, pos, Pal.SILVER, 12, 300.0, 0.35, 6.0, 600.0, 70.0, Vector2.UP)
	if kills > 0:
		var stomp_gain: int = _add_points(30.0 * float(kills) * Buffs.factor("stomp_points"))
		Fx.popup(fx_root, pos + Vector2(0.0, -80.0), "+%d" % stomp_gain, Pal.SILVER, 3.0)
		precision.register(Timing.Rating.PERFECT, "PISOTÓN", pos, "attack")


## Trampolin: rebote normal o super rebote si se pulso justo al pisarlo.
func _on_bounced(pos: Vector2, perfect: bool) -> void:
	Sfx.play("jump", 1.4 if perfect else 1.2)
	Fx.burst(fx_root, pos, Pal.YELLOW, 10, 260.0, 0.35, 6.0, 300.0, 60.0, Vector2.UP)
	if perfect:
		_add_points(40.0 * Buffs.factor("bounce_points"))
		Fx.ring(fx_root, pos, Pal.YELLOW, 70.0)
		precision.register(Timing.Rating.PERFECT, "SUPER REBOTE", pos, "jump")


## Perseguidores que te han adelantado sin tocarte: esquiva premiada.
func _check_dodges() -> void:
	while Daylight.dodges > 0:
		Daylight.dodges -= 1
		_add_points(60.0 * Buffs.factor("dodge_points"))
		precision.register(Timing.Rating.PERFECT, "¡ESQUIVADO!", player.position, "dodge")


## Presenta lo nuevo de este nivel: enemigo del mundo o mecanica nueva.
func _announce_new_content() -> void:
	if _test_mode:
		return
	if not _level_mode or bool(_def.get("final", false)):
		if not _level_mode:
			var first: Array = Bestiary.entry(0, 0)
			hud.toast("UN GOLPE Y CAES. ENEMIGO: " + String(first[0]), Pal.ORANGE)
		return
	var world_index: int = int(_def["world"])
	var level: int = int(_def["level"])
	var creature: int = Bestiary.introduced(level)
	if creature >= 0:
		var data: Array = Bestiary.entry(world_index, creature)
		hud.show_banner("NUEVO: " + String(data[0]), String(data[6]))
	if world_index == 0:
		for item in LevelGenerator.MECHANICS:
			var mechanic: Array = item
			if int(mechanic[1]) == level:
				hud.toast("MECÁNICA NUEVA: %s. %s" % [String(mechanic[2]), String(mechanic[3])], Pal.CYAN)
		if level == 2:
			hud.toast("PISOTÓN: PULSA CAYENDO DESDE LO ALTO", Pal.CYAN)


func _on_player_damaged() -> void:
	_lose_life(false)


func _on_player_fell() -> void:
	_lose_life(true)


## Un solo golpe mata. La Pluma de Fenix (tienda) salva una vez por intento.
func _lose_life(fell_in_hole: bool) -> void:
	if _state != State.PLAYING:
		return
	# Prueba con invencibilidad: solo se marca el golpe.
	if Daylight.invincible:
		Sfx.play("hurt")
		hud.flash(Pal.RED, 0.25)
		Fx.popup(fx_root, player.position + Vector2(0.0, -90.0), "¡GOLPE!", Pal.RED, 3.0)
		if fell_in_hole:
			_respawn_player()
		player.start_invulnerability(0.6)
		return
	_damage_taken += 1
	precision.on_damage()
	_jump_chain = 0
	_shake = 1.0
	Sfx.play("hurt")
	hud.flash(Pal.RED, 0.45)
	if not fell_in_hole:
		Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.RED, 14, 300.0, 0.5, 7.0, 700.0, 180.0, Vector2.UP)
	if Buffs.has("phoenix") and not _phoenix_used:
		_phoenix_used = true
		player.play_hurt()
		if fell_in_hole:
			_respawn_player()
		player.start_invulnerability(1.5)
		Sfx.play("revive")
		hud.show_banner("¡PLUMA DE FÉNIX!", "TE HA SALVADO. EL RANGO MÁXIMO BAJA A A")
		Fx.burst(fx_root, player.position + Vector2(0.0, -30.0), Pal.ORANGE, 26, 380.0, 0.6, 8.0, 300.0, 180.0, Vector2.UP)
		return
	_game_over()


## Partida de prueba (panel de administrador): mundo, enemigo o patron
## elegidos, velocidad del mundo y, si se pidio, invencibilidad.
func _setup_test() -> void:
	_test_mode = true
	var world_index: int = clampi(int(GameData.run.get("world", 0)), 0, Campaign.world_count() - 1)
	Daylight.theme = Campaign.theme(world_index)
	Daylight.time = 0.25
	_speed = 360.0 + 80.0 * float(world_index)
	_target_speed = _speed + 30.0
	_level = 5
	precision.window_scale = [1.25, 1.05, 0.92, 0.82, 0.72][world_index]
	_def = {"world": world_index, "level": 0, "final": false}
	generator.configure_test(world_index, int(GameData.run.get("creature", -1)), int(GameData.run.get("pattern", -1)))
	Daylight.invincible = bool(GameData.run.get("invincible", false))
	hud.set_level_name("PRUEBA" + (" - INVENCIBLE" if Daylight.invincible else ""))
	hud.toast("MODO PRUEBA: NO SE GUARDA NADA", Pal.ORANGE)


func _create_hero_light() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_hero_light = PointLight2D.new()
	_hero_light.texture = texture
	_hero_light.texture_scale = 4.0
	_hero_light.color = Color(1.0, 0.86, 0.62)
	_hero_light.energy = 0.0
	player.add_child(_hero_light)
	_hero_light.position = Vector2(0.0, -30.0)


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
	if _test_mode:
		return false
	GameData.add_mission_progress("distance", _meters())
	if _diamond_found and _level_mode:
		GameData.claim_hidden_diamond(int(_def["world"]), int(_def["level"]))
	GameData.stats["best_combo"] = maxi(int(GameData.stats.get("best_combo", 0)), precision.best_combo)
	GameData.add_stat("perfects", int(precision.counts[3]))
	GameData.add_stat("legendaries", int(precision.counts[4]))
	var fused: int = GameData.add_gem_shards(_gems)
	if fused > 0:
		hud.toast("FRAGMENTOS FUNDIDOS: +%d DIAMANTE" % fused, Pal.CYAN)
	return GameData.finish_run(_score(), int(_coins_f), _kills, _gems, _meters())


func _game_over() -> void:
	_state = State.DYING
	_death_time = 0.0
	hud.can_pause = false
	player.die()
	Sfx.set_intensity(0)
	Sfx.play("gameover")
	# Muerte: camara lenta breve, destello rojo y onda.
	Engine.time_scale = 0.4
	lights.flash(Pal.RED, 0.6, 0.5)
	Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.WHITE, 24, 420.0, 0.7, 8.0, 600.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.RED, 16, 300.0, 0.6, 7.0, 400.0, 180.0, Vector2.UP)
	Fx.ring(fx_root, player.position + Vector2(0.0, -28.0), Pal.RED, 120.0)
	_update_hud()
	var wait: float = 0.5 if Buffs.has("quick_retry") else 1.3
	await get_tree().create_timer(wait, true, false, true).timeout
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
	var grade: float = precision.grade(info) + Buffs.stat("rank_bonus")
	var rank: int = Timing.rank_for(grade)
	# La Pluma de Fenix limita el rango maximo a A.
	if _phoenix_used:
		rank = mini(rank, 3)
	# Estrellas: 1 por llegar, 2 con rango B o mejor, 3 con rango A o mejor
	# y como mucho un golpe recibido.
	var stars: int = 1
	if rank >= 2:
		stars += 1
	if rank >= 3 and _damage_taken <= 1:
		stars += 1
	var world_index: int = int(_def["world"])
	var level: int = int(_def["level"])
	var final_score: int = _score()
	var rewards: Dictionary = GameData.complete_level(world_index, level, stars, rank, final_score)
	# Retos opcionales del nivel.
	var challenge_list: Array = Campaign.challenges(world_index, level)
	var challenge_texts: Array = []
	var challenge_results: Array = []
	for item in challenge_list:
		var challenge: Dictionary = item
		challenge_texts.append(String(challenge["text"]))
		challenge_results.append(precision.challenge_done(challenge, info))
	var extra: Dictionary = GameData.complete_challenges(world_index, level, challenge_results)
	# Modo de dominio.
	var mode_line: String = ""
	if _challenge != "normal":
		if _challenge_met():
			var paid: Dictionary = GameData.complete_mode(world_index, level, _challenge)
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
	lights.flash(Pal.YELLOW, 0.5, 0.8)
	# Meta: confeti de colores y ondas de luz.
	Fx.burst(fx_root, player.position + Vector2(0.0, -40.0), Pal.YELLOW, 40, 520.0, 0.9, 9.0, 600.0, 180.0, Vector2.UP)
	for color in [Pal.CYAN, Pal.PINK, Pal.LIME, Pal.ORANGE]:
		Fx.burst(fx_root, player.position + Vector2(randf_range(-80.0, 80.0), -60.0), color, 14, 480.0, 1.1, 7.0, 500.0, 70.0, Vector2.UP)
	Fx.ring(fx_root, player.position + Vector2(0.0, -40.0), Pal.YELLOW, 140.0)
	Fx.ring(fx_root, player.position + Vector2(0.0, -40.0), Pal.WHITE, 220.0)
	var has_next: bool = level < Campaign.LEVELS_PER_WORLD - 1 or world_index < Campaign.world_count() - 1
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
	var world_index: int = int(_def.get("world", 0))
	var level: int = int(_def.get("level", 0)) + 1
	if level >= Campaign.LEVELS_PER_WORLD:
		level = 0
		world_index += 1
	if world_index >= Campaign.world_count():
		_go_to_menu()
		return
	GameData.run = {"mode": "level", "world": world_index, "level": level}
	Transition.reload()


func _restart() -> void:
	_bank_run()
	Transition.reload()


func _go_to_menu() -> void:
	_bank_run()
	Transition.change_scene(MENU_SCENE)



## Victoria de nivel: el reintento rapido no debe saltarse esa pantalla.
func _level_mode_won() -> bool:
	return _state == State.GAME_OVER and player.alive
