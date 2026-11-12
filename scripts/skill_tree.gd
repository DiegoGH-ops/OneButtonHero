extends Control
## Arbol de mejoras: un mapa grande con 15 categorias (mas de 120 mejoras)
## que se explora con zoom y desplazamiento, como el arbol de habilidades de
## un RPG. Controles:
##   - Rueda del raton / gesto de pellizco / botones + y -: zoom (con limites).
##   - Arrastrar con el raton o el dedo (o WASD / flechas): desplazarse.
##   - Lista de categorias: centra la vista en una categoria.
##   - VISTA GENERAL (o tecla Inicio / 0): todo el arbol de un vistazo.
##   - Q / E: categoria anterior / siguiente.
## Los datos estan en Catalog.TREE; las compras en GameData; los efectos se
## aplican con buffs.gd. Rendimiento: solo se dibuja lo que se ve, los
## textos son texturas en cache (text_cache.gd) y al alejarse se usa un
## nivel de detalle reducido.

signal closed

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Buffs = preload("res://scripts/buffs.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Fx = preload("res://scripts/fx.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const TextCache = preload("res://scripts/text_cache.gd")
const Pal = preload("res://scripts/palette.gd")

## Geometria del mapa (coordenadas del arbol, independientes del zoom).
const NODE_SIZE := Vector2(184.0, 100.0)
const STEP := Vector2(232.0, 150.0)
const REGION := Vector2(1260.0, 620.0)
const NODE_OFFSET := Vector2(60.0, 120.0)
## Zona de la pantalla que ocupa cada parte.
const SIDEBAR := Rect2(20.0, 104.0, 218.0, 596.0)
const MAP_RECT := Rect2(246.0, 104.0, 676.0, 596.0)
const INFO_RECT := Rect2(930.0, 104.0, 330.0, 596.0)
const ZOOM_MAX := 1.6
## Por debajo de este zoom los nodos se dibujan sin texto.
const DETAIL_ZOOM := 0.42
const TIER_COLORS := {
	"normal": Color("94b0c2"), "advanced": Color("41a6f6"), "epic": Color("b06fd0"),
	"special": Color("ffcd75"), "legendary": Color("ef7d57"), "secret": Color("b13e53"),
}

var _selected: String = ""
var _branch: int = 0
var _time: float = 0.0
var _map: Control
var _sidebar: Control
var _info: Control
var _buy_button: PixelButton
var _toaster: Toaster
var _zoom_buttons: Array = []

# Camara del mapa.
var _zoom: float = 0.5
var _zoom_target: float = 0.5
var _center: Vector2 = Vector2.ZERO
var _center_target: Vector2 = Vector2.ZERO
var _zoom_min: float = 0.1
var _bounds: Rect2 = Rect2()
# Arrastre.
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragging: bool = false
# Momento en que se compro cada nodo (animacion de desbloqueo).
var _bought_at: Dictionary = {}
var _hover_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	_compute_bounds()

	_map = Control.new()
	_map.name = "Map"
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_child(_map)
	_map.position = MAP_RECT.position
	_map.size = MAP_RECT.size
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	_map.mouse_exited.connect(func() -> void: _hover_id = "")

	_sidebar = Control.new()
	_sidebar.name = "Sidebar"
	_sidebar.mouse_filter = Control.MOUSE_FILTER_STOP
	_sidebar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(_sidebar)
	_sidebar.position = SIDEBAR.position
	_sidebar.size = SIDEBAR.size
	_sidebar.draw.connect(_draw_sidebar)
	_sidebar.gui_input.connect(_on_sidebar_input)

	_info = Control.new()
	_info.name = "Info"
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_info.position = INFO_RECT.position
	_info.size = INFO_RECT.size
	_info.draw.connect(_draw_info)

	var close_button: PixelButton = UI.button(self, "X", Rect2(1184.0, 22.0, 76.0, 60.0), 4.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(close)

	# Controles de zoom sobre el mapa.
	var zoom_in: PixelButton = UI.button(self, "+", Rect2(MAP_RECT.end.x - 60.0, MAP_RECT.position.y + 12.0, 48.0, 44.0), 3.0)
	zoom_in.pressed.connect(_zoom_by.bind(1.35, Vector2.ZERO, false))
	var zoom_out: PixelButton = UI.button(self, "-", Rect2(MAP_RECT.end.x - 60.0, MAP_RECT.position.y + 62.0, 48.0, 44.0), 3.0)
	zoom_out.pressed.connect(_zoom_by.bind(1.0 / 1.35, Vector2.ZERO, false))
	var overview: PixelButton = UI.button(self, "VISTA GENERAL", Rect2(MAP_RECT.position.x + 12.0, MAP_RECT.end.y - 56.0, 200.0, 44.0), 2.0)
	overview.fill = Pal.PURPLE
	overview.fill_hot = Pal.RED
	overview.pressed.connect(show_overview)
	_zoom_buttons = [zoom_in, zoom_out, overview]
	for item in _zoom_buttons:
		var button: PixelButton = item
		button.focus_mode = Control.FOCUS_NONE

	_buy_button = UI.button(self, "MEJORAR", Rect2(INFO_RECT.position.x + 16.0, INFO_RECT.end.y - 76.0, INFO_RECT.size.x - 32.0, 62.0), 3.0)
	_buy_button.fill = Pal.GREEN
	_buy_button.fill_hot = Pal.LIME
	_buy_button.pressed.connect(_buy_selected)

	_toaster = Toaster.new()
	add_child(_toaster)
	GameData.wallet_changed.connect(queue_redraw)


func _compute_bounds() -> void:
	var cols: int = 0
	var rows: int = 0
	for item in Catalog.TREE_BRANCHES:
		var entry: Dictionary = item
		var cell: Array = entry["cell"]
		cols = maxi(cols, int(cell[0]) + 1)
		rows = maxi(rows, int(cell[1]) + 1)
	_bounds = Rect2(Vector2.ZERO, Vector2(float(cols) * REGION.x, float(rows) * REGION.y))
	_zoom_min = minf(MAP_RECT.size.x / _bounds.size.x, MAP_RECT.size.y / _bounds.size.y) * 0.92


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# Camara suave: el zoom y el centro se acercan a su objetivo.
	var k: float = 1.0 - exp(-delta * 11.0)
	_zoom = lerpf(_zoom, _zoom_target, k)
	_center = _center.lerp(_center_target, k)
	_pan_with_keys(delta)
	_map.queue_redraw()
	_sidebar.queue_redraw()


func _pan_with_keys(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		move.y += 1.0
	if move != Vector2.ZERO:
		_center_target = _clamp_center(_center_target + move.normalized() * 900.0 * delta / maxf(_zoom, 0.05))


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
	match key.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom_by(1.35, Vector2.ZERO, false)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_by(1.0 / 1.35, Vector2.ZERO, false)
		KEY_HOME, KEY_0, KEY_KP_0:
			show_overview()
		KEY_Q:
			focus_branch(posmod(_branch - 1, Catalog.TREE_BRANCHES.size()))
		KEY_E:
			focus_branch(posmod(_branch + 1, Catalog.TREE_BRANCHES.size()))
		KEY_ENTER, KEY_KP_ENTER:
			_buy_selected()
		_:
			return
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	Sfx.play_music("shop")
	if _selected == "":
		_selected = String(Catalog.TREE[0]["id"])
	# Empieza mostrando todo el arbol y se acerca a la primera categoria.
	_zoom = _zoom_min
	_center = _bounds.get_center()
	focus_branch(_branch)
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# ------------------------------------------------------------------ camara --

func _to_world(local: Vector2) -> Vector2:
	return (local - _map.size * 0.5) / _zoom + _center


func _to_local(world: Vector2) -> Vector2:
	return (world - _center) * _zoom + _map.size * 0.5


func _clamp_center(c: Vector2) -> Vector2:
	var margin: Vector2 = Vector2(200.0, 150.0)
	return Vector2(clampf(c.x, _bounds.position.x - margin.x, _bounds.end.x + margin.x), clampf(c.y, _bounds.position.y - margin.y, _bounds.end.y + margin.y))


## Zoom manteniendo fijo el punto `anchor` (coordenadas del mapa). Sin
## ancla, se usa el centro del mapa.
func _zoom_by(factor: float, anchor: Vector2, use_anchor: bool) -> void:
	var new_zoom: float = clampf(_zoom_target * factor, _zoom_min, ZOOM_MAX)
	if use_anchor:
		var world_point: Vector2 = (anchor - _map.size * 0.5) / _zoom_target + _center_target
		_center_target = _clamp_center(world_point - (anchor - _map.size * 0.5) / new_zoom)
	_zoom_target = new_zoom


func show_overview() -> void:
	_zoom_target = _zoom_min
	_center_target = _bounds.get_center()


## Centra la vista en una categoria y la encuadra.
func focus_branch(index: int) -> void:
	_branch = clampi(index, 0, Catalog.TREE_BRANCHES.size() - 1)
	var rect: Rect2 = _region_rect(Catalog.TREE_BRANCHES[_branch])
	_center_target = rect.get_center()
	_zoom_target = clampf(minf(_map.size.x / rect.size.x, _map.size.y / rect.size.y) * 0.96, _zoom_min, ZOOM_MAX)


# ---------------------------------------------------------------- geometria --

func _region_origin(branch: Dictionary) -> Vector2:
	var cell: Array = branch["cell"]
	return Vector2(float(cell[0]) * REGION.x, float(cell[1]) * REGION.y)


func _region_rect(branch: Dictionary) -> Rect2:
	return Rect2(_region_origin(branch) + Vector2(16.0, 16.0), REGION - Vector2(32.0, 40.0))


func _node_rect(node: Dictionary) -> Rect2:
	var branch: Dictionary = Catalog.branch(String(node["cat"]))
	var pos: Array = node["pos"]
	var origin: Vector2 = _region_origin(branch) + NODE_OFFSET + Vector2(float(pos[0]) * STEP.x, float(pos[1]) * STEP.y)
	var rect: Rect2 = Rect2(origin, NODE_SIZE)
	if String(node["tier"]) == "legendary":
		rect = rect.grow(8.0)
	return rect


func _visible_world() -> Rect2:
	var top_left: Vector2 = _to_world(Vector2.ZERO)
	return Rect2(top_left, _map.size / _zoom)


## Estado de un nodo: 0 bloqueado, 1 disponible, 2 comprado, 3 al maximo.
func _state(id: String) -> int:
	if GameData.node_price(id) < 0:
		return 3
	var level: int = GameData.node_level(id)
	if GameData.node_block_reason(id) != "":
		return 2 if level > 0 else 0
	return 2 if level > 0 else 1


func _node_at(local: Vector2) -> String:
	var world_point: Vector2 = _to_world(local)
	for item in Catalog.TREE:
		var node: Dictionary = item
		if _node_rect(node).grow(6.0).has_point(world_point):
			return String(node["id"])
	return ""


# ------------------------------------------------------------------- input --

func _on_map_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.15, button.position, true)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.15, button.position, true)
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT or button.button_index == MOUSE_BUTTON_MIDDLE:
			if button.pressed:
				_pressing = true
				_dragging = false
				_press_pos = button.position
			else:
				if _pressing and not _dragging and button.button_index == MOUSE_BUTTON_LEFT:
					var id: String = _node_at(button.position)
					if id != "":
						if id == _selected and button.double_click:
							_buy_selected()
						else:
							_select_node(id)
				_pressing = false
				_dragging = false
		_map.accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _pressing:
			if not _dragging and motion.position.distance_to(_press_pos) > 6.0:
				_dragging = true
			if _dragging:
				# Arrastre directo: el mapa sigue al cursor sin retraso.
				_center_target = _clamp_center(_center_target - motion.relative / _zoom)
				_center = _center_target
		else:
			_hover_id = _node_at(motion.position)
			_map.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_id != "" else Control.CURSOR_DRAG
		_map.accept_event()
		return
	var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify != null:
		_zoom_by(magnify.factor, magnify.position, true)
		_map.accept_event()
		return
	var pan: InputEventPanGesture = event as InputEventPanGesture
	if pan != null:
		_center_target = _clamp_center(_center_target + pan.delta * 12.0 / _zoom)
		_map.accept_event()


func _on_sidebar_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = int((button.position.y - 8.0) / _sidebar_step())
	if index >= 0 and index < Catalog.TREE_BRANCHES.size():
		Sfx.play("click")
		focus_branch(index)
	_sidebar.accept_event()


func _sidebar_step() -> float:
	return (SIDEBAR.size.y - 16.0) / float(Catalog.TREE_BRANCHES.size())


# ---------------------------------------------------------------- compras --

func _select_node(id: String) -> void:
	if _selected != id:
		Sfx.play("hover")
	_selected = id
	var node: Dictionary = Catalog.tree_node(id)
	var cat: String = node.get("cat", "")
	for i in Catalog.TREE_BRANCHES.size():
		var entry: Dictionary = Catalog.TREE_BRANCHES[i]
		if String(entry["id"]) == cat:
			_branch = i
	_refresh()


func _refresh() -> void:
	queue_redraw()
	_info.queue_redraw()
	var price: int = GameData.node_price(_selected)
	var reason: String = GameData.node_block_reason(_selected)
	if price < 0:
		_buy_button.caption = "NIVEL MÁXIMO"
		_buy_button.disabled = true
	elif GameData.admin_free_tree:
		_buy_button.caption = "MEJORAR GRATIS"
		_buy_button.disabled = reason != ""
	else:
		_buy_button.caption = "MEJORAR"
		_buy_button.disabled = reason != "" or GameData.wallet < price


func _buy_selected() -> void:
	if _selected == "":
		return
	var reason: String = GameData.node_block_reason(_selected)
	if reason != "":
		Sfx.play("error")
		_toaster.show_toast(reason, Pal.SILVER)
		return
	if not GameData.buy_node(_selected):
		Sfx.play("error")
		_toaster.show_toast("MONEDAS INSUFICIENTES", Pal.RED)
		_refresh()
		return
	var node: Dictionary = Catalog.tree_node(_selected)
	var accent: Color = Color(String(Catalog.branch(String(node["cat"]))["color"]))
	var level: int = GameData.node_level(_selected)
	_bought_at[_selected] = _time
	Sfx.play("upgrade")
	if level >= int(node["lv"]):
		Sfx.play("unlock")
	var center: Vector2 = _to_local(_node_rect(node).get_center())
	Fx.burst(_map, center, accent, 26, 420.0, 0.7, 9.0, 500.0, 180.0, Vector2.UP)
	Fx.burst(_map, center, Pal.WHITE, 12, 260.0, 0.4, 6.0, 0.0, 180.0, Vector2.UP)
	Fx.ring(_map, center, Pal.YELLOW, 70.0 + 30.0 * _zoom)
	Fx.ring(_map, center, accent, 120.0)
	var text: String = "¡%s NIVEL %d!" % [String(node["name"]), level]
	if level >= int(node["lv"]):
		text = "¡%s COMPLETADA!" % String(node["name"])
	_toaster.show_toast(text, Pal.LIME)
	_refresh()


# ------------------------------------------------------------------ dibujo --

## Fondo, cabecera y marcos de las tres zonas.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, UI.SCREEN), Color(0.03, 0.035, 0.07, 0.97))
	# Degradado sutil y vineta.
	for i in 12:
		var t: float = float(i) / 11.0
		draw_rect(Rect2(0.0, float(i) * 60.0, 1280.0, 60.0), Color(Pal.PURPLE, 0.05 * (1.0 - t)))
	# Cabecera.
	TextCache.draw(self, "ÁRBOL DE MEJORAS", Vector2(28.0, 26.0), 6.0, Pal.YELLOW)
	var total_levels: int = GameData.tree_total_levels()
	var max_levels: int = 0
	var complete: int = 0
	for item in Catalog.TREE:
		var node: Dictionary = item
		max_levels += int(node["lv"])
		if GameData.node_level(String(node["id"])) >= int(node["lv"]):
			complete += 1
	var pct: int = int(100.0 * float(total_levels) / float(maxi(max_levels, 1)))
	TextCache.draw(self, "NIVELES %d/%d  -  MEJORAS COMPLETAS %d/%d  -  %d%%" % [total_levels, max_levels, complete, Catalog.TREE.size(), pct], Vector2(30.0, 76.0), 2.0, Pal.SILVER)
	# Barra de progreso global.
	draw_rect(Rect2(560.0, 76.0, 300.0, 12.0), Pal.INK)
	draw_rect(Rect2(562.0, 78.0, 296.0 * float(pct) / 100.0, 8.0), Pal.YELLOW)
	# Monedero y diamantes.
	_draw_purse(Vector2(880.0, 24.0), "coin_0", str(GameData.wallet), Pal.YELLOW)
	_draw_purse(Vector2(1036.0, 24.0), "gem", str(GameData.diamonds), Pal.CYAN)
	if GameData.admin_free_tree:
		TextCache.draw(self, "MODO ADMIN: MEJORAS GRATIS", Vector2(880.0, 76.0), 2.0, Pal.ORANGE)
	# Marcos.
	_frame(SIDEBAR, Pal.STEEL)
	_frame(MAP_RECT, Pal.YELLOW.darkened(0.4))
	_frame(INFO_RECT, Pal.STEEL)


func _draw_purse(pos: Vector2, sprite: String, text: String, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(144.0, 56.0)), Pal.INK)
	draw_rect(Rect2(pos + Vector2(4.0, 4.0), Vector2(136.0, 48.0)), Pal.NAVY.darkened(0.4))
	PixelArt.draw(self, sprite, pos + Vector2(10.0, 14.0), 3.0)
	var w: float = TextCache.width(text, 3.0)
	TextCache.draw(self, text, pos + Vector2(132.0 - w, 18.0), 3.0, color)


