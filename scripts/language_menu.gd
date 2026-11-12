extends Control
## Selector de idioma (Configuracion > IDIOMA / LANGUAGE). Cada idioma se
## muestra con su nombre en su propia escritura. Al elegir uno, todo el
## juego cambia al instante y la preferencia se guarda.

signal closed

const UI = preload("res://scripts/ui.gd")
const Pal = preload("res://scripts/palette.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")

const COLUMNS := 3
const CELL := Vector2(256.0, 62.0)
const ORIGIN := Vector2(256.0, 168.0)

var _canvas: Control
var _hover: int = -1
var _focus: int = 0
var _time: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = UI.SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.dim(self, 0.8)
	UI.panel(self, Rect2(232.0, 56.0, 816.0, 612.0))
	_canvas = UI.layer(self, "Canvas")
	_canvas.draw.connect(_draw_menu)
	var close_button: PixelButton = UI.button(self, "X", Rect2(972.0, 72.0, 60.0, 50.0), 3.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(_close)
	_focus = maxi(_index_of(Loc.language), 0)


func _index_of(code: String) -> int:
	for i in Loc.LANGUAGES.size():
		if String(Array(Loc.LANGUAGES[i])[0]) == code:
			return i
	return -1


func _cell_rect(i: int) -> Rect2:
	var col: int = i % COLUMNS
	var row: int = int(float(i) / float(COLUMNS))
	return Rect2(ORIGIN + Vector2(float(col) * (CELL.x + 8.0), float(row) * (CELL.y + 6.0)), CELL)


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_hover = _cell_at(motion.position)
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var i: int = _cell_at(click.position)
		if i >= 0:
			_choose(i)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
	elif event.is_action_pressed("ui_right"):
		_focus = mini(_focus + 1, Loc.LANGUAGES.size() - 1)
	elif event.is_action_pressed("ui_left"):
		_focus = maxi(_focus - 1, 0)
	elif event.is_action_pressed("ui_down"):
		_focus = mini(_focus + COLUMNS, Loc.LANGUAGES.size() - 1)
	elif event.is_action_pressed("ui_up"):
		_focus = maxi(_focus - COLUMNS, 0)
	elif event.is_action_pressed("ui_accept"):
		_choose(_focus)
	else:
		return
	get_viewport().set_input_as_handled()


func _cell_at(point: Vector2) -> int:
	for i in Loc.LANGUAGES.size():
		if _cell_rect(i).has_point(point):
			return i
	return -1


func _choose(i: int) -> void:
	var code: String = String(Array(Loc.LANGUAGES[i])[0])
	Sfx.play("click")
	Loc.set_language(code)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _draw_menu() -> void:
	var title: String = Loc.s("IDIOMA / LANGUAGE")
	var w: float = PixelFont.text_width(title, 4.0)
	PixelFont.draw_text_shadowed(_canvas, title, Vector2(roundf(640.0 - w * 0.5), 96.0), 4.0, Pal.YELLOW, Pal.INK)
	for i in Loc.LANGUAGES.size():
		var code: String = String(Array(Loc.LANGUAGES[i])[0])
		var rect: Rect2 = _cell_rect(i)
		var current: bool = code == Loc.language
		var hot: bool = i == _hover or i == _focus
		_canvas.draw_rect(rect, Pal.INK)
		var fill: Color = Pal.TEAL if current else Pal.NAVY
		if hot:
			fill = fill.lightened(0.15)
		_canvas.draw_rect(rect.grow(-3.0), fill)
		if current:
			_canvas.draw_rect(rect, Pal.LIME, false, 3.0)
		elif hot:
			_canvas.draw_rect(rect, Color(Pal.YELLOW, 0.6 + 0.4 * sin(_time * 6.0)), false, 3.0)
		var px: float = 3.0
		var name_w: float = Loc.native_width(code, px)
		if name_w > rect.size.x - 24.0:
			px = 2.0
			name_w = Loc.native_width(code, px)
		Loc.draw_native(_canvas, code, Vector2(roundf(rect.get_center().x - name_w * 0.5), roundf(rect.get_center().y - 3.5 * px)), px, Pal.WHITE)
		if current:
			_canvas.draw_rect(Rect2(rect.position + Vector2(10.0, rect.size.y * 0.5 - 4.0), Vector2(8.0, 8.0)), Pal.LIME)
