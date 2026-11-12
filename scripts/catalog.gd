extends RefCounted
## Catalogo del juego: articulos de la tienda, poderes, logros y misiones.
## Son solo datos; la logica de compra y progreso vive en game_data.gd.

## Mejoras permanentes. `prices` tiene un precio por nivel.
const UPGRADES := [
	{"id": "magnet", "name": "IMÁN DE MONEDAS", "desc": "ATRAE LAS MONEDAS CERCANAS", "icon": "icon_magnet", "prices": [150, 400, 900]},
	{"id": "coin_mult", "name": "MULTIPLICADOR", "desc": "+25% DE MONEDAS POR NIVEL", "icon": "coin_0", "prices": [200, 500, 1100]},
	{"id": "shield", "name": "ESCUDO", "desc": "ABSORBE UN GOLPE Y SE RECARGA", "icon": "icon_shield", "prices": [250, 600, 1200]},
	{"id": "score", "name": "PUNTUACIÓN", "desc": "+10% DE PUNTOS POR NIVEL", "icon": "star", "prices": [150, 400, 900]},
	{"id": "bounty", "name": "RECOMPENSA", "desc": "+1 MONEDA POR ENEMIGO Y NIVEL", "icon": "goblin_a", "prices": [150, 400, 900]},
	{"id": "energy", "name": "ENERGÍA", "desc": "LOS PODERES SE RECARGAN ANTES", "icon": "icon_bolt", "prices": [200, 500, 1000]},
	{"id": "lucky", "name": "FORTUNA", "desc": "MÁS GEMAS Y RUBÍES EN EL CAMINO", "icon": "gem", "prices": [250, 600, 1300]},
	{"id": "reach", "name": "ALCANCE", "desc": "LA ESPADA LLEGA MÁS LEJOS", "icon": "sword", "prices": [200, 500, 1000]},
	{"id": "perfect", "name": "MAESTRÍA", "desc": "+20% DE PUNTOS POR ACCIÓN PERFECTA", "icon": "icon_soul", "prices": [250, 600, 1300]},
	{"id": "combo_coins", "name": "BOTÍN DE COMBO", "desc": "+1 MONEDA POR ACCIÓN PERFECTA Y NIVEL", "icon": "chest", "prices": [300, 700, 1500]},
	{"id": "recovery", "name": "RECUPERACIÓN", "desc": "MÁS INMUNIDAD TRAS RECIBIR UN GOLPE", "icon": "heart", "prices": [200, 500, 1000]},
]

## Objetos de un solo uso. Se gastan solos en la siguiente partida.
const CONSUMABLES := [
	{"id": "revive", "name": "REVIVIR", "desc": "VUELVES A LA VIDA UNA VEZ", "icon": "heart", "price": 300},
	{"id": "guard", "name": "PROTECCIÓN", "desc": "15 S INMUNE AL EMPEZAR", "icon": "icon_shield", "price": 120},
	{"id": "double", "name": "DOBLE BOTÍN", "desc": "MONEDAS X2 TODA LA PARTIDA", "icon": "gem", "price": 200},
	{"id": "magnet_boost", "name": "SUPERIMÁN", "desc": "IMÁN POTENTE DURANTE 45 S", "icon": "icon_magnet", "price": 120},
]

## Aspectos del heroe: remapeo de colores del sprite.
const SKINS := [
	{"id": "skin_azul", "name": "CABALLERO AZUL", "price": 0, "remap": {}},
	{"id": "skin_carmesi", "name": "CARMESÍ", "price": 300, "remap": {"b": "r", "B": "o", "r": "w"}},
	{"id": "skin_esmeralda", "name": "ESMERALDA", "price": 300, "remap": {"b": "G", "B": "L", "r": "y"}},
	{"id": "skin_hielo", "name": "GLACIAR", "price": 500, "remap": {"b": "B", "B": "c", "r": "c", "l": "w"}},
	{"id": "skin_sombra", "name": "SOMBRA", "price": 800, "remap": {"l": "g", "w": "l", "b": "p", "B": "r", "r": "c", "h": "l"}},
	{"id": "skin_dorado", "name": "PALADÍN DORADO", "price": 1500, "remap": {"l": "y", "g": "o", "b": "w", "B": "w", "r": "b"}},
]

