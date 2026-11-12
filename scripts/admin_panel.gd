extends Control
## Panel de ADMINISTRADOR: herramientas de desarrollo y pruebas.
## Solo se abre desde Configuracion (fuera del menu normal y nunca durante una
## partida) y exige un codigo de acceso. El codigo no esta escrito en ningun
## sitio: se compara su huella SHA-256.
##
## Pestanas:
##   MUNDOS     abrir / bloquear mundos, niveles sin restriccion y jugar
##              cualquier nivel de cualquier mundo.
##   ECONOMIA   anadir, fijar o restablecer monedas y diamantes.
##   PROGRESO   desbloquear o restablecer el arbol, completar categorias y
##              comprar mejoras gratis.
##   TIENDA     desbloquear cosmeticos y power-ups, y probar cualquier
##              heroe, espada, estela o aura sin comprarlos.
##   PRUEBAS    partidas de prueba con un enemigo, patron, obstaculo o
##              mecanica concretos; no guardan resultados.

signal closed
signal open_tree_requested

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Bestiary = preload("res://scripts/bestiary.gd")
const Buffs = preload("res://scripts/buffs.gd")
const LevelGenerator = preload("res://scripts/level_generator.gd")
const HeroPreview = preload("res://scripts/hero_preview.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Fx = preload("res://scripts/fx.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const TextCache = preload("res://scripts/text_cache.gd")
const Pal = preload("res://scripts/palette.gd")

const CODE_HASH := "5236b8e5ce1231b87341bc71e6d04f508c2c713a2bf1330392206a96141ccf2f"
const MAX_DIGITS := 8
const MAX_TRIES := 5
const GAME_SCENE := "res://scenes/game.tscn"
const TABS := ["MUNDOS", "ECONOMÍA", "PROGRESO", "TIENDA", "PRUEBAS"]
## Patrones que se pueden probar: [patron, nombre, tipo].
var _test_patterns: Array = [
	[LevelGenerator.Pattern.SPIKES, "PINCHOS", "OBSTÁCULO"],
	[LevelGenerator.Pattern.DOUBLE_SPIKES, "PINCHOS DOBLES", "OBSTÁCULO"],
	[LevelGenerator.Pattern.ROCK, "ROCA", "OBSTÁCULO"],
	[LevelGenerator.Pattern.TOTEM, "TÓTEM", "OBSTÁCULO"],
	[LevelGenerator.Pattern.BOULDER, "ROCA RODANTE", "OBSTÁCULO"],
	[LevelGenerator.Pattern.TRAP, "TRAMPAS", "OBSTÁCULO"],
	[LevelGenerator.Pattern.HOLE, "HUECO", "OBSTÁCULO"],
	[LevelGenerator.Pattern.WIDE_HOLE, "ABISMO ANCHO", "OBSTÁCULO"],
	[LevelGenerator.Pattern.SPIKES_HOLE, "PINCHOS Y HUECO", "OBSTÁCULO"],
	[LevelGenerator.Pattern.PLATFORM, "PLATAFORMA", "OBSTÁCULO"],
	[LevelGenerator.Pattern.CHAIN, "SALTOS ENCADENADOS", "MECÁNICA"],
	[LevelGenerator.Pattern.CEILING, "TECHO BAJO", "MECÁNICA"],
	[LevelGenerator.Pattern.RAPID_SIX, "RAPID SIX", "MECÁNICA"],
	[LevelGenerator.Pattern.JUMP_DRILL, "SECUENCIA DE SALTOS", "MECÁNICA"],
	[LevelGenerator.Pattern.ENCOUNTER, "ENCUENTRO MÚLTIPLE", "ENEMIGO"],
	[LevelGenerator.Pattern.BOUNCE, "TRAMPOLÍN", "MECÁNICA"],
	[LevelGenerator.Pattern.ROUTE, "RUTA ALTA", "MECÁNICA"],
	[LevelGenerator.Pattern.SLIME, "SLIME", "ENEMIGO"],
	[LevelGenerator.Pattern.GOBLIN, "GOBLIN", "ENEMIGO"],
	[LevelGenerator.Pattern.BAT, "MURCIÉLAGO", "ENEMIGO"],
	[LevelGenerator.Pattern.KNIGHT, "CABALLERO", "ENEMIGO"],
	[LevelGenerator.Pattern.GHOST, "ESPECTRO", "ENEMIGO"],
	[LevelGenerator.Pattern.DOUBLE_ENEMY, "PAREJA DE ENEMIGOS", "ENEMIGO"],
]

var _unlocked: bool = false
var _code: String = ""
var _tries: int = 0
var _lockout: float = 0.0
var _shake: float = 0.0
var _error_time: float = 0.0
var _grant_time: float = -1.0
var _time: float = 0.0

var _lock_layer: Control
var _lock_canvas: Control
var _panel_layer: Control
var _content: Control
var _canvas: Control
var _tab: int = 0
var _tab_buttons: Array = []
var _toaster: Toaster
var _status: String = ""

# Estado de las herramientas.
var _world: int = 0
var _level: int = 0
var _entry: String = ""
var _category: int = 0
var _test_world: int = 0
var _test_enemy: int = 0
var _test_pattern: int = 0
var _invincible: bool = true
var _confirm: String = ""
var _trial_index: Dictionary = {"skin": 0, "sword": 0, "trail": 0, "aura": 0}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	_build_lock()
	_panel_layer = UI.layer(self, "Panel")
	_panel_layer.visible = false
	_toaster = Toaster.new()
	add_child(_toaster)


func open() -> void:
	visible = true
	_unlocked = false
	_code = ""
	_grant_time = -1.0
	_lock_layer.visible = true
	_panel_layer.visible = false
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func close() -> void:
	if not visible:
		return
	visible = false
	_unlocked = false
	_code = ""
	GameData.save_data()
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_lockout = maxf(_lockout - delta, 0.0)
	if _lock_layer.visible:
		_lock_layer.position.x = sin(_time * 70.0) * 14.0 * _shake
		_lock_canvas.queue_redraw()
		if _grant_time >= 0.0 and _time - _grant_time > 1.1:
			_grant_time = -1.0
			_show_panel()
	elif _canvas != null:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var digit: int = -1
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		digit = key.keycode - KEY_0
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		digit = key.keycode - KEY_KP_0
	if _lock_layer.visible:
		if digit >= 0:
			_type_digit(digit)
		elif key.keycode == KEY_BACKSPACE:
			_erase_digit()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_submit()
		else:
			return
		get_viewport().set_input_as_handled()
	elif _tab == 1:
		# Campo numerico de la pestana de economia.
		if digit >= 0 and _entry.length() < 9:
			_entry += str(digit)
		elif key.keycode == KEY_BACKSPACE and not _entry.is_empty():
			_entry = _entry.substr(0, _entry.length() - 1)
		else:
			return
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------- pantalla de acceso --

func _build_lock() -> void:
	_lock_layer = UI.layer(self, "Lock")
	UI.dim(_lock_layer, 0.9)
	var panel: Control = UI.panel(_lock_layer, Rect2(380.0, 70.0, 520.0, 590.0))
	panel.set("fill", Color(0.06, 0.07, 0.12))
	panel.set("accent", Pal.STEEL)
	_lock_canvas = UI.layer(_lock_layer, "LockCanvas")
	_lock_canvas.draw.connect(_draw_lock)
	var keys: Array = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]
	for i in keys.size():
		var column: int = i % 3
		var row: int = int(float(i) / 3.0)
		var label: String = keys[i]
		var button: PixelButton = UI.button(_lock_layer, label, Rect2(470.0 + float(column) * 116.0, 330.0 + float(row) * 74.0, 104.0, 62.0), 4.0)
		button.fill = Pal.SLATE
		button.fill_hot = Pal.STEEL
		if label == "OK":
			button.fill = Pal.GREEN.darkened(0.3)
			button.fill_hot = Pal.GREEN
			button.pressed.connect(_submit)
		elif label == "<":
			button.fill = Pal.RED.darkened(0.3)
			button.fill_hot = Pal.RED
			button.pressed.connect(_erase_digit)
		else:
			button.pressed.connect(_type_digit.bind(int(label)))
	var back: PixelButton = UI.button(_lock_layer, "VOLVER", Rect2(560.0, 606.0, 160.0, 40.0), 2.0)
	back.pressed.connect(close)


