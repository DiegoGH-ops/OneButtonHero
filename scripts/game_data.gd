extends Node
## Autoload "GameData": perfil permanente del jugador.
## Monedero, mejoras, objetos, cosmeticos, estadisticas, logros, misiones
## diarias y ajustes. Todo se guarda en user://one_button_hero.cfg (ConfigFile).

signal settings_changed
signal wallet_changed
## Aviso para mostrar en pantalla (logro, mision, recompensa...).
signal notice(text: String)
## Logro conseguido (lo muestra AchievementPopup con su animacion).
signal achievement_unlocked(entry: Dictionary)

const Catalog = preload("res://scripts/catalog.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Buffs = preload("res://scripts/buffs.gd")
const Missions = preload("res://scripts/missions.gd")
const Achievements = preload("res://scripts/achievements.gd")
const AchievementPopup = preload("res://scripts/achievement_popup.gd")

const SAVE_PATH := "user://one_button_hero.cfg"
## Accion principal: ESPACIO, clic izquierdo o toque en pantalla.
const ACTION := "hero_action"
## Precios de las mejoras y objetos de versiones anteriores: al cargar una
## partida antigua se devuelve lo gastado para invertirlo en el arbol nuevo.
const OLD_UPGRADE_PRICES := [150, 400, 900, 1800, 3200]
const OLD_CONSUMABLE_PRICES := {"revive": 300, "guard": 120, "double": 200, "magnet_boost": 120}

var wallet: int = 0
## Moneda especial: solo se consigue jugando (hitos, tres estrellas...).
var diamonds: int = 0
## Progreso de campana: "mundo_nivel" -> {"stars", "rank", "score"}.
var campaign: Dictionary = {}
## Partida que se va a jugar (no se guarda): modo "endless" o "level".
var run: Dictionary = {"mode": "endless"}
## Arbol de mejoras: id del nodo -> nivel comprado.
var tree: Dictionary = {}
## Power-ups de tienda comprados -> activado (true) o desactivado.
var powerups: Dictionary = {}
## Gemas acumuladas para la mejora "Fragmentos" (se funden en diamantes).
var shards: int = 0
## Acaba de derrotarse al ultimo jefe: hay que mostrar la presentacion del
## conjunto del Caballero del Abismo (no se guarda).
var abyss_pending: bool = false

## Herramientas del panel de administrador (ver admin_panel.gd).
## admin_worlds: "normal" (progreso real), "all" (todos abiertos) o "locked".
var admin_worlds: String = "normal"
## Todos los niveles de los mundos abiertos accesibles sin superar el anterior.
var admin_levels: bool = false
## Comprar mejoras del arbol sin gastar monedas ni cumplir requisitos.
var admin_free_tree: bool = false
## Cosmeticos en prueba (no se guardan): ranura -> id. Se equipan sin poseerlos.
var trial: Dictionary = {}
var owned: Dictionary = {"skin_azul": true, "sword_acero": true, "trail_polvo": true, "aura_ninguna": true}
var equipped: Dictionary = {"skin": "skin_azul", "sword": "sword_acero", "trail": "trail_polvo", "aura": "aura_ninguna"}

## Estadisticas acumuladas.
const DEFAULT_STATS := [
	"high_score", "best_distance", "games_played", "total_coins", "total_kills", "total_gems", "total_distance", "nights_survived",
	"powers_used", "deaths", "best_combo", "perfects", "legendaries", "levels_cleared", "bosses", "modes_cleared", "total_stars", "owned_count",
]
var stats: Dictionary = {
	"high_score": 0, "best_distance": 0, "games_played": 0, "total_coins": 0,
	"total_kills": 0, "total_gems": 0, "total_distance": 0, "nights_survived": 0,
	"powers_used": 0, "deaths": 0, "best_combo": 0, "perfects": 0, "legendaries": 0, "levels_cleared": 0,
	"bosses": 0, "modes_cleared": 0, "total_stars": 0, "owned_count": 0,
}
## Logros conseguidos: id -> {"date": "AAAA-MM-DD"}.
var achievements: Dictionary = {}
## Titulo elegido (de los que dan los logros).
var title: String = ""
## Marcas de "solo la primera vez" (niveles distintos, 3 estrellas...).
var uniques: Dictionary = {}

## Misiones. Las diarias y semanales se sortean por periodo; el resto son
## permanentes y leen las estadisticas.
var period_day: int = -1
var period_week: int = -1
## Hora mas alta vista: atrasar el reloj no renueva nada.
var clock_high: float = 0.0
var daily_ids: Array = []
var daily_progress: Dictionary = {}
var daily_claimed: Dictionary = {}
var weekly_ids: Array = []
var weekly_progress: Dictionary = {}
var weekly_claimed: Dictionary = {}
## Permanentes cobradas: id -> fecha.
var mission_claimed: Dictionary = {}
## Completadas que aun no se han visto en el panel (estado "COMPLETADA").
var mission_fresh: Dictionary = {}
## Permanentes ya anunciadas (para avisar una sola vez).
var mission_announced: Dictionary = {}
var _missions_by_stat: Dictionary = {}
var _achievements_by_stat: Dictionary = {}

## Recompensa por jugar cada dia (racha de dias seguidos).
var login_day: int = -1
var login_streak: int = 0

## Ajustes.
var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var screen_shake: bool = true
## Preferencia del boton de velocidad 1.5X (se recuerda entre niveles).
var speed_2x: bool = false
var fullscreen: bool = false

var high_score: int:
	get:
		return int(stats.get("high_score", 0))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	load_data()
	_migrate_stats()
	refresh_missions()
	add_child(AchievementPopup.new())
	call_deferred("check_achievements")
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
	diamonds = int(cfg.get_value("profile", "diamonds", 0))
	_merge(campaign, cfg.get_value("profile", "campaign", {}))
	_merge(tree, cfg.get_value("profile", "tree", {}))
	_merge(powerups, cfg.get_value("profile", "powerups", {}))
	shards = int(cfg.get_value("profile", "shards", 0))
	admin_worlds = String(cfg.get_value("admin", "worlds", "normal"))
	admin_levels = bool(cfg.get_value("admin", "levels", false))
	admin_free_tree = bool(cfg.get_value("admin", "free_tree", false))
	_refund_old_items(cfg.get_value("profile", "upgrades", {}), cfg.get_value("profile", "stock", {}))
	_merge(owned, cfg.get_value("profile", "owned", {}))
	_merge(equipped, cfg.get_value("profile", "equipped", {}))
	_merge(stats, cfg.get_value("profile", "stats", {}))
	_merge(achievements, cfg.get_value("profile", "achievements", {}))
	# Compatibilidad con la primera version del juego.
	var old_score: int = int(cfg.get_value("scores", "high_score", 0))
	if old_score > int(stats.get("high_score", 0)):
		stats["high_score"] = old_score
	title = String(cfg.get_value("profile", "title", ""))
	_merge(uniques, cfg.get_value("profile", "uniques", {}))
	period_day = int(cfg.get_value("missions3", "day", -1))
	period_week = int(cfg.get_value("missions3", "week", -1))
	clock_high = float(cfg.get_value("missions3", "clock", 0.0))
	daily_ids = Array(cfg.get_value("missions3", "daily_ids", []))
	weekly_ids = Array(cfg.get_value("missions3", "weekly_ids", []))
	_merge(daily_progress, cfg.get_value("missions3", "daily_progress", {}))
	_merge(daily_claimed, cfg.get_value("missions3", "daily_claimed", {}))
	_merge(weekly_progress, cfg.get_value("missions3", "weekly_progress", {}))
	_merge(weekly_claimed, cfg.get_value("missions3", "weekly_claimed", {}))
	_merge(mission_claimed, cfg.get_value("missions3", "claimed", {}))
	_merge(mission_fresh, cfg.get_value("missions3", "fresh", {}))
	_merge(mission_announced, cfg.get_value("missions3", "announced", {}))
	login_day = int(cfg.get_value("login", "day", -1))
	login_streak = int(cfg.get_value("login", "streak", 0))
	sfx_enabled = bool(cfg.get_value("settings", "sfx_enabled", true))
	music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("settings", "music_volume", 0.7)), 0.0, 1.0)
	screen_shake = bool(cfg.get_value("settings", "screen_shake", true))
	speed_2x = bool(cfg.get_value("settings", "speed_2x", false))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))


