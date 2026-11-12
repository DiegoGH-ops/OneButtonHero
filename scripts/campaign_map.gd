extends Control
## Mapa de campana: cinco mundos con veinte niveles cada uno. Muestra los
## niveles bloqueados, disponibles y superados, sus estrellas, el mejor rango
## y las recompensas pendientes, y permite jugar cualquier nivel desbloqueado.

signal closed

const UI = preload("res://scripts/ui.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Timing = preload("res://scripts/timing.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

const GAME_SCENE := "res://scenes/game.tscn"
const GRID_ORIGIN := Vector2(64.0, 262.0)
const CELL := Vector2(116.0, 110.0)

var _world: int = 0
var _level: int = 0
var _world_buttons: Array = []
var _level_buttons: Array = []
var _play_button: PixelButton
var _canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.82)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "CAMPAÑA", Vector2(64.0, 52.0), 7.0, Pal.YELLOW, 0)
	var close_button: PixelButton = UI.button(self, "X", Rect2(1140.0, 46.0, 76.0, 60.0), 4.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(close)
	for i in Campaign.world_count():
		var world: Dictionary = Campaign.WORLDS[i]
		var tab: PixelButton = UI.button(self, String(world["name"]), Rect2(64.0 + float(i) * 232.0, 128.0, 220.0, 48.0), 2.0)
		tab.pressed.connect(_select_world.bind(i))
		_world_buttons.append(tab)
	for i in Campaign.LEVELS_PER_WORLD:
		var column: int = i % 10
		var row: int = int(float(i) / 10.0)
		var button: PixelButton = UI.button(self, str(i + 1), Rect2(GRID_ORIGIN.x + float(column) * CELL.x, GRID_ORIGIN.y + float(row) * CELL.y, 100.0, 68.0), 4.0)
		button.pressed.connect(_select_level.bind(i))
		_level_buttons.append(button)
	_canvas = UI.layer(self, "Canvas")
	_canvas.draw.connect(_draw_content)
	_play_button = UI.button(self, "JUGAR", Rect2(900.0, 560.0, 300.0, 88.0), 6.0)
	_play_button.fill = Pal.GREEN
	_play_button.fill_hot = Pal.LIME
	_play_button.pressed.connect(_on_play_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	# Empieza en el ultimo mundo abierto y en su primer nivel sin superar.
	var world: int = 0
	for i in Campaign.world_count():
		if GameData.is_world_unlocked(i):
			world = i
	_select_world(world)
	_play_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _select_world(world: int) -> void:
	_world = clampi(world, 0, Campaign.world_count() - 1)
	for i in _world_buttons.size():
		var tab: PixelButton = _world_buttons[i]
		tab.selected = i == _world
		var entry: Dictionary = Campaign.WORLDS[i]
		tab.fill = Color(String(entry["color"])).darkened(0.45) if GameData.is_world_unlocked(i) else Pal.SLATE
	var pick: int = 0
	for i in Campaign.LEVELS_PER_WORLD:
		if GameData.is_level_unlocked(_world, i):
			pick = i
			if GameData.level_stars(_world, i) == 0:
				break
	_refresh_levels()
	_select_level(pick)


## Colorea cada nivel segun su estado: bloqueado, disponible o superado.
func _refresh_levels() -> void:
	for i in _level_buttons.size():
		var button: PixelButton = _level_buttons[i]
		var unlocked: bool = GameData.is_level_unlocked(_world, i)
		var stars: int = GameData.level_stars(_world, i)
		button.disabled = not unlocked
		button.caption = str(i + 1) if i < Campaign.LEVELS_PER_WORLD - 1 else "20"
		if stars > 0:
			button.fill = Pal.GREEN.darkened(0.2)
		elif i == Campaign.LEVELS_PER_WORLD - 1:
			button.fill = Pal.RED
		else:
			button.fill = Pal.BLUE


func _select_level(level: int) -> void:
	_level = clampi(level, 0, Campaign.LEVELS_PER_WORLD - 1)
	for i in _level_buttons.size():
		var button: PixelButton = _level_buttons[i]
		button.selected = i == _level
	_play_button.disabled = not GameData.is_level_unlocked(_world, _level)
	_canvas.queue_redraw()


func _on_play_pressed() -> void:
	if not GameData.is_level_unlocked(_world, _level):
		Sfx.play("error")
		return
	GameData.run = {"mode": "level", "world": _world, "level": _level}
	Transition.change_scene(GAME_SCENE)


func _text(text: String, pos: Vector2, px: float, color: Color) -> void:
	PixelFont.draw_text_shadowed(_canvas, text, pos, px, color, Pal.INK)


func _draw_content() -> void:
	var world: Dictionary = Campaign.WORLDS[_world]
	var world_color: Color = Color(String(world["color"]))
	var open_world: bool = GameData.is_world_unlocked(_world)

	# Progreso total y cabecera del mundo.
	var total: String = "ESTRELLAS %d/%d   DIAMANTES %d" % [GameData.total_stars(), Campaign.world_count() * Campaign.LEVELS_PER_WORLD * 3, GameData.diamonds]
	_text(total, Vector2(1116.0 - PixelFont.text_width(total, 2.0), 72.0), 2.0, Pal.CYAN)
	_text("MUNDO %d: %s" % [_world + 1, String(world["name"])], Vector2(64.0, 196.0), 4.0, world_color)
	_text(String(world["subtitle"]), Vector2(64.0, 232.0), 2.0, Pal.SILVER)
	var world_stars: int = 0
	for i in Campaign.LEVELS_PER_WORLD:
		world_stars += GameData.level_stars(_world, i)
	var summary: String = "%d/60 ESTRELLAS" % world_stars
	if not open_world:
		summary = "BLOQUEADO: SUPERA EL NIVEL 20 DEL MUNDO ANTERIOR"
	_text(summary, Vector2(1216.0 - PixelFont.text_width(summary, 2.0), 204.0), 2.0, Pal.YELLOW if open_world else Pal.RED)

	# Estrellas bajo cada nivel; candado en los bloqueados; hito con diamantes.
	for i in Campaign.LEVELS_PER_WORLD:
		var column: int = i % 10
		var row: int = int(float(i) / 10.0)
		var base: Vector2 = GRID_ORIGIN + Vector2(float(column) * CELL.x, float(row) * CELL.y + 72.0)
		var stars: int = GameData.level_stars(_world, i)
		for s in 3:
			var tint: Color = Color(1.0, 1.0, 1.0, 1.0) if s < stars else Color(0.18, 0.2, 0.32, 1.0)
			PixelArt.draw(_canvas, "star", base + Vector2(8.0 + float(s) * 28.0, 0.0), 3.0, tint)
		if stars == 0 and Campaign.first_clear_diamonds(_world, i) > 0:
			PixelArt.draw(_canvas, "gem", base + Vector2(72.0, -92.0), 3.0)

	# Ficha del nivel elegido.
	var def: Dictionary = Campaign.level_def(_world, _level)
	var record: Dictionary = GameData.level_record(_world, _level)
	_canvas.draw_rect(Rect2(64.0, 500.0, 800.0, 168.0), Pal.INK)
	_canvas.draw_rect(Rect2(68.0, 504.0, 792.0, 160.0), Pal.NAVY.lerp(Pal.INK, 0.4))
	var title: String = "NIVEL %s" % String(def["name"])
	if bool(def["final"]):
		title += " - PRUEBA FINAL"
	_text(title, Vector2(88.0, 520.0), 4.0, Pal.YELLOW)
	_text("DIFICULTAD: %s" % Campaign.difficulty_name(_world, _level), Vector2(88.0, 562.0), 2.0, Pal.ORANGE)
	_text("RECORRIDO: %d M   VELOCIDAD: %d" % [int(def["meters"]), int(float(def["speed"]) / 48.0)], Vector2(88.0, 586.0), 2.0, Pal.WHITE)
	if record.is_empty():
		var prize: String = "PRIMERA VEZ: +%d MONEDAS" % int(def["coins"])
		var gems: int = Campaign.first_clear_diamonds(_world, _level)
		if gems > 0:
			prize += "  +%d DIAMANTES" % gems
		_text(prize, Vector2(88.0, 614.0), 2.0, Pal.LIME)
		_text("3 ESTRELLAS: +1 DIAMANTE", Vector2(88.0, 638.0), 2.0, Pal.CYAN)
	else:
		var rank: int = clampi(int(record.get("rank", 0)), 0, 6)
		_text("MEJOR RANGO: %s (%s)" % [String(Timing.RANK_NAMES[rank]), String(Timing.RANK_TITLES[rank])], Vector2(88.0, 614.0), 2.0, Pal.LIME)
		_text("RÉCORD: %d PUNTOS" % int(record.get("score", 0)), Vector2(88.0, 638.0), 2.0, Pal.CYAN)
