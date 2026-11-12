extends RefCounted
## Catalogo del juego: cosmeticos (con sus buffs), power-ups de la tienda,
## arbol de mejoras, logros y misiones. Son solo datos; la logica vive en
## game_data.gd (compras), buffs.gd (efectos) y shop.gd / skill_tree.gd.
##
## Buffs: {"stat": valor}. Los nombres de los stats y como se muestran estan
## en buffs.gd (STATS). Todos son pequenos a proposito.

## Aspectos del heroe: remapeo de colores y un buff que define su estilo.
const SKINS := [
	{"id": "skin_azul", "name": "CABALLERO AZUL", "price": 0, "remap": {}, "buff": {"points": 1.0}},
	{"id": "skin_carmesi", "name": "CARMESÍ", "price": 300, "remap": {"b": "r", "B": "o", "r": "w"}, "buff": {"jump_cut": 6.0}},
	{"id": "skin_esmeralda", "name": "ESMERALDA", "price": 300, "remap": {"b": "G", "B": "L", "r": "y"}, "buff": {"good": 4.0}},
	{"id": "skin_hielo", "name": "GLACIAR", "price": 500, "remap": {"b": "B", "B": "c", "r": "c", "l": "w"}, "buff": {"ice_grip": 15.0}},
	{"id": "skin_sombra", "name": "SOMBRA", "price": 800, "remap": {"l": "g", "w": "l", "b": "p", "B": "r", "r": "c", "h": "l"}, "buff": {"legend": 3.0}},
	{"id": "skin_dorado", "name": "PALADÍN DORADO", "price": 1500, "remap": {"l": "y", "g": "o", "b": "w", "B": "w", "r": "b"}, "buff": {"coins": 3.0}},
	{"id": "skin_bosque", "name": "GUARDABOSQUES", "price": 0, "reward": "0_19", "rarity": "EPIC", "remap": {"b": "t", "B": "G", "r": "L", "l": "u", "g": "e"}, "buff": {"mash": 8.0}},
	{"id": "skin_demonio", "name": "DEMONÍACO", "price": 0, "reward": "1_19", "rarity": "EPIC", "remap": {"b": "r", "B": "o", "l": "d", "g": "k", "w": "g", "r": "y"}, "buff": {"jump_height": 2.0}},
	{"id": "skin_arcano", "name": "ARCANO", "price": 0, "reward": "2_19", "rarity": "LEGENDARY", "remap": {"b": "p", "B": "m", "r": "c", "l": "m", "g": "p"}, "buff": {"perfect": 3.0}},
	{"id": "skin_yeti", "name": "YETI", "price": 0, "reward": "3_19", "rarity": "LEGENDARY", "remap": {"b": "w", "B": "l", "r": "B", "l": "w", "g": "l"}, "buff": {"warn": 8.0}},
	{"id": "skin_faraon", "name": "FARAÓN", "price": 0, "reward": "4_19", "rarity": "MYTHIC", "remap": {"l": "y", "g": "o", "b": "t", "B": "c", "r": "y"}, "buff": {"combo_points": 6.0}},
]

