extends RefCounted
## Catalogo de logros: 15 categorias y 6 niveles (Bronce a Legendario).
## Igual que las misiones, cada logro lee una estadistica registrada con
## GameData.track() (las partidas de prueba y el modo administrador no
## cuentan). Se conceden solos, una unica vez, y guardan la fecha.

const Campaign = preload("res://scripts/campaign.gd")

const CATEGORIES := ["PROGRESO", "MUNDOS", "ENEMIGOS", "JEFES", "SALTOS", "PRECISIÓN", "VELOCIDAD", "SUPERVIVENCIA", "ECONOMÍA", "COSMÉTICOS", "MEJORAS", "MISIONES", "SECRETOS", "MAESTRÍA", "LEGENDARIOS"]
const TIERS := ["BRONCE", "PLATA", "ORO", "PLATINO", "DIAMANTE", "LEGENDARIO"]
const TIER_COLORS := ["c07a4a", "c4d0dc", "ffcd75", "73eff7", "b4e8ff", "ef7d57"]
## Recompensa base por nivel: monedas, diamantes y prestigio.
const TIER_COINS := [100, 300, 800, 2000, 4500, 10000]
const TIER_GEMS := [1, 1, 2, 2, 3, 4]
const TIER_PRESTIGE := [5, 10, 20, 35, 60, 100]
## Iconos dibujados por categoria (ver progress_panel.gd).
const CATEGORY_ICONS := ["flag", "globe", "skull", "crown", "wing", "target", "bolt", "heart", "coin", "shirt", "tree", "scroll", "eye", "star", "gem"]

