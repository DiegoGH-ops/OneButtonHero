extends Node
## Autoload "GameData": perfil permanente del jugador.
## Monedero, mejoras, objetos, cosmeticos, estadisticas, logros, misiones
## diarias y ajustes. Todo se guarda en user://one_button_hero.cfg (ConfigFile).

signal settings_changed
signal wallet_changed
## Aviso para mostrar en pantalla (logro, mision, recompensa...).
signal notice(text: String)

const Catalog = preload("res://scripts/catalog.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Buffs = preload("res://scripts/buffs.gd")

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
var stats: Dictionary = {
	"high_score": 0, "best_distance": 0, "games_played": 0, "total_coins": 0,
	"total_kills": 0, "total_gems": 0, "total_distance": 0, "nights_survived": 0,
	"powers_used": 0, "deaths": 0, "best_combo": 0, "perfects": 0, "legendaries": 0, "levels_cleared": 0,
	"bosses": 0, "modes_cleared": 0, "total_stars": 0, "owned_count": 0,
}
var achievements: Dictionary = {}

## Misiones del dia.
var missions_date: String = ""
var missions: Array = []
var mission_progress: Dictionary = {}
var mission_done: Dictionary = {}

## Desafio semanal (tres misiones mas exigentes que duran toda la semana).
var week_id: int = -1
var weekly: Array = []
var weekly_progress: Dictionary = {}
var weekly_done: Dictionary = {}

## Recompensa por jugar cada dia (racha de dias seguidos).
var login_day: int = -1
var login_streak: int = 0

## Ajustes.
var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var screen_shake: bool = true
## Preferencia del boton 2X (se recuerda entre niveles).
var speed_2x: bool = false
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
	missions_date = String(cfg.get_value("missions", "date", ""))
	week_id = int(cfg.get_value("weekly", "id", -1))
	_merge(weekly_progress, cfg.get_value("weekly", "progress", {}))
	_merge(weekly_done, cfg.get_value("weekly", "done", {}))
	login_day = int(cfg.get_value("login", "day", -1))
	login_streak = int(cfg.get_value("login", "streak", 0))
	_merge(mission_progress, cfg.get_value("missions", "progress", {}))
	_merge(mission_done, cfg.get_value("missions", "done", {}))
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
	cfg.set_value("missions", "date", missions_date)
	cfg.set_value("weekly", "id", week_id)
	cfg.set_value("weekly", "progress", weekly_progress)
	cfg.set_value("weekly", "done", weekly_done)
	cfg.set_value("login", "day", login_day)
	cfg.set_value("login", "streak", login_streak)
	cfg.set_value("missions", "progress", mission_progress)
	cfg.set_value("missions", "done", mission_done)
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
	elif not _spend(int(entry["price"])):
		return false
	owned[id] = true
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
	if not admin_free_tree and not _spend(node_price(id)):
		return false
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
	diamonds += gems
	add_coins(coins)
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems, "first": first, "items": unlocked_items}


func world_stars(world: int) -> int:
	var total: int = 0
	for i in Campaign.LEVELS_PER_WORLD:
		total += level_stars(world, i)
	return total


## Entrega los objetos de aspecto ligados a un nivel. Devuelve sus nombres.
func grant_level_rewards(world: int, level: int) -> Array:
	var names: Array = []
	var key: String = level_key(world, level)
	for slot in ["skin", "sword", "trail", "aura"]:
		for item in Catalog.cosmetics(String(slot)):
			var entry: Dictionary = item
			if String(entry.get("reward", "")) == key and not is_owned(String(entry["id"])):
				owned[String(entry["id"])] = true
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
		if now and not before:
			coins += int(30.0 * Campaign.world_reward(world) * Buffs.factor("challenge_coins"))
		merged[i] = before or now
		all_old = all_old and before
		all_new = all_new and bool(merged[i])
	var gems: int = 1 if all_new and not all_old else 0
	record["ch"] = merged
	campaign[key] = record
	diamonds += gems
	add_coins(coins)
	save_data()
	wallet_changed.emit()
	return {"coins": coins, "diamonds": gems}


# --------------------------------------------------------------- progresion --

## Elige las tres misiones del dia (las mismas para toda la jornada).
func refresh_missions() -> void:
	var today: String = Time.get_date_string_from_system()
	if today != missions_date:
		missions_date = today
		mission_progress = {}
		mission_done = {}
	_refresh_weekly()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool: Array = Catalog.MISSIONS.duplicate()
	missions = []
	for i in 3:
		var index: int = rng.randi_range(0, pool.size() - 1)
		missions.append(pool[index])
		pool.remove_at(index)