func _type_digit(digit: int) -> void:
	if _grant_time >= 0.0 or _lockout > 0.0:
		return
	if _code.length() < MAX_DIGITS:
		_code += str(digit)
		Sfx.play("hover")


func _erase_digit() -> void:
	if not _code.is_empty():
		_code = _code.substr(0, _code.length() - 1)
		Sfx.play("click")


func _submit() -> void:
	if _grant_time >= 0.0:
		return
	if _lockout > 0.0:
		Sfx.play("error")
		return
	if _code.sha256_text() == CODE_HASH:
		_grant_time = _time
		_tries = 0
		Sfx.play("unlock")
		Fx.burst(_lock_canvas, Vector2(640.0, 220.0), Pal.LIME, 30, 420.0, 0.8, 8.0, 300.0, 180.0, Vector2.UP)
		Fx.ring(_lock_canvas, Vector2(640.0, 220.0), Pal.LIME, 140.0)
		return
	_tries += 1
	_code = ""
	_shake = 1.0
	_error_time = _time
	Sfx.play("error")
	if _tries >= MAX_TRIES:
		_tries = 0
		_lockout = 10.0


func _draw_lock() -> void:
	var c: Control = _lock_canvas
	var granted: bool = _grant_time >= 0.0
	var t: float = clampf((_time - _grant_time) / 0.5, 0.0, 1.0) if granted else 0.0
	TextCache.draw(c, "ACCESO RESTRINGIDO", Vector2(640.0 - TextCache.width("ACCESO RESTRINGIDO", 4.0) * 0.5, 100.0), 4.0, Pal.YELLOW)
	var sub: String = "INTRODUCE EL CÓDIGO DE ADMINISTRADOR"
	TextCache.draw(c, sub, Vector2(640.0 - TextCache.width(sub, 2.0) * 0.5, 140.0), 2.0, Pal.SILVER)
	# Candado: el arco se levanta al conceder el acceso.
	var lock_color: Color = Pal.LIME if granted else (Pal.RED if _time - _error_time < 0.6 else Pal.SILVER)
	var lift: float = -18.0 * t
	var center: Vector2 = Vector2(640.0, 214.0)
	c.draw_rect(Rect2(center + Vector2(-22.0, -34.0 + lift), Vector2(8.0, 30.0)), lock_color)
	c.draw_rect(Rect2(center + Vector2(14.0, -34.0 + lift - 10.0 * t), Vector2(8.0, 30.0)), lock_color)
	c.draw_rect(Rect2(center + Vector2(-22.0, -42.0 + lift), Vector2(44.0, 8.0)), lock_color)
	c.draw_rect(Rect2(center + Vector2(-32.0, -6.0), Vector2(64.0, 46.0)), lock_color.darkened(0.3))
	c.draw_rect(Rect2(center + Vector2(-28.0, -2.0), Vector2(56.0, 38.0)), lock_color)
	c.draw_rect(Rect2(center + Vector2(-4.0, 8.0), Vector2(8.0, 16.0)), Pal.INK)
	if granted:
		PixelArt.draw_glow(c, center, 120.0 * t + 20.0, Color(Pal.LIME, 0.4 * (1.0 - t * 0.5)))
	# Casillas: solo puntos, nunca los digitos (ni el codigo correcto).
	var slots: int = maxi(_code.length(), 6)
	var slot_w: float = 40.0
	var start: float = 640.0 - float(slots) * (slot_w + 8.0) * 0.5
	for i in slots:
		var r: Rect2 = Rect2(start + float(i) * (slot_w + 8.0), 270.0, slot_w, 44.0)
		c.draw_rect(r, Pal.INK)
		c.draw_rect(r.grow(-4.0), (Pal.GREEN if granted else Pal.NAVY.darkened(0.3)))
		if i < _code.length():
			c.draw_rect(Rect2(r.get_center() - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Pal.WHITE)
	var message: String = ""
	var color: Color = Pal.RED
	if granted:
		message = "ACCESO CONCEDIDO"
		color = Pal.LIME
	elif _lockout > 0.0:
		message = "DEMASIADOS INTENTOS: ESPERA %d S" % int(ceilf(_lockout))
	elif _time - _error_time < 1.6:
		message = "CÓDIGO INCORRECTO"
	if message != "":
		TextCache.draw(c, message, Vector2(640.0 - TextCache.width(message, 3.0) * 0.5, 172.0 + 92.0 * float(granted)), 3.0, color)
	if granted:
		c.draw_rect(Rect2(Vector2.ZERO, UI.SCREEN), Color(Pal.LIME, 0.25 * (1.0 - t)))


# ------------------------------------------------------------------- panel --

func _show_panel() -> void:
	_unlocked = true
	_lock_layer.visible = false
	_panel_layer.visible = true
	for child in _panel_layer.get_children():
		child.queue_free()
	_tab_buttons = []
	UI.dim(_panel_layer, 0.92)
	var frame: Control = UI.panel(_panel_layer, Rect2(24.0, 18.0, 1232.0, 684.0))
	frame.set("fill", Color(0.06, 0.07, 0.12))
	frame.set("accent", Pal.ORANGE.darkened(0.3))
	_canvas = UI.layer(_panel_layer, "Canvas")
	_canvas.draw.connect(_draw_panel)
	var exit_button: PixelButton = UI.button(_panel_layer, "SALIR", Rect2(1092.0, 34.0, 148.0, 54.0), 3.0)
	exit_button.fill = Pal.RED
	exit_button.fill_hot = Pal.ORANGE
	exit_button.pressed.connect(close)
	for i in TABS.size():
		var tab: PixelButton = UI.button(_panel_layer, TABS[i], Rect2(48.0 + float(i) * 206.0, 104.0, 196.0, 48.0), 2.0)
		tab.fill = Pal.SLATE
		tab.fill_hot = Pal.ORANGE
		tab.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(tab)
	_content = UI.layer(_panel_layer, "Content")
	_select_tab(_tab)


func _select_tab(index: int) -> void:
	_tab = clampi(index, 0, TABS.size() - 1)
	_confirm = ""
	for i in _tab_buttons.size():
		var tab: PixelButton = _tab_buttons[i]
		tab.selected = i == _tab
	_build_tab()


func _done(text: String) -> void:
	_status = text
	_toaster.show_toast(text, Pal.LIME)
	Sfx.play("upgrade")
	Buffs.invalidate()
	GameData.save_data()
	GameData.wallet_changed.emit()
	_build_tab()


func _button(text: String, rect: Rect2, callback: Callable, fill: Color = Pal.BLUE, px: float = 2.0) -> PixelButton:
	var b: PixelButton = UI.button(_content, text, rect, px)
	b.fill = fill
	b.fill_hot = fill.lightened(0.25)
	b.pressed.connect(callback)
	return b


func _label(text: String, pos: Vector2, px: float, color: Color) -> PixelLabel:
	return UI.label(_content, text, pos, px, color, 0)


func _build_tab() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	match _tab:
		0:
			_build_worlds()
		1:
			_build_economy()
		2:
			_build_progress()
		3:
			_build_shop()
		_:
			_build_tests()


# ------------------------------------------------------------ mundos y niveles --

func _build_worlds() -> void:
	var mode_names: Dictionary = {"normal": "PROGRESO NORMAL", "all": "TODOS ABIERTOS", "locked": "TODOS BLOQUEADOS"}
	_label("ESTADO DE LOS MUNDOS: " + String(mode_names.get(GameData.admin_worlds, "")), Vector2(56.0, 176.0), 2.0, Pal.YELLOW)
	_button("DESBLOQUEAR TODOS", Rect2(56.0, 204.0, 280.0, 46.0), _set_worlds.bind("all"), Pal.GREEN.darkened(0.2))
	_button("BLOQUEAR TODOS", Rect2(346.0, 204.0, 280.0, 46.0), _set_worlds.bind("locked"), Pal.RED.darkened(0.2))
	_button("PROGRESO NORMAL", Rect2(636.0, 204.0, 280.0, 46.0), _set_worlds.bind("normal"), Pal.STEEL)
	_button("NIVELES SIN RESTRICCIÓN: " + ("SÍ" if GameData.admin_levels else "NO"), Rect2(56.0, 260.0, 570.0, 46.0), _toggle_levels, Pal.PURPLE)
	_label("TELETRANSPORTE: ELIGE MUNDO Y NIVEL (NO HACE FALTA HABERLOS ABIERTO)", Vector2(56.0, 326.0), 2.0, Pal.SILVER)
	for i in Campaign.world_count():
		var world: Dictionary = Campaign.WORLDS[i]
		var b: PixelButton = _button(String(world["name"]), Rect2(56.0 + float(i) * 230.0, 352.0, 220.0, 44.0), _pick_world.bind(i), Color(String(world["color"])).darkened(0.45))
		b.selected = i == _world
	for i in Campaign.LEVELS_PER_WORLD:
		var column: int = i % 10
		var row: int = int(float(i) / 10.0)
		var b: PixelButton = _button(str(i + 1), Rect2(56.0 + float(column) * 76.0, 410.0 + float(row) * 58.0, 68.0, 50.0), _pick_level.bind(i), Pal.RED if i == Campaign.LEVELS_PER_WORLD - 1 else Pal.BLUE, 3.0)
		b.selected = i == _level
	_button("JUGAR NIVEL %d-%d" % [_world + 1, _level + 1], Rect2(840.0, 410.0, 380.0, 50.0), _play_level, Pal.GREEN, 3.0)
	_button("IR AL MUNDO %d" % (_world + 1), Rect2(840.0, 468.0, 380.0, 50.0), _go_world, Pal.TEAL, 3.0)
	_label("LAS PARTIDAS LANZADAS DESDE AQUÍ CUENTAN COMO PARTIDAS REALES.", Vector2(56.0, 540.0), 2.0, Pal.SILVER)
	_label("USA LA PESTAÑA PRUEBAS PARA JUGAR SIN GUARDAR RESULTADOS.", Vector2(56.0, 562.0), 2.0, Pal.SILVER)


func _set_worlds(mode: String) -> void:
	GameData.admin_worlds = mode
	_done("MUNDOS: " + {"all": "TODOS DESBLOQUEADOS", "locked": "TODOS BLOQUEADOS", "normal": "PROGRESO NORMAL"}[mode])


func _toggle_levels() -> void:
	GameData.admin_levels = not GameData.admin_levels
	_done("NIVELES SIN RESTRICCIÓN: " + ("SÍ" if GameData.admin_levels else "NO"))


func _pick_world(world: int) -> void:
	_world = world
	_build_tab()


func _pick_level(level: int) -> void:
	_level = level
	_build_tab()


func _play_level() -> void:
	GameData.save_data()
	GameData.run = {"mode": "level", "world": _world, "level": _level, "challenge": "normal"}
	Transition.change_scene(GAME_SCENE)


func _go_world() -> void:
	_level = 0
	_play_level()


# --------------------------------------------------------------- economia --

func _build_economy() -> void:
	_label("MONEDAS: %d" % GameData.wallet, Vector2(56.0, 176.0), 3.0, Pal.YELLOW)
	var coin_steps: Array = [100, 1000, 10000, 100000, -1000, -10000]
	for i in coin_steps.size():
		var amount: int = coin_steps[i]
		_button(("+" if amount > 0 else "") + str(amount), Rect2(56.0 + float(i) * 190.0, 210.0, 180.0, 46.0), _add_coins.bind(amount), Pal.GREEN.darkened(0.2) if amount > 0 else Pal.RED.darkened(0.2))
	_label("DIAMANTES: %d" % GameData.diamonds, Vector2(56.0, 286.0), 3.0, Pal.CYAN)
	var gem_steps: Array = [1, 10, 100, -1, -10]
	for i in gem_steps.size():
		var gems: int = gem_steps[i]
		_button(("+" if gems > 0 else "") + str(gems), Rect2(56.0 + float(i) * 190.0, 320.0, 180.0, 46.0), _add_diamonds.bind(gems), Pal.TEAL if gems > 0 else Pal.RED.darkened(0.2))
	_label("CANTIDAD EXACTA (ESCRIBE CON EL TECLADO O LOS BOTONES):", Vector2(56.0, 396.0), 2.0, Pal.SILVER)
	for i in 10:
		_button(str(i), Rect2(56.0 + float(i) * 62.0, 424.0, 54.0, 46.0), _entry_digit.bind(i), Pal.SLATE, 3.0)
	_button("<", Rect2(680.0, 424.0, 70.0, 46.0), _entry_erase, Pal.RED.darkened(0.3), 3.0)
	_button("FIJAR MONEDAS", Rect2(56.0, 534.0, 300.0, 50.0), _set_coins, Pal.YELLOW.darkened(0.45))
	_button("FIJAR DIAMANTES", Rect2(366.0, 534.0, 300.0, 50.0), _set_diamonds, Pal.CYAN.darkened(0.5))
	var reset_text: String = "¿SEGURO? PULSA OTRA VEZ" if _confirm == "resources" else "RESTABLECER RECURSOS (0)"
	_button(reset_text, Rect2(676.0, 534.0, 400.0, 50.0), _reset_resources, Pal.RED)


func _draw_entry() -> void:
	if _tab != 1:
		return
	var r: Rect2 = Rect2(56.0, 480.0, 420.0, 44.0)
	_canvas.draw_rect(r, Pal.INK)
	_canvas.draw_rect(r.grow(-4.0), Pal.NAVY.darkened(0.4))
	var text: String = _entry if _entry != "" else "0"
	var cursor: String = "|" if int(_time * 2.0) % 2 == 0 else ""
	TextCache.draw(_canvas, text + cursor, r.position + Vector2(14.0, 12.0), 3.0, Pal.WHITE)


func _add_coins(amount: int) -> void:
	GameData.wallet = maxi(GameData.wallet + amount, 0)
	_done("MONEDAS: %d" % GameData.wallet)


func _add_diamonds(amount: int) -> void:
	GameData.diamonds = maxi(GameData.diamonds + amount, 0)
	_done("DIAMANTES: %d" % GameData.diamonds)


func _entry_digit(digit: int) -> void:
	if _entry.length() < 9:
		_entry += str(digit)


func _entry_erase() -> void:
	if not _entry.is_empty():
		_entry = _entry.substr(0, _entry.length() - 1)


func _set_coins() -> void:
	GameData.wallet = int(_entry) if _entry != "" else 0
	_entry = ""
	_done("MONEDAS FIJADAS EN %d" % GameData.wallet)


func _set_diamonds() -> void:
	GameData.diamonds = int(_entry) if _entry != "" else 0
	_entry = ""
	_done("DIAMANTES FIJADOS EN %d" % GameData.diamonds)


func _reset_resources() -> void:
	if _confirm != "resources":
		_confirm = "resources"
		_build_tab()
		return
	_confirm = ""
	GameData.wallet = 0
	GameData.diamonds = 0
	_done("RECURSOS RESTABLECIDOS")


# --------------------------------------------------------------- progreso --

func _build_progress() -> void:
	_label("MEJORAS: %d/%d NIVELES COMPRADOS" % [GameData.tree_total_levels(), _tree_max_levels()], Vector2(56.0, 176.0), 2.0, Pal.YELLOW)
	_button("DESBLOQUEAR TODO EL ÁRBOL", Rect2(56.0, 204.0, 380.0, 50.0), _unlock_tree, Pal.GREEN.darkened(0.2))
	var reset_text: String = "¿SEGURO? PULSA OTRA VEZ" if _confirm == "tree" else "RESTABLECER EL ÁRBOL"
	_button(reset_text, Rect2(446.0, 204.0, 380.0, 50.0), _reset_tree, Pal.RED)
	_button("COMPRAS GRATIS EN EL ÁRBOL: " + ("SÍ" if GameData.admin_free_tree else "NO"), Rect2(56.0, 264.0, 560.0, 50.0), _toggle_free_tree, Pal.PURPLE)
	_button("ABRIR EL ÁRBOL", Rect2(626.0, 264.0, 300.0, 50.0), _open_tree, Pal.TEAL)
	_label("DESBLOQUEAR UNA CATEGORÍA CONCRETA:", Vector2(56.0, 336.0), 2.0, Pal.SILVER)
	for i in Catalog.TREE_BRANCHES.size():
		var branch: Dictionary = Catalog.TREE_BRANCHES[i]
		var column: int = i % 5
		var row: int = int(float(i) / 5.0)
		var b: PixelButton = _button(String(branch["short"]), Rect2(56.0 + float(column) * 236.0, 362.0 + float(row) * 54.0, 226.0, 46.0), _pick_category.bind(i), Color(String(branch["color"])).darkened(0.55))
		b.selected = i == _category
	var picked: Dictionary = Catalog.TREE_BRANCHES[_category]
	_button("COMPLETAR " + String(picked["short"]), Rect2(56.0, 534.0, 420.0, 50.0), _unlock_category, Pal.GREEN.darkened(0.2))
	_label("CON COMPRAS GRATIS ACTIVADAS NO SE GASTAN MONEDAS NI SE EXIGEN REQUISITOS.", Vector2(56.0, 604.0), 2.0, Pal.SILVER)


func _tree_max_levels() -> int:
	var total: int = 0
	for item in Catalog.TREE:
		var node: Dictionary = item
		total += int(node["lv"])
	return total


## Sube un nodo al maximo respetando las especializaciones incompatibles
## (si ya tiene la pareja, no lo compra).
func _max_node(node: Dictionary) -> void:
	var id: String = node["id"]
	var excluded: String = String(node.get("ex", ""))
	if excluded != "" and GameData.node_level(excluded) > 0:
		return
	GameData.tree[id] = int(node["lv"])


func _unlock_tree() -> void:
	for item in Catalog.TREE:
		_max_node(item)
	_done("ÁRBOL COMPLETO DESBLOQUEADO")


func _reset_tree() -> void:
	if _confirm != "tree":
		_confirm = "tree"
		_build_tab()
		return
	_confirm = ""
	GameData.tree = {}
	_done("ÁRBOL RESTABLECIDO")


func _toggle_free_tree() -> void:
	GameData.admin_free_tree = not GameData.admin_free_tree
	_done("COMPRAS GRATIS: " + ("SÍ" if GameData.admin_free_tree else "NO"))


func _open_tree() -> void:
	visible = false
	open_tree_requested.emit()


func _pick_category(index: int) -> void:
	_category = index
	_build_tab()


func _unlock_category() -> void:
	var branch: Dictionary = Catalog.TREE_BRANCHES[_category]
	for item in Catalog.TREE:
		var node: Dictionary = item
		if String(node["cat"]) == String(branch["id"]):
			_max_node(node)
	_done("CATEGORÍA %s COMPLETA" % String(branch["short"]))


# ----------------------------------------------------------------- tienda --

func _build_shop() -> void:
	_button("DESBLOQUEAR TODOS LOS COSMÉTICOS", Rect2(56.0, 176.0, 520.0, 50.0), _unlock_cosmetics, Pal.GREEN.darkened(0.2))
	_button("DESBLOQUEAR LOS 10 POWER-UPS", Rect2(586.0, 176.0, 470.0, 50.0), _unlock_powerups, Pal.ORANGE.darkened(0.3))
	_label("PROBAR SIN COMPRAR (NO SE GUARDA; DESAPARECE AL CERRAR EL JUEGO):", Vector2(56.0, 250.0), 2.0, Pal.SILVER)
	var slots: Array = [["skin", "HÉROE"], ["sword", "ESPADA"], ["trail", "ESTELA"], ["aura", "AURA"]]
	for i in slots.size():
		var slot: String = slots[i][0]
		var y: float = 280.0 + float(i) * 66.0
		_label(String(slots[i][1]), Vector2(56.0, y + 18.0), 2.0, Pal.YELLOW)
		_button("<", Rect2(200.0, y, 60.0, 52.0), _cycle_trial.bind(slot, -1), Pal.SLATE, 3.0)
		var item: Dictionary = GameData.equipped_item(slot)
		var name_button: PixelButton = _button(String(item.get("name", "")), Rect2(270.0, y, 340.0, 52.0), _cycle_trial.bind(slot, 1), Pal.NAVY)
		name_button.disabled = false
		_button(">", Rect2(620.0, y, 60.0, 52.0), _cycle_trial.bind(slot, 1), Pal.SLATE, 3.0)
	_button("QUITAR PRUEBAS", Rect2(200.0, 548.0, 300.0, 50.0), _clear_trials, Pal.RED.darkened(0.2))
	var preview: HeroPreview = HeroPreview.new()
	preview.px = 9.0
	_content.add_child(preview)
	preview.position = Vector2(900.0, 520.0)


func _unlock_cosmetics() -> void:
	for slot in ["skin", "sword", "trail", "aura"]:
		for item in Catalog.cosmetics(String(slot)):
			var entry: Dictionary = item
			GameData.owned[String(entry["id"])] = true
	_done("TODOS LOS COSMÉTICOS DESBLOQUEADOS")


func _unlock_powerups() -> void:
	for item in Catalog.POWERUPS:
		var entry: Dictionary = item
		if not GameData.is_powerup_owned(String(entry["id"])):
			GameData.powerups[String(entry["id"])] = false
	_done("POWER-UPS DESBLOQUEADOS (ACTÍVALOS EN LA TIENDA)")


func _cycle_trial(slot: String, direction: int) -> void:
	var list: Array = Catalog.cosmetics(slot)
	var index: int = posmod(int(_trial_index.get(slot, 0)) + direction, list.size())
	_trial_index[slot] = index
	var entry: Dictionary = list[index]
	GameData.try_cosmetic(slot, String(entry["id"]))
	_status = "PROBANDO: " + String(entry["name"])
	Sfx.play("click")
	_build_tab()


func _clear_trials() -> void:
	GameData.clear_trials()
	_done("PRUEBAS RETIRADAS")


# ---------------------------------------------------------------- pruebas --

func _build_tests() -> void:
	_label("MUNDO DE LA PRUEBA:", Vector2(56.0, 176.0), 2.0, Pal.SILVER)
	for i in Campaign.world_count():
		var world: Dictionary = Campaign.WORLDS[i]
		var b: PixelButton = _button(String(world["name"]), Rect2(56.0 + float(i) * 210.0, 198.0, 200.0, 42.0), _pick_test_world.bind(i), Color(String(world["color"])).darkened(0.45))
		b.selected = i == _test_world
	_label("ENEMIGO DEL MUNDO:", Vector2(56.0, 256.0), 2.0, Pal.SILVER)
	for i in 5:
		var data: Array = Bestiary.entry(_test_world, i)
		var b: PixelButton = _button(String(data[0]), Rect2(56.0 + float(i) * 236.0, 278.0, 228.0, 42.0), _pick_enemy.bind(i), Pal.RED.darkened(0.4))
		b.selected = i == _test_enemy
	_button("PROBAR ENEMIGO", Rect2(56.0, 330.0, 300.0, 46.0), _test_enemy_run, Pal.GREEN.darkened(0.2))
	_label("PATRONES, OBSTÁCULOS Y MECÁNICAS:", Vector2(56.0, 392.0), 2.0, Pal.SILVER)
	for i in _test_patterns.size():
		var entry: Array = _test_patterns[i]
		var column: int = i % 6
		var row: int = int(float(i) / 6.0)
		var kind: String = entry[2]
		var fill: Color = Pal.STEEL
		if kind == "MECÁNICA":
			fill = Pal.TEAL
		elif kind == "ENEMIGO":
			fill = Pal.PURPLE
		var b: PixelButton = _button(String(entry[1]), Rect2(56.0 + float(column) * 196.0, 414.0 + float(row) * 48.0, 188.0, 42.0), _pick_pattern.bind(i), fill)
		b.selected = i == _test_pattern
	_button("PROBAR PATRÓN", Rect2(56.0, 614.0, 300.0, 46.0), _test_pattern_run, Pal.GREEN.darkened(0.2))
	_button("NIVEL DE PRUEBA LIBRE", Rect2(366.0, 614.0, 320.0, 46.0), _test_free_run, Pal.BLUE)
	_button("INVENCIBLE: " + ("SÍ" if _invincible else "NO"), Rect2(696.0, 614.0, 260.0, 46.0), _toggle_invincible, Pal.ORANGE.darkened(0.3))
	_label("LAS PRUEBAS NO GUARDAN MONEDAS, RÉCORDS NI PROGRESO.", Vector2(366.0, 344.0), 2.0, Pal.LIME)


func _pick_test_world(world: int) -> void:
	_test_world = world
	_build_tab()


func _pick_enemy(index: int) -> void:
	_test_enemy = index
	_build_tab()


func _pick_pattern(index: int) -> void:
	_test_pattern = index
	_build_tab()


func _toggle_invincible() -> void:
	_invincible = not _invincible
	_build_tab()


func _start_test(creature: int, pattern: int) -> void:
	GameData.save_data()
	GameData.run = {"mode": "test", "world": _test_world, "creature": creature, "pattern": pattern, "invincible": _invincible}
	Transition.change_scene(GAME_SCENE)


func _test_enemy_run() -> void:
	_start_test(_test_enemy, -1)


func _test_pattern_run() -> void:
	var entry: Array = _test_patterns[_test_pattern]
	_start_test(-1, int(entry[0]))


func _test_free_run() -> void:
	_start_test(-1, -1)


# ----------------------------------------------------------------- dibujo --

func _draw_panel() -> void:
	TextCache.draw(_canvas, "ADMINISTRADOR", Vector2(56.0, 40.0), 6.0, Pal.ORANGE)
	var info: String = "MONEDAS %d   DIAMANTES %d" % [GameData.wallet, GameData.diamonds]
	TextCache.draw(_canvas, info, Vector2(1070.0 - TextCache.width(info, 2.0), 48.0), 2.0, Pal.YELLOW)
	var badge: String = "HERRAMIENTA DE DESARROLLO"
	TextCache.draw(_canvas, badge, Vector2(1070.0 - TextCache.width(badge, 2.0), 72.0), 2.0, Pal.SILVER)
	_canvas.draw_rect(Rect2(48.0, 160.0, 1184.0, 2.0), Color(Pal.ORANGE, 0.5))
	if _status != "":
		TextCache.draw(_canvas, "ÚLTIMA ACCIÓN: " + _status, Vector2(56.0, 672.0), 2.0, Pal.LIME)
	_draw_entry()