## Escaleras: [categoria, stat, objetivos, nombres, descripcion (%d), nivel inicial]
const LADDERS := [
	["PROGRESO", "level_unique", [5, 20, 40, 60, 80, 100], ["PRIMEROS PASOS", "EXPLORADOR", "AVENTURERO", "VETERANO", "CONQUISTADOR", "LEYENDA VIVIENTE"], "SUPERA %d NIVELES DISTINTOS", 0],
	["PROGRESO", "stars_gained", [50, 150, 250], ["RECOLECTOR DE ESTRELLAS", "CONSTELACIÓN", "FIRMAMENTO"], "CONSIGUE %d ESTRELLAS", 0],
	["ENEMIGOS", "kills", [50, 250, 1000, 3000, 8000, 20000], ["CAZADOR", "VERDUGO", "AZOTE", "EXTERMINADOR", "PLAGA DE PLAGAS", "FIN DE LAS BESTIAS"], "DERROTA %d ENEMIGOS", 0],
	["ENEMIGOS", "stomps", [25, 100, 400], ["PISAPAPELES", "APISONADORA", "TERREMOTO"], "DERROTA %d ENEMIGOS PISÁNDOLOS", 0],
	["JEFES", "boss_kill", [1, 5, 10, 25, 50], ["MATAJEFES", "LIBERADOR", "AZOTE DE TIRANOS", "CAZADOR DE COLOSOS", "TERROR DE LOS JEFES"], "DERROTA %d JEFES", 0],
	["JEFES", "boss_rapid", [10, 50, 150], ["ROMPECADENAS", "ROMPEMUROS", "ROMPEMUNDOS"], "SUPERA %d RAPID SIX DE JEFE", 1],
	["SALTOS", "jump", [500, 2500, 10000, 30000, 75000, 150000], ["SALTARÍN", "CANGURO", "SALTAMONTES", "ACRÓBATA", "SIN GRAVEDAD", "SEÑOR DEL AIRE"], "SALTA %d VECES", 0],
	["SALTOS", "jump_full", [50, 300, 1000], ["ALTURA", "CUMBRE", "ESTRATOSFERA"], "HAZ %d SALTOS MANTENIENDO HASTA EL TOPE", 0],
	["SALTOS", "perfect_land", [25, 150, 500], ["GATO", "PLUMA", "ATERRIZAJE IMPOSIBLE"], "HAZ %d ATERRIZAJES PERFECT", 1],
	["PRECISIÓN", "perfects", [100, 500, 2000, 6000, 15000, 40000], ["PRECISO", "CERTERO", "QUIRÚRGICO", "MILIMÉTRICO", "INFALIBLE", "PRECISIÓN ABSOLUTA"], "HAZ %d ACCIONES PERFECT", 0],
	["PRECISIÓN", "legendaries", [25, 150, 600, 2000, 5000, 12000], ["ÚLTIMO SEGUNDO", "INSTANTE", "PARPADEO", "ENTRE LATIDOS", "TIEMPO DETENIDO", "DUEÑO DEL INSTANTE"], "HAZ %d ACCIONES LEGENDARY", 0],
	["VELOCIDAD", "turbo_clear", [1, 10, 30, 60, 90], ["ACELERÓN", "VELOZ", "SUPERSÓNICO", "HIPERSÓNICO", "LUZ"], "SUPERA %d NIVELES ENTEROS A 1.5X", 0],
	["VELOCIDAD", "rapid_lightning", [1, 10, 50], ["CHISPAZO", "RAYO", "TORMENTA"], "SUPERA %d RAPID SIX EN MENOS DE 0.6 S", 1],
	["VELOCIDAD", "rapid_success", [10, 100, 500], ["DEDOS ÁGILES", "AMETRALLADORA", "PULSO DE ACERO"], "SUPERA %d RAPID SIX", 0],
	["SUPERVIVENCIA", "nights", [1, 5, 20], ["NOCTÁMBULO", "CENTINELA", "SEÑOR DE LA NOCHE"], "SOBREVIVE A %d NOCHES", 0],
	["SUPERVIVENCIA", "flawless", [1, 10, 30, 75, 150], ["SIN UN RASGUÑO", "IMPECABLE", "INTOCABLE", "INVULNERABLE", "INMACULADO"], "SUPERA %d NIVELES SIN RECIBIR DAÑO", 0],
	["SUPERVIVENCIA", "endless_distance", [1000, 3000, 6000], ["CORREDOR", "FONDISTA", "INFINITO"], "RECORRE %d M EN UNA PARTIDA INFINITA", 1],
	["ECONOMÍA", "coins_picked", [1000, 10000, 50000, 150000, 400000, 1000000], ["AHORRADOR", "TESORERO", "BANQUERO", "MAGNATE", "REY MIDAS", "MILLONARIO"], "RECOGE %d MONEDAS", 0],
	["ECONOMÍA", "coins_spent", [5000, 50000, 250000, 1000000], ["CLIENTE", "INVERSOR", "MECENAS", "GRAN DERROCHADOR"], "GASTA %d MONEDAS", 0],
	["ECONOMÍA", "gems_picked", [20, 150, 500], ["JOYERO", "ORFEBRE", "CORONA DE GEMAS"], "RECOGE %d GEMAS", 0],
	["COSMÉTICOS", "cosmetics_got", [5, 15, 30, 50, 70, 90], ["COQUETO", "COLECCIONISTA", "ARMARIO LLENO", "MUSEO", "CATÁLOGO VIVO", "TODOS LOS ESTILOS"], "CONSIGUE %d COSMÉTICOS", 0],
	["MEJORAS", "tree_bought", [5, 25, 75, 150, 220, 272], ["BROTE", "RAÍZ", "TRONCO", "COPA", "BOSQUE", "ÁRBOL COMPLETO"], "COMPRA %d NIVELES DEL ÁRBOL", 0],
	["MEJORAS", "buy_power", [1, 5, 10], ["EMPODERADO", "ARSENAL", "TODOS LOS PODERES"], "COMPRA %d POWER-UPS", 0],
	["MISIONES", "missions_claimed", [10, 50, 150, 300, 600], ["CUMPLIDOR", "RESPONSABLE", "INCANSABLE", "AGENTE", "LEYENDA DEL DEBER"], "COBRA %d MISIONES", 0],
	["MISIONES", "weekly_claimed", [10, 40], ["SEMANA A SEMANA", "CALENDARIO COMPLETO"], "COBRA %d MISIONES SEMANALES", 1],
	["MAESTRÍA", "best_combo", [25, 50, 75], ["IMPARABLE", "INFALIBLE", "HIPNÓTICO"], "LOGRA UN COMBO PERFECTO DE %d", 1],
	["MAESTRÍA", "rank_s", [10, 50, 150], ["MAESTRO", "ÉLITE", "LA CIMA"], "SUPERA %d NIVELES CON RANGO S O MEJOR", 1],
	["MAESTRÍA", "rank_sss", [1, 10, 50], ["TRIPLE S", "SSS SERIAL", "SSS ETERNO"], "SUPERA %d NIVELES CON RANGO SSS", 2],
	["MAESTRÍA", "mode_clear", [10, 50, 150], ["DOMINADOR", "SEÑOR DE LOS MODOS", "TODOS LOS MODOS"], "SUPERA %d MODOS DE DOMINIO", 1],
]

