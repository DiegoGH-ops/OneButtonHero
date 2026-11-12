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

## Power-ups de la tienda: EXACTAMENTE DOS POR MUNDO, ligados a su tematica,
## sus enemigos y sus mecanicas. Se compran una vez (caros), solo cuando se
## ha llegado a su mundo, y se activan o desactivan en la tienda. Todos
## tienen una contrapartida. No anaden controles: funcionan solos.
const POWERUPS := [
	{"id": "pu_hawk", "world": 0, "name": "OJO DE HALCÓN", "price": 7000, "icon": "arrow_down", "color": "a7f070",
		"desc": "MARCA EN EL SUELO EL PUNTO EXACTO DE SALTO PERFECT DEL PRÓXIMO OBSTÁCULO. IDEAL PARA APRENDER LAS MECÁNICAS DE VERDANTIA",
		"cost": "-15% DE PUNTOS",
		"buff": {"hawk": 1.0, "points": -15.0}},
	{"id": "pu_roots", "world": 0, "name": "RAÍCES VIGÍAS", "price": 8500, "icon": "mushroom", "color": "38b764",
		"desc": "LAS RAÍCES DEL BOSQUE TE AVISAN: JABALÍES Y TOPOS SE DELATAN ANTES Y LOS PERSEGUIDORES CORREN UN 25% MÁS DESPACIO",
		"cost": "-10% DE MONEDAS",
		"buff": {"warn": 25.0, "chaser_slow": 25.0, "coins": -10.0}},
	{"id": "pu_phoenix", "world": 1, "name": "PLUMA DE FÉNIX", "price": 16000, "icon": "heart", "color": "ef7d57",
		"desc": "NACIDA EN LAS LLAMAS DE INFERNUS: UNA VEZ POR INTENTO SOBREVIVES A UN GOLPE MORTAL O A UNA CAÍDA",
		"cost": "PIERDES EL COMBO Y EL RANGO MÁXIMO BAJA A A",
		"buff": {"phoenix": 1.0}},
	{"id": "pu_magma", "world": 1, "name": "CORAZÓN DE MAGMA", "price": 14000, "icon": "flame_a", "color": "b13e53",
		"desc": "TUS PULSACIONES ARDEN: BRUTOS Y BARRICADAS CEDEN UN 40% ANTES Y EL MAGMA DIVISIBLE YA NO SE DIVIDE",
		"cost": "-12% DE PUNTOS",
		"buff": {"mash": 40.0, "no_split": 1.0, "points": -12.0}},
	{"id": "pu_prism", "world": 2, "name": "PRISMA REFRACTOR", "price": 24000, "icon": "gem", "color": "f29cb5",
		"desc": "LA LUZ ROMPE LAS DEFENSAS DE CRISTAL: LOS GUARDIANES QUEDAN VULNERABLES UN 60% MÁS Y CADA BLOQUEO LES ACERCA A ABRIRSE",
		"cost": "-10% DE MONEDAS",
		"buff": {"counter": 60.0, "shield_break": 2.0, "coins": -10.0}},
	{"id": "pu_mirror", "world": 2, "name": "ESPEJO DE CUARZO", "price": 26000, "icon": "star", "color": "73eff7",
		"desc": "DEVUELVES LOS ORBES DE LOS JEFES CON UN GOLPE GOOD Y CADA PROYECTIL QUE CORTAS DA PUNTOS EXTRA",
		"cost": "-8% DE PUNTOS",
		"buff": {"boss_reflect": 1.0, "reflect_points": 100.0, "points": -8.0}},
	{"id": "pu_crampons", "world": 3, "name": "CRAMPONES DE GLACIAR", "price": 34000, "icon": "icon_shield", "color": "94b0c2",
		"desc": "EL HIELO DE FROSTFALL APENAS TE ACELERA Y VES MUCHO MEJOR DURANTE LAS VENTISCAS",
		"cost": "-10% DE MONEDAS",
		"buff": {"ice_grip": 60.0, "storm_clear": 70.0, "coins": -10.0}},
	{"id": "pu_frost", "world": 3, "name": "ALIENTO GÉLIDO", "price": 36000, "icon": "icon_clock", "color": "41a6f6",
		"desc": "EL FRÍO LO RALENTIZA TODO: PROYECTILES Y BOLAS DE NIEVE UN 35% MÁS LENTOS Y PERSEGUIDORES UN 15%",
		"cost": "-12% DE PUNTOS",
		"buff": {"projectile_slow": 35.0, "chaser_slow": 15.0, "points": -12.0}},
	{"id": "pu_scarab", "world": 4, "name": "AMULETO DEL ESCARABAJO", "price": 48000, "icon": "chest", "color": "ffcd75",
		"desc": "EL TESORO DE LAS DUNAS: +25% DE MONEDAS Y LOS COFRES DAN EL DOBLE",
		"cost": "-20% DE PUNTOS",
		"buff": {"coins": 25.0, "chest": 100.0, "points": -20.0}},
	{"id": "pu_oracle", "world": 4, "name": "VISIÓN DEL ORÁCULO", "price": 52000, "icon": "icon_soul", "color": "b06fd0",
		"desc": "VES EL FUTURO: LOS HUECOS SE MARCAN, LOS AVISOS LLEGAN UN 50% ANTES Y LAS TORMENTAS DE ARENA APENAS TAPAN",
		"cost": "-15% DE MONEDAS",
		"buff": {"hole_sight": 1.0, "warn": 50.0, "storm_clear": 50.0, "coins": -15.0}},
]