func save_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("profile", "wallet", wallet)
	cfg.set_value("profile", "diamonds", diamonds)
	cfg.set_value("profile", "campaign", campaign)
	cfg.set_value("profile", "tree", tree)
	cfg.set_value("profile", "powerups", powerups)
	cfg.set_value("profile", "shards", shards)
	cfg.set_value("admin", "worlds", admin_worlds)
	cfg.set_value("admin", "levels", admin_levels)
	cfg.set_value("admin", "free_tree", admin_free_tree)
	cfg.set_value("profile", "owned", owned)
	cfg.set_value("profile", "equipped", equipped)
	cfg.set_value("profile", "stats", stats)
	cfg.set_value("profile", "achievements", achievements)
	cfg.set_value("profile", "title", title)
	cfg.set_value("profile", "uniques", uniques)
	cfg.set_value("missions3", "day", period_day)
	cfg.set_value("missions3", "week", period_week)
	cfg.set_value("missions3", "clock", clock_high)
	cfg.set_value("missions3", "daily_ids", daily_ids)
	cfg.set_value("missions3", "weekly_ids", weekly_ids)
	cfg.set_value("missions3", "daily_progress", daily_progress)
	cfg.set_value("missions3", "daily_claimed", daily_claimed)
	cfg.set_value("missions3", "weekly_progress", weekly_progress)
	cfg.set_value("missions3", "weekly_claimed", weekly_claimed)
	cfg.set_value("missions3", "claimed", mission_claimed)
	cfg.set_value("missions3", "fresh", mission_fresh)
	cfg.set_value("missions3", "announced", mission_announced)
	cfg.set_value("login", "day", login_day)
	cfg.set_value("login", "streak", login_streak)
	cfg.set_value("settings", "sfx_enabled", sfx_enabled)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "speed_2x", speed_2x)
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


func is_owned(id: String) -> bool:
	return bool(owned.get(id, false))


func equipped_id(slot: String) -> String:
	return String(equipped.get(slot, ""))


## Datos del cosmetico equipado en una ranura ("skin", "sword", "trail", "aura").
func equipped_item(slot: String) -> Dictionary:
	var list: Array = Catalog.cosmetics(slot)
	var id: String = String(trial.get(slot, equipped_id(slot)))
	var entry: Dictionary = Catalog.find(list, id)
	if entry.is_empty():
		entry = list[0]
	return entry


func _spend(price: int) -> bool:
	if price < 0 or wallet < price:
		return false
	wallet -= price
	wallet_changed.emit()
	return true


## Precio en diamantes con el descuento de la mejora "Regateo".
func diamond_price(entry: Dictionary) -> int:
	var gems: int = int(entry.get("gems", 0))
	if gems <= 0:
		return 0
	var discount: float = clampf(Buffs.stat("diamond_discount"), 0.0, 50.0)
	return maxi(int(roundf(float(gems) * (1.0 - discount / 100.0))), 1)


func buy_cosmetic(slot: String, id: String) -> bool:
	var entry: Dictionary = Catalog.find(Catalog.cosmetics(slot), id)
	if entry.is_empty() or is_owned(id) or entry.has("reward"):
		return false
	# Los articulos exclusivos se pagan con diamantes.
	var gems: int = diamond_price(entry)
	if gems > 0:
		if diamonds < gems:
			return false
		diamonds -= gems
		wallet_changed.emit()
		track("diamonds_spent", gems)
	elif not _spend(int(entry["price"])):
		return false
	else:
		track("coins_spent", int(entry["price"]))
	owned[id] = true
	track("buy_cosmetic")
	_track_cosmetic(entry)
	equipped[slot] = id
	Buffs.invalidate()
	save_data()
	return true


