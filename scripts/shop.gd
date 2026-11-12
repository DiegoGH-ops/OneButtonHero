extends Control
## Tienda. Se abre como pantalla superpuesta desde el menu principal y desde
## el Game Over. Pestanas: heroes, espadas, estelas, auras y los dos
## power-ups. Cada articulo muestra ANTES de comprarlo su buff exacto y lo
## compara con el equipado. Las compras se guardan al instante (GameData).
## Las mejoras tienen su propia pantalla: el arbol (skill_tree.gd).

signal closed

const UI = preload("res://scripts/ui.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Buffs = preload("res://scripts/buffs.gd")
const ShopCard = preload("res://scripts/shop_card.gd")
const HeroPreview = preload("res://scripts/hero_preview.gd")
const Toaster = preload("res://scripts/toaster.gd")
const Fx = preload("res://scripts/fx.gd")
const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")
const Campaign = preload("res://scripts/campaign.gd")

const TABS := ["HÉROES", "ESPADAS", "ESTELAS", "AURAS", "PODERES"]
const CATEGORIES := ["skin", "sword", "trail", "aura", "powerup"]
const SLOT_NAMES := {"skin": "HÉROE", "sword": "ESPADA", "trail": "ESTELA", "aura": "AURA"}
const CARD_SIZE := Vector2(190.0, 196.0)
const GRID_ORIGIN := Vector2(64.0, 196.0)
const INFO_LINES := 10

var _tab: int = 0
var _tab_buttons: Array = []
var _cards: Array = []
var _grid: Control
var _wallet: PixelLabel
var _gems: PixelLabel
var _info_name: PixelLabel
var _info_price: PixelLabel
var _info_lines: Array = []
var _toaster: Toaster
var _close_button: PixelButton
var _page: int = 0
var _page_label: PixelLabel
var _prev_button: PixelButton
var _next_button: PixelButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.82)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "TIENDA", Vector2(64.0, 52.0), 7.0, Pal.YELLOW, 0)

	# Monedero y diamantes.
	var purse: Control = UI.panel(self, Rect2(860.0, 44.0, 250.0, 64.0))
	purse.set("fill", Pal.INK)
	_wallet = UI.label(self, "0", Vector2(1090.0, 62.0), 4.0, Pal.YELLOW, 2)
	_purse_icon("coin_0", Rect2(868.0, 50.0, 56.0, 52.0), 4.0)
	var gem_purse: Control = UI.panel(self, Rect2(690.0, 44.0, 160.0, 64.0))
	gem_purse.set("fill", Pal.INK)
	_purse_icon("gem", Rect2(698.0, 50.0, 56.0, 52.0), 3.0)
	_gems = UI.label(self, "0", Vector2(836.0, 62.0), 4.0, Pal.CYAN, 2)

	_close_button = UI.button(self, "X", Rect2(1140.0, 46.0, 76.0, 60.0), 4.0)
	_close_button.fill = Pal.RED
	_close_button.fill_hot = Pal.ORANGE
	_close_button.pressed.connect(close)

	for i in TABS.size():
		var tab: PixelButton = UI.button(self, TABS[i], Rect2(64.0 + float(i) * 162.0, 128.0, 154.0, 48.0), 2.0)
		tab.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(tab)

	_grid = UI.layer(self, "Grid")
	_prev_button = UI.button(self, "<", Rect2(64.0, 630.0, 56.0, 44.0), 3.0)
	_prev_button.pressed.connect(_change_page.bind(-1))
	_next_button = UI.button(self, ">", Rect2(128.0, 630.0, 56.0, 44.0), 3.0)
	_next_button.pressed.connect(_change_page.bind(1))
	_page_label = UI.label(self, "", Vector2(200.0, 644.0), 2.0, Pal.SILVER, 0)

	# Ficha del articulo: vista previa, nombre, precio, buff y comparacion.
	var side: Control = UI.panel(self, Rect2(884.0, 128.0, 332.0, 540.0))
	side.set("fill", Pal.INK.lerp(Pal.NAVY, 0.6))
	var preview: HeroPreview = HeroPreview.new()
	preview.px = 7.0
	add_child(preview)
	preview.position = Vector2(1060.0, 296.0)
	_info_name = UI.label(self, "", Vector2(1050.0, 320.0), 3.0, Pal.YELLOW)
	_info_price = UI.label(self, "", Vector2(1050.0, 352.0), 2.0, Pal.CYAN)
	for i in INFO_LINES:
		var line: PixelLabel = UI.label(self, "", Vector2(1050.0, 384.0 + float(i) * 26.0), 2.0, Pal.WHITE)
		_info_lines.append(line)

	_toaster = Toaster.new()
	add_child(_toaster)
	GameData.wallet_changed.connect(_refresh_wallet)
	_refresh_wallet()