## Espadas: el alcance crece MUY poco y de forma progresiva con el precio
## (el alcance base es de unos 180 px; +3.5% son apenas 6 px).
const SWORDS := [
	{"id": "sword_acero", "name": "ACERO", "price": 0, "remap": {}, "slash": ["73eff7", "f4f4f4"], "buff": {"reach": 0.0}},
	{"id": "sword_fuego", "name": "LLAMA", "price": 350, "remap": {"w": "o", "y": "r", "o": "p"}, "slash": ["ef7d57", "ffcd75"], "buff": {"reach": 0.5}},
	{"id": "sword_hielo", "name": "ESCARCHA", "price": 350, "remap": {"w": "c", "y": "B", "o": "b"}, "slash": ["41a6f6", "f4f4f4"], "buff": {"reach": 0.5}},
	{"id": "sword_esmeralda", "name": "ESPINA", "price": 500, "remap": {"w": "L", "y": "G", "o": "t"}, "slash": ["38b764", "a7f070"], "buff": {"reach": 1.0}},
	{"id": "sword_sombra", "name": "PENUMBRA", "price": 800, "remap": {"w": "p", "y": "d", "o": "k"}, "slash": ["5d275d", "b13e53"], "buff": {"reach": 1.5}},
	{"id": "sword_oro", "name": "SOLAR", "price": 1200, "remap": {"w": "y", "y": "o", "o": "r"}, "slash": ["ffcd75", "f4f4f4"], "buff": {"reach": 2.0}},
	{"id": "sword_amatista", "name": "AMATISTA", "price": 0, "gems": 3, "rarity": "RARE", "remap": {"w": "m", "y": "p", "o": "n"}, "slash": ["f29cb5", "5d275d"], "buff": {"reach": 1.5}},
	{"id": "sword_celestial", "name": "CELESTIAL", "price": 0, "gems": 6, "rarity": "EPIC", "remap": {"w": "c", "y": "w", "o": "B"}, "slash": ["73eff7", "ffcd75"], "buff": {"reach": 2.5}},
	{"id": "sword_oscura", "name": "OSCURA", "price": 0, "gems": 6, "rarity": "EPIC", "remap": {"w": "d", "y": "p", "o": "k"}, "slash": ["5d275d", "b13e53"], "buff": {"reach": 2.5}},
	{"id": "sword_legendaria", "name": "LEGENDARIA", "price": 0, "gems": 15, "rarity": "MYTHIC", "remap": {"w": "y", "y": "r", "o": "p", "k": "e"}, "slash": ["ffcd75", "ef7d57"], "buff": {"reach": 3.5}},
	{"id": "sword_raiz", "name": "HOJA DE RAÍZ", "price": 0, "reward": "0_4", "rarity": "RARE", "remap": {"w": "L", "y": "G", "o": "u"}, "slash": ["a7f070", "38b764"], "buff": {"reach": 1.0}},
	{"id": "sword_ignea", "name": "COLMILLO ÍGNEO", "price": 0, "reward": "1_4", "rarity": "RARE", "remap": {"w": "y", "y": "r", "o": "k"}, "slash": ["ef7d57", "b13e53"], "buff": {"reach": 1.5}},
	{"id": "sword_prisma", "name": "FILO PRISMA", "price": 0, "reward": "2_4", "rarity": "EPIC", "remap": {"w": "m", "y": "c", "o": "p"}, "slash": ["f29cb5", "73eff7"], "buff": {"reach": 2.0}},
	{"id": "sword_gelida", "name": "GÉLIDA", "price": 0, "reward": "3_4", "rarity": "EPIC", "remap": {"w": "w", "y": "c", "o": "B"}, "slash": ["f4f4f4", "73eff7"], "buff": {"reach": 2.5}},
	{"id": "sword_eterna", "name": "SOL ETERNO", "price": 0, "reward": "4_4", "rarity": "LEGENDARY", "remap": {"w": "y", "y": "u", "o": "e"}, "slash": ["ffcd75", "8a5a44"], "buff": {"reach": 3.0}},
]

