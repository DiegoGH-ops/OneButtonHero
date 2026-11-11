extends Node2D
## Menu principal: titulo, PLAY, configuracion e instrucciones sobre un
## fondo animado (el mismo paisaje parallax del juego con el heroe corriendo).

const UI = preload("res://scripts/ui.gd")
const Player = preload("res://scripts/player.gd")
const Background = preload("res://scripts/background.gd")
const GroundRenderer = preload("res://scripts/ground_renderer.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

const GAME_SCENE := "res://scenes/game.tscn"
const GROUND_Y := 560.0
const SCROLL_SPEED := 230.0

var _scroll: float = 0.0
var _time: float = 0.0

var _title_top: PixelLabel
var _title_main: PixelLabel
var _record: PixelLabel
var _main_layer: Control
var _settings_layer: Control
var _play_button: PixelButton
var _settings_button: PixelButton
var _sfx_button: PixelButton
var _music_button: PixelButton
var _volume_label: PixelLabel
var _shake_button: PixelButton
var _fullscreen_button: PixelButton
var _reset_button: PixelButton
var _back_button: PixelButton

@onready var background: Background = $BackgroundLayer/Background
@onready var ground: GroundRenderer = $World/Ground
@onready var hero: Player = $Hero
@onready var camera: Camera2D = $Camera2D
@onready var ui_root: CanvasLayer = $UI


func _ready() -> void:
	get_tree().paused = false
	hero.demo_mode = true
	hero.run_speed = 300.0
	camera.make_current()
	_build_main()
	_build_settings()
	_refresh_settings()
	_update_scene()
	Sfx.start_music()
	_play_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_scroll += SCROLL_SPEED * delta
	_update_scene()
	# El titulo flota suavemente.
	var bob: float = roundf(sin(_time * 2.0) * 6.0)
	_title_top.position.y = 56.0 + bob
	_title_main.position.y = 124.0 + bob


func _update_scene() -> void:
	camera.position = Vector2(_scroll, 360.0)
	hero.position = Vector2(_scroll - 400.0, GROUND_Y)
	background.scroll_x = _scroll
	ground.view_left = _scroll - 640.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_layer.visible:
		_close_settings()
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------- menu principal --

func _build_main() -> void:
	_main_layer = UI.layer(ui_root, "Main")

	_title_top = UI.label(_main_layer, "ONE BUTTON", Vector2(640.0, 56.0), 8.0, Pal.WHITE)
	_title_top.outline = true
	_title_main = UI.label(_main_layer, "HERO", Vector2(640.0, 124.0), 20.0, Pal.YELLOW)
	_title_main.shadow_color = Pal.RED
	_title_main.shadow_px = 8.0

	_record = UI.label(_main_layer, "", Vector2(640.0, 300.0), 3.0, Pal.CYAN)
	_record.outline = true

	_play_button = UI.button(_main_layer, "PLAY", Rect2(480.0, 344.0, 320.0, 84.0), 6.0)
	_play_button.fill = Pal.GREEN
	_play_button.fill_hot = Pal.LIME
	_play_button.pressed.connect(_on_play_pressed)

	_settings_button = UI.button(_main_layer, "CONFIGURACIÓN", Rect2(480.0, 446.0, 320.0, 60.0), 3.0)
	_settings_button.pressed.connect(_open_settings)

	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var quit: PixelButton = UI.button(_main_layer, "SALIR", Rect2(1120.0, 24.0, 136.0, 52.0), 3.0)
		quit.fill = Pal.RED
		quit.fill_hot = Pal.ORANGE
		quit.pressed.connect(_on_quit_pressed)

	# Instrucciones de control.
	var help: Control = UI.panel(_main_layer, Rect2(500.0, 574.0, 760.0, 130.0))
	help.modulate.a = 0.94
	UI.label(_main_layer, "UN SOLO BOTÓN: ESPACIO / CLIC / TOQUE", Vector2(880.0, 594.0), 3.0, Pal.YELLOW)
	UI.label(_main_layer, "PULSA: SALTAR  -  MANTÉN PULSADO: SALTO MÁS ALTO", Vector2(880.0, 632.0), 2.0, Pal.WHITE)
	UI.label(_main_layer, "ENEMIGO CERCA (!): EL BOTÓN ATACA CON LA ESPADA", Vector2(880.0, 656.0), 2.0, Pal.WHITE)
	UI.label(_main_layer, "ESC: PAUSA  -  RECOGE MONEDAS Y GEMAS", Vector2(880.0, 680.0), 2.0, Pal.SILVER)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


# ------------------------------------------------------------ configuracion --

func _build_settings() -> void:
	_settings_layer = UI.layer(ui_root, "Settings")
	_settings_layer.visible = false
	UI.dim(_settings_layer, 0.6)
	UI.panel(_settings_layer, Rect2(360.0, 60.0, 560.0, 600.0))
	UI.label(_settings_layer, "CONFIGURACIÓN", Vector2(640.0, 96.0), 5.0, Pal.YELLOW)

	_sfx_button = UI.button(_settings_layer, "", Rect2(420.0, 160.0, 440.0, 56.0), 3.0)
	_sfx_button.pressed.connect(_toggle_sfx)
	_music_button = UI.button(_settings_layer, "", Rect2(420.0, 228.0, 440.0, 56.0), 3.0)
	_music_button.pressed.connect(_toggle_music)

	var minus: PixelButton = UI.button(_settings_layer, "-", Rect2(420.0, 296.0, 64.0, 56.0), 4.0)
	minus.pressed.connect(_change_volume.bind(-0.1))
	var plus: PixelButton = UI.button(_settings_layer, "+", Rect2(796.0, 296.0, 64.0, 56.0), 4.0)
	plus.pressed.connect(_change_volume.bind(0.1))
	_volume_label = UI.label(_settings_layer, "", Vector2(640.0, 312.0), 3.0, Pal.WHITE)

	_shake_button = UI.button(_settings_layer, "", Rect2(420.0, 364.0, 440.0, 56.0), 3.0)
	_shake_button.pressed.connect(_toggle_shake)
	_fullscreen_button = UI.button(_settings_layer, "", Rect2(420.0, 432.0, 440.0, 56.0), 3.0)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_reset_button = UI.button(_settings_layer, "BORRAR RÉCORD", Rect2(420.0, 500.0, 440.0, 56.0), 3.0)
	_reset_button.fill = Pal.RED
	_reset_button.fill_hot = Pal.ORANGE
	_reset_button.pressed.connect(_reset_record)
	_back_button = UI.button(_settings_layer, "VOLVER", Rect2(500.0, 580.0, 280.0, 56.0), 3.0)
	_back_button.fill = Pal.GREEN
	_back_button.fill_hot = Pal.LIME
	_back_button.pressed.connect(_close_settings)


func _yes_no(value: bool) -> String:
	return "SÍ" if value else "NO"


func _refresh_settings() -> void:
	_sfx_button.caption = "SONIDO: %s" % _yes_no(GameData.sfx_enabled)
	_music_button.caption = "MÚSICA: %s" % _yes_no(GameData.music_enabled)
	_volume_label.text = "VOLUMEN %d%%" % int(roundf(GameData.volume * 100.0))
	_shake_button.caption = "TEMBLOR DE CÁMARA: %s" % _yes_no(GameData.screen_shake)
	_fullscreen_button.caption = "PANTALLA COMPLETA: %s" % _yes_no(GameData.fullscreen)
	_record.text = "RÉCORD: %d" % GameData.high_score


func _open_settings() -> void:
	_main_layer.visible = false
	_settings_layer.visible = true
	_back_button.grab_focus()


func _close_settings() -> void:
	_settings_layer.visible = false
	_main_layer.visible = true
	_play_button.grab_focus()


func _toggle_sfx() -> void:
	GameData.sfx_enabled = not GameData.sfx_enabled
	_apply()


func _toggle_music() -> void:
	GameData.music_enabled = not GameData.music_enabled
	_apply()


func _change_volume(amount: float) -> void:
	GameData.volume = clampf(snappedf(GameData.volume + amount, 0.1), 0.0, 1.0)
	_apply()
	Sfx.play("coin")


func _toggle_shake() -> void:
	GameData.screen_shake = not GameData.screen_shake
	_apply()


func _toggle_fullscreen() -> void:
	GameData.fullscreen = not GameData.fullscreen
	_apply()


func _reset_record() -> void:
	GameData.reset_high_score()
	_refresh_settings()
	_reset_button.caption = "RÉCORD BORRADO"


func _apply() -> void:
	GameData.apply_settings()
	_refresh_settings()