func _frame(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(6.0, 6.0), rect.size), Color(0.0, 0.0, 0.0, 0.4))
	draw_rect(rect.grow(4.0), Pal.INK)
	draw_rect(rect.grow(2.0), color)
	draw_rect(rect, Color(0.05, 0.06, 0.11))


func _draw_sidebar() -> void:
	var step: float = _sidebar_step()
	for i in Catalog.TREE_BRANCHES.size():
		var branch: Dictionary = Catalog.TREE_BRANCHES[i]
		var accent: Color = Color(String(branch["color"]))
		var y: float = 8.0 + float(i) * step
		var row: Rect2 = Rect2(6.0, y, SIDEBAR.size.x - 12.0, step - 4.0)
		var selected: bool = i == _branch
		_sidebar.draw_rect(row, accent.darkened(0.55) if selected else Color(accent.darkened(0.8), 0.9))
		if selected:
			_sidebar.draw_rect(Rect2(row.position, Vector2(4.0, row.size.y)), accent)
		PixelArt.draw(_sidebar, String(branch["icon"]), row.position + Vector2(10.0, 6.0), 2.0)
		var label: String = String(branch["short"])
		TextCache.draw(_sidebar, label, row.position + Vector2(36.0, 8.0), 2.0, Pal.WHITE if selected else Pal.SILVER)
		# Progreso de la categoria.
		var have: int = GameData.branch_levels(String(branch["id"]))
		var total: int = 0
		for item in Catalog.TREE:
			var node: Dictionary = item
			if String(node["cat"]) == String(branch["id"]):
				total += int(node["lv"])
		var ratio: float = float(have) / float(maxi(total, 1))
		_sidebar.draw_rect(Rect2(row.position.x + 36.0, row.end.y - 8.0, row.size.x - 46.0, 4.0), Pal.INK)
		_sidebar.draw_rect(Rect2(row.position.x + 36.0, row.end.y - 8.0, (row.size.x - 46.0) * ratio, 4.0), Pal.YELLOW if ratio >= 1.0 else accent)