## Arbol de mejoras: 15 categorias repartidas en un mapa de 5 x 3 regiones.
## Cada nodo:
##   cat   categoria (region)          pos   [columna, fila] dentro de su region
##   tier  normal, advanced, epic, special, legendary o secret (precio y estilo)
##   lv    niveles                      buff  efecto POR NIVEL (ver buffs.gd)
##   w     mundo que hay que haber alcanzado (0 = Verdantia ... 4 = Solaris)
##   req   nodos que deben tener al menos un nivel
##   cond  requisito especial: {"stat": nombre, "min": n}, {"cats": [...], "min": n}
##         (suma de niveles en esas categorias), {"levels": n} (niveles totales)
##         o {"all_cats": n} (todas las categorias con n niveles o mas)
##   ex    nodo incompatible (especializaciones)
## Los precios salen de tree_prices() a partir del tier, el mundo y el nivel.
const TREE_BRANCHES := [
	{"id": "movimiento", "short": "MOVIMIENTO", "name": "MOVIMIENTO", "color": "41a6f6", "icon": "icon_wave", "cell": [0, 0]},
	{"id": "salto", "short": "SALTO", "name": "DOMINIO DEL SALTO", "color": "73eff7", "icon": "pad", "cell": [1, 0]},
	{"id": "precision", "short": "PRECISIÓN", "name": "PRECISIÓN", "color": "a7f070", "icon": "arrow_down", "cell": [2, 0]},
	{"id": "timing", "short": "TIMING", "name": "TIMING", "color": "38b764", "icon": "icon_clock", "cell": [3, 0]},
	{"id": "maestria", "short": "MAESTRÍA", "name": "MAESTRÍA", "color": "f4f4f4", "icon": "goal_flag", "cell": [4, 0]},
	{"id": "combate", "short": "COMBATE", "name": "COMBATE", "color": "b13e53", "icon": "sword", "cell": [0, 1]},
	{"id": "espadas", "short": "ESPADAS", "name": "ESPADAS", "color": "ef7d57", "icon": "sword", "cell": [1, 1]},
	{"id": "legendarias", "short": "LEGENDARIAS", "name": "MEJORAS LEGENDARIAS", "color": "ffcd75", "icon": "icon_soul", "cell": [2, 1]},
	{"id": "supervivencia", "short": "SUPERVIVENCIA", "name": "SUPERVIVENCIA", "color": "94b0c2", "icon": "heart", "cell": [3, 1]},
	{"id": "especializacion", "short": "ESPECIALIZAR", "name": "ESPECIALIZACIÓN", "color": "f29cb5", "icon": "icon_bolt", "cell": [4, 1]},
	{"id": "economia", "short": "ECONOMÍA", "name": "ECONOMÍA", "color": "ffcd75", "icon": "chest", "cell": [0, 2]},
	{"id": "monedas", "short": "MONEDAS", "name": "MONEDAS", "color": "ffb030", "icon": "coin_0", "cell": [1, 2]},
	{"id": "diamantes", "short": "DIAMANTES", "name": "DIAMANTES", "color": "73eff7", "icon": "gem", "cell": [2, 2]},
	{"id": "recompensas", "short": "RECOMPENSAS", "name": "RECOMPENSAS", "color": "b06fd0", "icon": "star", "cell": [3, 2]},
	{"id": "secretas", "short": "SECRETAS", "name": "MEJORAS SECRETAS", "color": "5d275d", "icon": "ghost", "cell": [4, 2]},
]

## Precio base de cada tier (nivel 1, mundo 0), crecimiento por nivel y
## multiplicador por mundo exigido. Ver tools/simulacion_economia.py.
const TIER_BASE := {"normal": 200, "advanced": 650, "epic": 2200, "special": 6000, "legendary": 20000, "secret": 9000}
const TIER_GROWTH := 1.7
const WORLD_PRICE := [1.0, 1.7, 2.6, 3.7, 5.0]
const TIER_NAMES := {"normal": "NORMAL", "advanced": "AVANZADA", "epic": "ÉPICA", "special": "ESPECIAL", "legendary": "LEGENDARIA", "secret": "SECRETA"}