## Estelas: buffs de movimiento y timing.
const TRAILS := [
	{"id": "trail_polvo", "name": "POLVO", "price": 0, "colors": ["f4f4f4"], "buff": {"coyote": 10.0}},
	{"id": "trail_chispas", "name": "CHISPAS", "price": 250, "colors": ["ffcd75", "f4f4f4"], "buff": {"perfect": 2.0}},
	{"id": "trail_fuego", "name": "FUEGO", "price": 400, "colors": ["ef7d57", "b13e53", "ffcd75"], "buff": {"jump_points": 5.0}},
	{"id": "trail_hielo", "name": "ESCARCHA", "price": 400, "colors": ["73eff7", "41a6f6", "f4f4f4"], "buff": {"land": 8.0}},
	{"id": "trail_arcoiris", "name": "ARCOÍRIS", "price": 900, "colors": ["b13e53", "ef7d57", "ffcd75", "38b764", "41a6f6", "5d275d"], "buff": {"good": 4.0}},
	{"id": "trail_cristales", "name": "CRISTALES", "price": 0, "gems": 3, "rarity": "RARE", "colors": ["f29cb5", "73eff7", "f4f4f4"], "buff": {"perfect": 3.0}},
	{"id": "trail_electrica", "name": "ELÉCTRICA", "price": 0, "gems": 5, "rarity": "EPIC", "colors": ["ffcd75", "f4f4f4", "41a6f6"], "buff": {"coyote": 20.0}},
	{"id": "trail_estrellas", "name": "ESTRELLAS", "price": 0, "gems": 8, "rarity": "LEGENDARY", "colors": ["f4f4f4", "ffcd75"], "buff": {"legend": 3.0}},
	{"id": "trail_energia", "name": "ENERGÍA PURA", "price": 0, "gems": 12, "rarity": "MYTHIC", "colors": ["a7f070", "73eff7", "5d275d", "f4f4f4"], "buff": {"chain": 12.0}},
	{"id": "trail_hojas", "name": "HOJAS", "price": 0, "reward": "0_14", "rarity": "RARE", "colors": ["38b764", "a7f070", "8a5a44"], "buff": {"jump_points": 4.0}},
	{"id": "trail_cenizas", "name": "CENIZAS", "price": 0, "reward": "1_14", "rarity": "EPIC", "colors": ["ef7d57", "333c57", "ffcd75"], "buff": {"land": 10.0}},
	{"id": "trail_prisma", "name": "PRISMA", "price": 0, "reward": "2_14", "rarity": "EPIC", "colors": ["f29cb5", "b06fd0", "73eff7"], "buff": {"perfect": 2.5}},
	{"id": "trail_nieve", "name": "VENTISCA", "price": 0, "reward": "3_14", "rarity": "LEGENDARY", "colors": ["f4f4f4", "94b0c2", "73eff7"], "buff": {"coyote": 15.0}},
	{"id": "trail_arena", "name": "ARENA DORADA", "price": 0, "reward": "4_14", "rarity": "LEGENDARY", "colors": ["ffcd75", "ef7d57", "8a5a44"], "buff": {"good": 5.0}},
]

## Auras: buffs de recompensas (monedas, puntos, iman, gemas, combo).
const AURAS := [
	{"id": "aura_ninguna", "name": "SIN AURA", "price": 0, "color": "", "buff": {"points": 1.0}},
	{"id": "aura_dorada", "name": "AURA DORADA", "price": 600, "color": "ffcd75", "buff": {"coins": 4.0}},
	{"id": "aura_arcana", "name": "AURA ARCANA", "price": 600, "color": "b13e53", "buff": {"combo_points": 5.0}},
	{"id": "aura_glacial", "name": "AURA GLACIAL", "price": 600, "color": "73eff7", "buff": {"magnet": 20.0}},
	{"id": "aura_fuego", "name": "AURA DE FUEGO", "price": 0, "gems": 3, "rarity": "RARE", "color": "ef7d57", "buff": {"coins": 5.0}},
	{"id": "aura_electrica", "name": "AURA ELÉCTRICA", "price": 0, "gems": 4, "rarity": "RARE", "color": "f4f4f4", "buff": {"magnet": 30.0}},
	{"id": "aura_violeta", "name": "AURA VIOLETA", "price": 0, "gems": 5, "rarity": "EPIC", "color": "b06fd0", "buff": {"gems": 3.0}},
	{"id": "aura_celestial", "name": "AURA CELESTIAL", "price": 0, "gems": 8, "rarity": "LEGENDARY", "color": "41a6f6", "buff": {"points": 4.0}},
	{"id": "aura_oscura", "name": "AURA OSCURA", "price": 0, "gems": 8, "rarity": "LEGENDARY", "color": "8a5a9a", "buff": {"combo_points": 8.0}},
	{"id": "aura_bosque", "name": "AURA DEL BOSQUE", "price": 0, "reward": "0_9", "rarity": "RARE", "color": "38b764", "buff": {"coins": 3.0}},
	{"id": "aura_infernal", "name": "AURA INFERNAL", "price": 0, "reward": "1_9", "rarity": "EPIC", "color": "e04a2a", "buff": {"points": 3.0}},
	{"id": "aura_prisma", "name": "AURA PRISMA", "price": 0, "reward": "2_9", "rarity": "EPIC", "color": "f29cb5", "buff": {"gems": 4.0}},
	{"id": "aura_boreal", "name": "AURA BOREAL", "price": 0, "reward": "3_9", "rarity": "LEGENDARY", "color": "7af0c0", "buff": {"magnet": 40.0}},
	{"id": "aura_solar", "name": "AURA SOLAR", "price": 0, "reward": "4_9", "rarity": "MYTHIC", "color": "ffb030", "buff": {"coins": 6.0}},
]