func _draw_map() -> void:
	var map_size: Vector2 = _map.size
	_map.draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.035, 0.04, 0.08))
	var view: Rect2 = _visible_world()
	var detail: bool = _zoom >= DETAIL_ZOOM
	_map.draw_set_transform(map_size * 0.5 - _center * _zoom, 0.0, Vector2(_zoom, _zoom))
	_draw_backdrop(view)
	for item in Catalog.TREE_BRANCHES:
		_draw_region(item, view, detail)
	_draw_links(view)
	for item in Catalog.TREE:
		var node: Dictionary = item
		var rect: Rect2 = _node_rect(node)
		if not view.intersects(rect.grow(40.0)):
			continue
		_draw_node(node, rect, detail)
	_map.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Indicadores sobre el mapa (sin zoom).
	var zoom_text: String = "ZOOM %d%%" % int(roundf(_zoom * 100.0))
	TextCache.draw(_map, zoom_text, Vector2(map_size.x - 80.0 - TextCache.width(zoom_text, 2.0), 22.0), 2.0, Pal.SILVER)
	TextCache.draw(_map, "RUEDA: ZOOM - ARRASTRA: MOVER - Q/E: CATEGORÍA", Vector2(226.0, map_size.y - 30.0), 2.0, Color(Pal.SILVER, 0.8))


