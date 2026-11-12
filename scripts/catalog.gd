extends RefCounted
## Catalogo del juego: articulos de la tienda, poderes, logros y misiones.
## Son solo datos; la logica de compra y progreso vive en game_data.gd.

## Arbol de mejoras permanentes en cuatro ramas. `prices` tiene un precio por
## nivel (cada vez mas caro) y `requires` es la mejora que hay que tener al
## menos a nivel 1 para desbloquearla.
const BRANCHES := {
	"monedas": {"name": "MONEDAS", "color": "ffcd75"},
	"combate": {"name": "COMBATE", "color": "b13e53"},
	"supervivencia": {"name": "SUPERVIVENCIA", "color": "41a6f6"},
	"precision": {"name": "PRECISIÓN", "color": "a7f070"},
}
const UPGRADES := [
	{"id": "coin_mult", "branch": "monedas", "name": "MULTIPLICADOR", "desc": "+20% DE MONEDAS POR NIVEL", "icon": "coin_0", "prices": [150, 400, 900, 1800, 3200]},
	{"id": "lucky", "branch": "monedas", "requires": "coin_mult", "name": "FORTUNA", "desc": "MÁS RUBÍES Y GEMAS EN EL CAMINO", "icon": "gem", "prices": [250, 600, 1300, 2500, 4200]},
	{"id": "magnet", "branch": "monedas", "requires": "coin_mult", "name": "IMÁN", "desc": "ATRAE LAS MONEDAS CERCANAS", "icon": "icon_magnet", "prices": [200, 500, 1100, 2200, 3800]},
	{"id": "bounty", "branch": "combate", "name": "RECOMPENSA", "desc": "+1 MONEDA POR ENEMIGO Y NIVEL", "icon": "goblin_a", "prices": [150, 400, 900, 1800, 3200]},
	{"id": "perfect", "branch": "combate", "requires": "bounty", "name": "GOLPE MAESTRO", "desc": "+20% PUNTOS POR ATAQUE PERFECTO", "icon": "icon_soul", "prices": [250, 600, 1300, 2500, 4200]},
	{"id": "reach", "branch": "combate", "requires": "bounty", "name": "ALCANCE", "desc": "LA ESPADA LLEGA UN 8% MÁS LEJOS", "icon": "sword", "prices": [200, 500, 1100, 2200, 3800]},
	{"id": "combo_coins", "branch": "combate", "requires": "perfect", "name": "BOTÍN DE COMBO", "desc": "+1 MONEDA POR ACCIÓN PERFECTA", "icon": "chest", "prices": [300, 700, 1500, 2800, 4500]},
	{"id": "energy", "branch": "combate", "requires": "reach", "name": "ENERGÍA", "desc": "TURBO Y ONDA SE RECARGAN ANTES", "icon": "icon_bolt", "prices": [200, 500, 1000, 2000, 3500]},
	{"id": "shield", "branch": "supervivencia", "name": "ESCUDO", "desc": "ABSORBE UN GOLPE Y SE RECARGA", "icon": "icon_shield", "prices": [250, 600, 1200, 2400, 4000]},
	{"id": "recovery", "branch": "supervivencia", "requires": "shield", "name": "RECUPERACIÓN", "desc": "MÁS INMUNIDAD TRAS UN GOLPE", "icon": "heart", "prices": [200, 500, 1000, 2000, 3500]},
	{"id": "armor", "branch": "supervivencia", "requires": "recovery", "name": "ARMADURA", "desc": "+1 VIDA MÁXIMA POR NIVEL", "icon": "knight_a", "prices": [1500, 4000]},
	{"id": "jump_bonus", "branch": "precision", "name": "SALTO MAESTRO", "desc": "+25% PUNTOS POR SALTO PERFECTO", "icon": "hero_legs_jump", "prices": [200, 500, 1000, 2000, 3500]},
	{"id": "dodge_bonus", "branch": "precision", "requires": "jump_bonus", "name": "ESQUIVA MAESTRA", "desc": "+30% POR ESQUIVA Y LAST SECOND", "icon": "icon_wave", "prices": [250, 600, 1300, 2500, 4200]},
	{"id": "score", "branch": "precision", "requires": "jump_bonus", "name": "PUNTUACIÓN", "desc": "+8% DE PUNTOS POR NIVEL", "icon": "star", "prices": [200, 500, 1100, 2200, 3800]},
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
	{"id": "skin_bosque", "name": "GUARDABOSQUES", "price": 0, "reward": "0_19", "rarity": "EPIC", "remap": {"b": "t", "B": "G", "r": "L", "l": "u", "g": "e"}},
	{"id": "skin_demonio", "name": "DEMONÍACO", "price": 0, "reward": "1_19", "rarity": "EPIC", "remap": {"b": "r", "B": "o", "l": "d", "g": "k", "w": "g", "r": "y"}},
	{"id": "skin_arcano", "name": "ARCANO", "price": 0, "reward": "2_19", "rarity": "LEGENDARY", "remap": {"b": "p", "B": "m", "r": "c", "l": "m", "g": "p"}},
	{"id": "skin_yeti", "name": "YETI", "price": 0, "reward": "3_19", "rarity": "LEGENDARY", "remap": {"b": "w", "B": "l", "r": "B", "l": "w", "g": "l"}},
	{"id": "skin_faraon", "name": "FARAÓN", "price": 0, "reward": "4_19", "rarity": "MYTHIC", "remap": {"l": "y", "g": "o", "b": "t", "B": "c", "r": "y"}},
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
	{"id": "sword_raiz", "name": "HOJA DE RAÍZ", "price": 0, "reward": "0_4", "rarity": "RARE", "remap": {"w": "L", "y": "G", "o": "u"}, "slash": ["a7f070", "38b764"]},
	{"id": "sword_ignea", "name": "COLMILLO ÍGNEO", "price": 0, "reward": "1_4", "rarity": "RARE", "remap": {"w": "y", "y": "r", "o": "k"}, "slash": ["ef7d57", "b13e53"]},
	{"id": "sword_prisma", "name": "FILO PRISMA", "price": 0, "reward": "2_4", "rarity": "EPIC", "remap": {"w": "m", "y": "c", "o": "p"}, "slash": ["f29cb5", "73eff7"]},
	{"id": "sword_gelida", "name": "GÉLIDA", "price": 0, "reward": "3_4", "rarity": "EPIC", "remap": {"w": "w", "y": "c", "o": "B"}, "slash": ["f4f4f4", "73eff7"]},
	{"id": "sword_eterna", "name": "SOL ETERNO", "price": 0, "reward": "4_4", "rarity": "LEGENDARY", "remap": {"w": "y", "y": "u", "o": "e"}, "slash": ["ffcd75", "8a5a44"]},
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
	{"id": "trail_hojas", "name": "HOJAS", "price": 0, "reward": "0_14", "rarity": "RARE", "colors": ["38b764", "a7f070", "8a5a44"]},
	{"id": "trail_cenizas", "name": "CENIZAS", "price": 0, "reward": "1_14", "rarity": "EPIC", "colors": ["ef7d57", "333c57", "ffcd75"]},
	{"id": "trail_prisma", "name": "PRISMA", "price": 0, "reward": "2_14", "rarity": "EPIC", "colors": ["f29cb5", "b06fd0", "73eff7"]},
	{"id": "trail_nieve", "name": "VENTISCA", "price": 0, "reward": "3_14", "rarity": "LEGENDARY", "colors": ["f4f4f4", "94b0c2", "73eff7"]},
	{"id": "trail_arena", "name": "ARENA DORADA", "price": 0, "reward": "4_14", "rarity": "LEGENDARY", "colors": ["ffcd75", "ef7d57", "8a5a44"]},
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
	{"id": "aura_bosque", "name": "AURA DEL BOSQUE", "price": 0, "reward": "0_9", "rarity": "RARE", "color": "38b764"},
	{"id": "aura_infernal", "name": "AURA INFERNAL", "price": 0, "reward": "1_9", "rarity": "EPIC", "color": "e04a2a"},
	{"id": "aura_prisma", "name": "AURA PRISMA", "price": 0, "reward": "2_9", "rarity": "EPIC", "color": "f29cb5"},
	{"id": "aura_boreal", "name": "AURA BOREAL", "price": 0, "reward": "3_9", "rarity": "LEGENDARY", "color": "7af0c0"},
	{"id": "aura_solar", "name": "AURA SOLAR", "price": 0, "reward": "4_9", "rarity": "MYTHIC", "color": "ffb030"},
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
	{"id": "combo_10", "name": "IMPARABLE", "desc": "COMBO PERFECTO DE 10", "stat": "best_combo", "target": 10, "reward": 100},
	{"id": "combo_25", "name": "INFALIBLE", "desc": "COMBO PERFECTO DE 25", "stat": "best_combo", "target": 25, "reward": 300},
	{"id": "perfects_100", "name": "PRECISO", "desc": "100 ACCIONES PERFECT", "stat": "perfects", "target": 100, "reward": 150},
	{"id": "legend_25", "name": "ÚLTIMO SEGUNDO", "desc": "25 ACCIONES LEGENDARY", "stat": "legendaries", "target": 25, "reward": 200},
	{"id": "levels_20", "name": "EXPLORADOR", "desc": "SUPERA 20 NIVELES", "stat": "levels_cleared", "target": 20, "reward": 200},
	{"id": "levels_100", "name": "CONQUISTADOR", "desc": "SUPERA LOS 100 NIVELES", "stat": "levels_cleared", "target": 100, "reward": 2000},
	{"id": "bosses_1", "name": "MATAJEFES", "desc": "DERROTA A UN JEFE", "stat": "bosses", "target": 1, "reward": 200},
	{"id": "bosses_5", "name": "LIBERTADOR", "desc": "DERROTA A LOS CINCO JEFES", "stat": "bosses", "target": 5, "reward": 1500},
	{"id": "stars_150", "name": "CONSTELACIÓN", "desc": "CONSIGUE 150 ESTRELLAS", "stat": "total_stars", "target": 150, "reward": 500},
	{"id": "collector_20", "name": "COLECCIONISTA", "desc": "REÚNE 20 OBJETOS DE ASPECTO", "stat": "owned_count", "target": 20, "reward": 300},
	{"id": "modes_10", "name": "DOMINADOR", "desc": "SUPERA 10 MODOS DE DOMINIO", "stat": "modes_cleared", "target": 10, "reward": 400},
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