## Logros sueltos: [id, categoria, nivel, stat, objetivo, nombre, descripcion, pista, extras]
## extras: {"secret": true, "title": "...", "cosmetic": "id", "badge": true}
const SINGLES := [
	# Mundos: liberar y dominar cada uno.
	["w_free_0", "MUNDOS", 0, "boss_kill@w0", 1, "LIBERADOR DE VERDANTIA", "DERROTA A THE ANCIENT ROOT", "", {}],
	["w_free_1", "MUNDOS", 1, "boss_kill@w1", 1, "LIBERADOR DE INFERNUS", "DERROTA A THE INFERNAL KING", "", {}],
	["w_free_2", "MUNDOS", 2, "boss_kill@w2", 1, "LIBERADOR DE AMETHYSTIA", "DERROTA A THE CRYSTAL EMPRESS", "", {}],
	["w_free_3", "MUNDOS", 3, "boss_kill@w3", 1, "LIBERADOR DE FROSTFALL", "DERROTA A THE FROZEN TITAN", "", {}],
	["w_free_4", "MUNDOS", 4, "boss_kill@w4", 1, "LIBERADOR DE SOLARIS", "DERROTA A THE SAND DEVOURER", "", {"title": "LIBERADOR"}],
	["w_star_0", "MUNDOS", 1, "three_star_levels@w0", 20, "MAESTRO DE VERDANTIA", "3 ESTRELLAS EN LOS 20 NIVELES DE VERDANTIA", "", {}],
	["w_star_1", "MUNDOS", 2, "three_star_levels@w1", 20, "MAESTRO DE INFERNUS", "3 ESTRELLAS EN LOS 20 NIVELES DE INFERNUS", "", {}],
	["w_star_2", "MUNDOS", 2, "three_star_levels@w2", 20, "MAESTRO DE AMETHYSTIA", "3 ESTRELLAS EN LOS 20 NIVELES DE AMETHYSTIA", "", {}],
	["w_star_3", "MUNDOS", 3, "three_star_levels@w3", 20, "MAESTRO DE FROSTFALL", "3 ESTRELLAS EN LOS 20 NIVELES DE FROSTFALL", "", {}],
	["w_star_4", "MUNDOS", 4, "three_star_levels@w4", 20, "MAESTRO DE SOLARIS", "3 ESTRELLAS EN LOS 20 NIVELES DE SOLARIS", "", {"badge": true}],
	# Jefes.
	["boss_clean", "JEFES", 3, "boss_flawless", 1, "SIN TOCARLE UN PELO", "VENCE A UN JEFE SIN RECIBIR DAÑO", "", {}],
	["boss_fast", "JEFES", 2, "boss_fast", 3, "CONTRARRELOJ", "VENCE 3 JEFES ANTES DEL TIEMPO OBJETIVO", "", {}],
	# Saltos y supervivencia sueltos.
	["jump_tap", "SALTOS", 1, "jump_tap", 300, "TOQUE DE PLUMA", "HAZ 300 SALTOS MÍNIMOS", "", {}],
	["dodge_100", "SUPERVIVENCIA", 2, "perfect_dodge", 100, "ESCURRIDIZO", "ESQUIVA 100 PROYECTILES EN EL ÚLTIMO MOMENTO", "", {}],
	["comeback", "SUPERVIVENCIA", 1, "comeback", 1, "AL BORDE DEL ABISMO", "SUPERA UN NIVEL TRAS RECIBIR 3 GOLPES O MÁS", "", {}],
	# Cosmeticos sueltos.
	["abyss_set", "COSMÉTICOS", 4, "abyss_owned", 1, "HEREDERO DEL ABISMO", "CONSIGUE EL CONJUNTO DEL CABALLERO DEL ABISMO", "", {"title": "CABALLERO DEL ABISMO"}],
	["mythic_1", "COSMÉTICOS", 3, "mythic_got", 1, "OBJETO MÍTICO", "CONSIGUE UN COSMÉTICO MÍTICO", "", {}],
	# Misiones.
	["daily_30", "MISIONES", 2, "daily_claimed", 30, "RUTINA DIARIA", "COBRA 30 MISIONES DIARIAS", "", {}],
	["secret_m", "MISIONES", 3, "secret_claimed", 10, "DETECTIVE", "COBRA 10 MISIONES SECRETAS", "", {}],
	# Secretos (ocultos hasta conseguirlos).
	["s_pacifist", "SECRETOS", 2, "pacifist", 1, "PACIFISTA", "SUPERA UN NIVEL CON ENEMIGOS SIN DERROTAR A NINGUNO", "NO TODO SE RESUELVE A ESPADAZOS", {"secret": true}],
	["s_tourist", "SECRETOS", 0, "slow_clear", 1, "TURISTA", "SUPERA UN NIVEL TARDANDO EL DOBLE DEL TIEMPO OBJETIVO", "SIN PRISA", {"secret": true}],
	["s_butter", "SECRETOS", 0, "rapid_fail", 25, "DEDOS DE MANTEQUILLA", "FALLA 25 RAPID SIX", "A VECES LOS DEDOS NO RESPONDEN", {"secret": true}],
	["s_fall", "SECRETOS", 1, "death", 100, "CAER Y LEVANTARSE", "CAE 100 VECES", "CAER TAMBIÉN ES APRENDER", {"secret": true}],
	["s_toggle", "SECRETOS", 0, "speed_toggle", 100, "PALANCA ROTA", "CAMBIA LA VELOCIDAD 100 VECES", "¿RÁPIDO O NORMAL?", {"secret": true}],
	["s_abyss", "SECRETOS", 3, "abyss_worn", 1, "VESTIDO DE OSCURIDAD", "SUPERA UN NIVEL CON EL CONJUNTO DEL ABISMO COMPLETO", "LA OSCURIDAD TE SIENTA BIEN", {"secret": true}],
	["s_masterpiece", "SECRETOS", 3, "three_star_flawless", 25, "OBRA MAESTRA", "3 ESTRELLAS SIN DAÑO EN 25 NIVELES", "ESTRELLAS SIN CICATRICES", {"secret": true}],
	["s_marathon", "SECRETOS", 4, "run_distance", 8000, "MÁS ALLÁ DEL HORIZONTE", "RECORRE 8000 M EN UNA SOLA PARTIDA", "SIGUE CORRIENDO...", {"secret": true}],
	# Legendarios: los mas dificiles del juego.
	["l_timing", "LEGENDARIOS", 5, "best_combo", 100, "MAESTRO DEL TIMING", "LOGRA UN COMBO PERFECTO DE 100", "", {"title": "MAESTRO DEL TIMING", "cosmetic": "aura_cronos", "badge": true}],
	["l_margin", "LEGENDARIOS", 5, "sss_flawless", 1, "SIN MARGEN DE ERROR", "SUPERA UN NIVEL CON RANGO SSS, SIN DAÑO Y SIN NINGUNA ACCIÓN NORMAL", "", {"title": "IMPECABLE", "badge": true}],
	["l_nightmare", "LEGENDARIOS", 5, "boss_flawless_worlds", 5, "PESADILLA DE LOS JEFES", "VENCE A LOS CINCO JEFES SIN RECIBIR NI UN GOLPE", "", {"title": "PESADILLA DE LOS JEFES", "cosmetic": "skin_pesadilla", "badge": true}],
	["l_speed", "LEGENDARIOS", 5, "turbo_unique", 95, "VELOCIDAD ABSOLUTA", "SUPERA LOS 95 NIVELES SIN JEFE ENTEROS A 1.5X", "", {"title": "VELOCIDAD ABSOLUTA", "cosmetic": "trail_absoluta", "badge": true}],
	["l_domain", "LEGENDARIOS", 5, "three_star_levels", 100, "DOMINIO TOTAL", "CONSIGUE 3 ESTRELLAS EN LOS 100 NIVELES", "", {"title": "DOMINIO TOTAL", "badge": true}],
	["l_abyss", "LEGENDARIOS", 5, "abyss_legend", 1, "LEYENDA DEL ABISMO", "VENCE AL ÚLTIMO JEFE CON RANGO SSS LLEVANDO EL CONJUNTO DEL ABISMO", "", {"title": "LEYENDA DEL ABISMO", "badge": true}],
	["l_rapid", "LEGENDARIOS", 5, "rapid_extreme", 100, "RAPID SIX MASTER", "SUPERA 100 RAPID SIX EXTREMOS", "", {"title": "RAPID SIX MASTER", "badge": true}],
	["l_reflex", "LEGENDARIOS", 5, "level_legendary", 40, "REFLEJOS SOBRENATURALES", "HAZ 40 ACCIONES LEGENDARY EN UN SOLO NIVEL", "", {"title": "REFLEJOS SOBRENATURALES", "badge": true}],
	["l_nofail", "LEGENDARIOS", 5, "flawless_streak", 15, "SIN FALLAR", "SUPERA 15 NIVELES SEGUIDOS SIN RECIBIR DAÑO", "", {"title": "SIN FALLAR", "badge": true}],
	["l_legend_speed", "LEGENDARIOS", 5, "turbo_s", 50, "VELOCIDAD DE LEYENDA", "SUPERA 50 NIVELES ENTEROS A 1.5X CON RANGO S O MEJOR", "", {"title": "VELOCIDAD DE LEYENDA", "badge": true}],
	["l_last_click", "LEGENDARIOS", 5, "rapid_last_click", 25, "EL ÚLTIMO CLIC", "TERMINA 25 RAPID SIX CON MENOS DE 0.15 S RESTANTES", "", {"title": "EL ÚLTIMO CLIC", "cosmetic": "sword_ultimo_clic", "badge": true}],
]

