extends Node2D
## Menu principal: titulo, PLAY, tienda, seleccion de heroe, progreso,
## configuracion e instrucciones, sobre el paisaje del juego con el heroe
## corriendo y el ciclo de dia y noche en marcha.

const UI = preload("res://scripts/ui.gd")
const Player = preload("res://scripts/player.gd")
const Background = preload("res://scripts/background.gd")
const GroundRenderer = preload("res://scripts/ground_renderer.gd")
const Shop = preload("res://scripts/shop.gd")
const ProgressPanel = preload("res://scripts/progress_panel.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Daylight = preload("res://scripts/daylight.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

const GAME_SCENE := "res://scenes/game.tscn"
const GROUND_Y := 560.0
const SCROLL_SPEED := 230.0
## En el menu el dia pasa mas deprisa para lucir el ciclo completo.
const MENU_DAY_LENGTH := 60.0

var _scroll: float = 0.0
var _time: float = 0.0
var _reset_armed: bool = false

var _title_top: PixelLabel
var _title_main: PixelLabel
var _record: PixelLabel
var _wallet: PixelLabel
var _main_layer: Control
var _settings_layer: Control
var _play_button: PixelButton
var _sfx_button: PixelButton
var _music_button: PixelButton
var _sfx_volume: PixelLabel
var _music_volume: PixelLabel
var _shake_button: PixelButton
var _fullscreen_button: PixelButton
var _reset_button: PixelButton
var _back_button: PixelButton
var _shop: Shop
var _progress: ProgressPanel
var _toaster: Toaster

@onready var background: Background = $BackgroundLayer/Background
@onready var world: Node2D = $World
@onready var ground: GroundRenderer = $World/Ground
@onready var hero: Player = $Hero
@onready var camera: Camera2D = $Camera2D
@onready var ui_root: CanvasLayer = $UI


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Daylight.time = 0.22
	Daylight.holes = []
	Daylight.magnet_radius = 0.0
	hero.demo_mode = true
	hero.run_speed = 300.0
	camera.make_current()
	_build_main()
	_build_settings()
	_shop = Shop.new()
	ui_root.add_child(_shop)
	_shop.closed.connect(_on_overlay_closed)
	_progress = ProgressPanel.new()
	ui_root.add_child(_progress)
	_progress.closed.connect(_on_overlay_closed)
	_toaster = Toaster.new()
	ui_root.add_child(_toaster)
	GameData.notice.connect(_on_notice)
	GameData.wallet_changed.connect(_refresh_texts)
	_refresh_texts()
	_update_scene()
	Sfx.play_music("menu")
	_play_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_scroll += SCROLL_SPEED * delta
	Daylight.time = fposmod(Daylight.time + delta / MENU_DAY_LENGTH, 1.0)
	_update_scene()
	# El titulo flota suavemente.
	var bob: float = roundf(sin(_time * 2.0) * 6.0)
	_title_top.position.y = 36.0 + bob
	_title_main.position.y = 100.0 + bob


func _update_scene() -> void:
	camera.position = Vector2(_scroll, 360.0)
	hero.position = Vector2(_scroll - 430.0, GROUND_Y)
	background.scroll_x = _scroll
	ground.view_left = _scroll - 640.0
	var ambient: Color = Daylight.ambient()
	world.modulate = ambient
	hero.modulate = ambient.lerp(Color(1.0, 1.0, 1.0), 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_layer.visible:
		_close_settings()
		get_viewport().set_input_as_handled()


func _on_notice(text: String) -> void:
	_toaster.show_toast(text, Pal.LIME)


# ----------------------------------------------------------- menu principal --

func _build_main() -> void:
	_main_layer = UI.layer(ui_root, "Main")

	_title_top = UI.label(_main_layer, "ONE BUTTON", Vector2(640.0, 36.0), 8.0, Pal.WHITE)
	_title_top.outline = true
	_title_main = UI.label(_main_layer, "HERO", Vector2(640.0, 100.0), 18.0, Pal.YELLOW)
	_title_main.shadow_color = Pal.RED
	_title_main.shadow_px = 8.0

	# Monedero.
	var purse: Control = UI.panel(_main_layer, Rect2(24.0, 24.0, 230.0, 60.0))
	purse.set("fill", Pal.INK)
	var coin: PixelButton = UI.button(_main_layer, "", Rect2(32.0, 30.0, 52.0, 48.0), 4.0)
	coin.icon_sprite = "coin_0"
	coin.disabled = true
	coin.focus_mode = Control.FOCUS_NONE
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet = UI.label(_main_layer, "0", Vector2(236.0, 40.0), 4.0, Pal.YELLOW, 2)

	_record = UI.label(_main_layer, "", Vector2(640.0, 250.0), 3.0, Pal.CYAN)
	_record.outline = true

	_play_button = UI.button(_main_layer, "PLAY", Rect2(480.0, 284.0, 320.0, 84.0), 6.0)
	_play_button.fill = Pal.GREEN
	_play_button.fill_hot = Pal.LIME
	_play_button.pressed.connect(_on_play_pressed)

	var shop_button: PixelButton = UI.button(_main_layer, "TIENDA", Rect2(334.0, 386.0, 196.0, 60.0), 3.0)
	shop_button.fill = Pal.PURPLE
	shop_button.fill_hot = Pal.RED
	shop_button.pressed.connect(_open_shop.bind(0))
	var hero_button: PixelButton = UI.button(_main_layer, "HÉROE", Rect2(542.0, 386.0, 196.0, 60.0), 3.0)
	hero_button.fill = Pal.TEAL
	hero_button.fill_hot = Pal.GREEN
	hero_button.pressed.connect(_open_shop.bind(2))
	var progress_button: PixelButton = UI.button(_main_layer, "PROGRESO", Rect2(750.0, 386.0, 196.0, 60.0), 3.0)
	progress_button.fill = Pal.ORANGE
	progress_button.fill_hot = Pal.YELLOW
	progress_button.pressed.connect(_open_progress)

	var settings_button: PixelButton = UI.button(_main_layer, "CONFIGURACIÓN", Rect2(480.0, 460.0, 320.0, 52.0), 3.0)
	settings_button.pressed.connect(_open_settings)

	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var quit: PixelButton = UI.button(_main_layer, "SALIR", Rect2(1120.0, 24.0, 136.0, 52.0), 3.0)
		quit.fill = Pal.RED
		quit.fill_hot = Pal.ORANGE
		quit.pressed.connect(_on_quit_pressed)

	# Instrucciones de control.
	var help: Control = UI.panel(_main_layer, Rect2(500.0, 566.0, 760.0, 142.0))
	help.modulate.a = 0.94
	UI.label(_main_layer, "UN SOLO BOTÓN: ESPACIO / CLIC / TOQUE", Vector2(880.0, 584.0), 3.0, Pal.YELLOW)
	UI.label(_main_layer, "PULSA: SALTAR  -  MANTÉN PULSADO: SALTO MÁS ALTO", Vector2(880.0, 620.0), 2.0, Pal.WHITE)
	UI.label(_main_layer, "ENEMIGO CERCA (!): EL BOTÓN ATACA CON LA ESPADA", Vector2(880.0, 642.0), 2.0, Pal.WHITE)
	UI.label(_main_layer, "PODERES: TECLAS 1 2 3 (TURBO, ONDA, TIEMPO LENTO)", Vector2(880.0, 664.0), 2.0, Pal.CYAN)
	UI.label(_main_layer, "ESC: PAUSA  -  GASTA TUS MONEDAS EN LA TIENDA", Vector2(880.0, 686.0), 2.0, Pal.SILVER)


func _refresh_texts() -> void:
	_record.text = "RÉCORD: %d  -  MEJOR DISTANCIA: %d M" % [GameData.high_score, int(GameData.stats.get("best_distance", 0))]
	_wallet.text = str(GameData.wallet)


func _on_play_pressed() -> void:
	Transition.change_scene(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_shop(tab: int) -> void:
	_main_layer.visible = false
	_shop.open(tab)


func _open_progress() -> void:
	_main_layer.visible = false
	_progress.open()


## Al cerrar la tienda o el progreso se vuelve al menu.
func _on_overlay_closed() -> void:
	_main_layer.visible = true
	hero.refresh_cosmetics()
	_refresh_texts()
	Sfx.play_music("menu")
	_play_button.grab_focus()


# ------------------------------------------------------------ configuracion --

func _build_settings() -> void:
	_settings_layer = UI.layer(ui_root, "Settings")
	_settings_layer.visible = false
	UI.dim(_settings_layer, 0.7)
	UI.panel(_settings_layer, Rect2(340.0, 40.0, 600.0, 640.0))
	UI.label(_settings_layer, "CONFIGURACIÓN", Vector2(640.0, 72.0), 5.0, Pal.YELLOW)

	_sfx_button = UI.button(_settings_layer, "", Rect2(400.0, 132.0, 480.0, 52.0), 3.0)
	_sfx_button.pressed.connect(_toggle_sfx)
	var sfx_minus: PixelButton = UI.button(_settings_layer, "-", Rect2(400.0, 194.0, 64.0, 52.0), 4.0)
	sfx_minus.pressed.connect(_change_sfx_volume.bind(-0.1))
	var sfx_plus: PixelButton = UI.button(_settings_layer, "+", Rect2(816.0, 194.0, 64.0, 52.0), 4.0)
	sfx_plus.pressed.connect(_change_sfx_volume.bind(0.1))
	_sfx_volume = UI.label(_settings_layer, "", Vector2(640.0, 208.0), 3.0, Pal.WHITE)

	_music_button = UI.button(_settings_layer, "", Rect2(400.0, 264.0, 480.0, 52.0), 3.0)
	_music_button.pressed.connect(_toggle_music)
	var music_minus: PixelButton = UI.button(_settings_layer, "-", Rect2(400.0, 326.0, 64.0, 52.0), 4.0)
	music_minus.pressed.connect(_change_music_volume.bind(-0.1))
	var music_plus: PixelButton = UI.button(_settings_layer, "+", Rect2(816.0, 326.0, 64.0, 52.0), 4.0)
	music_plus.pressed.connect(_change_music_volume.bind(0.1))
	_music_volume = UI.label(_settings_layer, "", Vector2(640.0, 340.0), 3.0, Pal.WHITE)

	_shake_button = UI.button(_settings_layer, "", Rect2(400.0, 396.0, 480.0, 52.0), 3.0)
	_shake_button.pressed.connect(_toggle_shake)
	_fullscreen_button = UI.button(_settings_layer, "", Rect2(400.0, 458.0, 480.0, 52.0), 3.0)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_reset_button = UI.button(_settings_layer, "BORRAR PROGRESO", Rect2(400.0, 520.0, 480.0, 52.0), 3.0)
	_reset_button.fill = Pal.RED
	_reset_button.fill_hot = Pal.ORANGE
	_reset_button.pressed.connect(_reset_progress)
	_back_button = UI.button(_settings_layer, "VOLVER", Rect2(500.0, 596.0, 280.0, 56.0), 3.0)
	_back_button.fill = Pal.GREEN
	_back_button.fill_hot = Pal.LIME
	_back_button.pressed.connect(_close_settings)
	_refresh_settings()


func _yes_no(value: bool) -> String:
	return "SÍ" if value else "NO"


func _refresh_settings() -> void:
	_sfx_button.caption = "EFECTOS DE SONIDO: %s" % _yes_no(GameData.sfx_enabled)
	_music_button.caption = "MÚSICA: %s" % _yes_no(GameData.music_enabled)
	_sfx_volume.text = "VOLUMEN EFECTOS %d%%" % int(roundf(GameData.sfx_volume * 100.0))
	_music_volume.text = "VOLUMEN MÚSICA %d%%" % int(roundf(GameData.music_volume * 100.0))
	_shake_button.caption = "TEMBLOR DE CÁMARA: %s" % _yes_no(GameData.screen_shake)
	_fullscreen_button.caption = "PANTALLA COMPLETA: %s" % _yes_no(GameData.fullscreen)


func _open_settings() -> void:
	_main_layer.visible = false
	_settings_layer.visible = true
	_reset_armed = false
	_reset_button.caption = "BORRAR PROGRESO"
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


func _change_sfx_volume(amount: float) -> void:
	GameData.sfx_volume = clampf(snappedf(GameData.sfx_volume + amount, 0.1), 0.0, 1.0)
	_apply()
	Sfx.play("coin")


func _change_music_volume(amount: float) -> void:
	GameData.music_volume = clampf(snappedf(GameData.music_volume + amount, 0.1), 0.0, 1.0)
	_apply()


func _toggle_shake() -> void:
	GameData.screen_shake = not GameData.screen_shake
	_apply()


func _toggle_fullscreen() -> void:
	GameData.fullscreen = not GameData.fullscreen
	_apply()


## Borra todo el progreso; pide una segunda pulsacion para confirmar.
func _reset_progress() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.caption = "¿SEGURO? PULSA OTRA VEZ"
		return
	_reset_armed = false
	GameData.reset_progress()
	hero.refresh_cosmetics()
	_refresh_texts()
	_reset_button.caption = "PROGRESO BORRADO"


func _apply() -> void:
	GameData.apply_settings()
	_refresh_settings()