## Constelacion de puntos de fondo (solo cerca, para dar profundidad).
func _draw_backdrop(view: Rect2) -> void:
	if _zoom < 0.3:
		return
	var cell: float = 120.0
	var x0: int = int(floor(view.position.x / cell))
	var y0: int = int(floor(view.position.y / cell))
	var cols: int = int(view.size.x / cell) + 2
	var rows: int = int(view.size.y / cell) + 2
	for gx in cols:
		for gy in rows:
			var i: int = x0 + gx
			var j: int = y0 + gy
			var h: float = PixelArt.hash01(i * 73 + j, 7)
			if h < 0.55:
				continue
			var p: Vector2 = Vector2(float(i) * cell + h * 60.0, float(j) * cell + PixelArt.hash01(j * 31 + i, 9) * 60.0)
			var twinkle: float = 0.25 + 0.2 * sin(_time * 1.5 + h * 20.0)
			_map.draw_rect(Rect2(p, Vector2(4.0, 4.0)), Color(Pal.SILVER, twinkle))


func _draw_region(branch: Dictionary, view: Rect2, detail: bool) -> void:
	var rect: Rect2 = _region_rect(branch)
	if not view.intersects(rect):
		return
	var accent: Color = Color(String(branch["color"]))
	var line: float = maxf(3.0, 2.0 / _zoom)
	_map.draw_rect(rect, Color(accent.darkened(0.82), 0.75))
	_map.draw_rect(Rect2(rect.position, Vector2(rect.size.x, line)), Color(accent, 0.7))
	_map.draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - line), Vector2(rect.size.x, line)), Color(accent, 0.35))
	_map.draw_rect(Rect2(rect.position, Vector2(line, rect.size.y)), Color(accent, 0.5))
	_map.draw_rect(Rect2(rect.position + Vector2(rect.size.x - line, 0.0), Vector2(line, rect.size.y)), Color(accent, 0.5))
	# Titulo legible a cualquier zoom (crece al alejarse, sin salirse).
	var title: String = String(branch["name"]) if detail else String(branch["short"])
	var px: float = clampf(3.0 / _zoom, 4.0, (rect.size.x - 120.0) / float(maxi(title.length(), 1) * PixelFont.ADVANCE))
	var icon_px: float = px * 0.9
	PixelArt.draw(_map, String(branch["icon"]), rect.position + Vector2(24.0, 22.0), icon_px)
	TextCache.draw(_map, title, rect.position + Vector2(24.0 + icon_px * 14.0, 26.0), px, accent.lightened(0.2))
	# Progreso de la categoria.
	var have: int = GameData.branch_levels(String(branch["id"]))
	var total: int = 0
	for item in Catalog.TREE:
		var node: Dictionary = item
		if String(node["cat"]) == String(branch["id"]):
			total += int(node["lv"])
	var ratio: float = float(have) / float(maxi(total, 1))
	var bar_y: float = rect.end.y - 24.0 - line
	_map.draw_rect(Rect2(rect.position.x + 24.0, bar_y, rect.size.x - 48.0, 10.0 + line), Pal.INK)
	_map.draw_rect(Rect2(rect.position.x + 24.0, bar_y, (rect.size.x - 48.0) * ratio, 10.0 + line), Pal.YELLOW if ratio >= 1.0 else accent)
	if detail:
		TextCache.draw(_map, "%d/%d" % [have, total], Vector2(rect.end.x - 120.0, rect.position.y + 30.0), 3.0, Pal.SILVER)


