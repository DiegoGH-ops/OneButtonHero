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
const ResetDialog = preload("res://scripts/reset_dialog.gd")
const LanguageMenu = preload("res://scripts/language_menu.gd")
const CampaignMap = preload("res://scripts/campaign_map.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")
const AdminPanel = preload("res://scripts/admin_panel.gd")
const Campaign = preload("res://scripts/campaign.gd")
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
var _reset_dialog: ResetDialog
var _language_button: PixelButton
var _language_menu: LanguageMenu

var _title_top: PixelLabel
var _title_main: PixelLabel
var _record: PixelLabel
var _wallet: PixelLabel
var _diamonds: PixelLabel
var _map: CampaignMap
var _tree: SkillTree
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
var _admin: AdminPanel
var _progress: ProgressPanel
var _progress_button: PixelButton
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
	Engine.physics_ticks_per_second = 60
	Daylight.time = 0.22
	Daylight.holes = []
	Daylight.theme = Campaign.theme(0)
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
	_map = CampaignMap.new()
	ui_root.add_child(_map)
	_map.closed.connect(_on_overlay_closed)
	_tree = SkillTree.new()
	ui_root.add_child(_tree)
	_tree.closed.connect(_on_overlay_closed)
	_admin = AdminPanel.new()
	ui_root.add_child(_admin)
	_admin.closed.connect(_on_admin_closed)
	_admin.open_tree_requested.connect(_open_tree)
	_toaster = Toaster.new()
	ui_root.add_child(_toaster)
	GameData.notice.connect(_on_notice)
	GameData.wallet_changed.connect(_refresh_texts)
	Loc.language_changed.connect(_on_language_changed)
	_refresh_texts()
	_update_scene()
	Sfx.play_music("menu")
	_play_button.grab_focus()
	# Recompensa por jugar hoy (racha de dias seguidos; el dia 7 da diamante).
	var login: Dictionary = GameData.claim_login()
	if not login.is_empty():
		var text: String = Loc.s("DÍA %d: +%d MONEDAS") % [int(login["day"]), int(login["coins"])]
		if int(login["diamonds"]) > 0:
			text += " +1 DIAMANTE"
		_toaster.show_toast(text, Pal.YELLOW)
		Sfx.play("unlock")
		_refresh_texts()


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
	if _admin.visible or (_reset_dialog != null and is_instance_valid(_reset_dialog)) or (_language_menu != null and is_instance_valid(_language_menu)):
		return
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
	# Diamantes: solo se consiguen jugando la campana.
	var gem_purse: Control = UI.panel(_main_layer, Rect2(24.0, 92.0, 230.0, 60.0))
	gem_purse.set("fill", Pal.INK)
	var gem: PixelButton = UI.button(_main_layer, "", Rect2(32.0, 98.0, 52.0, 48.0), 3.0)
	gem.icon_sprite = "gem"
	gem.disabled = true
	gem.focus_mode = Control.FOCUS_NONE
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diamonds = UI.label(_main_layer, "0", Vector2(236.0, 108.0), 4.0, Pal.CYAN, 2)

	_record = UI.label(_main_layer, "", Vector2(640.0, 250.0), 3.0, Pal.CYAN)
	_record.outline = true

	_play_button = UI.button(_main_layer, "CAMPAÑA", Rect2(440.0, 284.0, 400.0, 84.0), 6.0)
	_play_button.fill = Pal.GREEN
	_play_button.fill_hot = Pal.LIME
	_play_button.pressed.connect(_on_play_pressed)

	var shop_button: PixelButton = UI.button(_main_layer, "TIENDA", Rect2(334.0, 386.0, 196.0, 60.0), 3.0)
	shop_button.fill = Pal.PURPLE
	shop_button.fill_hot = Pal.RED
	shop_button.pressed.connect(_open_shop.bind(0))
	var tree_button: PixelButton = UI.button(_main_layer, "MEJORAS", Rect2(542.0, 386.0, 196.0, 60.0), 3.0)
	tree_button.fill = Pal.TEAL
	tree_button.fill_hot = Pal.GREEN
	tree_button.pressed.connect(_open_tree)
	var progress_button: PixelButton = UI.button(_main_layer, "PROGRESO", Rect2(750.0, 386.0, 196.0, 60.0), 3.0)
	_progress_button = progress_button
	progress_button.fill = Pal.ORANGE
	progress_button.fill_hot = Pal.YELLOW
	progress_button.pressed.connect(_open_progress)

	var endless_button: PixelButton = UI.button(_main_layer, "MODO INFINITO", Rect2(334.0, 460.0, 300.0, 52.0), 3.0)
	endless_button.pressed.connect(_on_endless_pressed)
	var settings_button: PixelButton = UI.button(_main_layer, "CONFIGURACIÓN", Rect2(646.0, 460.0, 300.0, 52.0), 3.0)
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
	UI.label(_main_layer, "SUELTA PRONTO: SALTO CORTO - PULSA CAYENDO: PISOTÓN", Vector2(880.0, 664.0), 2.0, Pal.CYAN)
	UI.label(_main_layer, "APURA AL LÍMITE: GOOD, PERFECT, LEGENDARY Y LAST SECOND", Vector2(880.0, 686.0), 2.0, Pal.YELLOW)