func equip(slot: String, id: String) -> void:
	if is_owned(id):
		equipped[slot] = id
		trial.erase(slot)
		Buffs.invalidate()
		save_data()


## Panel de administrador: prueba un cosmetico sin comprarlo ni guardarlo.
func try_cosmetic(slot: String, id: String) -> void:
	if not Catalog.find(Catalog.cosmetics(slot), id).is_empty():
		trial[slot] = id
		Buffs.invalidate()


func clear_trials() -> void:
	trial = {}
	Buffs.invalidate()


## Mejora "Fragmentos": las gemas recogidas se acumulan y cada cierto numero
## se funden en un diamante. Devuelve los diamantes conseguidos.
func add_gem_shards(count: int) -> int:
	var level: int = int(Buffs.stat("shards"))
	if level <= 0 or count <= 0:
		return 0
	var need: int = [40, 40, 30, 22, 15][clampi(level, 0, 4)]
	shards += count
	var made: int = int(float(shards) / float(need))
	shards -= made * need
	if made > 0:
		diamonds += made
		notice.emit("FRAGMENTOS: +%d DIAMANTE" % made)
	return made


# --------------------------------------------- power-ups y arbol de mejoras --

## Devuelve el dinero de las mejoras y objetos del sistema anterior.
func _refund_old_items(old_upgrades: Variant, old_stock: Variant) -> void:
	var refund: int = 0
	if old_upgrades is Dictionary:
		var levels: Dictionary = old_upgrades
		for key in levels:
			for i in mini(int(levels[key]), OLD_UPGRADE_PRICES.size()):
				refund += int(OLD_UPGRADE_PRICES[i])
	if old_stock is Dictionary:
		var items: Dictionary = old_stock
		for key in items:
			refund += int(OLD_CONSUMABLE_PRICES.get(String(key), 100)) * int(items[key])
	if refund > 0:
		wallet += refund
		call_deferred("emit_signal", "notice", "MEJORAS ANTIGUAS REEMBOLSADAS: +%d" % refund)
		call_deferred("save_data")


func is_powerup_owned(id: String) -> bool:
	return powerups.has(id)


func is_powerup_active(id: String) -> bool:
	return bool(powerups.get(id, false))


## Cada mundo vende sus dos power-ups en cuanto se llega a el.
func is_powerup_available(id: String) -> bool:
	var entry: Dictionary = Catalog.find(Catalog.POWERUPS, id)
	return not entry.is_empty() and is_world_unlocked(int(entry["world"]))


func buy_powerup(id: String) -> bool:
	var entry: Dictionary = Catalog.find(Catalog.POWERUPS, id)
	if entry.is_empty() or is_powerup_owned(id) or not is_powerup_available(id):
		return false
	if not _spend(int(entry["price"])):
		return false
	track("coins_spent", int(entry["price"]))
	track("buy_power")
	powerups[id] = true
	Buffs.invalidate()
	save_data()
	return true


## Activa o desactiva un power-up ya comprado.
func toggle_powerup(id: String) -> void:
	if is_powerup_owned(id):
		powerups[id] = not is_powerup_active(id)
		Buffs.invalidate()
		save_data()


func node_level(id: String) -> int:
	return int(tree.get(id, 0))


func node_max_level(id: String) -> int:
	return int(Catalog.tree_node(id).get("lv", 0))


## Precio del siguiente nivel de un nodo (-1 si esta al maximo).
func node_price(id: String) -> int:
	var prices: Array = Catalog.tree_prices(id)
	var level: int = node_level(id)
	return int(prices[level]) if level < prices.size() else -1


## Suma de niveles comprados en una categoria.
func branch_levels(branch_id: String) -> int:
	var total: int = 0
	for key in tree:
		var node: Dictionary = Catalog.tree_node(String(key))
		if not node.is_empty() and String(node["cat"]) == branch_id:
			total += int(tree[key])
	return total


## Niveles comprados en todo el arbol.
func tree_total_levels() -> int:
	var total: int = 0
	for key in tree:
		if not Catalog.tree_node(String(key)).is_empty():
			total += int(tree[key])
	return total


## Requisito especial de un nodo (secretas y maestrias). Devuelve
## [cumplido, texto del requisito, progreso actual, objetivo].
func node_condition(id: String) -> Array:
	var node: Dictionary = Catalog.tree_node(id)
	var cond: Dictionary = node.get("cond", {})
	if cond.is_empty():
		return [true, "", 0, 0]
	if cond.has("stat"):
		var stat_name: String = cond["stat"]
		var current: int = int(stats.get(stat_name, 0))
		if stat_name == "total_stars":
			current = total_stars()
		elif stat_name == "owned_count":
			current = owned.size()
		var goal: int = int(cond["min"])
		return [current >= goal, String(node.get("hint", "")), current, goal]
	if cond.has("cats"):
		var sum: int = 0
		var names: PackedStringArray = PackedStringArray()
		for cat in cond["cats"]:
			sum += branch_levels(String(cat))
			names.append(String(Catalog.branch(String(cat)).get("name", "")))
		var need: int = int(cond["min"])
		return [sum >= need, "%d NIVELES EN %s" % [need, " Y ".join(names)], sum, need]
	if cond.has("levels"):
		var have: int = tree_total_levels()
		var target: int = int(cond["levels"])
		return [have >= target, "%d NIVELES DE MEJORA EN TOTAL" % target, have, target]
	if cond.has("all_cats"):
		var each: int = int(cond["all_cats"])
		var done: int = 0
		var cats: Array = Catalog.core_branches()
		for cat in cats:
			if branch_levels(String(cat)) >= each:
				done += 1
		return [done >= cats.size(), String(node.get("hint", "")), done, cats.size()]
	return [true, "", 0, 0]


## Las mejoras secretas no se revelan hasta cumplir su requisito.
func node_revealed(id: String) -> bool:
	var node: Dictionary = Catalog.tree_node(id)
	if String(node.get("tier", "")) != "secret":
		return true
	return admin_free_tree or node_level(id) > 0 or bool(node_condition(id)[0])