## Estadisticas que guardan una mejor marca en vez de acumularse.
const MAX_STATS := ["best_combo", "run_combo", "endless_distance", "coins_run", "kills_run", "run_distance", "level_legendary", "rapid_streak", "rapid_streak_run", "nodeath_streak", "flawless_streak", "worlds_conquered", "boss_flawless_worlds"]

static var _all: Array = []
static var _by_id: Dictionary = {}


static func all() -> Array:
	if not _all.is_empty():
		return _all
	for row in LADDERS:
		var ladder: Array = row
		var targets: Array = ladder[2]
		var names: Array = ladder[3]
		var start: int = int(ladder[5])
		for j in targets.size():
			var tier: int = clampi(start + j, 0, 5)
			var desc: String = String(ladder[4]) % int(targets[j])
			_add({"id": "%s_%d" % [String(ladder[1]), int(targets[j])], "cat": String(ladder[0]), "tier": tier, "stat": String(ladder[1]), "target": int(targets[j]), "name": String(names[j]), "desc": desc, "hint": "", "secret": false})
	for row in SINGLES:
		var s: Array = row
		var extras: Dictionary = s[8]
		var entry: Dictionary = {"id": String(s[0]), "cat": String(s[1]), "tier": int(s[2]), "stat": String(s[3]), "target": int(s[4]), "name": String(s[5]), "desc": String(s[6]), "hint": String(s[7]), "secret": bool(extras.get("secret", false))}
		for key in ["title", "cosmetic", "badge"]:
			if extras.has(key):
				entry[key] = extras[key]
		_add(entry)
	return _all


