extends Node
## Autoload "GameData": perfil permanente del jugador.
## Monedero, mejoras, objetos, cosmeticos, estadisticas, logros, misiones
## diarias y ajustes. Todo se guarda en user://one_button_hero.cfg (ConfigFile).

signal settings_changed
signal wallet_changed
## Aviso para mostrar en pantalla (logro, mision, recompensa...).
signal notice(text: String)

const Catalog = preload("res://scripts/catalog.gd")

const SAVE_PATH := "user://one_button_hero.cfg"
## Accion principal: ESPACIO, clic izquierdo o toque en pantalla.
const ACTION := "hero_action"
const POWER_ACTIONS := ["power_1", "power_2", "power_3"]

var wallet: int = 0
var upgrades: Dictionary = {}
var stock: Dictionary = {}
var owned: Dictionary = {"skin_azul": true, "sword_acero": true, "trail_polvo": true, "aura_ninguna": true}
var equipped: Dictionary = {"skin": "skin_azul", "sword": "sword_acero", "trail": "trail_polvo", "aura": "aura_ninguna"}

## Estadisticas acumuladas.
var stats: Dictionary = {
	"high_score": 0, "best_distance": 0, "games_played": 0, "total_coins": 0,
	"total_kills": 0, "total_gems": 0, "total_distance": 0, "nights_survived": 0,
	"powers_used": 0, "deaths": 0,
}
var achievements: Dictionary = {}

## Misiones del dia.
var missions_date: String = ""
var missions: Array = []
var mission_progress: Dictionary = {}
var mission_done: Dictionary = {}

## Ajustes.
var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var screen_shake: bool = true
var fullscreen: bool = false

var high_score: int:
	get:
		return int(stats.get("high_score", 0))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	load_data()
	refresh_missions()
	_apply_window_mode()


## Crea las acciones por codigo para no depender del mapa de entrada.
func _register_input() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		InputMap.action_add_event(ACTION, key)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(ACTION, click)
	var keys: Array = [[KEY_1, KEY_Q], [KEY_2, KEY_W], [KEY_3, KEY_E]]
	for i in POWER_ACTIONS.size():
		var action: String = POWER_ACTIONS[i]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var pair: Array = keys[i]
		for code in pair:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- guardado --

func _merge(target: Dictionary, loaded: Variant) -> void:
	if loaded is Dictionary:
		var source: Dictionary = loaded
		for key in source:
			target[key] = source[key]


func load_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	wallet = int(cfg.get_value("profile", "wallet", 0))
	_merge(upgrades, cfg.get_value("profile", "upgrades", {}))
	_merge(stock, cfg.get_value("profile", "stock", {}))
	_merge(owned, cfg.get_value("profile", "owned", {}))
	_merge(equipped, cfg.get_value("profile", "equipped", {}))
	_merge(stats, cfg.get_value("profile", "stats", {}))
	_merge(achievements, cfg.get_value("profile", "achievements", {}))
	# Compatibilidad con la primera version del juego.
	var old_score: int = int(cfg.get_value("scores", "high_score", 0))
	if old_score > int(stats.get("high_score", 0)):
		stats["high_score"] = old_score
	missions_date = String(cfg.get_value("missions", "date", ""))
	_merge(mission_progress, cfg.get_value("missions", "progress", {}))
	_merge(mission_done, cfg.get_value("missions", "done", {}))
	sfx_enabled = bool(cfg.get_value("settings", "sfx_enabled", true))
	music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("settings", "music_volume", 0.7)), 0.0, 1.0)
	screen_shake = bool(cfg.get_value("settings", "screen_shake", true))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))


func save_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("profile", "wallet", wallet)
	cfg.set_value("profile", "upgrades", upgrades)
	cfg.set_value("profile", "stock", stock)
	cfg.set_value("profile", "owned", owned)
	cfg.set_value("profile", "equipped", equipped)
	cfg.set_value("profile", "stats", stats)
	cfg.set_value("profile", "achievements", achievements)
	cfg.set_value("missions", "date", missions_date)
	cfg.set_value("missions", "progress", mission_progress)
	cfg.set_value("missions", "done", mission_done)
	cfg.set_value("settings", "sfx_enabled", sfx_enabled)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "fullscreen", fullscreen)
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("No se pudo guardar la partida (error %d)" % err)


# ------------------------------------------------------------------ tienda --

func add_coins(amount: int) -> void:
	if amount == 0:
		return
	wallet = maxi(wallet + amount, 0)
	wallet_changed.emit()


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func stock_of(id: String) -> int:
	return int(stock.get(id, 0))


func is_owned(id: String) -> bool:
	return bool(owned.get(id, false))


func equipped_id(slot: String) -> String:
	return String(equipped.get(slot, ""))


## Datos del cosmetico equipado en una ranura ("skin", "sword", "trail", "aura").
func equipped_item(slot: String) -> Dictionary:
	var list: Array = Catalog.cosmetics(slot)
	var entry: Dictionary = Catalog.find(list, equipped_id(slot))
	if entry.is_empty():
		entry = list[0]
	return entry