## Dia local como numero entero (para rachas y semanas).
func _local_day() -> int:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + float(bias) * 60.0) / 86400.0))


## Desafio semanal: tres misiones x5 que cambian cada lunes.
func _refresh_weekly() -> void:
	var week: int = int(floor(float(_local_day() + 3) / 7.0))
	if week != week_id:
		week_id = week
		weekly_progress = {}
		weekly_done = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = week * 7919 + 13
	var pool: Array = Catalog.MISSIONS.duplicate()
	weekly = []
	for i in 3:
		var index: int = rng.randi_range(0, pool.size() - 1)
		var base: Dictionary = pool[index]
		var mission: Dictionary = base.duplicate()
		mission["id"] = "w_" + String(base["id"])
		mission["target"] = int(base["target"]) * 5
		mission["reward"] = int(base["reward"]) * 4
		weekly.append(mission)
		pool.remove_at(index)


## Recompensa por jugar hoy. Devuelve {} si ya se cobro.
func claim_login() -> Dictionary:
	var today: int = _local_day()
	if today == login_day:
		return {}
	login_streak = login_streak + 1 if today == login_day + 1 else 1
	login_day = today
	var day: int = (login_streak - 1) % 7 + 1
	var coins: int = int(40.0 * float(day) * Buffs.factor("login"))
	var gems: int = 1 if day == 7 else 0
	diamonds += gems
	add_coins(coins)
	save_data()
	return {"day": day, "coins": coins, "diamonds": gems}


## Suma progreso a las misiones cuyo contador sea `stat`.
func add_mission_progress(stat: String, amount: int) -> void:
	# Las partidas de prueba del administrador no cuentan.
	if amount <= 0 or String(run.get("mode", "")) == "test":
		return
	for item in weekly:
		var week_mission: Dictionary = item
		var week_key: String = week_mission["id"]
		if String(week_mission["stat"]) != stat or bool(weekly_done.get(week_key, false)):
			continue
		var week_value: int = int(weekly_progress.get(week_key, 0)) + amount
		weekly_progress[week_key] = week_value
		if week_value >= int(week_mission["target"]):
			weekly_done[week_key] = true
			var week_reward: int = int(float(week_mission["reward"]) * Buffs.factor("weekly"))
			add_coins(week_reward)
			diamonds += 1
			notice.emit("DESAFÍO SEMANAL: +%d Y 1 DIAMANTE" % week_reward)
	for item in missions:
		var mission: Dictionary = item
		var id: String = mission["id"]
		if String(mission["stat"]) != stat or bool(mission_done.get(id, false)):
			continue
		var value: int = int(mission_progress.get(id, 0)) + amount
		mission_progress[id] = value
		if value >= int(mission["target"]):
			mission_done[id] = true
			var mission_reward: int = int(float(mission["reward"]) * Buffs.factor("mission"))
			add_coins(mission_reward)
			notice.emit("MISIÓN CUMPLIDA: +%d MONEDAS" % mission_reward)


func mission_text(mission: Dictionary) -> String:
	return String(mission["text"]) % int(mission["target"])


func add_stat(stat: String, amount: int) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount


## Comprueba los logros y entrega sus recompensas.
func check_achievements() -> void:
	stats["total_stars"] = total_stars()
	stats["owned_count"] = owned.size()
	for item in Catalog.ACHIEVEMENTS:
		var entry: Dictionary = item
		var id: String = entry["id"]
		if bool(achievements.get(id, false)):
			continue
		if int(stats.get(String(entry["stat"]), 0)) >= int(entry["target"]):
			achievements[id] = true
			var prize: int = int(float(entry["reward"]) * Buffs.factor("achievement"))
			add_coins(prize)
			notice.emit("LOGRO: %s  +%d" % [String(entry["name"]), prize])


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
	diamonds = 0
	campaign = {}
	weekly_progress = {}
	weekly_done = {}
	tree = {}
	powerups = {}
	shards = 0
	trial = {}
	owned = {"skin_azul": true, "sword_acero": true, "trail_polvo": true, "aura_ninguna": true}
	equipped = {"skin": "skin_azul", "sword": "sword_acero", "trail": "trail_polvo", "aura": "aura_ninguna"}
	for key in stats:
		stats[key] = 0
	achievements = {}
	mission_progress = {}
	mission_done = {}
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