## Espadas: remapeo del sprite y colores de la estela del tajo.
const SWORDS := [
	{"id": "sword_acero", "name": "ACERO", "price": 0, "remap": {}, "slash": ["73eff7", "f4f4f4"]},
	{"id": "sword_fuego", "name": "LLAMA", "price": 350, "remap": {"w": "o", "y": "r", "o": "p"}, "slash": ["ef7d57", "ffcd75"]},
	{"id": "sword_hielo", "name": "ESCARCHA", "price": 350, "remap": {"w": "c", "y": "B", "o": "b"}, "slash": ["41a6f6", "f4f4f4"]},
	{"id": "sword_esmeralda", "name": "ESPINA", "price": 500, "remap": {"w": "L", "y": "G", "o": "t"}, "slash": ["38b764", "a7f070"]},
	{"id": "sword_sombra", "name": "PENUMBRA", "price": 800, "remap": {"w": "p", "y": "d", "o": "k"}, "slash": ["5d275d", "b13e53"]},
	{"id": "sword_oro", "name": "SOLAR", "price": 1200, "remap": {"w": "y", "y": "o", "o": "r"}, "slash": ["ffcd75", "f4f4f4"]},
	# Exclusivas de diamantes ("gems" = precio en diamantes).
	{"id": "sword_amatista", "name": "AMATISTA", "price": 0, "gems": 3, "rarity": "RARE", "remap": {"w": "m", "y": "p", "o": "n"}, "slash": ["f29cb5", "5d275d"]},
	{"id": "sword_celestial", "name": "CELESTIAL", "price": 0, "gems": 6, "rarity": "EPIC", "remap": {"w": "c", "y": "w", "o": "B"}, "slash": ["73eff7", "ffcd75"]},
	{"id": "sword_oscura", "name": "OSCURA", "price": 0, "gems": 6, "rarity": "EPIC", "remap": {"w": "d", "y": "p", "o": "k"}, "slash": ["5d275d", "b13e53"]},
	{"id": "sword_legendaria", "name": "LEGENDARIA", "price": 0, "gems": 15, "rarity": "MYTHIC", "remap": {"w": "y", "y": "r", "o": "p", "k": "e"}, "slash": ["ffcd75", "ef7d57"]},
]

## Estelas de particulas al correr.
const TRAILS := [
	{"id": "trail_polvo", "name": "POLVO", "price": 0, "colors": ["f4f4f4"]},
	{"id": "trail_chispas", "name": "CHISPAS", "price": 250, "colors": ["ffcd75", "f4f4f4"]},
	{"id": "trail_fuego", "name": "FUEGO", "price": 400, "colors": ["ef7d57", "b13e53", "ffcd75"]},
	{"id": "trail_hielo", "name": "ESCARCHA", "price": 400, "colors": ["73eff7", "41a6f6", "f4f4f4"]},
	{"id": "trail_arcoiris", "name": "ARCOÍRIS", "price": 900, "colors": ["b13e53", "ef7d57", "ffcd75", "38b764", "41a6f6", "5d275d"]},
	{"id": "trail_cristales", "name": "CRISTALES", "price": 0, "gems": 3, "rarity": "RARE", "colors": ["f29cb5", "73eff7", "f4f4f4"]},
	{"id": "trail_electrica", "name": "ELÉCTRICA", "price": 0, "gems": 5, "rarity": "EPIC", "colors": ["ffcd75", "f4f4f4", "41a6f6"]},
	{"id": "trail_estrellas", "name": "ESTRELLAS", "price": 0, "gems": 8, "rarity": "LEGENDARY", "colors": ["f4f4f4", "ffcd75"]},
	{"id": "trail_energia", "name": "ENERGÍA PURA", "price": 0, "gems": 12, "rarity": "MYTHIC", "colors": ["a7f070", "73eff7", "5d275d", "f4f4f4"]},
]

## Efectos especiales: aura luminosa alrededor del heroe.
const AURAS := [
	{"id": "aura_ninguna", "name": "SIN AURA", "price": 0, "color": ""},
	{"id": "aura_dorada", "name": "AURA DORADA", "price": 600, "color": "ffcd75"},
	{"id": "aura_arcana", "name": "AURA ARCANA", "price": 600, "color": "b13e53"},
	{"id": "aura_glacial", "name": "AURA GLACIAL", "price": 600, "color": "73eff7"},
	{"id": "aura_fuego", "name": "AURA DE FUEGO", "price": 0, "gems": 3, "rarity": "RARE", "color": "ef7d57"},
	{"id": "aura_electrica", "name": "AURA ELÉCTRICA", "price": 0, "gems": 4, "rarity": "RARE", "color": "f4f4f4"},
	{"id": "aura_violeta", "name": "AURA VIOLETA", "price": 0, "gems": 5, "rarity": "EPIC", "color": "b06fd0"},
	{"id": "aura_celestial", "name": "AURA CELESTIAL", "price": 0, "gems": 8, "rarity": "LEGENDARY", "color": "41a6f6"},
	{"id": "aura_oscura", "name": "AURA OSCURA", "price": 0, "gems": 8, "rarity": "LEGENDARY", "color": "8a5a9a"},
]

