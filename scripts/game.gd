extends Node2D
## Escena principal de la partida. Coordina al heroe, el generador de nivel,
## la camara, la dificultad, la puntuacion, las vidas y la interfaz.

const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Background = preload("res://scripts/background.gd")
const GroundRenderer = preload("res://scripts/ground_renderer.gd")
const LevelGenerator = preload("res://scripts/level_generator.gd")
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
## Distancia horizontal entre el heroe y el centro de la camara.
const CAMERA_LEAD := 320.0
const PIXELS_PER_METER := 48.0
const MENU_SCENE := "res://scenes/main_menu.tscn"

## Peligros que se estrenan en cada nivel (para el aviso en pantalla).
const NEW_HAZARDS := {
	1: "NUEVO: HUECOS Y DIABLILLOS",
	2: "NUEVO: TÓTEMS Y PLATAFORMAS",
	3: "NUEVO: MURCIÉLAGOS Y PINCHOS DOBLES",
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
var _bonus: int = 0
var _coins: int = 0
var _kills: int = 0
var _lives: int = MAX_LIVES
var _shake: float = 0.0
var _enemy_colors: Array = [Pal.GREEN, Pal.RED, Pal.PURPLE]

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var background: Background = $BackgroundLayer/Background
@onready var ground: GroundRenderer = $World/Ground
@onready var spans_root: Node2D = $World/Spans
@onready var objects_root: Node2D = $World/Objects
@onready var fx_root: Node2D = $Fx
@onready var generator: LevelGenerator = $Generator
@onready var hud: Hud = $HUD


func _ready() -> void:
	get_tree().paused = false
	generator.setup(spans_root, objects_root)
	ground.holes = generator.holes

	player.position = Vector2(0.0, GROUND_Y - 2.0)
	player.run_speed = _speed
	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)
	player.attacked.connect(_on_player_attacked)
	player.coin_collected.connect(_on_coin_collected)
	player.enemy_killed.connect(_on_enemy_killed)
	player.damaged.connect(_on_player_damaged)
	player.fell.connect(_on_player_fell)
	_last_player_x = player.position.x

	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_go_to_menu)
	hud.set_max_lives(MAX_LIVES)
	hud.set_high_score(GameData.high_score)

	camera.make_current()
	_update_camera()
	_update_hud()
	Sfx.start_music()

	player.active = true
	hud.can_pause = true


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.PLAYING and event.is_action_pressed(GameData.ACTION):
		player.press()


func _process(delta: float) -> void:
	if _state == State.PLAYING:
		_level_timer += delta
		if _level_timer >= LEVEL_SECONDS:
			_level_timer -= LEVEL_SECONDS
			_level_up()
		_speed = move_toward(_speed, _target_speed, 24.0 * delta)
		player.run_speed = _speed

		var moved: float = player.position.x - _last_player_x
		if moved > 0.0:
			_distance_px += moved
		_last_player_x = player.position.x

		generator.update(player.position.x, _speed, _level, delta)
		_update_camera()

	# Temblor de camara.
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		var strength: float = _shake * 14.0 if GameData.screen_shake else 0.0
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		camera.offset = Vector2.ZERO

	background.scroll_x = camera.position.x
	ground.view_left = camera.position.x - 640.0
	_update_hud()


func _update_camera() -> void:
	camera.position = Vector2(player.position.x + CAMERA_LEAD, 360.0)


func _score() -> int:
	return int(_distance_px / PIXELS_PER_METER) + _bonus


func _update_hud() -> void:
	var ratio: float = clampf((_speed - BASE_SPEED) / (MAX_SPEED - BASE_SPEED), 0.0, 1.0)
	var pips: int = 1 + int(roundf(ratio * 9.0))
	hud.set_stats(_score(), _coins, _lives, _level + 1, pips, int(roundf(_speed / PIXELS_PER_METER)))


# -------------------------------------------------------------- dificultad --