## Motivo por el que un nodo no se puede comprar ("" si se puede).
func node_block_reason(id: String) -> String:
	var node: Dictionary = Catalog.tree_node(id)
	if node.is_empty():
		return "NO EXISTE"
	if node_price(id) < 0:
		return "NIVEL MÁXIMO"
	var excluded: String = String(node.get("ex", ""))
	if excluded != "" and node_level(excluded) > 0:
		return "INCOMPATIBLE CON " + String(Catalog.tree_node(excluded).get("name", ""))
	if admin_free_tree:
		return ""
	var world: int = int(node.get("w", 0))
	if not is_world_unlocked(world):
		return "REQUIERE LLEGAR AL MUNDO %d" % (world + 1)
	for req in node.get("req", []):
		if node_level(String(req)) <= 0:
			return "REQUIERE " + String(Catalog.tree_node(String(req)).get("name", ""))
	var cond: Array = node_condition(id)
	if not bool(cond[0]):
		return "REQUIERE %s (%d/%d)" % [String(cond[1]), int(cond[2]), int(cond[3])]
	return ""


func buy_node(id: String) -> bool:
	if node_block_reason(id) != "":
		return false
	var price: int = node_price(id)
	if not admin_free_tree and not _spend(price):
		return false
	# Con el arbol gratis del administrador track() no registra nada.
	track("coins_spent", price)
	track("tree_bought")
	tree[id] = node_level(id) + 1
	Buffs.invalidate()
	save_data()
	return true


# ----------------------------------------------------------------- campana --

func level_key(world: int, level: int) -> String:
	return "%d_%d" % [world, level]


func level_record(world: int, level: int) -> Dictionary:
	var record: Variant = campaign.get(level_key(world, level), {})
	if record is Dictionary:
		return record
	return {}


func level_stars(world: int, level: int) -> int:
	return int(level_record(world, level).get("stars", 0))


## Un mundo se abre al superar el nivel 20 del anterior. El panel de
## administrador puede abrirlos todos o bloquearlos todos.
func is_world_unlocked(world: int) -> bool:
	if world <= 0:
		return true
	if admin_worlds == "all":
		return true
	if admin_worlds == "locked":
		return false
	return level_stars(world - 1, Campaign.LEVELS_PER_WORLD - 1) > 0


func is_level_unlocked(world: int, level: int) -> bool:
	if not is_world_unlocked(world):
		return false
	if admin_levels:
		return true
	return level <= 0 or level_stars(world, level - 1) > 0


## Mundo conquistado: su jefe ya ha caido.
func is_world_conquered(world: int) -> bool:
	return level_stars(world, Campaign.LEVELS_PER_WORLD - 1) > 0


func conquered_worlds() -> int:
	var count: int = 0
	for w in Campaign.world_count():
		if is_world_conquered(w):
			count += 1
	return count


## Mundo mas avanzado al que se ha llegado (por progreso real).
func highest_world() -> int:
	var best: int = 0
	for w in Campaign.world_count():
		if w == 0 or level_stars(w - 1, Campaign.LEVELS_PER_WORLD - 1) > 0:
			best = w
	return best


## Multiplicador de las monedas recogidas durante una partida de campana:
## cada mundo paga mas que el anterior, y repetir un mundo que ya has dejado
## atras paga menos (la mejora "Veterano" reduce esa penalizacion).
func run_coin_factor(world: int) -> float:
	var factor: float = float(Campaign.WORLD_COIN[clampi(world, 0, Campaign.WORLD_COIN.size() - 1)])
	if world < highest_world():
		factor *= minf(Campaign.REPLAY_FACTOR + Buffs.stat("replay") / 100.0, 1.0)
	return factor * (1.0 + Buffs.stat("world_coins") / 100.0 * float(conquered_worlds()))


func total_stars() -> int:
	var total: int = 0
	for key in campaign:
		var record: Variant = campaign[key]
		if record is Dictionary:
			total += int(record.get("stars", 0))
	return total


## Guarda el resultado de un nivel y entrega las recompensas que toquen
## (solo la primera vez). Devuelve {"coins", "diamonds", "first"}.
func complete_level(world: int, level: int, stars: int, rank: int, score: int) -> Dictionary:
	var old: Dictionary = level_record(world, level)
	var first: bool = old.is_empty()
	var reward: float = Campaign.world_reward(world)
	var coins: int = 0
	var gems: int = 0
	var unlocked_items: Array = []
	if first:
		var base: float = float(Campaign.first_clear_coins(world, level))
		# Hitos: nivel 1 recompensa inicial; 5 espada; 10 aura; 15 estela;
		# 20 jefe: botin, aspecto exclusivo y siguiente mundo.
		if level == 0:
			base += 150.0 * reward
		coins += int(base * Buffs.factor("level_coins"))
		gems += Campaign.first_clear_diamonds(world, level)
		add_stat("levels_cleared", 1)
		if level == Campaign.LEVELS_PER_WORLD - 1:
			coins += int(800.0 * reward * Buffs.factor("boss_coins"))
			gems += int(Buffs.stat("boss_diamonds"))
			add_stat("bosses", 1)
		unlocked_items = grant_level_rewards(world, level)
	# Estrellas nuevas: mejora "Estrellas de oro".
	var new_stars: int = maxi(stars - int(old.get("stars", 0)), 0)
	if new_stars > 0 and Buffs.stat("star_coins") > 0.0:
		coins += int(Buffs.stat("star_coins") * float(new_stars) * reward)
	# Tres estrellas por primera vez: un diamante (y quiza otro con Constelacion).
	if stars >= 3 and int(old.get("stars", 0)) < 3:
		gems += 1
		if randf() * 100.0 < Buffs.stat("star_diamonds"):
			gems += 1
	# Interes: un porcentaje de los ahorros, con tope segun el mundo.
	if Buffs.stat("interest") > 0.0:
		coins += mini(int(float(wallet) * Buffs.stat("interest") / 100.0), int(150.0 * reward))
	# Registro para misiones y logros (no cuenta en pruebas ni con admin).
	var key: String = level_key(world, level)
	track("level_clear")
	if track_unique("level_unique", "l:" + key):
		track("level_new")
	if new_stars > 0:
		track("stars_gained", new_stars)
	if stars >= 3:
		track("three_star")
		track_unique("three_star_levels", "3:" + key)
	campaign[level_key(world, level)] = {
		"stars": maxi(stars, int(old.get("stars", 0))),
		"rank": maxi(rank, int(old.get("rank", 0))),
		"score": maxi(score, int(old.get("score", 0))),
		"ch": old.get("ch", [false, false, false]),
		"modes": old.get("modes", {}),
		"dia": old.get("dia", false),
	}
	# Maestria del mundo: las 60 estrellas dan un gran premio (una vez).
	var mastery_key: String = "mastery_%d" % world
	if not bool(campaign.get(mastery_key, false)) and world_stars(world) >= Campaign.LEVELS_PER_WORLD * 3:
		campaign[mastery_key] = true
		coins += int(1500.0 * reward)
		gems += 3
		call_deferred("emit_signal", "notice", "¡MUNDO DOMINADO! +%d Y 3 DIAMANTES" % int(1500.0 * reward))
		unlocked_items.append_array(grant_reward_key("m_%d" % world))
	diamonds += gems
	add_coins(coins)
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems, "first": first, "items": unlocked_items}


