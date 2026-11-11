extends Node
## Autoload "GameData": record, ajustes y registro del unico boton del juego.
## Guarda todo en user://one_button_hero.cfg mediante ConfigFile.

signal settings_changed

const SAVE_PATH := "user://one_button_hero.cfg"
## Nombre de la accion de entrada: ESPACIO, clic izquierdo o toque en pantalla.
const ACTION := "hero_action"

var high_score: int = 0
var total_coins: int = 0
var games_played: int = 0

var sfx_enabled: bool = true
var music_enabled: bool = true
var volume: float = 0.8
var screen_shake: bool = true
var fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	load_data()
	_apply_window_mode()


## Crea la accion por codigo para no depender del mapa de entrada del proyecto.
## Los toques en pantalla llegan como clic izquierdo (Godot los emula por defecto).
func _register_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event(ACTION, key)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(ACTION, click)


func load_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = int(cfg.get_value("scores", "high_score", 0))
	total_coins = int(cfg.get_value("scores", "total_coins", 0))
	games_played = int(cfg.get_value("scores", "games_played", 0))
	sfx_enabled = bool(cfg.get_value("settings", "sfx_enabled", true))
	music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
	volume = clampf(float(cfg.get_value("settings", "volume", 0.8)), 0.0, 1.0)
	screen_shake = bool(cfg.get_value("settings", "screen_shake", true))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))


func save_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("scores", "high_score", high_score)
	cfg.set_value("scores", "total_coins", total_coins)
	cfg.set_value("scores", "games_played", games_played)
	cfg.set_value("settings", "sfx_enabled", sfx_enabled)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "fullscreen", fullscreen)
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("No se pudo guardar la partida (error %d)" % err)


## Registra el resultado de una partida. Devuelve true si es un nuevo record.
func submit_score(score: int, coins: int) -> bool:
	games_played += 1
	total_coins += coins
	var is_record: bool = score > high_score
	if is_record:
		high_score = score
	save_data()
	return is_record


func reset_high_score() -> void:
	high_score = 0
	save_data()


## Llamar despues de cambiar cualquier ajuste: guarda y avisa a quien escuche.
func apply_settings() -> void:
	_apply_window_mode()
	save_data()
	settings_changed.emit()


func _apply_window_mode() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
