extends CanvasLayer
## Interfaz de la partida: marcadores, poderes, pausa, Game Over (con acceso
## a la tienda), avisos de nivel, notificaciones y destello de dano.
## Funciona tambien con el arbol en pausa (process_mode = ALWAYS).

signal restart_requested
signal menu_requested
signal power_pressed(index: int)

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const HudBar = preload("res://scripts/hud_bar.gd")
const PowerButton = preload("res://scripts/power_button.gd")
const Shop = preload("res://scripts/shop.gd")
const Toaster = preload("res://scripts/toaster.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

## game.gd lo activa solo mientras se esta jugando.
var can_pause: bool = false

var _bar: HudBar
var _pause_button: PixelButton
var _power_buttons: Array = []
var _pause_layer: Control
var _continue_button: PixelButton
var _music_button: PixelButton
var _sfx_button: PixelButton
var _over_layer: Control
var _retry_button: PixelButton
var _over_buttons: Array = []
var _over_score: PixelLabel
var _over_record: PixelLabel
var _over_new_record: PixelLabel
var _over_coins: PixelLabel
var _over_stats: PixelLabel
var _banner: PixelLabel
var _banner_sub: PixelLabel
var _hint_layer: Control
var _flash: ColorRect
var _banner_tween: Tween
var _toaster: Toaster
var _shop: Shop
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash()
	_build_bar()
	_build_hint()
	_build_banner()
	_build_pause()
	_build_game_over()
	_toaster = Toaster.new()
	add_child(_toaster)
	_shop = Shop.new()
	add_child(_shop)
	_shop.closed.connect(_on_shop_closed)
	GameData.notice.connect(_on_notice)


func _process(delta: float) -> void:
	_time += delta
	if _over_layer.visible and _over_new_record.visible:
		_over_new_record.color = Pal.YELLOW if int(_time * 4.0) % 2 == 0 else Pal.ORANGE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume()
		elif can_pause:
			_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pausa automatica si la ventana pierde el foco.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and can_pause and not get_tree().paused:
			_pause()


func _on_notice(text: String) -> void:
	Sfx.play("mission")
	_toaster.show_toast(text, Pal.LIME)


## Aviso emergente en la parte superior.
func toast(text: String, color: Color) -> void:
	_toaster.show_toast(text, color)


# ------------------------------------------------------------ construccion --

func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(Pal.RED, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.position = Vector2.ZERO
	_flash.size = UI.SCREEN


func _build_bar() -> void:
	_bar = HudBar.new()
	add_child(_bar)
	_bar.position = Vector2.ZERO
	_bar.size = UI.SCREEN
	_pause_button = UI.button(self, "|", Rect2(1196.0, 16.0, 64.0, 60.0), 4.0)
	# Sin foco de teclado: asi la barra espaciadora nunca pulsa la pausa.
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_pause)
	# Botones de poderes (abajo a la izquierda; tambien teclas 1-2-3 / Q-W-E).
	for i in Catalog.POWERS.size():
		var power: Dictionary = Catalog.POWERS[i]
		var button: PowerButton = PowerButton.new()
		button.icon_sprite = String(power["icon"])
		button.key_label = String(power["key"])
		button.power_name = String(power["name"])
		add_child(button)
		button.position = Vector2(24.0 + float(i) * 96.0, 600.0)
		button.size = Vector2(80.0, 84.0)
		button.pressed.connect(_on_power_button.bind(i))
		_power_buttons.append(button)


func _on_power_button(index: int) -> void:
	power_pressed.emit(index)


func _build_hint() -> void:
	_hint_layer = UI.layer(self, "Hint")
	UI.label(_hint_layer, "ESPACIO / CLIC / TOQUE: SALTAR", Vector2(700.0, 612.0), 3.0, Pal.WHITE)
	UI.label(_hint_layer, "MANTÉN: SALTO ALTO - ENEMIGO CERCA (!): ATACAR", Vector2(700.0, 648.0), 2.0, Pal.YELLOW)
	UI.label(_hint_layer, "PODERES: TECLAS 1 2 3 O TOCA LOS BOTONES", Vector2(700.0, 676.0), 2.0, Pal.CYAN)
	var tween: Tween = create_tween()
	tween.tween_interval(8.0)
	tween.tween_property(_hint_layer, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_hint_layer.hide)


func _build_banner() -> void:
	_banner = UI.label(self, "", Vector2(640.0, 180.0), 6.0, Pal.YELLOW)
	_banner.outline = true
	_banner.visible = false
	_banner_sub = UI.label(self, "", Vector2(640.0, 236.0), 3.0, Pal.WHITE)
	_banner_sub.outline = true
	_banner_sub.visible = false


func _build_pause() -> void:
	_pause_layer = UI.layer(self, "Pause")
	_pause_layer.visible = false
	UI.dim(_pause_layer, 0.6)
	UI.panel(_pause_layer, Rect2(400.0, 110.0, 480.0, 500.0))
	UI.label(_pause_layer, "PAUSA", Vector2(640.0, 146.0), 8.0, Pal.YELLOW)
	_continue_button = UI.button(_pause_layer, "CONTINUAR", Rect2(460.0, 236.0, 360.0, 68.0), 4.0)
	_continue_button.fill = Pal.GREEN
	_continue_button.fill_hot = Pal.LIME
	_continue_button.pressed.connect(_resume)
	var restart: PixelButton = UI.button(_pause_layer, "REINICIAR", Rect2(460.0, 320.0, 360.0, 64.0), 4.0)
	restart.pressed.connect(_on_restart_pressed)
	var menu: PixelButton = UI.button(_pause_layer, "MENÚ", Rect2(460.0, 400.0, 360.0, 64.0), 4.0)
	menu.pressed.connect(_on_menu_pressed)
	_music_button = UI.button(_pause_layer, "", Rect2(460.0, 488.0, 172.0, 52.0), 2.0)
	_music_button.pressed.connect(_toggle_music)
	_sfx_button = UI.button(_pause_layer, "", Rect2(648.0, 488.0, 172.0, 52.0), 2.0)
	_sfx_button.pressed.connect(_toggle_sfx)
	_refresh_audio_buttons()


func _refresh_audio_buttons() -> void:
	_music_button.caption = "MÚSICA: %s" % ("SÍ" if GameData.music_enabled else "NO")
	_sfx_button.caption = "SONIDO: %s" % ("SÍ" if GameData.sfx_enabled else "NO")


func _toggle_music() -> void:
	GameData.music_enabled = not GameData.music_enabled
	GameData.apply_settings()
	_refresh_audio_buttons()


func _toggle_sfx() -> void:
	GameData.sfx_enabled = not GameData.sfx_enabled
	GameData.apply_settings()
	_refresh_audio_buttons()


func _build_game_over() -> void:
	_over_layer = UI.layer(self, "GameOver")
	_over_layer.visible = false
	UI.dim(_over_layer, 0.7)
	UI.panel(_over_layer, Rect2(300.0, 50.0, 680.0, 620.0))
	UI.label(_over_layer, "GAME OVER", Vector2(640.0, 86.0), 9.0, Pal.RED)
	UI.label(_over_layer, "PUNTUACIÓN", Vector2(640.0, 186.0), 3.0, Pal.SILVER)
	_over_score = UI.label(_over_layer, "0", Vector2(640.0, 216.0), 9.0, Pal.WHITE)
	_over_record = UI.label(_over_layer, "RÉCORD 0", Vector2(640.0, 304.0), 4.0, Pal.YELLOW)
	_over_new_record = UI.label(_over_layer, "¡NUEVO RÉCORD!", Vector2(640.0, 346.0), 4.0, Pal.YELLOW)
	var purse: Control = UI.panel(_over_layer, Rect2(400.0, 388.0, 480.0, 56.0))
	purse.set("fill", Pal.INK)
	_over_coins = UI.label(_over_layer, "", Vector2(640.0, 406.0), 3.0, Pal.YELLOW)
	_over_stats = UI.label(_over_layer, "", Vector2(640.0, 462.0), 2.0, Pal.CYAN)
	_retry_button = UI.button(_over_layer, "JUGAR DE NUEVO", Rect2(360.0, 496.0, 560.0, 72.0), 4.0)
	_retry_button.fill = Pal.GREEN
	_retry_button.fill_hot = Pal.LIME
	_retry_button.pressed.connect(_on_restart_pressed)
	var shop_button: PixelButton = UI.button(_over_layer, "TIENDA", Rect2(360.0, 584.0, 272.0, 60.0), 3.0)
	shop_button.icon_sprite = "coin_0"
	shop_button.fill = Pal.PURPLE
	shop_button.fill_hot = Pal.RED
	shop_button.pressed.connect(_open_shop)
	var menu_button: PixelButton = UI.button(_over_layer, "MENÚ", Rect2(648.0, 584.0, 272.0, 60.0), 3.0)
	menu_button.pressed.connect(_on_menu_pressed)
	_over_buttons = [_retry_button, shop_button, menu_button]


# ------------------------------------------------------------- marcadores --

func set_stats(score: int, coins: int, lives: int, level: int, speed_pips: int, speed_value: int) -> void:
	_bar.score = score
	_bar.coins = coins
	_bar.lives = lives
	_bar.level = level
	_bar.speed_pips = speed_pips
	_bar.speed_value = speed_value


## Hora del dia, multiplicador, escudo y efectos activos.
func set_status(phase_name: String, night: bool, multiplier_text: String, shield: bool, effects_text: String) -> void:
	_bar.phase_name = phase_name
	_bar.night = night
	_bar.multiplier_text = multiplier_text
	_bar.shield = shield
	_bar.effects_text = effects_text


## Estado de un poder: recarga pendiente (0..1) y si esta en marcha.
func set_power(index: int, cooldown: float, running: bool) -> void:
	if index < 0 or index >= _power_buttons.size():
		return
	var button: PowerButton = _power_buttons[index]
	button.cooldown = cooldown
	button.running = running


func set_high_score(value: int) -> void:
	_bar.high_score = value


func set_max_lives(value: int) -> void:
	_bar.max_lives = value
	_bar.queue_redraw()


## Aviso grande en pantalla (subida de nivel, eventos...).
func show_banner(title: String, subtitle: String) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = title
	_banner_sub.text = subtitle
	_banner.visible = true
	_banner_sub.visible = true
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner.position.y = 140.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "position:y", 180.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(_banner.hide)
	_banner_tween.tween_callback(_banner_sub.hide)


## Destello de color a pantalla completa (dano, poderes...).
func flash(color: Color, strength: float = 0.45) -> void:
	_flash.color = Color(color, strength)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)