## Precio del siguiente nivel de una mejora (-1 si ya esta al maximo).
func upgrade_price(id: String) -> int:
	var entry: Dictionary = Catalog.find(Catalog.UPGRADES, id)
	if entry.is_empty():
		return -1
	var prices: Array = entry["prices"]
	var level: int = upgrade_level(id)
	if level >= prices.size():
		return -1
	return int(prices[level])


func _spend(price: int) -> bool:
	if price < 0 or wallet < price:
		return false
	wallet -= price
	wallet_changed.emit()
	return true


func buy_upgrade(id: String) -> bool:
	if not _spend(upgrade_price(id)):
		return false
	upgrades[id] = upgrade_level(id) + 1
	save_data()
	return true


func buy_consumable(id: String) -> bool:
	var entry: Dictionary = Catalog.find(Catalog.CONSUMABLES, id)
	if entry.is_empty() or not _spend(int(entry["price"])):
		return false
	stock[id] = stock_of(id) + 1
	save_data()
	return true


## Gasta una unidad de un consumible. Devuelve false si no quedaba ninguna.
func use_consumable(id: String) -> bool:
	if stock_of(id) <= 0:
		return false
	stock[id] = stock_of(id) - 1
	save_data()
	return true


func buy_cosmetic(slot: String, id: String) -> bool:
	var entry: Dictionary = Catalog.find(Catalog.cosmetics(slot), id)
	if entry.is_empty() or is_owned(id) or not _spend(int(entry["price"])):
		return false
	owned[id] = true
	equipped[slot] = id
	save_data()
	return true


func equip(slot: String, id: String) -> void:
	if is_owned(id):
		equipped[slot] = id
		save_data()


# --------------------------------------------------------------- progresion --

## Elige las tres misiones del dia (las mismas para toda la jornada).
func refresh_missions() -> void:
	var today: String = Time.get_date_string_from_system()
	if today != missions_date:
		missions_date = today
		mission_progress = {}
		mission_done = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool: Array = Catalog.MISSIONS.duplicate()
	missions = []
	for i in 3:
		var index: int = rng.randi_range(0, pool.size() - 1)
		missions.append(pool[index])
		pool.remove_at(index)


## Suma progreso a las misiones cuyo contador sea `stat`.
func add_mission_progress(stat: String, amount: int) -> void:
	if amount <= 0:
		return
	for item in missions:
		var mission: Dictionary = item
		var id: String = mission["id"]
		if String(mission["stat"]) != stat or bool(mission_done.get(id, false)):
			continue
		var value: int = int(mission_progress.get(id, 0)) + amount
		mission_progress[id] = value
		if value >= int(mission["target"]):
			mission_done[id] = true
			add_coins(int(mission["reward"]))
			notice.emit("MISIÓN CUMPLIDA: +%d MONEDAS" % int(mission["reward"]))


func mission_text(mission: Dictionary) -> String:
	return String(mission["text"]) % int(mission["target"])


func add_stat(stat: String, amount: int) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount


## Comprueba los logros y entrega sus recompensas.
func check_achievements() -> void:
	for item in Catalog.ACHIEVEMENTS:
		var entry: Dictionary = item
		var id: String = entry["id"]
		if bool(achievements.get(id, false)):
			continue
		if int(stats.get(String(entry["stat"]), 0)) >= int(entry["target"]):
			achievements[id] = true
			add_coins(int(entry["reward"]))
			notice.emit("LOGRO: %s  +%d" % [String(entry["name"]), int(entry["reward"])])


## Registra el final de una partida. Devuelve true si hay nuevo record.
func finish_run(score: int, coins: int, kills: int, gems: int, meters: int) -> bool:
	var is_record: bool = score > int(stats["high_score"])
	if is_record:
		stats["high_score"] = score
	stats["best_distance"] = maxi(int(stats["best_distance"]), meters)
	add_stat("games_played", 1)
	add_stat("deaths", 1)
	add_stat("total_coins", coins)
	add_stat("total_kills", kills)
	add_stat("total_gems", gems)
	add_stat("total_distance", meters)
	add_coins(coins)
	add_mission_progress("runs", 1)
	check_achievements()
	save_data()
	return is_record


func reset_progress() -> void:
	wallet = 0
	upgrades = {}
	stock = {}
	owned = {"skin_azul": true, "sword_acero": true, "trail_polvo": true, "aura_ninguna": true}
	equipped = {"skin": "skin_azul", "sword": "sword_acero", "trail": "trail_polvo", "aura": "aura_ninguna"}
	for key in stats:
		stats[key] = 0
	achievements = {}
	mission_progress = {}
	mission_done = {}
	save_data()
	wallet_changed.emit()


# ------------------------------------------------------------------ ajustes --

## Llamar despues de cambiar cualquier ajuste: guarda y avisa a quien escuche.
func apply_settings() -> void:
	_apply_window_mode()
	save_data()
	settings_changed.emit()


func _apply_window_mode() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
