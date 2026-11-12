extends Control
## Tienda. Se abre como pantalla superpuesta desde el menu principal y desde
## el Game Over. Pestanas: mejoras permanentes, objetos consumibles, heroes,
## espadas, estelas y auras. Las compras se guardan al instante (GameData).

signal closed

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const ShopCard = preload("res://scripts/shop_card.gd")
const HeroPreview = preload("res://scripts/hero_preview.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Fx = preload("res://scripts/fx.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

const TABS := ["MEJORAS", "OBJETOS", "HÉROES", "ESPADAS", "ESTELAS", "AURAS"]
const CATEGORIES := ["upgrade", "consumable", "skin", "sword", "trail", "aura"]
const CARD_SIZE := Vector2(190.0, 196.0)
const GRID_ORIGIN := Vector2(64.0, 196.0)

var _tab: int = 0
var _tab_buttons: Array = []
var _cards: Array = []
var _grid: Control
var _wallet: PixelLabel
var _info_name: PixelLabel
var _info_lines: Array = []
var _toaster: Toaster
var _close_button: PixelButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.82)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "TIENDA", Vector2(64.0, 52.0), 7.0, Pal.YELLOW, 0)

	# Monedero.
	var purse: Control = UI.panel(self, Rect2(860.0, 44.0, 250.0, 64.0))
	purse.set("fill", Pal.INK)
	_wallet = UI.label(self, "0", Vector2(1090.0, 62.0), 4.0, Pal.YELLOW, 2)
	var coin: PixelButton = UI.button(self, "", Rect2(868.0, 50.0, 56.0, 52.0), 4.0)
	coin.icon_sprite = "coin_0"
	coin.disabled = true
	coin.focus_mode = Control.FOCUS_NONE
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_close_button = UI.button(self, "X", Rect2(1140.0, 46.0, 76.0, 60.0), 4.0)
	_close_button.fill = Pal.RED
	_close_button.fill_hot = Pal.ORANGE
	_close_button.pressed.connect(close)

	for i in TABS.size():
		var tab: PixelButton = UI.button(self, TABS[i], Rect2(64.0 + float(i) * 136.0, 128.0, 128.0, 48.0), 2.0)
		tab.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(tab)

	_grid = UI.layer(self, "Grid")

	# Panel lateral: vista previa del heroe y descripcion del articulo.
	var side: Control = UI.panel(self, Rect2(884.0, 128.0, 332.0, 540.0))
	side.set("fill", Pal.INK.lerp(Pal.NAVY, 0.6))
	var preview: HeroPreview = HeroPreview.new()
	preview.px = 10.0
	add_child(preview)
	preview.position = Vector2(1066.0, 400.0)
	_info_name = UI.label(self, "", Vector2(1050.0, 452.0), 3.0, Pal.YELLOW)
	for i in 5:
		var line: PixelLabel = UI.label(self, "", Vector2(1050.0, 500.0 + float(i) * 26.0), 2.0, Pal.WHITE)
		_info_lines.append(line)

	_toaster = Toaster.new()
	add_child(_toaster)
	GameData.wallet_changed.connect(_refresh_wallet)
	_refresh_wallet()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Abre la tienda en la pestana indicada (0 mejoras ... 2 heroes ...).
func open(tab: int = 0) -> void:
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	Sfx.play_music("shop")
	_select_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _refresh_wallet() -> void:
	_wallet.text = str(GameData.wallet)


func _items(category: String) -> Array:
	if category == "upgrade":
		return Catalog.UPGRADES
	if category == "consumable":
		return Catalog.CONSUMABLES
	return Catalog.cosmetics(category)


func _select_tab(tab: int) -> void:
	_tab = clampi(tab, 0, TABS.size() - 1)
	for i in _tab_buttons.size():
		var button: PixelButton = _tab_buttons[i]
		button.selected = i == _tab
	for old in _cards:
		var old_card: ShopCard = old
		old_card.queue_free()
	_cards = []
	var category: String = CATEGORIES[_tab]
	var items: Array = _items(category)
	for i in items.size():
		var card: ShopCard = ShopCard.new()
		card.category = category
		card.item = items[i]
		_grid.add_child(card)
		var column: int = i % 4
		var row: int = int(float(i) / 4.0)
		card.position = GRID_ORIGIN + Vector2(float(column) * (CARD_SIZE.x + 12.0), float(row) * (CARD_SIZE.y + 22.0))
		card.size = CARD_SIZE
		card.pressed.connect(_on_card_pressed.bind(card))
		card.hovered.connect(_on_card_hovered)
		_cards.append(card)
		_refresh_card(card)
	if not _cards.is_empty():
		var first: ShopCard = _cards[0]
		first.grab_focus()
		_show_info(first)