## Poderes activables (teclas 1-2-3 / Q-W-E o botones en pantalla).
## Soul Reaper no tiene recarga por tiempo: se carga con acciones perfectas.
const POWERS := [
	{"id": "turbo", "name": "TURBO", "icon": "icon_bolt", "key": "1", "cooldown": 18.0, "duration": 3.5},
	{"id": "wave", "name": "ONDA", "icon": "icon_wave", "key": "2", "cooldown": 26.0, "duration": 0.5},
	{"id": "soul", "name": "SOUL", "icon": "icon_soul", "key": "3", "cooldown": 0.0, "duration": 0.0},
]

## Logros: se cumplen cuando la estadistica `stat` alcanza `target`.
const ACHIEVEMENTS := [
	{"id": "dist_500", "name": "CAMINANTE", "desc": "RECORRE 500 M EN UNA PARTIDA", "stat": "best_distance", "target": 500, "reward": 50},
	{"id": "dist_1500", "name": "CORREDOR", "desc": "RECORRE 1500 M EN UNA PARTIDA", "stat": "best_distance", "target": 1500, "reward": 150},
	{"id": "dist_3000", "name": "LEYENDA", "desc": "RECORRE 3000 M EN UNA PARTIDA", "stat": "best_distance", "target": 3000, "reward": 400},
	{"id": "kills_25", "name": "CAZADOR", "desc": "DERROTA 25 ENEMIGOS", "stat": "total_kills", "target": 25, "reward": 60},
	{"id": "kills_150", "name": "VERDUGO", "desc": "DERROTA 150 ENEMIGOS", "stat": "total_kills", "target": 150, "reward": 250},
	{"id": "coins_500", "name": "AHORRADOR", "desc": "REÚNE 500 MONEDAS EN TOTAL", "stat": "total_coins", "target": 500, "reward": 80},
	{"id": "coins_3000", "name": "TESORERO", "desc": "REÚNE 3000 MONEDAS EN TOTAL", "stat": "total_coins", "target": 3000, "reward": 300},
	{"id": "games_10", "name": "PERSISTENTE", "desc": "JUEGA 10 PARTIDAS", "stat": "games_played", "target": 10, "reward": 50},
	{"id": "games_50", "name": "VETERANO", "desc": "JUEGA 50 PARTIDAS", "stat": "games_played", "target": 50, "reward": 200},
	{"id": "score_2000", "name": "PUNTUADOR", "desc": "CONSIGUE 2000 PUNTOS", "stat": "high_score", "target": 2000, "reward": 100},
	{"id": "score_6000", "name": "MAESTRO", "desc": "CONSIGUE 6000 PUNTOS", "stat": "high_score", "target": 6000, "reward": 300},
	{"id": "nights_1", "name": "NOCTÁMBULO", "desc": "SOBREVIVE A UNA NOCHE ENTERA", "stat": "nights_survived", "target": 1, "reward": 100},
	{"id": "gems_20", "name": "JOYERO", "desc": "RECOGE 20 GEMAS", "stat": "total_gems", "target": 20, "reward": 100},
	{"id": "powers_30", "name": "HECHICERO", "desc": "USA 30 PODERES", "stat": "powers_used", "target": 30, "reward": 100},
]

## Plantillas de misiones diarias: cada dia se eligen tres.
const MISSIONS := [
	{"id": "m_coins", "text": "RECOGE %d MONEDAS", "stat": "coins", "target": 60, "reward": 40},
	{"id": "m_kills", "text": "DERROTA %d ENEMIGOS", "stat": "kills", "target": 12, "reward": 40},
	{"id": "m_distance", "text": "RECORRE %d METROS", "stat": "distance", "target": 1200, "reward": 50},
	{"id": "m_gems", "text": "RECOGE %d GEMAS", "stat": "gems", "target": 4, "reward": 50},
	{"id": "m_runs", "text": "JUEGA %d PARTIDAS", "stat": "runs", "target": 3, "reward": 30},
	{"id": "m_powers", "text": "USA %d PODERES", "stat": "powers", "target": 6, "reward": 40},
	{"id": "m_night", "text": "SOBREVIVE %d NOCHE", "stat": "nights", "target": 1, "reward": 60},
]


static func find(list: Array, id: String) -> Dictionary:
	for item in list:
		var entry: Dictionary = item
		if String(entry["id"]) == id:
			return entry
	return {}


## Lista de cosmeticos de una categoria: "skin", "sword", "trail" o "aura".
static func cosmetics(slot: String) -> Array:
	if slot == "skin":
		return SKINS
	if slot == "sword":
		return SWORDS
	if slot == "trail":
		return TRAILS
	return AURAS