func _track_cosmetic(entry: Dictionary) -> void:
	track("cosmetics_got")
	if String(entry.get("rarity", "")) == "MÍTICO":
		track("mythic_got")
	if String(entry.get("set", "")) == "abyss" and abyss_set_owned():
		track_unique("abyss_owned", "abyss_set")


func abyss_set_owned() -> bool:
	for id in ["skin_abyss", "sword_abyss", "trail_abyss", "aura_abyss"]:
		if not is_owned(String(id)):
			return false
	return true


## Lleva puesto el conjunto completo del Caballero del Abismo.
func abyss_set_worn() -> bool:
	return equipped_item("skin")["id"] == "skin_abyss" and equipped_item("sword")["id"] == "sword_abyss" \
		and equipped_item("trail")["id"] == "trail_abyss" and equipped_item("aura")["id"] == "aura_abyss"


func world_challenges_done(world: int) -> bool:
	for i in Campaign.LEVELS_PER_WORLD:
		var done: Array = level_record(world, i).get("ch", [])
		if done.size() < 3 or not (bool(done[0]) and bool(done[1]) and bool(done[2])):
			return false
	return true


func world_stars(world: int) -> int:
	var total: int = 0
	for i in Campaign.LEVELS_PER_WORLD:
		total += level_stars(world, i)
	return total


## Entrega los objetos de aspecto ligados a un nivel. Devuelve sus nombres.
func grant_level_rewards(world: int, level: int) -> Array:
	var names: Array = grant_reward_key(level_key(world, level))
	# Ultimo jefe del juego: conjunto exclusivo del Caballero del Abismo.
	if world == Campaign.world_count() - 1 and level == Campaign.LEVELS_PER_WORLD - 1:
		names.append_array(grant_reward_key("abyss"))
		abyss_pending = true
	return names


## Entrega los cosmeticos ligados a una clave de recompensa ("1_4", "m_2",
## "c_3", "abyss"). Devuelve sus nombres.
func grant_reward_key(key: String) -> Array:
	var names: Array = []
	for slot in ["skin", "sword", "trail", "aura"]:
		for item in Catalog.cosmetics(String(slot)):
			var entry: Dictionary = item
			if String(entry.get("reward", "")) == key and not is_owned(String(entry["id"])):
				owned[String(entry["id"])] = true
				_track_cosmetic(entry)
				names.append(String(entry["name"]))
	return names


## Modo de dominio superado (primera vez): monedas y un diamante.
func complete_mode(world: int, level: int, mode: String) -> Dictionary:
	var record: Dictionary = level_record(world, level)
	var modes: Dictionary = record.get("modes", {})
	if bool(modes.get(mode, false)):
		return {"coins": 0, "diamonds": 0}
	modes[mode] = true
	record["modes"] = modes
	campaign[level_key(world, level)] = record
	add_stat("modes_cleared", 1)
	track("mode_clear")
	var coins: int = int(120.0 * Campaign.world_reward(world) * Buffs.factor("mode_coins"))
	var gems: int = 1
	if randf() * 100.0 < Buffs.stat("mode_diamonds"):
		gems += 1
	diamonds += gems
	add_coins(coins)
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems}


func mode_done(world: int, level: int, mode: String) -> bool:
	var modes: Dictionary = level_record(world, level).get("modes", {})
	return bool(modes.get(mode, false))


## Diamante oculto de la ruta arriesgada: solo cuenta una vez por nivel.
func claim_hidden_diamond(world: int, level: int) -> bool:
	var record: Dictionary = level_record(world, level)
	if bool(record.get("dia", false)):
		return false
	record["dia"] = true
	campaign[level_key(world, level)] = record
	diamonds += 1
	save_data()
	return true


func hidden_diamond_taken(world: int, level: int) -> bool:
	return bool(level_record(world, level).get("dia", false))


## Anota los retos superados de un nivel y paga los nuevos: monedas por
## cada uno y un diamante al completar los tres.
func complete_challenges(world: int, level: int, results: Array) -> Dictionary:
	var key: String = level_key(world, level)
	var record: Dictionary = level_record(world, level)
	var old: Array = record.get("ch", [false, false, false])
	var merged: Array = [false, false, false]
	var coins: int = 0
	var all_old: bool = true
	var all_new: bool = true
	for i in 3:
		var before: bool = i < old.size() and bool(old[i])
		var now: bool = i < results.size() and bool(results[i])
		if now:
			track("challenges_met")
			track_unique("challenge_new", "c:%s:%d" % [key, i])
		if now and not before:
			coins += int(30.0 * Campaign.world_reward(world) * Buffs.factor("challenge_coins"))
		merged[i] = before or now
		all_old = all_old and before
		all_new = all_new and bool(merged[i])
	var gems: int = 1 if all_new and not all_old else 0
	record["ch"] = merged
	campaign[key] = record
	# Todos los retos de un mundo: espada exclusiva de ese mundo.
	if gems > 0 and world_challenges_done(world):
		var names: Array = grant_reward_key("c_%d" % world)
		if not names.is_empty():
			call_deferred("emit_signal", "notice", "EXCLUSIVO DESBLOQUEADO: " + ", ".join(PackedStringArray(names)))
	diamonds += gems
	add_coins(coins)
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems}


