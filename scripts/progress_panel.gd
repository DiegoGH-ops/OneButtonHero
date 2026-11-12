extends Control
## Pantalla de progreso: misiones diarias, logros y estadisticas.
## Se abre como pantalla superpuesta desde el menu principal.

signal closed

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

const TABS := ["MISIONES", "LOGROS", "ESTADÍSTICAS"]
const STATS := [
	["high_score", "RÉCORD DE PUNTOS"], ["best_distance", "RÉCORD DE DISTANCIA (M)"],
	["games_played", "PARTIDAS JUGADAS"], ["total_distance", "DISTANCIA TOTAL (M)"],
	["total_coins", "MONEDAS RECOGIDAS"], ["total_gems", "GEMAS RECOGIDAS"],
	["total_kills", "ENEMIGOS DERROTADOS"], ["nights_survived", "NOCHES SUPERADAS"],
	["powers_used", "PODERES USADOS"],
]

var _tab: int = 0
var _tab_buttons: Array = []
var _canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.82)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "PROGRESO", Vector2(64.0, 52.0), 7.0, Pal.YELLOW, 0)
	var close_button: PixelButton = UI.button(self, "X", Rect2(1140.0, 46.0, 76.0, 60.0), 4.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(close)
	for i in TABS.size():
		var tab: PixelButton = UI.button(self, TABS[i], Rect2(64.0 + float(i) * 252.0, 128.0, 240.0, 48.0), 3.0)
		tab.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(tab)
	_canvas = UI.layer(self, "Canvas")
	_canvas.draw.connect(_draw_content)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	GameData.refresh_missions()
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_select_tab(0)
	var first: PixelButton = _tab_buttons[0]
	first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _select_tab(tab: int) -> void:
	_tab = tab
	for i in _tab_buttons.size():
		var button: PixelButton = _tab_buttons[i]
		button.selected = i == _tab
	_canvas.queue_redraw()


func _text(text: String, pos: Vector2, px: float, color: Color) -> void:
	PixelFont.draw_text_shadowed(_canvas, text, pos, px, color, Pal.INK)


func _text_right(text: String, right: float, y: float, px: float, color: Color) -> void:
	_text(text, Vector2(right - PixelFont.text_width(text, px), y), px, color)


## Fila con fondo, usada por las tres pestanas.
func _row(rect: Rect2, done: bool) -> void:
	_canvas.draw_rect(rect, Pal.INK)
	var fill: Color = Pal.TEAL.lerp(Pal.NAVY, 0.4) if done else Pal.NAVY.lerp(Pal.INK, 0.35)
	_canvas.draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), fill)


func _draw_content() -> void:
	if _tab == 0:
		_draw_missions()
	elif _tab == 1:
		_draw_achievements()
	else:
		_draw_stats()


func _draw_missions() -> void:
	_text("MISIONES DE HOY - CAMBIAN CADA DÍA", Vector2(64.0, 204.0), 3.0, Pal.CYAN)
	for i in GameData.missions.size():
		var mission: Dictionary = GameData.missions[i]
		var id: String = mission["id"]
		var target: int = int(mission["target"])
		var done: bool = bool(GameData.mission_done.get(id, false))
		var value: int = target if done else mini(int(GameData.mission_progress.get(id, 0)), target)
		var rect: Rect2 = Rect2(64.0, 250.0 + float(i) * 128.0, 1152.0, 112.0)
		_row(rect, done)
		_text(GameData.mission_text(mission), rect.position + Vector2(28.0, 22.0), 4.0, Pal.WHITE)
		# Barra de progreso.
		var bar: Rect2 = Rect2(rect.position + Vector2(28.0, 70.0), Vector2(700.0, 20.0))
		_canvas.draw_rect(bar, Pal.INK)
		var ratio: float = float(value) / float(maxi(target, 1))
		_canvas.draw_rect(Rect2(bar.position + Vector2(4.0, 4.0), Vector2((bar.size.x - 8.0) * ratio, 12.0)), Pal.LIME if done else Pal.YELLOW)
		_text("%d / %d" % [value, target], bar.position + Vector2(720.0, 2.0), 2.0, Pal.SILVER)
		if done:
			_text_right("¡COMPLETADA!", rect.end.x - 28.0, rect.position.y + 40.0, 4.0, Pal.LIME)
		else:
			PixelArt.draw(_canvas, "coin_0", Vector2(rect.end.x - 200.0, rect.position.y + 36.0), 5.0)
			_text("+%d" % int(mission["reward"]), Vector2(rect.end.x - 150.0, rect.position.y + 42.0), 4.0, Pal.YELLOW)


func _draw_achievements() -> void:
	var list: Array = Catalog.ACHIEVEMENTS
	for i in list.size():
		var entry: Dictionary = list[i]
		var done: bool = bool(GameData.achievements.get(String(entry["id"]), false))
		var column: int = i % 2
		var row: int = int(float(i) / 2.0)
		var rect: Rect2 = Rect2(64.0 + float(column) * 580.0, 196.0 + float(row) * 68.0, 572.0, 62.0)
		_row(rect, done)
		PixelArt.draw(_canvas, "star", rect.position + Vector2(14.0, 13.0), 4.0, Color(1.0, 1.0, 1.0, 1.0) if done else Color(0.25, 0.25, 0.35, 1.0))
		_text(String(entry["name"]), rect.position + Vector2(64.0, 12.0), 3.0, Pal.YELLOW if done else Pal.WHITE)
		_text(String(entry["desc"]), rect.position + Vector2(64.0, 38.0), 2.0, Pal.SILVER)
		var value: int = mini(int(GameData.stats.get(String(entry["stat"]), 0)), int(entry["target"]))
		if done:
			_text_right("HECHO", rect.end.x - 16.0, rect.position.y + 14.0, 2.0, Pal.LIME)
		else:
			_text_right("%d/%d" % [value, int(entry["target"])], rect.end.x - 16.0, rect.position.y + 14.0, 2.0, Pal.SILVER)
		_text_right("+%d" % int(entry["reward"]), rect.end.x - 16.0, rect.position.y + 36.0, 2.0, Pal.YELLOW)


func _draw_stats() -> void:
	for i in STATS.size():
		var pair: Array = STATS[i]
		var rect: Rect2 = Rect2(64.0, 196.0 + float(i) * 50.0, 1152.0, 44.0)
		_row(rect, i % 2 == 0)
		_text(String(pair[1]), rect.position + Vector2(24.0, 12.0), 3.0, Pal.WHITE)
		_text_right(str(int(GameData.stats.get(String(pair[0]), 0))), rect.end.x - 24.0, rect.position.y + 12.0, 3.0, Pal.YELLOW)
	_text_right("MONEDERO: %d" % GameData.wallet, 1216.0, 660.0, 2.0, Pal.CYAN)