## Calcula los textos de una tarjeta segun lo comprado y el monedero.
func _refresh_card(card: ShopCard) -> void:
	var entry: Dictionary = card.item
	var id: String = entry["id"]
	var title: String = entry["name"]
	if card.category == "upgrade":
		var prices: Array = entry["prices"]
		var level: int = GameData.upgrade_level(id)
		var price: int = GameData.upgrade_price(id)
		if price < 0:
			card.configure(title, "", "MÁXIMO", Pal.LIME, false, level, prices.size(), true)
		else:
			card.configure(title, "", str(price), _afford_color(price), true, level, prices.size(), level > 0)
	elif card.category == "consumable":
		var owned: int = GameData.stock_of(id)
		var cost: int = int(entry["price"])
		card.configure(title, "TIENES: %d" % owned, str(cost), _afford_color(cost), true, -1, 0, owned > 0)
	else:
		var cost_c: int = int(entry["price"])
		if GameData.equipped_id(card.category) == id:
			card.configure(title, "EQUIPADO", "EN USO", Pal.LIME, false, -1, 0, true)
		elif GameData.is_owned(id):
			card.configure(title, "COMPRADO", "EQUIPAR", Pal.WHITE, false, -1, 0, false)
		else:
			card.configure(title, "", str(cost_c), _afford_color(cost_c), true, -1, 0, false)


func _afford_color(price: int) -> Color:
	return Pal.YELLOW if GameData.wallet >= price else Pal.RED


func _refresh_all() -> void:
	for item in _cards:
		var card: ShopCard = item
		_refresh_card(card)


func _on_card_hovered(card: Button) -> void:
	_show_info(card as ShopCard)


## Muestra nombre y descripcion del articulo en el panel lateral.
func _show_info(card: ShopCard) -> void:
	if card == null:
		return
	var entry: Dictionary = card.item
	_info_name.text = String(entry["name"])
	var text: String = ""
	if entry.has("desc"):
		text = String(entry["desc"])
	elif card.category == "skin":
		text = "NUEVO ASPECTO PARA TU HÉROE"
	elif card.category == "sword":
		text = "ESPADA CON ESTELA DE COLOR PROPIO"
	elif card.category == "trail":
		text = "ESTELA DE PARTÍCULAS AL CORRER"
	else:
		text = "AURA LUMINOSA ALREDEDOR DEL HÉROE"
	if card.category == "consumable":
		text += ". SE USA SOLO EN TU PRÓXIMA PARTIDA"
	var lines: Array = _wrap(text, 24)
	for i in _info_lines.size():
		var label: PixelLabel = _info_lines[i]
		label.text = String(lines[i]) if i < lines.size() else ""


## Parte un texto en lineas de como mucho `width` caracteres.
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


func _on_card_pressed(card: ShopCard) -> void:
	var entry: Dictionary = card.item
	var id: String = entry["id"]
	var bought: bool = false
	var message: String = "¡COMPRA REALIZADA!"
	var sound: String = "buy"
	if card.category == "upgrade":
		if GameData.upgrade_price(id) < 0:
			_toaster.show_toast("YA ESTÁ AL MÁXIMO", Pal.SILVER)
			return
		bought = GameData.buy_upgrade(id)
		message = "¡MEJORA NIVEL %d!" % GameData.upgrade_level(id)
		sound = "upgrade"
	elif card.category == "consumable":
		bought = GameData.buy_consumable(id)
	elif GameData.is_owned(id):
		# Ya comprado: solo se equipa.
		if GameData.equipped_id(card.category) != id:
			GameData.equip(card.category, id)
			Sfx.play("click")
			card.pulse()
			_refresh_all()
		return
	else:
		bought = GameData.buy_cosmetic(card.category, id)

	if bought:
		Sfx.play(sound)
		card.pulse()
		_toaster.show_toast(message, Pal.LIME)
		var center: Vector2 = card.position + card.size * 0.5
		Fx.burst(_grid, center, Pal.YELLOW, 22, 420.0, 0.6, 9.0, 900.0, 180.0, Vector2.UP)
		Fx.burst(_grid, center, Pal.WHITE, 10, 260.0, 0.4, 6.0, 500.0, 180.0, Vector2.UP)
	else:
		Sfx.play("error")
		card.shake()
		_toaster.show_toast("MONEDAS INSUFICIENTES", Pal.RED)
	_refresh_all()
	_refresh_wallet()