# --------------------------------------------------------------- progresion --

## --- Registro de sucesos ----------------------------------------------------
## Toda estadistica de misiones y logros entra por track(), track_max() o
## track_unique(). Las partidas de prueba y el modo administrador (mundos o
## niveles abiertos, arbol gratis) no registran nada: no conceden logros ni
## ensucian las estadisticas.

## Partida de prueba del panel de administrador: no cuenta para nada.
func is_test_run() -> bool:
	return String(run.get("mode", "")) == "test"


## Alguna herramienta de administrador que altera la progresion esta activa.
func admin_active() -> bool:
	return admin_free_tree or admin_levels or admin_worlds != "normal"


func stats_locked() -> bool:
	return is_test_run() or admin_active() or bool(run.get("admin", false))


## Mundo de la partida actual (-1 en el modo infinito).
func run_world() -> int:
	if String(run.get("mode", "")) == "level":
		return int(run.get("world", -1))
	return -1


func add_stat(stat: String, amount: int) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount


## Suma a un suceso (y a su version por mundo, "kills@w2").
func track(event: String, amount: int = 1) -> void:
	if amount <= 0 or stats_locked():
		return
	_bump(event, amount)
	var world: int = run_world()
	if world >= 0:
		_bump("%s@w%d" % [event, world], amount)


## Guarda la mejor marca de un suceso (combo de una partida, rachas...).
func track_max(event: String, value: int) -> void:
	if stats_locked():
		return
	_raise(event, value)
	var world: int = run_world()
	if world >= 0:
		_raise("%s@w%d" % [event, world], value)


## Suma solo la primera vez que ocurre algo concreto (un nivel distinto...).
func track_unique(event: String, key: String) -> bool:
	if stats_locked() or uniques.has(key):
		return false
	uniques[key] = true
	track(event)
	return true


## Rachas (portales seguidos, niveles sin morir...). Devuelve la racha.
func bump_streak(streak: String, success: bool) -> int:
	if stats_locked():
		return 0
	var key: String = "streak_" + streak
	var value: int = int(stats.get(key, 0)) + 1 if success else 0
	stats[key] = value
	return value


func _bump(key: String, amount: int) -> void:
	stats[key] = int(stats.get(key, 0)) + amount
	_period_progress(key, amount, false)
	_after_stat(key)


func _raise(key: String, value: int) -> void:
	_period_progress(key, value, true)
	if value > int(stats.get(key, 0)):
		stats[key] = value
		_after_stat(key)


# --------------------------------------------------------------- misiones --

## Reloj protegido: si la hora del sistema retrocede, se usa la mas alta
## vista, asi atrasar el reloj no renueva misiones ni recompensas.
func _clock() -> float:
	var now: float = Time.get_unix_time_from_system()
	if now < clock_high:
		return clock_high
	clock_high = now
	return now


## Dia local como numero entero (para rachas y periodos).
func _local_day() -> int:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((_clock() + float(bias) * 60.0) / 86400.0))


func _week_of(day: int) -> int:
	return int(floor(float(day + 3) / 7.0))


## Renueva las diarias y semanales cuando cambia el dia o la semana. Solo
## avanza: un dia anterior al ya visto nunca vuelve a sortear misiones.
func refresh_missions() -> void:
	var day: int = _local_day()
	var changed: bool = false
	if day > period_day:
		period_day = day
		daily_ids = _pick(Missions.by_category("diaria"), Missions.DAILY_COUNT, day * 7349 + 11)
		daily_progress = {}
		daily_claimed = {}
		changed = true
	var week: int = _week_of(day)
	if week > period_week:
		period_week = week
		weekly_ids = _pick(Missions.by_category("semanal"), Missions.WEEKLY_COUNT, week * 7919 + 13)
		weekly_progress = {}
		weekly_claimed = {}
		changed = true
	if changed:
		save_data()