## Lineas de dependencia: codo en angulo recto dentro de la categoria y
## linea discontinua cuando el requisito esta en otra categoria. Las ya
## desbloqueadas brillan y llevan un pulso de energia que fluye.
func _draw_links(view: Rect2) -> void:
	var width: float = maxf(6.0, 2.5 / _zoom)
	for item in Catalog.TREE:
		var node: Dictionary = item
		var rect: Rect2 = _node_rect(node)
		for req in node.get("req", []):
			var parent: Dictionary = Catalog.tree_node(String(req))
			if parent.is_empty():
				continue
			var from_rect: Rect2 = _node_rect(parent)
			var box: Rect2 = from_rect.merge(rect)
			if not view.intersects(box.grow(20.0)):
				continue
			var unlocked: bool = GameData.node_level(String(req)) > 0
			var accent: Color = Color(String(Catalog.branch(String(node["cat"]))["color"]))
			if String(parent["cat"]) != String(node["cat"]):
				_dashed(from_rect.get_center(), rect.get_center(), Color(accent if unlocked else Pal.SILVER, 0.45 if unlocked else 0.2), width * 0.6)
				continue
			var a: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y)
			var b: Vector2 = Vector2(rect.position.x, rect.get_center().y)
			if b.x < a.x:
				a = Vector2(from_rect.get_center().x, from_rect.end.y)
				b = Vector2(rect.get_center().x, rect.position.y)
			var mid: float = (a.x + b.x) * 0.5
			var color: Color = accent if unlocked else Color(Pal.SLATE, 0.9)
			if unlocked:
				# Halo de la linea encendida.
				_elbow(a, b, mid, Color(accent, 0.25), width * 2.4)
			_elbow(a, b, mid, color, width)
			if unlocked:
				var t: float = fposmod(_time * 0.7 + PixelArt.hash01(int(rect.position.x), int(rect.position.y)), 1.0)
				var p: Vector2 = _elbow_point(a, b, mid, t)
				_map.draw_rect(Rect2(p - Vector2(width, width), Vector2(width * 2.0, width * 2.0)), Pal.WHITE)


func _elbow(a: Vector2, b: Vector2, mid: float, color: Color, width: float) -> void:
	var h: float = width * 0.5
	_map.draw_rect(Rect2(minf(a.x, mid), a.y - h, absf(mid - a.x) + h, width), color)
	_map.draw_rect(Rect2(mid - h, minf(a.y, b.y) - h, width, absf(b.y - a.y) + width), color)
	_map.draw_rect(Rect2(minf(mid, b.x) - h, b.y - h, absf(b.x - mid) + h, width), color)