func _purse_icon(sprite: String, rect: Rect2, px: float) -> void:
	var icon: PixelButton = UI.button(self, "", rect, px)
	icon.icon_sprite = sprite
	icon.disabled = true
	icon.focus_mode = Control.FOCUS_NONE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Abre la tienda en la pestana indicada (0 heroes ... 4 poderes).
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
	_gems.text = str(GameData.diamonds)


func _items(category: String) -> Array:
	if category == "powerup":
		return Catalog.POWERUPS
	return Catalog.cosmetics(category)


func _select_tab(tab: int) -> void:
	_tab = clampi(tab, 0, TABS.size() - 1)
	for i in _tab_buttons.size():
		var button: PixelButton = _tab_buttons[i]
		button.selected = i == _tab
	_page = 0
	_build_cards()


func _change_page(direction: int) -> void:
	_page += direction
	_build_cards()


## Crea las tarjetas de la pagina actual (ocho por pagina).
func _build_cards() -> void:
	for old in _cards:
		var old_card: ShopCard = old
		old_card.queue_free()
	_cards = []
	var category: String = CATEGORIES[_tab]
	var all_items: Array = _items(category)
	var pages: int = maxi(int(ceil(float(all_items.size()) / 8.0)), 1)
	_page = clampi(_page, 0, pages - 1)
	_prev_button.visible = pages > 1
	_next_button.visible = pages > 1
	_page_label.text = "PÁGINA %d/%d" % [_page + 1, pages] if pages > 1 else ""
	var items: Array = all_items.slice(_page * 8, _page * 8 + 8)
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
	if card.category == "powerup":
		var cost: int = int(entry["price"])
		var world: int = int(entry["world"])
		card.band_color = Color(String(entry["color"]))
		if GameData.is_powerup_owned(id):
			var on: bool = GameData.is_powerup_active(id)
			card.configure(title, "ACTIVO" if on else "INACTIVO", "DESACTIVAR" if on else "ACTIVAR", Pal.WHITE, false, -1, 0, on)
		elif not GameData.is_powerup_available(id):
			card.configure(title, "MUNDO %d" % (world + 1), "BLOQUEADO", Pal.SILVER, false, -1, 0, false)
		else:
			card.configure(title, "MUNDO %d" % (world + 1), str(cost), _afford_color(cost), true, -1, 0, false)
		return
	var gems: int = GameData.diamond_price(entry)
	var rarity: String = String(entry.get("rarity", ""))
	if entry.has("reward") and not GameData.is_owned(id):
		# Recompensa de campana: no se vende.
		var parts: PackedStringArray = String(entry["reward"]).split("_")
		card.configure(title, rarity, "NIVEL %d-%d" % [int(parts[0]) + 1, int(parts[1]) + 1], Pal.SILVER, false, -1, 0, false)
		return
	card.currency_sprite = "gem" if gems > 0 else "coin_0"
	var price: int = gems if gems > 0 else int(entry["price"])
	var price_color: Color = _afford_color(price)
	if gems > 0:
		price_color = Pal.CYAN if GameData.diamonds >= gems else Pal.RED
	if GameData.equipped_id(card.category) == id:
		card.configure(title, "EQUIPADO", "EN USO", Pal.LIME, false, -1, 0, true)
	elif GameData.is_owned(id):
		card.configure(title, "COMPRADO", "EQUIPAR", Pal.WHITE, false, -1, 0, false)
	else:
		card.configure(title, rarity, str(price), price_color, true, -1, 0, false)


func _afford_color(price: int) -> Color:
	return Pal.YELLOW if GameData.wallet >= price else Pal.RED


func _refresh_all() -> void:
	for item in _cards:
		var card: ShopCard = item
		_refresh_card(card)


func _on_card_hovered(card: Button) -> void:
	_show_info(card as ShopCard)


