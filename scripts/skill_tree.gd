extends Control
## Arbol de mejoras: pantalla propia con seis ramas (movimiento, precision,
## combate, supervivencia, economia y especializacion). Cada nodo tiene
## niveles con coste creciente y desbloquea a los siguientes; las
## especializaciones van por parejas incompatibles (hay que elegir).
## Los datos estan en Catalog.TREE; los efectos se aplican via buffs.gd.

signal closed

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Buffs = preload("res://scripts/buffs.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Fx = preload("res://scripts/fx.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")

const NODE_SIZE := Vector2(176.0, 100.0)
const ORIGIN := Vector2(76.0, 220.0)
const STEP := Vector2(200.0, 150.0)

var _branch: int = 0
var _selected: String = ""
var _tab_buttons: Array = []
var _node_buttons: Array = []
var _canvas: Control
var _wallet: PixelLabel
var _info_name: PixelLabel
var _info_lines: Array = []
var _buy_button: PixelButton
var _toaster: Toaster
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.85)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "MEJORAS", Vector2(64.0, 52.0), 7.0, Pal.YELLOW, 0)
	var purse: Control = UI.panel(self, Rect2(860.0, 44.0, 250.0, 64.0))
	purse.set("fill", Pal.INK)
	_wallet = UI.label(self, "0", Vector2(1090.0, 62.0), 4.0, Pal.YELLOW, 2)
	var close_button: PixelButton = UI.button(self, "X", Rect2(1140.0, 46.0, 76.0, 60.0), 4.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(close)
	for i in Catalog.TREE_BRANCHES.size():
		var branch: Dictionary = Catalog.TREE_BRANCHES[i]
		var tab: PixelButton = UI.button(self, String(branch["name"]), Rect2(64.0 + float(i) * 192.0, 128.0, 186.0, 48.0), 2.0)
		tab.fill = Color(String(branch["color"])).darkened(0.55)
		tab.pressed.connect(_select_branch.bind(i))
		_tab_buttons.append(tab)

	_canvas = UI.layer(self, "Tree")
	_canvas.draw.connect(_draw_tree)

	var side: Control = UI.panel(self, Rect2(884.0, 190.0, 332.0, 478.0))
	side.set("fill", Pal.INK.lerp(Pal.NAVY, 0.6))
	_info_name = UI.label(self, "", Vector2(1050.0, 212.0), 3.0, Pal.YELLOW)
	for i in 13:
		var line: PixelLabel = UI.label(self, "", Vector2(1050.0, 250.0 + float(i) * 25.0), 2.0, Pal.WHITE)
		_info_lines.append(line)
	_buy_button = UI.button(self, "MEJORAR", Rect2(908.0, 584.0, 284.0, 64.0), 3.0)
	_buy_button.fill = Pal.GREEN
	_buy_button.fill_hot = Pal.LIME
	_buy_button.pressed.connect(_buy_selected)

	_toaster = Toaster.new()
	add_child(_toaster)
	GameData.wallet_changed.connect(_refresh_wallet)


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	Sfx.play_music("shop")
	_refresh_wallet()
	_select_branch(_branch)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _refresh_wallet() -> void:
	_wallet.text = str(GameData.wallet)


func _branch_nodes() -> Array:
	var branch: Dictionary = Catalog.TREE_BRANCHES[_branch]
	var result: Array = []
	for item in Catalog.TREE:
		var node: Dictionary = item
		if String(node["branch"]) == String(branch["id"]):
			result.append(node)
	return result


func _node_rect(node: Dictionary) -> Rect2:
	var pos: Array = node["pos"]
	return Rect2(ORIGIN + Vector2(float(pos[0]) * STEP.x, float(pos[1]) * STEP.y), NODE_SIZE)


func _select_branch(index: int) -> void:
	_branch = clampi(index, 0, Catalog.TREE_BRANCHES.size() - 1)
	for i in _tab_buttons.size():
		var tab: PixelButton = _tab_buttons[i]
		tab.selected = i == _branch
	for old in _node_buttons:
		var old_button: Button = old
		old_button.queue_free()
	_node_buttons = []
	var nodes: Array = _branch_nodes()
	for item in nodes:
		var node: Dictionary = item
		# Boton transparente: el nodo se dibuja en el lienzo.
		var button: Button = Button.new()
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			button.add_theme_stylebox_override(style_name, empty)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(button)
		var rect: Rect2 = _node_rect(node)
		button.position = rect.position
		button.size = rect.size
		button.pressed.connect(_select_node.bind(String(node["id"])))
		button.mouse_entered.connect(_select_node.bind(String(node["id"])))
		button.focus_entered.connect(_select_node.bind(String(node["id"])))
		_node_buttons.append(button)
	if not nodes.is_empty():
		var first: Dictionary = nodes[0]
		_select_node(String(first["id"]))
		var first_button: Button = _node_buttons[0]
		first_button.grab_focus()


## Estado de un nodo: 0 bloqueado, 1 disponible, 2 comprado, 3 al maximo.
func _state(id: String) -> int:
	var level: int = GameData.node_level(id)
	if GameData.node_price(id) < 0:
		return 3
	var reason: String = GameData.node_block_reason(id)
	if reason != "":
		return 2 if level > 0 else 0
	return 2 if level > 0 else 1


func _draw_tree() -> void:
	var branch: Dictionary = Catalog.TREE_BRANCHES[_branch]
	var accent: Color = Color(String(branch["color"]))
	var nodes: Array = _branch_nodes()
	# Lineas de dependencia dentro de la rama.
	for item in nodes:
		var node: Dictionary = item
		var rect: Rect2 = _node_rect(node)
		for req in node.get("requires", []):
			var parent: Dictionary = Catalog.find(Catalog.TREE, String(req))
			if parent.is_empty() or String(parent["branch"]) != String(node["branch"]):
				continue
			var from_rect: Rect2 = _node_rect(parent)
			var a: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y)
			var b: Vector2 = Vector2(rect.position.x, rect.get_center().y)
			var unlocked: bool = GameData.node_level(String(req)) > 0
			var color: Color = accent if unlocked else Pal.SLATE
			var mid: float = (a.x + b.x) * 0.5
			_canvas.draw_rect(Rect2(a.x, a.y - 3.0, mid - a.x, 6.0), color)
			_canvas.draw_rect(Rect2(mid - 3.0, minf(a.y, b.y) - 3.0, 6.0, absf(b.y - a.y) + 6.0), color)
			_canvas.draw_rect(Rect2(mid, b.y - 3.0, b.x - mid, 6.0), color)
	# Especializaciones: las parejas incompatibles se marcan con "O".
	if String(branch["id"]) == "especializacion":
		for col in 3:
			var x: float = ORIGIN.x + float(col) * STEP.x + NODE_SIZE.x * 0.5
			PixelFont.draw_text_shadowed(_canvas, "O", Vector2(x - 6.0, ORIGIN.y + STEP.y + 30.0), 4.0, Pal.PINK, Pal.INK)
		PixelFont.draw_text_shadowed(_canvas, "ELIGE UNA DE CADA PAREJA", Vector2(ORIGIN.x, 640.0), 2.0, Pal.PINK, Pal.INK)
	# Nodos.
	for item in nodes:
		var node: Dictionary = item
		var id: String = node["id"]
		var rect: Rect2 = _node_rect(node)
		var state: int = _state(id)
		var level: int = GameData.node_level(id)
		var prices: Array = node["prices"]
		var fill: Color = Pal.SLATE.darkened(0.3)
		var border: Color = Pal.INK
		if state == 1:
			fill = Pal.NAVY
			border = accent if int(_time * 3.0) % 2 == 0 else accent.darkened(0.3)
		elif state == 2:
			fill = accent.darkened(0.55)
			border = accent
		elif state == 3:
			fill = accent.darkened(0.35)
			border = Pal.YELLOW
		if id == _selected:
			border = Pal.WHITE
		_canvas.draw_rect(Rect2(rect.position + Vector2(6.0, 6.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
		_canvas.draw_rect(rect, border)
		_canvas.draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), fill)
		var title: String = node["name"]
		var lines: Array = _wrap(title, 13)
		for i in lines.size():
			var text: String = lines[i]
			PixelFont.draw_text_shadowed(_canvas, text, rect.position + Vector2(roundf((rect.size.x - PixelFont.text_width(text, 2.0)) * 0.5), 12.0 + float(i) * 18.0), 2.0, Pal.WHITE if state > 0 else Pal.SILVER, Pal.INK)
		# Niveles (pips).
		var total: float = float(prices.size()) * 20.0 - 4.0
		for k in prices.size():
			var pip: Rect2 = Rect2(rect.position + Vector2(roundf((rect.size.x - total) * 0.5) + float(k) * 20.0, 56.0), Vector2(16.0, 8.0))
			_canvas.draw_rect(pip, Pal.INK)
			_canvas.draw_rect(Rect2(pip.position + Vector2(2.0, 2.0), Vector2(12.0, 4.0)), accent if k < level else Pal.SLATE)
		# Coste del siguiente nivel o estado.
		var footer: String = "MÁXIMO"
		var footer_color: Color = Pal.YELLOW
		if state == 0:
			footer = "BLOQUEADO"
			footer_color = Pal.SILVER
		elif state != 3:
			var price: int = GameData.node_price(id)
			footer = str(price)
			footer_color = Pal.YELLOW if GameData.wallet >= price else Pal.RED
		PixelFont.draw_text_shadowed(_canvas, footer, rect.position + Vector2(roundf((rect.size.x - PixelFont.text_width(footer, 2.0)) * 0.5), 74.0), 2.0, footer_color, Pal.INK)


func _select_node(id: String) -> void:
	_selected = id
	var node: Dictionary = Catalog.find(Catalog.TREE, id)
	if node.is_empty():
		return
	var level: int = GameData.node_level(id)
	var prices: Array = node["prices"]
	_info_name.text = String(node["name"])
	var lines: Array = []
	lines.append("NIVEL %d/%d" % [level, prices.size()])
	lines.append("")
	lines.append_array(_wrap(String(node["desc"]), 24))
	lines.append("")
	lines.append("POR NIVEL:")
	lines.append_array(_wrap(Buffs.describe(node["buff"]), 24))
	if level > 0:
		var total: Dictionary = {}
		var buff: Dictionary = node["buff"]
		for key in buff:
			total[key] = float(buff[key]) * float(level)
		lines.append("AHORA: " + Buffs.describe(total))
	var reason: String = GameData.node_block_reason(id)
	if reason != "" and reason != "NIVEL MÁXIMO":
		lines.append("")
		lines.append_array(_wrap(reason, 24))
	for i in _info_lines.size():
		var label: PixelLabel = _info_lines[i]
		label.text = String(lines[i]) if i < lines.size() else ""
		label.color = Pal.RED if String(label.text).begins_with("REQUIERE") or String(label.text).begins_with("INCOMPATIBLE") else Pal.WHITE
	var price: int = GameData.node_price(id)
	if price < 0:
		_buy_button.caption = "NIVEL MÁXIMO"
		_buy_button.disabled = true
	else:
		_buy_button.caption = "MEJORAR: %d" % price
		_buy_button.disabled = reason != ""


func _buy_selected() -> void:
	if _selected == "":
		return
	var reason: String = GameData.node_block_reason(_selected)
	if reason != "":
		Sfx.play("error")
		_toaster.show_toast(reason, Pal.SILVER)
		return
	if GameData.buy_node(_selected):
		Sfx.play("upgrade")
		var node: Dictionary = Catalog.find(Catalog.TREE, _selected)
		var center: Vector2 = _node_rect(node).get_center()
		Fx.burst(_canvas, center, Pal.YELLOW, 24, 420.0, 0.6, 9.0, 600.0, 180.0, Vector2.UP)
		Fx.ring(_canvas, center, Pal.WHITE, 90.0)
		_toaster.show_toast("¡%s NIVEL %d!" % [String(node["name"]), GameData.node_level(_selected)], Pal.LIME)
	else:
		Sfx.play("error")
		_toaster.show_toast("MONEDAS INSUFICIENTES", Pal.RED)
	_refresh_wallet()
	_select_node(_selected)


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