func _elbow_point(a: Vector2, b: Vector2, mid: float, t: float) -> Vector2:
	var l1: float = absf(mid - a.x)
	var l2: float = absf(b.y - a.y)
	var l3: float = absf(b.x - mid)
	var d: float = t * (l1 + l2 + l3)
	if d <= l1:
		return Vector2(a.x + signf(mid - a.x) * d, a.y)
	d -= l1
	if d <= l2:
		return Vector2(mid, a.y + signf(b.y - a.y) * d)
	d -= l2
	return Vector2(mid + signf(b.x - mid) * d, b.y)


func _dashed(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var length: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / maxf(length, 1.0)
	var dash: float = 28.0
	var d: float = 0.0
	while d < length:
		_map.draw_line(a + dir * d, a + dir * minf(d + dash, length), color, width)
		d += dash * 2.0


func _draw_node(node: Dictionary, base_rect: Rect2, detail: bool) -> void:
	var id: String = node["id"]
	var tier: String = node["tier"]
	var branch: Dictionary = Catalog.branch(String(node["cat"]))
	var accent: Color = Color(String(branch["color"]))
	var tier_color: Color = TIER_COLORS.get(tier, Pal.SILVER)
	var state: int = _state(id)
	var level: int = GameData.node_level(id)
	var max_level: int = int(node["lv"])
	var revealed: bool = GameData.node_revealed(id)
	var rect: Rect2 = base_rect
	# Animacion de compra: pulso y destello.
	var since: float = _time - float(_bought_at.get(id, -10.0))
	if since < 0.6:
		rect = rect.grow(14.0 * sin(since / 0.6 * PI))
	if id == _hover_id:
		rect = rect.grow(4.0)

	var fill: Color = Color(0.09, 0.1, 0.17)
	var border: Color = Pal.SLATE
	if state == 1:
		fill = Pal.NAVY.darkened(0.3)
		border = accent.lerp(Pal.WHITE, 0.35 + 0.35 * sin(_time * 5.0))
	elif state == 2:
		fill = accent.darkened(0.62)
		border = accent
	elif state == 3:
		fill = accent.darkened(0.45)
		border = Pal.YELLOW
	if tier == "secret" and not revealed:
		fill = Color(0.12, 0.05, 0.12)
		border = Color(Pal.PURPLE, 0.9)

	# Resplandor de las desbloqueadas (y de las legendarias siempre).
	if state >= 2 or tier == "legendary":
		var glow_alpha: float = 0.35 if state >= 2 else 0.18
		if state == 3:
			glow_alpha = 0.5 + 0.12 * sin(_time * 3.0)
		PixelArt.draw_glow(_map, rect.get_center(), rect.size.x * 0.85, Color(tier_color if tier == "legendary" else accent, glow_alpha))

	var line: float = maxf(4.0, 2.0 / _zoom)
	_map.draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), rect.size), Color(0.0, 0.0, 0.0, 0.45))
	_draw_shape(rect, tier, border, fill, line)
	if since < 0.6:
		_draw_shape(rect, tier, Color(Pal.WHITE, 0.6 * (1.0 - since / 0.6)), Color(Pal.WHITE, 0.4 * (1.0 - since / 0.6)), line)
	if id == _selected:
		_brackets(rect.grow(10.0), Pal.WHITE, line)

	# Insignia del tier (franja superior con su color).
	_map.draw_rect(Rect2(rect.position + Vector2(line, line), Vector2(rect.size.x - line * 2.0, 6.0)), Color(tier_color, 0.9))

	if not detail:
		# Vista lejana: solo icono, estado y nivel.
		var icon: String = String(branch["icon"]) if revealed else "ghost"
		var icon_px: float = 5.0
		var sz: Vector2 = PixelArt.size_of(icon, icon_px)
		PixelArt.draw(_map, icon, rect.get_center() - sz * 0.5, icon_px, Color(1.0, 1.0, 1.0, 1.0) if state > 0 else Color(0.45, 0.45, 0.55, 1.0))
		if state == 0:
			_padlock(rect.get_center() + Vector2(46.0, 20.0), 3.0)
		_draw_pips(rect, level, max_level, accent, 8.0)
		return

	# Vista cercana: nombre, niveles, coste o estado.
	var title: String = String(node["name"]) if revealed else "MEJORA SECRETA"
	var lines: Array = _wrap(title, 14)
	var name_color: Color = Pal.WHITE if state > 0 else Pal.SILVER
	for i in mini(lines.size(), 2):
		var text: String = lines[i]
		TextCache.draw(_map, text, rect.position + Vector2(roundf((rect.size.x - TextCache.width(text, 2.0)) * 0.5), 16.0 + float(i) * 18.0), 2.0, name_color)
	_draw_pips(rect, level, max_level, accent, 4.0)
	var footer: String = "MÁXIMO"
	var footer_color: Color = Pal.YELLOW
	if state == 0:
		footer = "BLOQUEADA" if revealed else "???"
		footer_color = Pal.SILVER
		_padlock(rect.position + Vector2(rect.size.x - 26.0, rect.size.y - 30.0), 2.0)
	elif state != 3:
		var price: int = GameData.node_price(id)
		footer = "GRATIS" if GameData.admin_free_tree else _short_number(price)
		footer_color = Pal.YELLOW if GameData.wallet >= price or GameData.admin_free_tree else Pal.RED
		if not GameData.admin_free_tree:
			PixelArt.draw(_map, "coin_0", rect.position + Vector2(rect.size.x * 0.5 - TextCache.width(footer, 2.0) * 0.5 - 22.0, rect.size.y - 28.0), 2.0)
	TextCache.draw(_map, footer, rect.position + Vector2(roundf((rect.size.x - TextCache.width(footer, 2.0)) * 0.5), rect.size.y - 26.0), 2.0, footer_color)