func _pick(pool_source: Array, count: int, seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = pool_source.duplicate()
	var ids: Array = []
	for i in mini(count, pool.size()):
		var index: int = rng.randi_range(0, pool.size() - 1)
		ids.append(String(Dictionary(pool[index])["id"]))
		pool.remove_at(index)
	return ids


func is_rotating(mission: Dictionary) -> bool:
	var cat: String = mission["cat"]
	return cat == "diaria" or cat == "semanal"


## Misiones visibles de una categoria (las de rotacion: solo las del periodo).
func missions_of(cat: String) -> Array:
	if cat == "diaria" or cat == "semanal":
		var list: Array = []
		for id in (daily_ids if cat == "diaria" else weekly_ids):
			var entry: Dictionary = Missions.find(String(id))
			if not entry.is_empty():
				list.append(entry)
		return list
	return Missions.by_category(cat)


func _period_progress(key: String, value: int, is_max: bool) -> void:
	for pair in [[daily_ids, daily_progress, daily_claimed], [weekly_ids, weekly_progress, weekly_claimed]]:
		var ids: Array = pair[0]
		var progress: Dictionary = pair[1]
		var claimed: Dictionary = pair[2]
		for id in ids:
			var mission: Dictionary = Missions.find(String(id))
			if mission.is_empty() or String(mission["stat"]) != key or claimed.has(id):
				continue
			var max_mode: bool = String(mission["mode"]) == "max"
			if max_mode != is_max:
				continue
			var before: int = int(progress.get(id, 0))
			var after: int = maxi(before, value) if is_max else before + value
			progress[id] = after
			if before < int(mission["target"]) and after >= int(mission["target"]):
				_announce_mission(mission)


func mission_progress(mission: Dictionary) -> int:
	var id: String = mission["id"]
	if String(mission["cat"]) == "diaria":
		return int(daily_progress.get(id, 0))
	if String(mission["cat"]) == "semanal":
		return int(weekly_progress.get(id, 0))
	return int(stats.get(String(mission["stat"]), 0))


func is_mission_claimed(mission: Dictionary) -> bool:
	var id: String = mission["id"]
	if String(mission["cat"]) == "diaria":
		return daily_claimed.has(id)
	if String(mission["cat"]) == "semanal":
		return weekly_claimed.has(id)
	return mission_claimed.has(id)


## Estado: 0 no iniciada, 1 en progreso, 2 completada (recien), 3 recompensa
## disponible, 4 reclamada.
func mission_state(mission: Dictionary) -> int:
	if is_mission_claimed(mission):
		return 4
	var value: int = mission_progress(mission)
	if value >= int(mission["target"]):
		return 2 if mission_fresh.has(String(mission["id"])) else 3
	return 1 if value > 0 else 0


## Las recompensas de diarias y semanales crecen con el mundo alcanzado
## para seguir siendo utiles (el resto ya estan ajustadas a su mundo).
func mission_coins(mission: Dictionary) -> int:
	var coins: float = float(mission["coins"])
	var cat: String = mission["cat"]
	if cat == "diaria":
		coins *= Campaign.world_reward(highest_world()) * Buffs.factor("mission")
	elif cat == "semanal":
		coins *= Campaign.world_reward(highest_world()) * Buffs.factor("weekly")
	return int(coins)


## Cobra una mision. Devuelve {} si no se puede (no completada o ya cobrada):
## la marca de cobrada se pone antes de pagar, asi nunca se paga dos veces.
func claim_mission(id: String) -> Dictionary:
	var mission: Dictionary = Missions.find(id)
	if mission.is_empty() or is_test_run() or is_mission_claimed(mission):
		return {}
	if mission_progress(mission) < int(mission["target"]):
		return {}
	var cat: String = mission["cat"]
	if is_rotating(mission) and not (daily_ids.has(id) or weekly_ids.has(id)):
		return {}
	var date: String = Time.get_date_string_from_unix_time(int(_clock()))
	if cat == "diaria":
		daily_claimed[id] = true
	elif cat == "semanal":
		weekly_claimed[id] = true
	else:
		mission_claimed[id] = date
	mission_fresh.erase(id)
	var coins: int = mission_coins(mission)
	var gems: int = int(mission["gems"])
	diamonds += gems
	add_coins(coins)
	track("missions_claimed")
	if cat == "diaria":
		track("daily_claimed")
	elif cat == "semanal":
		track("weekly_claimed")
	elif cat == "secreta":
		track("secret_claimed")
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems}


## Cobra todas las disponibles de una categoria ("" = todas).
func claim_all(cat: String = "") -> Dictionary:
	var total: Dictionary = {"coins": 0, "diamonds": 0, "count": 0}
	for c in Missions.CATEGORIES:
		if cat != "" and String(c) != cat:
			continue
		for item in missions_of(String(c)):
			var mission: Dictionary = item
			if mission_state(mission) < 2:
				continue
			var paid: Dictionary = claim_mission(String(mission["id"]))
			if not paid.is_empty():
				total["coins"] = int(total["coins"]) + int(paid["coins"])
				total["diamonds"] = int(total["diamonds"]) + int(paid["diamonds"])
				total["count"] = int(total["count"]) + 1
	return total


func claimable_count() -> int:
	var count: int = 0
	for c in Missions.CATEGORIES:
		for item in missions_of(String(c)):
			if mission_state(item) in [2, 3]:
				count += 1
	return count


## Las misiones recien completadas se ven como "COMPLETADA" la primera vez.
func mark_missions_seen() -> void:
	mission_fresh = {}


func _announce_mission(mission: Dictionary) -> void:
	if is_mission_claimed(mission):
		return
	mission_fresh[String(mission["id"])] = true
	var title: String = String(mission["name"])
	if String(mission["cat"]) == "secreta":
		title = "SECRETA: " + title
	notice.emit("MISIÓN COMPLETADA: %s" % title)


## Indices stat -> misiones permanentes / logros, para comprobar solo lo
## que puede haber cambiado.
func _mission_index() -> Dictionary:
	if _missions_by_stat.is_empty():
		for item in Missions.all():
			var mission: Dictionary = item
			if is_rotating(mission):
				continue
			var key: String = mission["stat"]
			if not _missions_by_stat.has(key):
				_missions_by_stat[key] = []
			_missions_by_stat[key].append(mission)
	return _missions_by_stat


func _achievement_index() -> Dictionary:
	if _achievements_by_stat.is_empty():
		for item in Achievements.all():
			var entry: Dictionary = item
			var key: String = entry["stat"]
			if not _achievements_by_stat.has(key):
				_achievements_by_stat[key] = []
			_achievements_by_stat[key].append(entry)
	return _achievements_by_stat


## Tras cambiar una estadistica: misiones permanentes y logros que dependen
## de ella, y estadisticas derivadas.
func _after_stat(key: String) -> void:
	var value: int = int(stats.get(key, 0))
	for item in _mission_index().get(key, []):
		var mission: Dictionary = item
		if value >= int(mission["target"]) and not is_mission_claimed(mission) and not mission_announced.has(String(mission["id"])):
			mission_announced[String(mission["id"])] = true
			_announce_mission(mission)
	for item in _achievement_index().get(key, []):
		var entry: Dictionary = item
		if value >= int(entry["target"]) and not has_achievement(String(entry["id"])):
			_unlock_achievement(entry)
	if key.begins_with("boss_flawless@w"):
		var worlds: int = 0
		for w in Campaign.world_count():
			if int(stats.get("boss_flawless@w%d" % w, 0)) > 0:
				worlds += 1
		_raise("boss_flawless_worlds", worlds)
	elif key.begins_with("boss_kill@w"):
		var conquered: int = 0
		for w in Campaign.world_count():
			if int(stats.get("boss_kill@w%d" % w, 0)) > 0:
				conquered += 1
		_raise("worlds_conquered", conquered)


# ------------------------------------------------------------------ logros --