func show_game_over(score: int, high_score: int, is_record: bool, coins: int, kills: int, meters: int) -> void:
	can_pause = false
	_pause_button.visible = false
	_hint_layer.visible = false
	for item in _power_buttons:
		var power_button: PowerButton = item
		power_button.visible = false
	_over_score.text = str(score)
	_over_record.text = "RÉCORD %d" % high_score
	_over_new_record.visible = is_record
	_over_coins.text = "+%d MONEDAS  -  TOTAL %d" % [coins, GameData.wallet]
	_over_stats.text = "ENEMIGOS %d - DISTANCIA %d M" % [kills, meters]
	_over_layer.visible = true
	_over_layer.modulate.a = 0.0
	# Los botones se activan tras una breve espera para que una pulsacion
	# hecha "a la desesperada" al morir no reinicie la partida sin querer.
	_set_over_buttons_disabled(true)
	var tween: Tween = create_tween()
	tween.tween_property(_over_layer, "modulate:a", 1.0, 0.3)
	tween.tween_interval(0.4)
	tween.tween_callback(_enable_game_over_buttons)


func _set_over_buttons_disabled(value: bool) -> void:
	for item in _over_buttons:
		var button: PixelButton = item
		button.disabled = value


func _enable_game_over_buttons() -> void:
	_set_over_buttons_disabled(false)
	_retry_button.grab_focus()


func _open_shop() -> void:
	_over_layer.visible = false
	_shop.open(0)


func _on_shop_closed() -> void:
	_over_layer.visible = true
	_over_coins.text = "MONEDERO: %d" % GameData.wallet
	Sfx.play_music("gameover")
	_retry_button.grab_focus()


# ------------------------------------------------------------------ pausa --

func _pause() -> void:
	if not can_pause or get_tree().paused:
		return
	get_tree().paused = true
	_pause_layer.visible = true
	_continue_button.grab_focus()


func _resume() -> void:
	_pause_layer.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