## Contorno segun el tier: normal (recto), avanzada (doble marco), epica
## (esquinas cortadas), especial (esquinas doradas), legendaria (marco
## dorado animado) y secreta (marco morado).
func _draw_shape(rect: Rect2, tier: String, border: Color, fill: Color, line: float) -> void:
	if tier == "epic" or tier == "legendary":
		var c: float = 18.0
		var outer: PackedVector2Array = _octagon(rect, c)
		_map.draw_colored_polygon(outer, border)
		_map.draw_colored_polygon(_octagon(rect.grow(-line), c * 0.8), fill)
		if tier == "legendary":
			# Destello que recorre el marco.
			var t: float = fposmod(_time * 0.5, 1.0)
			var px: float = rect.position.x + rect.size.x * t
			_map.draw_rect(Rect2(px - 10.0, rect.position.y - 2.0, 20.0, line + 2.0), Color(Pal.WHITE, 0.8))
			_map.draw_rect(Rect2(rect.end.x - rect.size.x * t - 10.0, rect.end.y - line, 20.0, line + 2.0), Color(Pal.WHITE, 0.8))
		return
	_map.draw_rect(rect, border)
	_map.draw_rect(rect.grow(-line), fill)
	if tier == "advanced":
		_outline(rect.grow(-line * 2.5), Color(border, 0.6), line * 0.5)
	elif tier == "special" or tier == "secret":
		var corner: Color = Pal.YELLOW if tier == "special" else Pal.PINK
		var s: float = 14.0
		for p in [rect.position, Vector2(rect.end.x - s, rect.position.y), Vector2(rect.position.x, rect.end.y - s), rect.end - Vector2(s, s)]:
			_map.draw_rect(Rect2(p, Vector2(s, s)), corner)


func _octagon(rect: Rect2, c: float) -> PackedVector2Array:
	var p: Vector2 = rect.position
	var e: Vector2 = rect.end
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c),
	])


func _outline(rect: Rect2, color: Color, width: float) -> void:
	_map.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color)
	_map.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	_map.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color)
	_map.draw_rect(Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), color)


## Corchetes animados alrededor del nodo seleccionado.
func _brackets(rect: Rect2, color: Color, width: float) -> void:
	var grow: float = 4.0 * sin(_time * 6.0)
	var r: Rect2 = rect.grow(grow)
	var s: float = 26.0
	for corner in 4:
		var x: float = r.position.x if corner % 2 == 0 else r.end.x - s
		var y: float = r.position.y if corner < 2 else r.end.y - width
		_map.draw_rect(Rect2(x, y, s, width), color)
		var vx: float = r.position.x if corner % 2 == 0 else r.end.x - width
		var vy: float = r.position.y if corner < 2 else r.end.y - s
		_map.draw_rect(Rect2(vx, vy, width, s), color)


func _draw_pips(rect: Rect2, level: int, max_level: int, accent: Color, scale_factor: float) -> void:
	var pip: Vector2 = Vector2(4.0, 2.0) * scale_factor
	var gap: float = scale_factor
	var total: float = float(max_level) * (pip.x + gap) - gap
	var y: float = rect.position.y + rect.size.y * (0.56 if scale_factor <= 4.0 else 0.78)
	for k in max_level:
		var p: Vector2 = Vector2(rect.position.x + roundf((rect.size.x - total) * 0.5) + float(k) * (pip.x + gap), y)
		_map.draw_rect(Rect2(p, pip), Pal.INK)
		_map.draw_rect(Rect2(p + Vector2(2.0, 2.0), pip - Vector2(4.0, 4.0)), accent.lightened(0.2) if k < level else Pal.SLATE)


## Candado de los nodos bloqueados.
func _padlock(pos: Vector2, px: float) -> void:
	_map.draw_rect(Rect2(pos + Vector2(1.0, -3.0) * px, Vector2(4.0, 1.0) * px), Pal.SILVER)
	_map.draw_rect(Rect2(pos + Vector2(1.0, -3.0) * px, Vector2(1.0, 3.0) * px), Pal.SILVER)
	_map.draw_rect(Rect2(pos + Vector2(4.0, -3.0) * px, Vector2(1.0, 3.0) * px), Pal.SILVER)
	_map.draw_rect(Rect2(pos, Vector2(6.0, 5.0) * px), Pal.STEEL)
	_map.draw_rect(Rect2(pos + Vector2(2.5, 1.5) * px, Vector2(1.0, 2.0) * px), Pal.INK)


func _short_number(value: int) -> String:
	if value >= 100000:
		return "%dK" % int(float(value) / 1000.0)
	if value >= 10000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


# ---------------------------------------------------------- ficha del nodo --