func has_achievement(id: String) -> bool:
	var value: Variant = achievements.get(id, null)
	return value != null and not (value is bool and not bool(value))


func achievement_date(id: String) -> String:
	var value: Variant = achievements.get(id, null)
	if value is Dictionary:
		return String(Dictionary(value).get("date", ""))
	return ""


func achievement_progress(entry: Dictionary) -> int:
	return mini(int(stats.get(String(entry["stat"]), 0)), int(entry["target"]))


func _unlock_achievement(entry: Dictionary) -> void:
	var id: String = entry["id"]
	if has_achievement(id) or stats_locked():
		return
	achievements[id] = {"date": Time.get_date_string_from_unix_time(int(_clock()))}
	var coins: int = int(float(entry["coins"]) * Buffs.factor("achievement"))
	diamonds += int(entry["gems"])
	add_coins(coins)
	var cosmetic: String = String(entry.get("cosmetic", ""))
	if cosmetic != "":
		grant_reward_key("a_" + id)
	achievement_unlocked.emit(entry)
	call_deferred("save_data")


## Comprueba todos los logros (al cargar o tras una migracion).
func check_achievements() -> void:
	if stats_locked():
		return
	for item in Achievements.all():
		var entry: Dictionary = item
		if not has_achievement(String(entry["id"])) and int(stats.get(String(entry["stat"]), 0)) >= int(entry["target"]):
			_unlock_achievement(entry)


func prestige() -> int:
	var total: int = 0
	for item in Achievements.all():
		var entry: Dictionary = item
		if has_achievement(String(entry["id"])):
			total += int(entry["prestige"])
	return total


func unlocked_titles() -> Array:
	var list: Array = []
	for item in Achievements.all():
		var entry: Dictionary = item
		if entry.has("title") and has_achievement(String(entry["id"])):
			list.append(String(entry["title"]))
	return list


func badges() -> Array:
	var list: Array = []
	for item in Achievements.all():
		var entry: Dictionary = item
		if bool(entry.get("badge", false)) and has_achievement(String(entry["id"])):
			list.append(entry)
	return list


func set_title(text: String) -> void:
	if text == "" or unlocked_titles().has(text):
		title = text
		save_data()


## Pasa las estadisticas de versiones anteriores a las nuevas (una vez).
func _migrate_stats() -> void:
	if int(stats.get("_v3", 0)) > 0:
		return
	stats["_v3"] = 1
	var copies: Dictionary = {"kills": "total_kills", "coins_picked": "total_coins", "gems_picked": "total_gems", "nights": "nights_survived", "run": "games_played", "death": "deaths", "distance": "total_distance", "mode_clear": "modes_cleared", "boss_kill": "bosses", "run_distance": "best_distance"}
	for key in copies:
		stats[key] = maxi(int(stats.get(key, 0)), int(stats.get(String(copies[key]), 0)))
	for key in campaign:
		var record: Variant = campaign[key]
		if not (record is Dictionary) or int(Dictionary(record).get("stars", 0)) <= 0:
			continue
		var parts: PackedStringArray = String(key).split("_")
		if parts.size() != 2 or not parts[0].is_valid_int():
			continue
		var w: int = int(parts[0])
		uniques["l:" + String(key)] = true
		add_stat("level_unique", 1)
		add_stat("level_unique@w%d" % w, 1)
		add_stat("stars_gained", int(Dictionary(record)["stars"]))
		if int(Dictionary(record)["stars"]) >= 3:
			uniques["3:" + String(key)] = true
			add_stat("three_star_levels", 1)
			add_stat("three_star_levels@w%d" % w, 1)
		if int(parts[1]) == Campaign.LEVELS_PER_WORLD - 1:
			stats["boss_kill@w%d" % w] = maxi(int(stats.get("boss_kill@w%d" % w, 0)), 1)
	var conquered: int = 0
	for w in Campaign.world_count():
		if int(stats.get("boss_kill@w%d" % w, 0)) > 0:
			conquered += 1
	stats["worlds_conquered"] = conquered
	stats["tree_bought"] = tree_total_levels()
	stats["cosmetics_got"] = maxi(owned.size() - 4, 0)

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
	track("run")
	track("distance", meters)
	track_max("run_distance", meters)
	track_max("coins_run", coins)
	track_max("kills_run", kills)
	if run_world() < 0 and not is_test_run():
		track_max("endless_distance", meters)
	save_data()
	return is_record


## Recompensa por jugar hoy. Devuelve {} si ya se cobro.
func claim_login() -> Dictionary:
	var today: int = _local_day()
	if today <= login_day:
		return {}
	login_streak = login_streak + 1 if today == login_day + 1 else 1
	login_day = today
	var day: int = (login_streak - 1) % 7 + 1
	var coins: int = int(40.0 * float(day) * Buffs.factor("login"))
	var gems: int = 1 if day == 7 else 0
	diamonds += gems
	add_coins(coins)
	track("login")
	save_data()
	return {"day": day, "coins": coins, "diamonds": gems}


## Borrado de progreso (tras la triple confirmacion del menu). Se conservan
## los ajustes (sonido, graficos, controles) y la configuracion de
## administrador; tambien el reloj protegido y el sorteo del periodo, para
## que borrar no sirva para renovar misiones.
func reset_progress() -> void:
	wallet = 0
	diamonds = 0
	campaign = {}
	tree = {}
	powerups = {}
	shards = 0
	trial = {}
	run = {"mode": "endless"}
	abyss_pending = false
	owned = {"skin_azul": true, "sword_acero": true, "trail_polvo": true, "aura_ninguna": true}
	equipped = {"skin": "skin_azul", "sword": "sword_acero", "trail": "trail_polvo", "aura": "aura_ninguna"}
	stats = {}
	for key in DEFAULT_STATS:
		stats[key] = 0
	stats["_v3"] = 1
	achievements = {}
	title = ""
	uniques = {}
	daily_progress = {}
	daily_claimed = {}
	weekly_progress = {}
	weekly_claimed = {}
	mission_claimed = {}
	mission_fresh = {}
	mission_announced = {}
	login_day = -1
	login_streak = 0
	Buffs.invalidate()
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