func _refresh_texts() -> void:
	var heading: String = Loc.s("RÉCORD: %d  -  MEJOR DISTANCIA: %d M") % [GameData.high_score, int(GameData.stats.get("best_distance", 0))]
	if GameData.title != "":
		heading = Loc.s(GameData.title) + "  -  " + heading
	_record.text = heading
	if _progress_button != null:
		var ready_count: int = GameData.claimable_count()
		_progress_button.caption = "¡PROGRESO!" if ready_count > 0 else "PROGRESO"
	_wallet.text = str(GameData.wallet)
	_diamonds.text = str(GameData.diamonds)


func _on_play_pressed() -> void:
	_main_layer.visible = false
	_map.open()


## Modo infinito: la partida sin fin de siempre.
func _on_endless_pressed() -> void:
	GameData.run = {"mode": "endless"}
	Transition.change_scene(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_shop(tab: int) -> void:
	_main_layer.visible = false
	_shop.open(tab)


func _open_tree() -> void:
	_main_layer.visible = false
	_tree.open()


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
	UI.panel(_settings_layer, Rect2(340.0, 20.0, 600.0, 680.0))
	UI.label(_settings_layer, "CONFIGURACIÓN", Vector2(640.0, 44.0), 5.0, Pal.YELLOW)
	# Idioma: el nombre de cada idioma aparece en su propia escritura.
	_language_button = UI.button(_settings_layer, "", Rect2(400.0, 104.0, 480.0, 52.0), 3.0)
	_language_button.icon_sprite = "arrow_down"
	_language_button.fill = Pal.TEAL
	_language_button.pressed.connect(_open_language_menu)

	_sfx_button = UI.button(_settings_layer, "", Rect2(400.0, 166.0, 480.0, 52.0), 3.0)
	_sfx_button.pressed.connect(_toggle_sfx)
	var sfx_minus: PixelButton = UI.button(_settings_layer, "-", Rect2(400.0, 226.0, 64.0, 48.0), 4.0)
	sfx_minus.pressed.connect(_change_sfx_volume.bind(-0.1))
	var sfx_plus: PixelButton = UI.button(_settings_layer, "+", Rect2(816.0, 226.0, 64.0, 48.0), 4.0)
	sfx_plus.pressed.connect(_change_sfx_volume.bind(0.1))
	_sfx_volume = UI.label(_settings_layer, "", Vector2(640.0, 240.0), 3.0, Pal.WHITE)

	_music_button = UI.button(_settings_layer, "", Rect2(400.0, 284.0, 480.0, 52.0), 3.0)
	_music_button.pressed.connect(_toggle_music)
	var music_minus: PixelButton = UI.button(_settings_layer, "-", Rect2(400.0, 344.0, 64.0, 48.0), 4.0)
	music_minus.pressed.connect(_change_music_volume.bind(-0.1))
	var music_plus: PixelButton = UI.button(_settings_layer, "+", Rect2(816.0, 344.0, 64.0, 48.0), 4.0)
	music_plus.pressed.connect(_change_music_volume.bind(0.1))
	_music_volume = UI.label(_settings_layer, "", Vector2(640.0, 358.0), 3.0, Pal.WHITE)

	_shake_button = UI.button(_settings_layer, "", Rect2(400.0, 402.0, 480.0, 52.0), 3.0)
	_shake_button.pressed.connect(_toggle_shake)
	_fullscreen_button = UI.button(_settings_layer, "", Rect2(400.0, 462.0, 480.0, 52.0), 3.0)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_reset_button = UI.button(_settings_layer, "BORRAR PROGRESO", Rect2(400.0, 524.0, 480.0, 52.0), 3.0)
	_reset_button.fill = Pal.RED
	_reset_button.fill_hot = Pal.ORANGE
	_reset_button.pressed.connect(_reset_progress)
	_back_button = UI.button(_settings_layer, "VOLVER", Rect2(500.0, 596.0, 280.0, 56.0), 3.0)
	_back_button.fill = Pal.GREEN
	_back_button.fill_hot = Pal.LIME
	_back_button.pressed.connect(_close_settings)
	# Acceso discreto al panel de administrador (pide codigo).
	var admin_button: PixelButton = UI.button(_settings_layer, "ADMIN", Rect2(812.0, 604.0, 112.0, 40.0), 2.0)
	admin_button.fill = Pal.SLATE
	admin_button.fill_hot = Pal.STEEL
	admin_button.pressed.connect(_open_admin)
	_refresh_settings()


func _open_language_menu() -> void:
	if _language_menu != null and is_instance_valid(_language_menu):
		return
	_language_menu = LanguageMenu.new()
	ui_root.add_child(_language_menu)
	_language_menu.closed.connect(_on_language_menu_closed)


func _on_language_menu_closed() -> void:
	_language_menu = null
	_language_button.grab_focus()


## Idioma cambiado: los textos calculados se rehacen (el resto se traduce
## solo al redibujarse).
func _on_language_changed() -> void:
	_refresh_settings()
	_refresh_texts()


func _yes_no(value: bool) -> String:
	return Loc.s("SÍ") if value else Loc.s("NO")


func _refresh_settings() -> void:
	_sfx_button.caption = Loc.s("EFECTOS DE SONIDO: %s") % _yes_no(GameData.sfx_enabled)
	_music_button.caption = Loc.s("MÚSICA: %s") % _yes_no(GameData.music_enabled)
	_sfx_volume.text = Loc.s("VOLUMEN EFECTOS %d%%") % int(roundf(GameData.sfx_volume * 100.0))
	_music_volume.text = Loc.s("VOLUMEN MÚSICA %d%%") % int(roundf(GameData.music_volume * 100.0))
	_shake_button.caption = Loc.s("TEMBLOR DE CÁMARA: %s") % _yes_no(GameData.screen_shake)
	_fullscreen_button.caption = Loc.s("PANTALLA COMPLETA: %s") % _yes_no(GameData.fullscreen)
	_language_button.caption = Loc.s("IDIOMA / LANGUAGE") + ": " + Loc.language_name(Loc.language)


func _open_settings() -> void:
	_main_layer.visible = false
	_settings_layer.visible = true
	_reset_button.caption = "BORRAR PROGRESO"
	_back_button.grab_focus()


func _open_admin() -> void:
	_settings_layer.visible = false
	_admin.open()


func _on_admin_closed() -> void:
	_settings_layer.visible = true
	hero.refresh_cosmetics()
	_refresh_texts()
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


## Borrar progreso: abre las tres confirmaciones (ver reset_dialog.gd).
func _reset_progress() -> void:
	if _reset_dialog != null and is_instance_valid(_reset_dialog):
		return
	_reset_dialog = ResetDialog.new()
	ui_root.add_child(_reset_dialog)
	_reset_dialog.finished.connect(_on_reset_finished)


func _on_reset_finished(deleted: bool) -> void:
	_reset_dialog = null
	if deleted:
		hero.refresh_cosmetics()
		_refresh_texts()
		_refresh_settings()
	else:
		_toaster.show_toast("BORRADO CANCELADO: NO SE HA TOCADO NADA", Pal.LIME)
	_back_button.grab_focus()


func _apply() -> void:
	GameData.apply_settings()
	_refresh_settings()