func _draw_info() -> void:
	if _selected == "":
		return
	var node: Dictionary = Catalog.tree_node(_selected)
	if node.is_empty():
		return
	var branch: Dictionary = Catalog.branch(String(node["cat"]))
	var accent: Color = Color(String(branch["color"]))
	var tier: String = node["tier"]
	var tier_color: Color = TIER_COLORS.get(tier, Pal.SILVER)
	var revealed: bool = GameData.node_revealed(_selected)
	var level: int = GameData.node_level(_selected)
	var max_level: int = int(node["lv"])
	var x: float = 18.0
	var y: float = 16.0
	var w: float = INFO_RECT.size.x - 36.0

	# Insignia de tier y categoria.
	var tier_name: String = String(Catalog.TIER_NAMES.get(tier, ""))
	_info.draw_rect(Rect2(x, y, TextCache.width(tier_name, 2.0) + 16.0, 22.0), tier_color.darkened(0.3))
	TextCache.draw(_info, tier_name, Vector2(x + 8.0, y + 4.0), 2.0, Pal.WHITE)
	TextCache.draw(_info, String(branch["short"]), Vector2(x + TextCache.width(tier_name, 2.0) + 28.0, y + 4.0), 2.0, accent)
	y += 36.0
	var title: String = String(node["name"]) if revealed else "MEJORA SECRETA"
	for line in _wrap(title, 18):
		TextCache.draw(_info, String(line), Vector2(x, y), 3.0, Pal.YELLOW)
		y += 28.0
	# Niveles.
	TextCache.draw(_info, "NIVEL %d/%d" % [level, max_level], Vector2(x, y + 2.0), 2.0, Pal.WHITE)
	for k in max_level:
		var p: Vector2 = Vector2(x + 130.0 + float(k) * 30.0, y)
		_info.draw_rect(Rect2(p, Vector2(26.0, 14.0)), Pal.INK)
		_info.draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(22.0, 10.0)), accent if k < level else Pal.SLATE)
	y += 30.0
	_info.draw_rect(Rect2(x, y, w, 2.0), Color(accent, 0.5))
	y += 12.0

	var lines: Array = []
	if revealed:
		for line in _wrap(String(node["desc"]), 26):
			lines.append([line, Pal.WHITE])
		lines.append(["", Pal.WHITE])
		lines.append(["POR NIVEL:", Pal.SILVER])
		for line in _wrap(Buffs.describe(node["buff"]), 26):
			lines.append([line, Pal.LIME])
		if level > 0:
			lines.append(["AHORA:", Pal.SILVER])
			for line in _wrap(Buffs.describe(node["buff"], float(level)), 26):
				lines.append([line, Pal.CYAN])
	else:
		lines.append(["SE REVELA AL CUMPLIR", Pal.SILVER])
		lines.append(["SU REQUISITO SECRETO.", Pal.SILVER])
	lines.append(["", Pal.WHITE])
	# Requisitos con su estado (+ cumplido, - pendiente).
	var reqs: Array = _requirements(node)
	if not reqs.is_empty():
		lines.append(["REQUISITOS:", Pal.SILVER])
		for item in reqs:
			var entry: Array = item
			var ok: bool = entry[1]
			for line in _wrap(("+ " if ok else "- ") + String(entry[0]), 26):
				lines.append([line, Pal.LIME if ok else Pal.RED])
	for item in lines:
		var entry: Array = item
		if y > INFO_RECT.size.y - 130.0:
			break
		TextCache.draw(_info, String(entry[0]), Vector2(x, y), 2.0, entry[1])
		y += 20.0

	# Precio del siguiente nivel.
	var price: int = GameData.node_price(_selected)
	var price_y: float = INFO_RECT.size.y - 116.0
	if price >= 0:
		var price_text: String = "GRATIS (ADMIN)" if GameData.admin_free_tree else str(price)
		PixelArt.draw(_info, "coin_0", Vector2(x, price_y), 3.0)
		TextCache.draw(_info, price_text, Vector2(x + 34.0, price_y + 2.0), 3.0, Pal.YELLOW if GameData.wallet >= price or GameData.admin_free_tree else Pal.RED)
	else:
		TextCache.draw(_info, "MEJORA COMPLETA", Vector2(x, price_y + 2.0), 3.0, Pal.YELLOW)


## Lista de requisitos de un nodo: [texto, cumplido].
func _requirements(node: Dictionary) -> Array:
	var result: Array = []
	var world: int = int(node.get("w", 0))
	if world > 0:
		result.append(["LLEGAR AL MUNDO %d" % (world + 1), GameData.is_world_unlocked(world)])
	for req in node.get("req", []):
		var parent: Dictionary = Catalog.tree_node(String(req))
		var req_name: String = String(parent.get("name", "")) if GameData.node_revealed(String(req)) else "MEJORA SECRETA"
		result.append([req_name, GameData.node_level(String(req)) > 0])
	if node.has("cond"):
		var cond: Array = GameData.node_condition(String(node["id"]))
		result.append(["%s (%d/%d)" % [String(cond[1]), int(cond[2]), int(cond[3])], bool(cond[0])])
	var excluded: String = String(node.get("ex", ""))
	if excluded != "":
		var other: String = String(Catalog.tree_node(excluded).get("name", ""))
		result.append(["INCOMPATIBLE CON " + other, GameData.node_level(excluded) <= 0])
	return result


func _wrap(text: String, width: int) -> Array:
	var lines: Array = []
	var current: String = ""
	for word in text.split(" ", false):
		if current.length() + word.length() + 1 > width and current != "":
			lines.append(current)
			current = word
		elif current == "":
			current = word
		else:
			current += " " + word
	if current != "":
		lines.append(current)
	return lines