## Ficha del articulo: precio, buff exacto, descripcion y comparacion con el
## cosmetico equipado en esa ranura.
func _show_info(card: ShopCard) -> void:
	if card == null:
		return
	var entry: Dictionary = card.item
	var id: String = entry["id"]
	_info_name.text = String(entry["name"])
	var lines: Array = []
	if card.category == "powerup":
		var world: int = int(entry["world"])
		var world_name: String = String(Campaign.WORLDS[world]["name"])
		_info_price.text = "PRECIO: %d MONEDAS" % int(entry["price"])
		lines.append("PODER DE %s" % world_name)
		lines.append_array(_wrap(String(entry["desc"]), 24))
		lines.append("CONTRAPARTIDA:")
		lines.append_array(_wrap(String(entry["cost"]), 24))
		if not GameData.is_powerup_available(id):
			lines.append("SE VENDE AL LLEGAR AL MUNDO %d" % (world + 1))
	else:
		var gems: int = GameData.diamond_price(entry)
		if entry.has("reward"):
			var parts: PackedStringArray = String(entry["reward"]).split("_")
			_info_price.text = "RECOMPENSA DEL NIVEL %d-%d" % [int(parts[0]) + 1, int(parts[1]) + 1]
		elif gems > 0:
			_info_price.text = "PRECIO: %d DIAMANTES" % gems
		else:
			_info_price.text = "PRECIO: %d MONEDAS" % int(entry["price"])
		var buff: Dictionary = entry.get("buff", {})
		lines.append("BUFF:")
		lines.append_array(_wrap(Buffs.describe(buff, Buffs.affinity(card.category)), 24))
		if entry.has("rarity"):
			lines.append("RAREZA: " + String(entry["rarity"]))
		lines.append("")
		var current: Dictionary = GameData.equipped_item(card.category)
		if String(current.get("id", "")) == id:
			lines.append("YA LO TIENES EQUIPADO")
		else:
			lines.append("%s EQUIPADO:" % String(SLOT_NAMES.get(card.category, "")))
			lines.append(String(current.get("name", "")))
			lines.append_array(_wrap(Buffs.describe(current.get("buff", {})), 24))
	for i in _info_lines.size():
		var label: PixelLabel = _info_lines[i]
		label.text = String(lines[i]) if i < lines.size() else ""
		label.color = Pal.WHITE
		if card.category != "powerup" and i == 1:
			label.color = Pal.LIME
		elif card.category == "powerup" and (i == 0 or String(label.text).begins_with("CONTRAPARTIDA") or String(label.text).begins_with("SE VENDE")):
			label.color = Pal.ORANGE if i > 0 else Color(String(entry["color"]))


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
	if card.category == "powerup":
		if GameData.is_powerup_owned(id):
			GameData.toggle_powerup(id)
			Sfx.play("click")
			card.pulse()
			_refresh_all()
			_show_info(card)
			return
		if not GameData.is_powerup_available(id):
			Sfx.play("error")
			card.shake()
			_toaster.show_toast("LLEGA AL MUNDO %d PARA COMPRARLO" % (int(entry["world"]) + 1), Pal.SILVER)
			return
		bought = GameData.buy_powerup(id)
	elif GameData.is_owned(id):
		# Ya comprado: solo se equipa (y su buff sustituye al anterior).
		if GameData.equipped_id(card.category) != id:
			GameData.equip(card.category, id)
			Sfx.play("click")
			card.pulse()
			_refresh_all()
			_show_info(card)
		return
	elif entry.has("reward"):
		Sfx.play("error")
		card.shake()
		_toaster.show_toast("SE CONSIGUE EN LA CAMPAÑA", Pal.SILVER)
		return
	else:
		bought = GameData.buy_cosmetic(card.category, id)

	if bought:
		Sfx.play("buy")
		card.pulse()
		_toaster.show_toast("¡COMPRA REALIZADA!", Pal.LIME)
		var center: Vector2 = card.position + card.size * 0.5
		Fx.burst(_grid, center, Pal.YELLOW, 22, 420.0, 0.6, 9.0, 900.0, 180.0, Vector2.UP)
		Fx.burst(_grid, center, Pal.WHITE, 10, 260.0, 0.4, 6.0, 500.0, 180.0, Vector2.UP)
		Fx.ring(_grid, center, Pal.YELLOW, 110.0)
		Fx.ring(_grid, center, Pal.WHITE, 60.0)
	else:
		Sfx.play("error")
		card.shake()
		var missing: String = "DIAMANTES INSUFICIENTES" if int(entry.get("gems", 0)) > 0 else "MONEDAS INSUFICIENTES"
		_toaster.show_toast(missing, Pal.RED)
	_refresh_all()
	_refresh_wallet()
	_show_info(card)
