extends CanvasLayer
## Interfaz de la partida: marcadores, boton de pausa, menu de pausa,
## pantalla de Game Over, avisos de nivel y destello de dano.
## Funciona tambien con el arbol en pausa (process_mode = ALWAYS).

signal restart_requested
signal menu_requested

const UI = preload("res://scripts/ui.gd")
const HudBar = preload("res://scripts/hud_bar.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

## game.gd lo activa solo mientras se esta jugando.
var can_pause: bool = false

var _bar: HudBar
var _pause_button: PixelButton
var _pause_layer: Control
var _continue_button: PixelButton
var _over_layer: Control
var _retry_button: PixelButton
var _over_menu_button: PixelButton
var _over_score: PixelLabel
var _over_record: PixelLabel
var _over_new_record: PixelLabel
var _over_stats: PixelLabel
var _banner: PixelLabel
var _banner_sub: PixelLabel
var _hint_layer: Control
var _flash: ColorRect
var _banner_tween: Tween
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash()
	_build_bar()
	_build_hint()
	_build_banner()
	_build_pause()
	_build_game_over()


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
	# Pausa automatica si la ventana pierde el foco (o la app pasa a segundo plano).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and can_pause and not get_tree().paused:
			_pause()


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


func _build_hint() -> void:
	_hint_layer = UI.layer(self, "Hint")
	UI.label(_hint_layer, "ESPACIO / CLIC / TOQUE: SALTAR", Vector2(640.0, 612.0), 3.0, Pal.WHITE)
	UI.label(_hint_layer, "MANTÉN PULSADO: SALTO ALTO  -  ENEMIGO CERCA (!): ATACAR", Vector2(640.0, 648.0), 2.0, Pal.YELLOW)
	var tween: Tween = create_tween()
	tween.tween_interval(7.0)
	tween.tween_property(_hint_layer, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_hint_layer.hide)


func _build_banner() -> void:
	_banner = UI.label(self, "", Vector2(640.0, 170.0), 6.0, Pal.YELLOW)
	_banner.outline = true
	_banner.visible = false
	_banner_sub = UI.label(self, "", Vector2(640.0, 226.0), 3.0, Pal.WHITE)
	_banner_sub.outline = true
	_banner_sub.visible = false


func _build_pause() -> void:
	_pause_layer = UI.layer(self, "Pause")
	_pause_layer.visible = false
	UI.dim(_pause_layer, 0.6)
	UI.panel(_pause_layer, Rect2(410.0, 150.0, 460.0, 420.0))
	UI.label(_pause_layer, "PAUSA", Vector2(640.0, 190.0), 8.0, Pal.YELLOW)
	_continue_button = UI.button(_pause_layer, "CONTINUAR", Rect2(470.0, 290.0, 340.0, 68.0), 4.0)
	_continue_button.fill = Pal.GREEN
	_continue_button.fill_hot = Pal.LIME
	_continue_button.pressed.connect(_resume)
	var restart: PixelButton = UI.button(_pause_layer, "REINICIAR", Rect2(470.0, 376.0, 340.0, 68.0), 4.0)
	restart.pressed.connect(_on_restart_pressed)
	var menu: PixelButton = UI.button(_pause_layer, "MENÚ", Rect2(470.0, 462.0, 340.0, 68.0), 4.0)
	menu.pressed.connect(_on_menu_pressed)


func _build_game_over() -> void:
	_over_layer = UI.layer(self, "GameOver")
	_over_layer.visible = false
	UI.dim(_over_layer, 0.65)
	UI.panel(_over_layer, Rect2(340.0, 70.0, 600.0, 580.0))
	UI.label(_over_layer, "GAME OVER", Vector2(640.0, 108.0), 9.0, Pal.RED)
	UI.label(_over_layer, "PUNTUACIÓN", Vector2(640.0, 214.0), 3.0, Pal.SILVER)
	_over_score = UI.label(_over_layer, "0", Vector2(640.0, 246.0), 9.0, Pal.WHITE)
	_over_record = UI.label(_over_layer, "RÉCORD 0", Vector2(640.0, 336.0), 4.0, Pal.YELLOW)
	_over_new_record = UI.label(_over_layer, "¡NUEVO RÉCORD!", Vector2(640.0, 380.0), 4.0, Pal.YELLOW)
	_over_stats = UI.label(_over_layer, "", Vector2(640.0, 428.0), 2.0, Pal.CYAN)
	_retry_button = UI.button(_over_layer, "JUGAR DE NUEVO", Rect2(430.0, 468.0, 420.0, 72.0), 4.0)
	_retry_button.fill = Pal.GREEN
	_retry_button.fill_hot = Pal.LIME
	_retry_button.pressed.connect(_on_restart_pressed)
	_over_menu_button = UI.button(_over_layer, "MENÚ", Rect2(430.0, 556.0, 420.0, 64.0), 4.0)
	_over_menu_button.pressed.connect(_on_menu_pressed)


# ------------------------------------------------------------- marcadores --

func set_stats(score: int, coins: int, lives: int, level: int, speed_pips: int, speed_value: int) -> void:
	_bar.score = score
	_bar.coins = coins
	_bar.lives = lives
	_bar.level = level
	_bar.speed_pips = speed_pips
	_bar.speed_value = speed_value


func set_high_score(value: int) -> void:
	_bar.high_score = value


func set_max_lives(value: int) -> void:
	_bar.max_lives = value
	_bar.queue_redraw()


## Aviso grande en pantalla (subida de nivel, etc.).
func show_banner(title: String, subtitle: String) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = title
	_banner_sub.text = subtitle
	_banner.visible = true
	_banner_sub.visible = true
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner.position.y = 130.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "position:y", 170.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(_banner.hide)
	_banner_tween.tween_callback(_banner_sub.hide)


## Destello rojo al recibir dano.
func flash_damage() -> void:
	_flash.color = Color(Pal.RED, 0.45)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)


func show_game_over(score: int, high_score: int, is_record: bool, coins: int, kills: int, meters: int) -> void:
	can_pause = false
	_pause_button.visible = false
	_hint_layer.visible = false
	_over_score.text = str(score)
	_over_record.text = "RÉCORD %d" % high_score
	_over_new_record.visible = is_record
	_over_stats.text = "MONEDAS %d - ENEMIGOS %d - %d METROS" % [coins, kills, meters]
	_over_layer.visible = true
	_over_layer.modulate.a = 0.0
	# Los botones se activan tras una breve espera para que una pulsacion
	# hecha "a la desesperada" al morir no reinicie la partida sin querer.
	_retry_button.disabled = true
	_over_menu_button.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(_over_layer, "modulate:a", 1.0, 0.3)
	tween.tween_interval(0.35)
	tween.tween_callback(_enable_game_over_buttons)


func _enable_game_over_buttons() -> void:
	_retry_button.disabled = false
	_over_menu_button.disabled = false
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