func _level_up() -> void:
	_level += 1
	_target_speed = minf(BASE_SPEED + SPEED_STEP * float(_level), MAX_SPEED)
	# El cielo avanza del dia al atardecer y a la noche.
	background.target_mood = clampf(float(_level - 1) / 7.0, 0.0, 1.0)
	var subtitle: String = "¡MÁS RÁPIDO!"
	if NEW_HAZARDS.has(_level):
		subtitle = NEW_HAZARDS[_level]
	hud.show_banner("NIVEL %d" % (_level + 1), subtitle)
	Sfx.play("level")


# ----------------------------------------------------------------- senales --

func _on_player_jumped(pos: Vector2) -> void:
	Sfx.play("jump", randf_range(0.95, 1.05))
	Fx.burst(fx_root, pos, Color(Pal.WHITE, 0.8), 6, 130.0, 0.3, 5.0, 300.0, 70.0, Vector2.UP)


func _on_player_landed(pos: Vector2) -> void:
	Sfx.play("land")
	Fx.burst(fx_root, pos, Color(Pal.WHITE, 0.7), 5, 110.0, 0.25, 5.0, 300.0, 80.0, Vector2.UP)


func _on_player_attacked(pos: Vector2) -> void:
	Sfx.play("attack", randf_range(0.92, 1.08))
	Fx.burst(fx_root, pos + Vector2(60.0, -34.0), Pal.CYAN, 6, 260.0, 0.22, 5.0, 0.0, 35.0, Vector2.RIGHT)


func _on_coin_collected(value: int, pos: Vector2, special: bool) -> void:
	_coins += 5 if special else 1
	_bonus += value
	if special:
		Sfx.play("gem")
		Fx.burst(fx_root, pos, Pal.CYAN, 16, 280.0, 0.5, 7.0, 500.0, 180.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -30.0), "+%d" % value, Pal.CYAN, 4.0)
	else:
		Sfx.play("coin", randf_range(0.97, 1.06))
		Fx.burst(fx_root, pos, Pal.YELLOW, 8, 200.0, 0.4, 5.0, 500.0, 180.0, Vector2.UP)
		Fx.popup(fx_root, pos + Vector2(0.0, -26.0), "+%d" % value, Pal.YELLOW, 3.0)


func _on_enemy_killed(points: int, pos: Vector2, kind: int) -> void:
	_kills += 1
	_bonus += points
	_shake = maxf(_shake, 0.35)
	Sfx.play("kill")
	var color: Color = _enemy_colors[clampi(kind, 0, _enemy_colors.size() - 1)]
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), color, 18, 340.0, 0.55, 8.0, 700.0, 180.0, Vector2.UP)
	Fx.burst(fx_root, pos + Vector2(0.0, -20.0), Pal.WHITE, 8, 240.0, 0.35, 5.0, 300.0, 180.0, Vector2.UP)
	Fx.popup(fx_root, pos + Vector2(0.0, -60.0), "+%d" % points, Pal.WHITE, 4.0)


func _on_player_damaged() -> void:
	_lose_life(false)


func _on_player_fell() -> void:
	_lose_life(true)


func _lose_life(fell_in_hole: bool) -> void:
	if _state != State.PLAYING:
		return
	_lives -= 1
	_shake = 1.0
	Sfx.play("hurt")
	hud.flash_damage()
	if not fell_in_hole:
		Fx.burst(fx_root, player.position + Vector2(0.0, -28.0), Pal.RED, 14, 300.0, 0.5, 7.0, 700.0, 180.0, Vector2.UP)
	if _lives <= 0:
		_game_over()
		return
	if fell_in_hole:
		# Reaparece al otro lado del hueco, con unos segundos de inmunidad.
		var x: float = generator.get_respawn_x(player.position.x)
		player.respawn(Vector2(x, GROUND_Y - 150.0))
		_last_player_x = player.position.x
		_update_camera()
		player.start_invulnerability(2.2)
	else:
		player.start_invulnerability(1.6)


func _game_over() -> void:
	_state = State.DYING
	_lives = 0
	hud.can_pause = false
	player.die()
	Sfx.play("gameover")
	_update_hud()
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	_state = State.GAME_OVER
	var final_score: int = _score()
	var is_record: bool = GameData.submit_score(final_score, _coins)
	hud.show_game_over(final_score, GameData.high_score, is_record, _coins, _kills, int(_distance_px / PIXELS_PER_METER))


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