const TREE := [
	# ------------------------------------------------------------ MOVIMIENTO
	{"id": "m_control", "cat": "movimiento", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "CONTROL DE SALTO", "desc": "AL SOLTAR PRONTO, EL SALTO CORTO ES MÁS BAJO Y PRECISO", "buff": {"jump_cut": 4.0}},
	{"id": "m_long", "cat": "movimiento", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["m_control"], "name": "SALTO PROLONGADO", "desc": "MANTENIENDO EL BOTÓN, EL SALTO LLEGA UN POCO MÁS ALTO", "buff": {"jump_height": 1.5}},
	{"id": "m_recover", "cat": "movimiento", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["m_control"], "name": "RECUPERACIÓN", "desc": "MÁS MARGEN PARA SALTAR JUSTO DESPUÉS DE DEJAR UN BORDE", "buff": {"coyote": 12.0}},
	{"id": "m_precise", "cat": "movimiento", "pos": [2, 0], "tier": "advanced", "lv": 2, "w": 0, "req": ["m_long"], "name": "SALTO DE PRECISIÓN", "desc": "LA PULSACIÓN HECHA UN POCO ANTES DE ATERRIZAR SE GUARDA", "buff": {"buffer": 15.0}},
	{"id": "m_chain", "cat": "movimiento", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["m_recover"], "name": "SALTO ENCADENADO", "desc": "MÁS PUNTOS POR CADA CADENA DE TRES SALTOS PERFECTOS", "buff": {"chain": 20.0}},
	{"id": "m_air", "cat": "movimiento", "pos": [3, 0], "tier": "advanced", "lv": 2, "w": 0, "req": ["m_precise"], "name": "DOMINIO AÉREO", "desc": "EL PISOTÓN APLASTA ENEMIGOS EN UN RADIO MAYOR", "buff": {"stomp": 12.0}},
	{"id": "m_hang", "cat": "movimiento", "pos": [3, 2], "tier": "epic", "lv": 3, "w": 1, "req": ["m_precise", "m_chain"], "name": "SUSPENSIÓN", "desc": "EN EL PUNTO MÁS ALTO DEL SALTO LA GRAVEDAD AFLOJA: MÁS TIEMPO PARA DECIDIR", "buff": {"hang": 12.0}},
	{"id": "m_stomp_bounce", "cat": "movimiento", "pos": [4, 0], "tier": "advanced", "lv": 3, "w": 1, "req": ["m_air"], "name": "REBOTE DE PISOTÓN", "desc": "AL APLASTAR A UN ENEMIGO REBOTAS MÁS ALTO", "buff": {"stomp_bounce": 15.0}},
	{"id": "m_trajectory", "cat": "movimiento", "pos": [4, 2], "tier": "special", "lv": 2, "w": 2, "req": ["m_hang"], "name": "TRAYECTORIA AVANZADA", "desc": "CONTROL TOTAL DEL ARCO: SALTO CORTO MÁS CORTO Y LARGO MÁS LARGO", "buff": {"jump_cut": 5.0, "jump_height": 1.0}},

	# ----------------------------------------------------- DOMINIO DEL SALTO
	{"id": "j_bounce", "cat": "salto", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "MUELLES", "desc": "EL SUPER REBOTE DEL TRAMPOLÍN TE LANZA MÁS ALTO", "buff": {"bounce": 4.0}},
	{"id": "j_bounce_pts", "cat": "salto", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["j_bounce"], "name": "ACRÓBATA", "desc": "EL SUPER REBOTE DA MÁS PUNTOS", "buff": {"bounce_points": 25.0}},
	{"id": "j_land", "cat": "salto", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["j_bounce"], "name": "ATERRIZAJE SUAVE", "desc": "VENTANA MÁS AMPLIA PARA LOS ATERRIZAJES PERFECTOS TRAS UN HUECO", "buff": {"land": 6.0}},
	{"id": "j_stomp_pts", "cat": "salto", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["j_bounce_pts"], "name": "PISOTÓN DEMOLEDOR", "desc": "CADA PISOTÓN QUE APLASTA DA MÁS PUNTOS", "buff": {"stomp_points": 25.0}},
	{"id": "j_land_pts", "cat": "salto", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["j_land"], "name": "CAÍDA EXACTA", "desc": "LOS ATERRIZAJES PERFECTOS DAN MÁS PUNTOS", "buff": {"land_points": 25.0}},
	{"id": "j_dodge_pts", "cat": "salto", "pos": [3, 2], "tier": "advanced", "lv": 3, "w": 1, "req": ["j_land_pts"], "name": "ROZAMIENTO", "desc": "ESQUIVAR POR MUY POCO Y DEJAR ATRÁS A UN PERSEGUIDOR DA MÁS PUNTOS", "buff": {"dodge_points": 25.0}},
	{"id": "j_glide", "cat": "salto", "pos": [3, 0], "tier": "epic", "lv": 3, "w": 1, "req": ["j_stomp_pts", "j_land_pts"], "name": "PLANEO", "desc": "SI MANTIENES EL BOTÓN DESPUÉS DEL PUNTO MÁS ALTO, CAES MÁS DESPACIO", "buff": {"glide": 15.0}},
	{"id": "j_air_master", "cat": "salto", "pos": [4, 1], "tier": "special", "lv": 1, "w": 2, "req": ["j_glide", "j_dodge_pts"], "name": "SEÑOR DEL AIRE", "desc": "PLANEO, SUSPENSIÓN Y REBOTE MEJORADOS A LA VEZ", "buff": {"glide": 15.0, "hang": 10.0, "bounce": 5.0}},

	# ------------------------------------------------------------- PRECISION
	{"id": "p_window", "cat": "precision", "pos": [0, 1], "tier": "normal", "lv": 5, "w": 0, "name": "VENTANA DE TIMING", "desc": "LA VENTANA GOOD ES UN POCO MÁS AMPLIA", "buff": {"good": 2.0}},
	{"id": "p_perfect", "cat": "precision", "pos": [1, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["p_window"], "name": "PERFECT TIMING", "desc": "LA VENTANA PERFECT ES UN POCO MÁS AMPLIA", "buff": {"perfect": 2.5}},
	{"id": "p_reaction", "cat": "precision", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["p_window"], "name": "REACCIÓN MEJORADA", "desc": "LOS AVISOS DE PELIGRO LLEGAN ANTES", "buff": {"warn": 5.0}},
	{"id": "p_legend", "cat": "precision", "pos": [2, 0], "tier": "epic", "lv": 2, "w": 1, "req": ["p_perfect"], "name": "PULSO LEGENDARIO", "desc": "LA VENTANA LEGENDARY ES UN POCO MÁS AMPLIA", "buff": {"legend": 3.0}},
	{"id": "p_mash", "cat": "precision", "pos": [2, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["p_reaction"], "name": "PULSACIÓN FIRME", "desc": "CADA PULSACIÓN EMPUJA MÁS A BARRICADAS Y BRUTOS", "buff": {"mash": 8.0}},
	{"id": "p_advanced", "cat": "precision", "pos": [3, 0], "tier": "epic", "lv": 3, "w": 1, "req": ["p_legend"], "name": "PRECISIÓN AVANZADA", "desc": "AMPLÍA A LA VEZ LAS VENTANAS PERFECT Y GOOD", "buff": {"perfect": 1.5, "good": 1.5}},
	{"id": "p_rank", "cat": "precision", "pos": [3, 2], "tier": "advanced", "lv": 3, "w": 1, "req": ["p_mash"], "name": "OJO CRÍTICO", "desc": "SUMA PUNTOS A LA NOTA CON LA QUE SE CALCULA EL RANGO DEL NIVEL", "buff": {"rank_bonus": 1.5}},
	{"id": "p_pulse", "cat": "precision", "pos": [4, 1], "tier": "special", "lv": 2, "w": 2, "req": ["p_advanced", "p_rank"], "name": "MAESTRÍA DE PULSACIÓN", "desc": "PULSACIONES RÁPIDAS DEMOLEDORAS: MÁS EMPUJE Y GOLPES DOBLES", "buff": {"mash": 10.0, "crit": 8.0}},

	# ---------------------------------------------------------------- TIMING
	{"id": "t_combo_start", "cat": "timing", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "IMPULSO INICIAL", "desc": "EMPIEZAS CADA INTENTO CON ACCIONES PERFECTAS YA SUMADAS AL COMBO", "buff": {"combo_start": 1.0}},
	{"id": "t_combo_pts", "cat": "timing", "pos": [1, 0], "tier": "normal", "lv": 5, "w": 0, "req": ["t_combo_start"], "name": "RITMO", "desc": "EL MULTIPLICADOR DE COMBO DA MÁS PUNTOS", "buff": {"combo_points": 4.0}},
	{"id": "t_jump_pts", "cat": "timing", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["t_combo_start"], "name": "SALTO PERFECTO", "desc": "LOS SALTOS PERFECT Y LEGENDARY DAN MÁS PUNTOS", "buff": {"jump_points": 10.0}},
	{"id": "t_legend_pts", "cat": "timing", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["t_combo_pts"], "name": "ÚLTIMO SEGUNDO", "desc": "CADA ACCIÓN LEGENDARY DA MÁS PUNTOS", "buff": {"legend_points": 15.0}},
	{"id": "t_buffer", "cat": "timing", "pos": [2, 2], "tier": "advanced", "lv": 2, "w": 0, "req": ["t_jump_pts"], "name": "MEMORIA MUSCULAR", "desc": "MÁS MARGEN ANTES DE ATERRIZAR Y AL DEJAR UN BORDE", "buff": {"buffer": 10.0, "coyote": 8.0}},
	{"id": "t_slowmo", "cat": "timing", "pos": [3, 0], "tier": "epic", "lv": 3, "w": 1, "req": ["t_legend_pts"], "name": "TIEMPO BALA", "desc": "CADA ACCIÓN LEGENDARY RALENTIZA EL TIEMPO UN INSTANTE. MÁS NIVELES, MÁS DURACIÓN", "buff": {"slowmo": 1.0}},
	{"id": "t_flow", "cat": "timing", "pos": [3, 2], "tier": "epic", "lv": 3, "w": 2, "req": ["t_buffer", "t_slowmo"], "name": "FLUJO", "desc": "EMPIEZAS CON MÁS COMBO Y EL MULTIPLICADOR RINDE MÁS", "buff": {"combo_start": 2.0, "combo_points": 4.0}},
	{"id": "t_metronome", "cat": "timing", "pos": [4, 1], "tier": "special", "lv": 1, "w": 3, "req": ["t_flow"], "name": "METRÓNOMO", "desc": "TU PULSO ES UN RELOJ: VENTANAS LEGENDARY Y PERFECT MUCHO MÁS AMPLIAS", "buff": {"legend": 4.0, "perfect": 3.0}},

	# ------------------------------------------------------------- MAESTRIA
	{"id": "y_mov", "cat": "maestria", "pos": [0, 0], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["movimiento"], "min": 12}, "name": "MAESTRO DEL MOVIMIENTO", "desc": "RECOMPENSA POR DOMINAR LA RAMA DE MOVIMIENTO", "buff": {"jump_height": 1.5, "coyote": 15.0}},
	{"id": "y_jump", "cat": "maestria", "pos": [1, 0], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["salto"], "min": 12}, "name": "MAESTRO DEL SALTO", "desc": "RECOMPENSA POR DOMINAR EL SALTO", "buff": {"bounce": 5.0, "land": 8.0}},
	{"id": "y_precision", "cat": "maestria", "pos": [2, 0], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["precision"], "min": 12}, "name": "MAESTRO DE LA PRECISIÓN", "desc": "RECOMPENSA POR DOMINAR LA PRECISIÓN", "buff": {"perfect": 2.0, "good": 3.0}},
	{"id": "y_timing", "cat": "maestria", "pos": [3, 0], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["timing"], "min": 12}, "name": "MAESTRO DEL TIEMPO", "desc": "RECOMPENSA POR DOMINAR EL TIMING", "buff": {"combo_start": 2.0, "legend": 2.0}},
	{"id": "y_combat", "cat": "maestria", "pos": [0, 2], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["combate", "espadas"], "min": 18}, "name": "MAESTRO DE ARMAS", "desc": "RECOMPENSA POR DOMINAR COMBATE Y ESPADAS", "buff": {"reach": 1.0, "crit": 10.0}},
	{"id": "y_economy", "cat": "maestria", "pos": [1, 2], "tier": "special", "lv": 1, "w": 1, "cond": {"cats": ["economia", "monedas"], "min": 20}, "name": "MAESTRO MERCADER", "desc": "RECOMPENSA POR DOMINAR ECONOMÍA Y MONEDAS", "buff": {"coins": 8.0}},
	{"id": "y_survival", "cat": "maestria", "pos": [2, 2], "tier": "special", "lv": 1, "w": 2, "cond": {"cats": ["supervivencia"], "min": 10}, "name": "MAESTRO SUPERVIVIENTE", "desc": "RECOMPENSA POR DOMINAR LA SUPERVIVENCIA", "buff": {"hitbox": 1.0, "warn": 8.0}},
	{"id": "y_grand", "cat": "maestria", "pos": [4, 1], "tier": "legendary", "lv": 1, "w": 3, "req": ["y_mov", "y_precision", "y_timing", "y_combat"], "cond": {"levels": 150}, "name": "GRAN MAESTRO", "desc": "EXIGE 150 NIVELES DE MEJORA EN TOTAL Y CUATRO MAESTRÍAS", "buff": {"points": 10.0, "coins": 10.0}},

	# --------------------------------------------------------------- COMBATE
	{"id": "c_reach", "cat": "combate", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "FILO LARGO", "desc": "ALCANCE DE ATAQUE LIGERAMENTE MAYOR", "buff": {"reach": 0.8}},
	{"id": "c_bounty", "cat": "combate", "pos": [1, 0], "tier": "normal", "lv": 5, "w": 0, "req": ["c_reach"], "name": "BOTÍN DE CAZA", "desc": "+1 MONEDA POR CADA ENEMIGO DERROTADO", "buff": {"bounty": 1.0}},
	{"id": "c_master", "cat": "combate", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["c_reach"], "name": "GOLPE MAESTRO", "desc": "LOS ATAQUES PERFECT Y LEGENDARY DAN MÁS PUNTOS", "buff": {"attack_points": 12.0}},
	{"id": "c_counter", "cat": "combate", "pos": [2, 0], "tier": "advanced", "lv": 2, "w": 0, "req": ["c_bounty", "c_master"], "name": "CONTRAGOLPE", "desc": "LOS CENTINELAS QUEDAN VULNERABLES MÁS TIEMPO", "buff": {"counter": 10.0}},
	{"id": "c_combo", "cat": "combate", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["c_master"], "name": "BOTÍN DE COMBO", "desc": "+1 MONEDA POR CADA ACCIÓN PERFECT O LEGENDARY", "buff": {"combo_coins": 1.0}},
	{"id": "c_shield", "cat": "combate", "pos": [3, 0], "tier": "advanced", "lv": 3, "w": 1, "req": ["c_counter"], "name": "ROMPEESCUDOS", "desc": "CADA GOLPE BLOQUEADO ADELANTA EL MOMENTO EN QUE EL ESCUDO SE ABRE", "buff": {"shield_break": 1.0}},
	{"id": "c_crit", "cat": "combate", "pos": [3, 2], "tier": "epic", "lv": 3, "w": 1, "req": ["c_combo"], "name": "GOLPE CRÍTICO", "desc": "PROBABILIDAD DE QUE UN GOLPE A UN ACORAZADO CUENTE DOBLE", "buff": {"crit": 10.0}},
	{"id": "c_boss", "cat": "combate", "pos": [4, 1], "tier": "special", "lv": 3, "w": 2, "req": ["c_shield", "c_crit"], "name": "CAZADOR DE JEFES", "desc": "PROBABILIDAD DE QUE CADA GOLPE AL JEFE HAGA UN PUNTO DE DAÑO EXTRA", "buff": {"boss_damage": 15.0}},

	# --------------------------------------------------------------- ESPADAS
	{"id": "w_affinity", "cat": "espadas", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "AFINIDAD DE ESPADA", "desc": "EL BUFF DE LA ESPADA EQUIPADA ES MÁS FUERTE", "buff": {"sword_affinity": 25.0}},
	{"id": "w_edge", "cat": "espadas", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["w_affinity"], "name": "FILO TEMPLADO", "desc": "UN POCO MÁS DE ALCANCE HORIZONTAL", "buff": {"reach": 0.6}},
	{"id": "w_reflect", "cat": "espadas", "pos": [1, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["w_affinity"], "name": "DEVOLVER", "desc": "CORTAR UN PROYECTIL DA PUNTOS EXTRA", "buff": {"reflect_points": 30.0}},
	{"id": "w_cleave", "cat": "espadas", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["w_edge"], "name": "TAJO AMPLIO", "desc": "EL TAJO ALCANZA ENEMIGOS MÁS ALTOS Y MÁS BAJOS", "buff": {"vreach": 10.0}},
	{"id": "w_reflect_coins", "cat": "espadas", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 1, "req": ["w_reflect"], "name": "ESPEJO DE ACERO", "desc": "CADA PROYECTIL CORTADO DA MONEDAS", "buff": {"reflect_coins": 1.0}},
	{"id": "w_master_sword", "cat": "espadas", "pos": [3, 0], "tier": "epic", "lv": 2, "w": 1, "req": ["w_cleave"], "name": "ESPADA MAESTRA", "desc": "POTENCIA MUCHO MÁS EL BUFF DE LA ESPADA EQUIPADA", "buff": {"sword_affinity": 50.0}},
	{"id": "w_return", "cat": "espadas", "pos": [3, 2], "tier": "epic", "lv": 1, "w": 2, "req": ["w_reflect_coins"], "name": "DEVOLUCIÓN FÁCIL", "desc": "DEVUELVES LOS ORBES DE LOS JEFES TAMBIÉN CON UN GOLPE GOOD", "buff": {"boss_reflect": 1.0}},
	{"id": "w_soul", "cat": "espadas", "pos": [4, 1], "tier": "special", "lv": 1, "w": 3, "req": ["w_master_sword", "w_return"], "name": "ALMA DE LA ESPADA", "desc": "TU ESPADA DESPIERTA: SU BUFF CASI SE DUPLICA Y GANAS ALCANCE", "buff": {"sword_affinity": 75.0, "reach": 1.0}},

	# ----------------------------------------------------------- LEGENDARIAS
	{"id": "l_phoenix_wing", "cat": "legendarias", "pos": [0, 0], "tier": "legendary", "lv": 1, "w": 3, "req": ["j_air_master"], "name": "ALAS DEL VIENTO", "desc": "PLANEO Y SUSPENSIÓN LLEVADOS AL LÍMITE", "buff": {"glide": 25.0, "hang": 15.0}},
	{"id": "l_bullet", "cat": "legendarias", "pos": [2, 0], "tier": "legendary", "lv": 1, "w": 3, "req": ["t_metronome"], "name": "CRONOS", "desc": "EL TIEMPO BALA DURA MUCHO MÁS Y LA VENTANA LEGENDARY CRECE", "buff": {"slowmo": 2.0, "legend": 3.0}},
	{"id": "l_combo", "cat": "legendarias", "pos": [4, 0], "tier": "legendary", "lv": 1, "w": 4, "req": ["t_flow"], "name": "ETERNO RETORNO", "desc": "EMPIEZAS CON UN COMBO ENORME Y EL MULTIPLICADOR RINDE MUCHO MÁS", "buff": {"combo_start": 4.0, "combo_points": 15.0}},
	{"id": "l_blade", "cat": "legendarias", "pos": [0, 2], "tier": "legendary", "lv": 1, "w": 4, "req": ["w_soul"], "name": "HOJA ETERNA", "desc": "LA ESPADA DEFINITIVA: ALCANCE, AFINIDAD Y GOLPES DOBLES", "buff": {"reach": 2.0, "sword_affinity": 100.0, "crit": 15.0}},
	{"id": "l_guardian", "cat": "legendarias", "pos": [1, 1], "tier": "legendary", "lv": 1, "w": 4, "req": ["s_chaser", "s_brute"], "name": "GUARDIÁN", "desc": "SILUETA MÍNIMA, AVISOS TEMPRANOS Y PROYECTILES LENTOS", "buff": {"hitbox": 1.0, "warn": 10.0, "projectile_slow": 10.0}},
	{"id": "l_midas", "cat": "legendarias", "pos": [3, 1], "tier": "legendary", "lv": 1, "w": 4, "req": ["k_midas", "e_empire"], "name": "REY MIDAS", "desc": "TODO LO QUE TOCAS ES ORO: MÁS MONEDAS, COFRES E INTERESES", "buff": {"coins": 20.0, "chest": 50.0, "interest": 1.0}},
	{"id": "l_crown", "cat": "legendarias", "pos": [4, 2], "tier": "legendary", "lv": 1, "w": 4, "req": ["y_grand"], "name": "CORONA DEL HÉROE", "desc": "LA CIMA DEL ÁRBOL: MÁS PUNTOS, MONEDAS Y GEMAS EN TODO", "buff": {"points": 15.0, "coins": 15.0, "gems": 5.0}},

	# --------------------------------------------------------- SUPERVIVENCIA
	{"id": "s_hitbox", "cat": "supervivencia", "pos": [0, 1], "tier": "advanced", "lv": 3, "w": 0, "name": "SILUETA ÁGIL", "desc": "TU CUERPO OCUPA 1 PX MENOS POR NIVEL: ROCES MÁS JUSTOS", "buff": {"hitbox": 1.0}},
	{"id": "s_ledge", "cat": "supervivencia", "pos": [1, 0], "tier": "normal", "lv": 2, "w": 0, "req": ["s_hitbox"], "name": "AGARRE DE BORDE", "desc": "TE SUBES A LOS BORDES DE LOS HUECOS CON MÁS MARGEN", "buff": {"ledge": 4.0}},
	{"id": "s_ice", "cat": "supervivencia", "pos": [1, 2], "tier": "normal", "lv": 2, "w": 0, "req": ["s_hitbox"], "name": "PIES FIRMES", "desc": "EL HIELO TE ACELERA MENOS", "buff": {"ice_grip": 20.0}},
	{"id": "s_quick", "cat": "supervivencia", "pos": [2, 0], "tier": "advanced", "lv": 1, "w": 0, "req": ["s_ledge"], "name": "REINTENTO RÁPIDO", "desc": "AL MORIR, PULSA PARA REINTENTAR AL INSTANTE", "buff": {"quick_retry": 1.0}},
	{"id": "s_abyss", "cat": "supervivencia", "pos": [2, 2], "tier": "advanced", "lv": 1, "w": 0, "req": ["s_ice"], "name": "OJO DEL ABISMO", "desc": "EL BORDE DE CADA HUECO SE MARCA CON UN AVISO", "buff": {"hole_sight": 1.0}},
	{"id": "s_slow_proj", "cat": "supervivencia", "pos": [3, 0], "tier": "epic", "lv": 3, "w": 1, "req": ["s_quick"], "name": "REFLEJOS", "desc": "LOS PROYECTILES ENEMIGOS VUELAN MÁS DESPACIO", "buff": {"projectile_slow": 8.0}},
	{"id": "s_storm", "cat": "supervivencia", "pos": [3, 2], "tier": "advanced", "lv": 2, "w": 1, "req": ["s_abyss"], "name": "VISTA CLARA", "desc": "VENTISCAS Y TORMENTAS DE ARENA TAPAN MENOS", "buff": {"storm_clear": 35.0}},
	{"id": "s_chaser", "cat": "supervivencia", "pos": [4, 0], "tier": "epic", "lv": 2, "w": 2, "req": ["s_slow_proj"], "name": "SEXTO SENTIDO", "desc": "LOS ENEMIGOS QUE TE PERSIGUEN O TE EMBISTEN VAN MÁS DESPACIO", "buff": {"chaser_slow": 10.0}},
	{"id": "s_brute", "cat": "supervivencia", "pos": [4, 2], "tier": "epic", "lv": 2, "w": 2, "req": ["s_storm"], "name": "PIES DE PLOMO", "desc": "BRUTOS Y BARRICADAS AVANZAN MÁS DESPACIO HACIA TI", "buff": {"brute_slow": 12.0}},

	# ------------------------------------------------------- ESPECIALIZACION
	{"id": "x_daredevil", "cat": "especializacion", "pos": [0, 0], "tier": "special", "lv": 1, "w": 0, "req": ["p_perfect", "m_long"], "ex": "x_method", "name": "TEMERARIO", "desc": "LAST SECOND Y LEGENDARY X2 PUNTOS. GOOD NO DA PUNTOS", "buff": {"daredevil": 1.0}},
	{"id": "x_method", "cat": "especializacion", "pos": [0, 2], "tier": "special", "lv": 1, "w": 0, "req": ["p_window"], "ex": "x_daredevil", "name": "METÓDICO", "desc": "LAS ACCIONES GOOD TAMBIÉN SUMAN AL COMBO. LEGENDARY X0.5", "buff": {"methodical": 1.0}},
	{"id": "x_fury", "cat": "especializacion", "pos": [1, 0], "tier": "special", "lv": 1, "w": 0, "req": ["c_master"], "ex": "x_zen", "name": "FURIA", "desc": "ENEMIGOS X2 PUNTOS. SALTOS PERFECTOS X0.5", "buff": {"fury": 1.0}},
	{"id": "x_zen", "cat": "especializacion", "pos": [1, 2], "tier": "special", "lv": 1, "w": 0, "req": ["m_chain"], "ex": "x_fury", "name": "SERENIDAD", "desc": "SALTOS PERFECTOS X2 PUNTOS. ENEMIGOS X0.5", "buff": {"zen": 1.0}},
	{"id": "x_greed", "cat": "especializacion", "pos": [2, 0], "tier": "special", "lv": 1, "w": 0, "req": ["e_lucky"], "ex": "x_ascetic", "name": "AVARICIA", "desc": "+25% MONEDAS, -15% PUNTOS", "buff": {"coins": 25.0, "points": -15.0}},
	{"id": "x_ascetic", "cat": "especializacion", "pos": [2, 2], "tier": "special", "lv": 1, "w": 0, "req": ["e_score"], "ex": "x_greed", "name": "ASCETA", "desc": "+25% PUNTOS, -25% MONEDAS", "buff": {"points": 25.0, "coins": -25.0}},
	{"id": "x_sprinter", "cat": "especializacion", "pos": [3, 0], "tier": "special", "lv": 1, "w": 1, "req": ["m_hang"], "ex": "x_patient", "name": "VELOCISTA", "desc": "CORRES UN 8% MÁS RÁPIDO Y GANAS UN 20% MÁS DE PUNTOS", "buff": {"run_speed": 8.0, "points": 20.0}},
	{"id": "x_patient", "cat": "especializacion", "pos": [3, 2], "tier": "special", "lv": 1, "w": 1, "req": ["t_buffer"], "ex": "x_sprinter", "name": "PACIENTE", "desc": "CORRES UN 6% MÁS DESPACIO PERO LA VENTANA GOOD CRECE MUCHO. -10% PUNTOS", "buff": {"run_speed": -6.0, "good": 12.0, "points": -10.0}},
	{"id": "x_hunter", "cat": "especializacion", "pos": [4, 0], "tier": "special", "lv": 1, "w": 2, "req": ["c_crit"], "ex": "x_acrobat", "name": "CAZADOR", "desc": "+3 MONEDAS Y +30% PUNTOS POR ENEMIGO. SALTOS -30% PUNTOS", "buff": {"bounty": 3.0, "attack_points": 30.0, "jump_points": -30.0}},
	{"id": "x_acrobat", "cat": "especializacion", "pos": [4, 2], "tier": "special", "lv": 1, "w": 2, "req": ["j_glide"], "ex": "x_hunter", "name": "ACRÓBATA", "desc": "SALTOS +30% Y ESQUIVAS +50% DE PUNTOS. ATAQUES -30%", "buff": {"jump_points": 30.0, "dodge_points": 50.0, "attack_points": -30.0}},

	# --------------------------------------------------------------- ECONOMIA
	{"id": "e_coins", "cat": "economia", "pos": [0, 1], "tier": "normal", "lv": 5, "w": 0, "name": "BOLSILLO", "desc": "+6% DE MONEDAS EN LAS PARTIDAS", "buff": {"coins": 6.0}},
	{"id": "e_score", "cat": "economia", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["e_coins"], "name": "PUNTUACIÓN", "desc": "+4% DE PUNTOS", "buff": {"points": 4.0}},
	{"id": "e_interest", "cat": "economia", "pos": [1, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["e_coins"], "name": "INTERÉS", "desc": "AL SUPERAR UN NIVEL COBRAS UN 1% DE TUS AHORROS POR NIVEL (CON TOPE SEGÚN EL MUNDO)", "buff": {"interest": 1.0}},
	{"id": "e_replay", "cat": "economia", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 1, "req": ["e_score"], "name": "VETERANO", "desc": "LOS MUNDOS YA CONQUISTADOS PAGAN MÁS AL REPETIRLOS", "buff": {"replay": 10.0}},
	{"id": "e_level", "cat": "economia", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["e_interest"], "name": "PAGA DE NIVEL", "desc": "MÁS MONEDAS AL SUPERAR UN NIVEL POR PRIMERA VEZ", "buff": {"level_coins": 15.0}},
	{"id": "e_multiplier", "cat": "economia", "pos": [3, 0], "tier": "epic", "lv": 3, "w": 1, "req": ["e_replay"], "name": "MULTIPLICADOR PROGRESIVO", "desc": "+3% DE MONEDAS POR NIVEL POR CADA MUNDO CONQUISTADO", "buff": {"world_coins": 3.0}},
	{"id": "e_boss", "cat": "economia", "pos": [3, 2], "tier": "epic", "lv": 3, "w": 1, "req": ["e_level"], "name": "BOTÍN REAL", "desc": "LOS JEFES Y SUS RECOMPENSAS PAGAN MÁS", "buff": {"boss_coins": 25.0}},
	{"id": "e_empire", "cat": "economia", "pos": [4, 1], "tier": "special", "lv": 1, "w": 3, "req": ["e_multiplier", "e_boss"], "name": "IMPERIO", "desc": "UNA FORTUNA QUE TRABAJA SOLA: MÁS MONEDAS Y PUNTOS", "buff": {"coins": 15.0, "points": 5.0}},

	# ---------------------------------------------------------------- MONEDAS
	{"id": "e_magnet", "cat": "monedas", "pos": [0, 1], "tier": "normal", "lv": 5, "w": 0, "name": "IMÁN", "desc": "ATRAE LAS MONEDAS CERCANAS", "buff": {"magnet": 35.0}},
	{"id": "k_chest", "cat": "monedas", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["e_magnet"], "name": "COFRES", "desc": "LOS COFRES DEL TESORO DAN MÁS MONEDAS", "buff": {"chest": 25.0}},
	{"id": "k_gemcoins", "cat": "monedas", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["e_magnet"], "name": "GEMAS PULIDAS", "desc": "CADA GEMA O RUBÍ DA MONEDAS EXTRA", "buff": {"gem_coins": 1.0}},
	{"id": "k_milestone", "cat": "monedas", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["k_chest"], "name": "HITOS", "desc": "LOS PREMIOS POR DISTANCIA RECORRIDA SON MAYORES", "buff": {"milestone": 30.0}},
	{"id": "k_combo_reward", "cat": "monedas", "pos": [2, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["k_gemcoins"], "name": "PREMIO DE COMBO", "desc": "LOS PREMIOS POR COMBOS LARGOS DAN MÁS MONEDAS", "buff": {"combo_reward": 30.0}},
	{"id": "k_night", "cat": "monedas", "pos": [3, 0], "tier": "advanced", "lv": 2, "w": 1, "req": ["k_milestone"], "name": "TURNO DE NOCHE", "desc": "SOBREVIVIR A UNA NOCHE EN EL MODO INFINITO PAGA MÁS", "buff": {"night_coins": 50.0}},
	{"id": "k_rush", "cat": "monedas", "pos": [3, 2], "tier": "epic", "lv": 2, "w": 1, "req": ["k_combo_reward"], "name": "FIEBRE DORADA", "desc": "LA FIEBRE DEL ORO DURA MÁS SEGUNDOS", "buff": {"rush": 4.0}},
	{"id": "k_midas", "cat": "monedas", "pos": [4, 1], "tier": "special", "lv": 1, "w": 2, "req": ["k_night", "k_rush"], "name": "TOQUE DE MIDAS", "desc": "MÁS MONEDAS Y UN IMÁN ENORME", "buff": {"coins": 10.0, "magnet": 60.0}},

	# -------------------------------------------------------------- DIAMANTES
	{"id": "e_lucky", "cat": "diamantes", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "FORTUNA", "desc": "MÁS RUBÍES Y GEMAS EN EL CAMINO", "buff": {"gems": 3.0}},
	{"id": "e_gems", "cat": "diamantes", "pos": [1, 0], "tier": "advanced", "lv": 1, "w": 0, "req": ["e_lucky"], "name": "OJO DE JOYERO", "desc": "EL DIAMANTE OCULTO SIEMPRE APARECE EN LA RUTA ALTA", "buff": {"diamond_sense": 1.0}},
	{"id": "d_shards", "cat": "diamantes", "pos": [1, 2], "tier": "advanced", "lv": 3, "w": 0, "req": ["e_lucky"], "name": "FRAGMENTOS", "desc": "LAS GEMAS QUE RECOGES SE ACUMULAN Y SE FUNDEN EN DIAMANTES. MÁS NIVELES, MENOS GEMAS POR DIAMANTE", "buff": {"shards": 1.0}},
	{"id": "d_modes", "cat": "diamantes", "pos": [2, 0], "tier": "epic", "lv": 2, "w": 1, "req": ["e_gems"], "name": "TALLADOR", "desc": "PROBABILIDAD DE UN DIAMANTE EXTRA AL SUPERAR UN MODO DE DOMINIO", "buff": {"mode_diamonds": 25.0}},
	{"id": "d_discount", "cat": "diamantes", "pos": [2, 2], "tier": "epic", "lv": 3, "w": 1, "req": ["d_shards"], "name": "REGATEO", "desc": "LOS ARTÍCULOS QUE SE PAGAN CON DIAMANTES CUESTAN MENOS", "buff": {"diamond_discount": 8.0}},
	{"id": "d_boss", "cat": "diamantes", "pos": [3, 0], "tier": "epic", "lv": 2, "w": 2, "req": ["d_modes"], "name": "CORONA DE GEMAS", "desc": "CADA JEFE DERROTADO POR PRIMERA VEZ DA DIAMANTES EXTRA", "buff": {"boss_diamonds": 1.0}},
	{"id": "d_star", "cat": "diamantes", "pos": [3, 2], "tier": "advanced", "lv": 2, "w": 1, "req": ["d_discount"], "name": "CONSTELACIÓN", "desc": "PROBABILIDAD DE UN DIAMANTE EXTRA AL LOGRAR TRES ESTRELLAS", "buff": {"star_diamonds": 25.0}},
	{"id": "d_heart", "cat": "diamantes", "pos": [4, 1], "tier": "special", "lv": 1, "w": 3, "req": ["d_boss", "d_star"], "name": "CORAZÓN DE DIAMANTE", "desc": "MÁS GEMAS, FRAGMENTOS MÁS RÁPIDOS Y MEJOR REGATEO", "buff": {"gems": 6.0, "shards": 1.0, "diamond_discount": 6.0}},

	# ------------------------------------------------------------ RECOMPENSAS
	{"id": "r_challenge", "cat": "recompensas", "pos": [0, 1], "tier": "normal", "lv": 3, "w": 0, "name": "RETADOR", "desc": "LOS RETOS OPCIONALES DE CADA NIVEL PAGAN MÁS", "buff": {"challenge_coins": 20.0}},
	{"id": "r_mission", "cat": "recompensas", "pos": [1, 0], "tier": "normal", "lv": 3, "w": 0, "req": ["r_challenge"], "name": "MISIONERO", "desc": "LAS MISIONES DIARIAS PAGAN MÁS", "buff": {"mission": 20.0}},
	{"id": "r_login", "cat": "recompensas", "pos": [1, 2], "tier": "normal", "lv": 3, "w": 0, "req": ["r_challenge"], "name": "CONSTANCIA", "desc": "EL PREMIO POR JUGAR CADA DÍA ES MAYOR", "buff": {"login": 25.0}},
	{"id": "r_modes", "cat": "recompensas", "pos": [2, 0], "tier": "advanced", "lv": 3, "w": 0, "req": ["r_mission"], "name": "DOMINADOR", "desc": "LOS MODOS DE DOMINIO PAGAN MÁS", "buff": {"mode_coins": 25.0}},
	{"id": "r_achieve", "cat": "recompensas", "pos": [2, 2], "tier": "advanced", "lv": 2, "w": 0, "req": ["r_login"], "name": "TROFEOS", "desc": "LOS LOGROS PAGAN MÁS", "buff": {"achievement": 25.0}},
	{"id": "r_stars", "cat": "recompensas", "pos": [3, 2], "tier": "advanced", "lv": 3, "w": 1, "req": ["r_achieve"], "name": "ESTRELLAS DE ORO", "desc": "CADA ESTRELLA NUEVA QUE CONSIGUES DA MONEDAS", "buff": {"star_coins": 10.0}},
	{"id": "r_weekly", "cat": "recompensas", "pos": [3, 0], "tier": "epic", "lv": 2, "w": 1, "req": ["r_modes"], "name": "SEMANA HEROICA", "desc": "LOS DESAFÍOS SEMANALES PAGAN MÁS", "buff": {"weekly": 30.0}},
	{"id": "r_patron", "cat": "recompensas", "pos": [4, 1], "tier": "special", "lv": 1, "w": 3, "req": ["r_weekly", "r_stars"], "name": "MECENAS", "desc": "RETOS, MODOS Y NIVELES PAGAN MUCHO MÁS", "buff": {"challenge_coins": 30.0, "mode_coins": 30.0, "level_coins": 20.0}},

	# --------------------------------------------------------------- SECRETAS
	{"id": "z_legend", "cat": "secretas", "pos": [0, 0], "tier": "secret", "lv": 1, "w": 1, "cond": {"stat": "legendaries", "min": 150}, "hint": "150 ACCIONES LEGENDARY", "name": "SEÑOR DEL ÚLTIMO SEGUNDO", "desc": "LAS ACCIONES LEGENDARY SON MÁS FÁCILES Y VALEN MÁS", "buff": {"legend": 4.0, "legend_points": 30.0}},
	{"id": "z_boss", "cat": "secretas", "pos": [1, 0], "tier": "secret", "lv": 1, "w": 4, "cond": {"stat": "bosses", "min": 5}, "hint": "DERROTA A LOS CINCO JEFES", "name": "MATARREYES", "desc": "LOS JEFES SUFREN MÁS Y PAGAN MÁS", "buff": {"boss_damage": 25.0, "boss_coins": 50.0}},
	{"id": "z_stars", "cat": "secretas", "pos": [2, 0], "tier": "secret", "lv": 1, "w": 2, "cond": {"stat": "total_stars", "min": 200}, "hint": "200 ESTRELLAS", "name": "CONSTELACIÓN PERFECTA", "desc": "LAS ESTRELLAS Y LOS PUNTOS RINDEN MÁS", "buff": {"star_coins": 20.0, "points": 8.0}},
	{"id": "z_night", "cat": "secretas", "pos": [3, 0], "tier": "secret", "lv": 1, "w": 1, "cond": {"stat": "nights_survived", "min": 10}, "hint": "SOBREVIVE A 10 NOCHES", "name": "HIJO DE LA NOCHE", "desc": "LA NOCHE ES TU ALIADA: PAGA EL TRIPLE Y TE AVISA ANTES", "buff": {"night_coins": 100.0, "warn": 6.0}},
	{"id": "z_combo", "cat": "secretas", "pos": [4, 0], "tier": "secret", "lv": 1, "w": 2, "cond": {"stat": "best_combo", "min": 40}, "hint": "COMBO PERFECTO DE 40", "name": "INQUEBRANTABLE", "desc": "EMPIEZAS CON MÁS COMBO Y RINDE MÁS", "buff": {"combo_start": 3.0, "combo_points": 10.0}},
	{"id": "z_collector", "cat": "secretas", "pos": [0, 2], "tier": "secret", "lv": 1, "w": 1, "cond": {"stat": "owned_count", "min": 30}, "hint": "REÚNE 30 OBJETOS DE ASPECTO", "name": "COLECCIONISTA", "desc": "TODO LO QUE LLEVAS EQUIPADO (HÉROE, ESPADA, ESTELA Y AURA) RINDE UN 25% MÁS", "buff": {"sword_affinity": 25.0, "skin_affinity": 25.0, "trail_affinity": 25.0, "aura_affinity": 25.0}},
	{"id": "z_modes", "cat": "secretas", "pos": [1, 2], "tier": "secret", "lv": 1, "w": 2, "cond": {"stat": "modes_cleared", "min": 25}, "hint": "SUPERA 25 MODOS DE DOMINIO", "name": "DOMINIO TOTAL", "desc": "LOS MODOS DE DOMINIO PAGAN MUCHO MÁS", "buff": {"mode_coins": 50.0, "mode_diamonds": 25.0}},
	{"id": "z_traveler", "cat": "secretas", "pos": [2, 2], "tier": "secret", "lv": 1, "w": 1, "cond": {"stat": "total_distance", "min": 100000}, "hint": "RECORRE 100 KM EN TOTAL", "name": "TROTAMUNDOS", "desc": "CADA METRO CUENTA: PREMIOS DE DISTANCIA MUY SUPERIORES", "buff": {"milestone": 60.0, "coins": 5.0}},
	{"id": "z_polymath", "cat": "secretas", "pos": [4, 2], "tier": "secret", "lv": 1, "w": 2, "cond": {"all_cats": 3}, "hint": "3 NIVELES EN CADA CATEGORÍA", "name": "POLÍMATA", "desc": "QUIEN LO PRUEBA TODO LO APROVECHA TODO", "buff": {"points": 6.0, "coins": 6.0, "perfect": 1.5}},
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


static var _tree_index: Dictionary = {}
static var _price_cache: Dictionary = {}


static func find(list: Array, id: String) -> Dictionary:
	for item in list:
		var entry: Dictionary = item
		if String(entry["id"]) == id:
			return entry
	return {}


## Nodo del arbol por id (indice en memoria: el arbol tiene mas de 100).
static func tree_node(id: String) -> Dictionary:
	if _tree_index.is_empty():
		for item in TREE:
			var node: Dictionary = item
			_tree_index[String(node["id"])] = node
	return _tree_index.get(id, {})


static func branch(id: String) -> Dictionary:
	return find(TREE_BRANCHES, id)


## Precios de todos los niveles de un nodo. Crecen con el tier, con el mundo
## exigido y con cada nivel; se redondean a cifras limpias.
static func tree_prices(id: String) -> Array:
	if _price_cache.has(id):
		return _price_cache[id]
	var node: Dictionary = tree_node(id)
	var prices: Array = []
	if not node.is_empty():
		var base: float = float(TIER_BASE.get(String(node["tier"]), 300))
		var world: int = clampi(int(node.get("w", 0)), 0, WORLD_PRICE.size() - 1)
		for level in int(node["lv"]):
			var raw: float = base * float(WORLD_PRICE[world]) * pow(TIER_GROWTH, float(level))
			prices.append(nice_price(raw))
	_price_cache[id] = prices
	return prices


## Redondea un precio: 50 por debajo de 1000, 100 hasta 10000 y 500 despues.
static func nice_price(raw: float) -> int:
	var step: float = 50.0
	if raw >= 10000.0:
		step = 500.0
	elif raw >= 1000.0:
		step = 100.0
	return int(maxf(roundf(raw / step) * step, step))


## Categorias que cuentan para la mejora secreta "Polimata".
static func core_branches() -> Array:
	var result: Array = []
	for item in TREE_BRANCHES:
		var entry: Dictionary = item
		var id: String = entry["id"]
		if not ["secretas", "legendarias", "maestria", "especializacion"].has(id):
			result.append(id)
	return result


## Power-ups de un mundo (siempre dos).
static func world_powerups(world: int) -> Array:
	var result: Array = []
	for item in POWERUPS:
		var entry: Dictionary = item
		if int(entry["world"]) == world:
			result.append(entry)
	return result


## Lista de cosmeticos de una categoria: "skin", "sword", "trail" o "aura".
static func cosmetics(slot: String) -> Array:
	if slot == "skin":
		return SKINS
	if slot == "sword":
		return SWORDS
	if slot == "trail":
		return TRAILS
	return AURAS