## Los dos power-ups de la tienda: se compran una vez (caros) y se activan o
## desactivan en la tienda. Funcionan solos; no anaden controles.
const POWERUPS := [
	{"id": "pu_phoenix", "name": "PLUMA DE FÉNIX", "price": 9000, "icon": "heart",
		"desc": "UNA VEZ POR INTENTO SOBREVIVES A UN GOLPE MORTAL. PIERDES EL COMBO Y EL RANGO MÁXIMO DEL NIVEL BAJA A A",
		"buff": {"phoenix": 1.0}},
	{"id": "pu_hawk", "name": "OJO DE HALCÓN", "price": 7000, "icon": "arrow_down",
		"desc": "MARCA EN EL SUELO EL PUNTO DE SALTO PERFECT DEL PRÓXIMO OBSTÁCULO. A CAMBIO, -15% DE PUNTOS",
		"buff": {"hawk": 1.0, "points": -15.0}},
]

## Arbol de mejoras. Cada nodo: rama, posicion en su rejilla [columna, fila],
## precios por nivel (cada vez mas caros), requisitos (nodos a nivel 1 o
## mas), buff por nivel y, en especializaciones, el nodo incompatible.
const TREE_BRANCHES := [
	{"id": "movimiento", "name": "MOVIMIENTO", "color": "41a6f6"},
	{"id": "precision", "name": "PRECISIÓN", "color": "a7f070"},
	{"id": "combate", "name": "COMBATE", "color": "b13e53"},
	{"id": "supervivencia", "name": "SUPERVIVENCIA", "color": "73eff7"},
	{"id": "economia", "name": "ECONOMÍA", "color": "ffcd75"},
	{"id": "especializacion", "name": "ESPECIALIZACIÓN", "color": "f29cb5"},
]
const TREE := [
	{"id": "m_control", "branch": "movimiento", "pos": [0, 1], "name": "CONTROL DE SALTO", "desc": "SALTOS CORTOS MÁS BAJOS Y PRECISOS", "prices": [200, 450, 900], "buff": {"jump_cut": 4.0}},
	{"id": "m_long", "branch": "movimiento", "pos": [1, 0], "requires": ["m_control"], "name": "SALTO PROLONGADO", "desc": "SALTO MÁXIMO UN POCO MÁS ALTO", "prices": [400, 900, 1700], "buff": {"jump_height": 1.5}},
	{"id": "m_precise", "branch": "movimiento", "pos": [2, 0], "requires": ["m_long"], "name": "SALTO DE PRECISIÓN", "desc": "PUEDES PULSAR UN POCO ANTES DE ATERRIZAR", "prices": [800, 1600], "buff": {"buffer": 15.0}},
	{"id": "m_air", "branch": "movimiento", "pos": [3, 0], "requires": ["m_precise"], "name": "DOMINIO AÉREO", "desc": "EL PISOTÓN ALCANZA MÁS ENEMIGOS", "prices": [1500, 3000], "buff": {"stomp": 12.0}},
	{"id": "m_recover", "branch": "movimiento", "pos": [1, 2], "requires": ["m_control"], "name": "RECUPERACIÓN", "desc": "MÁS MARGEN PARA SALTAR AL DEJAR UN BORDE", "prices": [350, 800, 1500], "buff": {"coyote": 12.0}},
	{"id": "m_chain", "branch": "movimiento", "pos": [2, 2], "requires": ["m_recover"], "name": "SALTO ENCADENADO", "desc": "MÁS PREMIO POR CADENAS DE SALTOS PERFECTOS", "prices": [700, 1400, 2600], "buff": {"chain": 20.0}},
	{"id": "p_window", "branch": "precision", "pos": [0, 1], "name": "VENTANA DE TIMING", "desc": "VENTANA GOOD UN POCO MÁS AMPLIA", "prices": [250, 500, 900, 1500, 2400], "buff": {"good": 2.0}},
	{"id": "p_perfect", "branch": "precision", "pos": [1, 0], "requires": ["p_window"], "name": "PERFECT TIMING", "desc": "VENTANA PERFECT UN POCO MÁS AMPLIA", "prices": [600, 1300, 2500], "buff": {"perfect": 2.5}},
	{"id": "p_legend", "branch": "precision", "pos": [2, 0], "requires": ["p_perfect"], "name": "PULSO LEGENDARIO", "desc": "VENTANA LEGENDARY UN POCO MÁS AMPLIA", "prices": [1500, 3200], "buff": {"legend": 3.0}},
	{"id": "p_reaction", "branch": "precision", "pos": [1, 2], "requires": ["p_window"], "name": "REACCIÓN MEJORADA", "desc": "LOS AVISOS DE PELIGRO LLEGAN ANTES", "prices": [400, 900, 1700], "buff": {"warn": 5.0}},
	{"id": "p_mash", "branch": "precision", "pos": [2, 2], "requires": ["p_reaction"], "name": "PULSACIÓN FIRME", "desc": "CADA PULSACIÓN EMPUJA MÁS A BARRICADAS Y BRUTOS", "prices": [500, 1100, 2000], "buff": {"mash": 8.0}},
	{"id": "c_reach", "branch": "combate", "pos": [0, 1], "name": "FILO LARGO", "desc": "ALCANCE DE ATAQUE LIGERAMENTE MAYOR", "prices": [300, 700, 1400], "buff": {"reach": 0.8}},
	{"id": "c_bounty", "branch": "combate", "pos": [1, 0], "requires": ["c_reach"], "name": "BOTÍN DE CAZA", "desc": "+1 MONEDA POR ENEMIGO", "prices": [300, 600, 1100, 1800, 2800], "buff": {"bounty": 1.0}},
	{"id": "c_master", "branch": "combate", "pos": [1, 2], "requires": ["c_reach"], "name": "GOLPE MAESTRO", "desc": "MÁS PUNTOS POR ATAQUE PERFECTO", "prices": [500, 1100, 2100], "buff": {"attack_points": 12.0}},
	{"id": "c_combo", "branch": "combate", "pos": [2, 2], "requires": ["c_master"], "name": "BOTÍN DE COMBO", "desc": "+1 MONEDA POR ACCIÓN PERFECTA", "prices": [900, 1900, 3500], "buff": {"combo_coins": 1.0}},
	{"id": "c_counter", "branch": "combate", "pos": [2, 0], "requires": ["c_bounty", "c_master"], "name": "CONTRAGOLPE", "desc": "LOS CENTINELAS QUEDAN VULNERABLES MÁS TIEMPO", "prices": [1200, 2500], "buff": {"counter": 10.0}},
	{"id": "s_hitbox", "branch": "supervivencia", "pos": [0, 1], "name": "SILUETA ÁGIL", "desc": "TU CUERPO OCUPA 1 PX MENOS: ROCES MÁS JUSTOS", "prices": [500, 1200, 2400], "buff": {"hitbox": 1.0}},
	{"id": "s_ledge", "branch": "supervivencia", "pos": [1, 0], "requires": ["s_hitbox"], "name": "AGARRE DE BORDE", "desc": "TE SUBES A LOS BORDES DE LOS HUECOS CON MÁS MARGEN", "prices": [700, 1500], "buff": {"ledge": 4.0}},
	{"id": "s_ice", "branch": "supervivencia", "pos": [1, 2], "requires": ["s_hitbox"], "name": "PIES FIRMES", "desc": "EL HIELO TE ACELERA MENOS", "prices": [500, 1100], "buff": {"ice_grip": 20.0}},
	{"id": "s_quick", "branch": "supervivencia", "pos": [2, 1], "requires": ["s_ledge"], "name": "REINTENTO RÁPIDO", "desc": "AL MORIR, PULSA PARA REINTENTAR AL INSTANTE", "prices": [1000], "buff": {"quick_retry": 1.0}},
	{"id": "e_coins", "branch": "economia", "pos": [0, 1], "name": "BOLSILLO", "desc": "+6% DE MONEDAS", "prices": [250, 550, 1000, 1700, 2700], "buff": {"coins": 6.0}},
	{"id": "e_magnet", "branch": "economia", "pos": [1, 0], "requires": ["e_coins"], "name": "IMÁN", "desc": "ATRAE LAS MONEDAS CERCANAS", "prices": [300, 650, 1200, 2000, 3200], "buff": {"magnet": 35.0}},
	{"id": "e_lucky", "branch": "economia", "pos": [1, 2], "requires": ["e_coins"], "name": "FORTUNA", "desc": "MÁS RUBÍES Y GEMAS", "prices": [500, 1100, 2100], "buff": {"gems": 3.0}},
	{"id": "e_score", "branch": "economia", "pos": [2, 0], "requires": ["e_magnet"], "name": "PUNTUACIÓN", "desc": "+4% DE PUNTOS", "prices": [600, 1300, 2500], "buff": {"points": 4.0}},
	{"id": "e_gems", "branch": "economia", "pos": [2, 2], "requires": ["e_lucky"], "name": "OJO DE JOYERO", "desc": "EL DIAMANTE OCULTO SIEMPRE APARECE EN LA RUTA ALTA", "prices": [2500], "buff": {"diamond_sense": 1.0}},
	{"id": "x_daredevil", "branch": "especializacion", "pos": [0, 0], "requires": ["p_perfect", "m_long"], "excludes": "x_method", "name": "TEMERARIO", "desc": "LAST SECOND Y LEGENDARY X2 PUNTOS. GOOD NO DA PUNTOS", "prices": [4000], "buff": {"daredevil": 1.0}},
	{"id": "x_method", "branch": "especializacion", "pos": [0, 2], "requires": ["p_window"], "excludes": "x_daredevil", "name": "METÓDICO", "desc": "LAS ACCIONES GOOD TAMBIÉN SUMAN AL COMBO. LEGENDARY X0.5", "prices": [4000], "buff": {"methodical": 1.0}},
	{"id": "x_fury", "branch": "especializacion", "pos": [1, 0], "requires": ["c_master"], "excludes": "x_zen", "name": "FURIA", "desc": "ENEMIGOS X2 PUNTOS. SALTOS PERFECTOS X0.5", "prices": [3500], "buff": {"fury": 1.0}},
	{"id": "x_zen", "branch": "especializacion", "pos": [1, 2], "requires": ["m_chain"], "excludes": "x_fury", "name": "SERENIDAD", "desc": "SALTOS PERFECTOS X2 PUNTOS. ENEMIGOS X0.5", "prices": [3500], "buff": {"zen": 1.0}},
	{"id": "x_greed", "branch": "especializacion", "pos": [2, 0], "requires": ["e_lucky"], "excludes": "x_ascetic", "name": "AVARICIA", "desc": "+25% MONEDAS, -15% PUNTOS", "prices": [3000], "buff": {"coins": 25.0, "points": -15.0}},
	{"id": "x_ascetic", "branch": "especializacion", "pos": [2, 2], "requires": ["e_score"], "excludes": "x_greed", "name": "ASCETA", "desc": "+25% PUNTOS, -25% MONEDAS", "prices": [3000], "buff": {"points": 25.0, "coins": -25.0}},
]

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