static func _add(entry: Dictionary) -> void:
	var tier: int = int(entry["tier"])
	entry["coins"] = int(TIER_COINS[tier])
	entry["gems"] = int(TIER_GEMS[tier])
	entry["prestige"] = int(TIER_PRESTIGE[tier])
	# Del platino en adelante, cada logro da tambien una insignia.
	if tier >= 3:
		entry["badge"] = true
	_all.append(entry)
	_by_id[String(entry["id"])] = entry


static func find(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


static func tier_name(tier: int) -> String:
	return String(TIERS[clampi(tier, 0, 5)])


static func tier_color(tier: int) -> Color:
	return Color(String(TIER_COLORS[clampi(tier, 0, 5)]))


static func by_category(cat: String) -> Array:
	var list: Array = []
	for item in all():
		var entry: Dictionary = item
		if cat == "" or String(entry["cat"]) == cat:
			list.append(entry)
	return list


## Texto corto de la recompensa.
static func reward_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("+%d MONEDAS" % int(entry["coins"]))
	parts.append("+%d DIAMANTES" % int(entry["gems"]))
	if entry.has("title"):
		parts.append("TÍTULO")
	if entry.has("cosmetic"):
		parts.append("COSMÉTICO")
	if bool(entry.get("badge", false)):
		parts.append("INSIGNIA")
	parts.append("%d PRESTIGIO" % int(entry["prestige"]))
	return " ".join(parts)


## Iconos de 7x7 por categoria (para medallas del panel y del aviso).
const ICON_PIXELS := {
	"flag": ["##.....", "#####..", "#######", "#####..", "#......", "#......", "#......"],
	"globe": ["..###..", ".#.#.#.", "#######", "#..#..#", "#######", ".#.#.#.", "..###.."],
	"skull": [".#####.", "#######", "#..#..#", "#######", ".##.##.", "..###..", "..#.#.."],
	"crown": ["#..#..#", "#.###.#", "#######", "#######", "#######", ".......", "#######"],
	"wing": ["......#", "....###", "..#####", "#######", ".######", "...####", ".....##"],
	"target": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	"bolt": ["...###.", "..###..", ".###...", "#######", "...###.", "..###..", ".###..."],
	"heart": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
	"coin": ["..###..", ".#####.", "##.#.##", "##.#.##", "##.#.##", ".#####.", "..###.."],
	"shirt": ["##...##", "###.###", "#######", ".#####.", ".#####.", ".#####.", ".#####."],
	"tree": ["..###..", ".#####.", "#######", ".#####.", "...#...", "...#...", "..###.."],
	"scroll": ["######.", "#....#.", "#.##.#.", "#....#.", "#.##.#.", "#....##", "######."],
	"eye": [".......", "..###..", ".#...#.", "#..#..#", ".#...#.", "..###..", "......."],
	"star": ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "#.....#"],
	"gem": [".#####.", "#.#.#.#", "#######", ".#####.", "..###..", "...#...", "......."],
}


static func icon_for(entry: Dictionary) -> String:
	var index: int = CATEGORIES.find(String(entry.get("cat", "")))
	return String(CATEGORY_ICONS[index]) if index >= 0 else "star"


## Medalla redonda con el color del nivel y el icono de la categoria.
static func draw_medal(ci: CanvasItem, center: Vector2, radius: float, tier: int, icon: String, locked: bool) -> void:
	var color: Color = Color(0.22, 0.24, 0.32, 1.0) if locked else tier_color(tier)
	ci.draw_circle(center, radius + 3.0, Color("1a1c2c"))
	ci.draw_circle(center, radius, color.darkened(0.35))
	ci.draw_circle(center, radius * 0.8, color)
	var pixels: Array = ICON_PIXELS.get(icon, ICON_PIXELS["star"])
	var cell: float = floorf(radius * 1.1 / 7.0)
	var origin: Vector2 = center - Vector2(cell * 3.5, cell * 3.5)
	var ink: Color = Color(0.35, 0.37, 0.45, 1.0) if locked else Color("1a1c2c")
	for y in pixels.size():
		var row: String = pixels[y]
		for x in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2(origin + Vector2(float(x) * cell, float(y) * cell), Vector2(cell, cell)), ink)
