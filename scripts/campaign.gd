extends RefCounted
## Datos de la campana: 5 mundos x 20 niveles.
## Cada nivel se define con parametros (velocidad, longitud, dificultad,
## patrones disponibles, patrones protagonistas, semilla fija...) de modo que
## su recorrido es siempre el mismo y se puede aprender. La curva no se
## reinicia al cambiar de mundo: cada mundo empieza mas arriba que el anterior.

const LEVELS_PER_WORLD := 20
const PIXELS_PER_METER := 48.0
const DIFFICULTY_NAMES := ["MEDIA", "MEDIA-ALTA", "ALTA", "MUY ALTA", "EXTREMA", "BRUTAL"]
## Curva global: [tramo inicial, tramo final] de cada mundo (indices de
## DIFFICULTY_NAMES). Mundo 1 media->alta ... mundo 5 extrema->brutal.
const WORLD_CURVE := [[0, 2], [2, 3], [3, 4], [4, 4], [4, 5]]
## Modos de dominio: se desbloquean al superar el nivel. No son obligatorios.
const MODES := [
	{"id": "normal", "name": "NORMAL", "desc": "EL NIVEL TAL CUAL"},
	{"id": "precision", "name": "PRECISIÓN", "desc": "TERMINA CON PRECISIÓN DE %d%%"},
	{"id": "no_damage", "name": "IMPECABLE", "desc": "NINGUNA ACCIÓN NORMAL: SOLO GOOD O MEJOR"},
	{"id": "perfect_combo", "name": "COMBO PERFECTO", "desc": "LOGRA UN COMBO DE %d"},
	{"id": "speed", "name": "VELOCIDAD +15%", "desc": "TODO EL NIVEL UN 15% MÁS RÁPIDO"},
	{"id": "legendary_only", "name": "SOLO LEGENDARY", "desc": "CADA ENEMIGO, CON GOLPE LEGENDARY"},
]

## Mundos. `theme` describe su aspecto: cielo (arriba, medio, horizonte),
## capas del fondo, recoloreado del suelo, arboles y particulas ambientales.
const WORLDS := [
	{
		"name": "VERDANTIA", "subtitle": "THE ANCIENT FOREST", "color": "38b764",
		"theme": {
			"style": "forest", "sky": ["3b5dc9", "41a6f6", "73eff7"], "far": "94b0c2", "mid": "566c86", "hill": "2e946e", "forest": "257179",
			"swap": {1: [6, 0.5]}, "enemy_remap": {},
			"spike_remap": {"w": "L", "l": "G", "g": "t", "k": "e"}, "platform": "normal", "ice": false, "storm": "",
			"ground": {}, "ground_key": "", "trees": 1.0, "tree_tint": "ffffff", "decor": true, "particles": "pollen", "ambient": "ffffff",
		},
	},
	{
		"name": "INFERNUS", "subtitle": "THE BURNING DEPTHS", "color": "ef7d57",
		"theme": {
			"style": "inferno", "sky": ["1a1c2c", "5d275d", "ef7d57"], "far": "5d275d", "mid": "3a1a2e", "hill": "7a2a3a", "forest": "2a1420",
			"swap": {2: [9, 1.0]}, "enemy_remap": {"G": "o", "L": "y", "t": "r"},
			"spike_remap": {"w": "y", "l": "o", "g": "r"}, "platform": "crumble", "ice": false, "storm": "", "lava": true,
			"ground": {"L": "o", "G": "r", "t": "p", "n": "k"}, "ground_key": "inferno", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "embers", "ambient": "ffd2b8",
		},
	},
	{
		"name": "AMETHYSTIA", "subtitle": "THE CRYSTAL VEIL", "color": "b13e53",
		"theme": {
			"style": "crystal", "sky": ["29366f", "5d275d", "f29cb5"], "far": "8a6fb0", "mid": "5d3a7a", "hill": "7a3f8c", "forest": "3a2a5e",
			"swap": {3: [7, 1.0]}, "enemy_remap": {"G": "m", "L": "w", "t": "p"},
			"spike_remap": {"w": "w", "l": "m", "g": "p"}, "platform": "blink", "ice": false, "storm": "",
			"ground": {"L": "m", "G": "p", "t": "n", "n": "k"}, "ground_key": "amethyst", "trees": 0.6, "tree_tint": "d0a0ff", "decor": false, "particles": "sparkles", "ambient": "f0d8ff",
		},
	},
	{
		"name": "FROSTFALL", "subtitle": "THE FROZEN KINGDOM", "color": "73eff7",
		"theme": {
			"style": "frost", "sky": ["3b5dc9", "94b0c2", "f4f4f4"], "far": "dfe9f0", "mid": "94b0c2", "hill": "b8d4e6", "forest": "6f8fb0",
			"swap": {1: [6, 0.6], 4: [10, 1.0]}, "enemy_remap": {"G": "c", "L": "w", "t": "B", "g": "w", "d": "l"},
			"spike_remap": {"w": "w", "l": "c", "g": "B"}, "platform": "normal", "ice": true, "storm": "f4f4f4",
			"ground": {"L": "w", "G": "c", "t": "B", "n": "b"}, "ground_key": "frost", "trees": 0.7, "tree_tint": "c8e8ff", "decor": false, "particles": "snow", "ambient": "e0f0ff",
		},
	},
	{
		"name": "SOLARIS", "subtitle": "THE LOST DUNES", "color": "ffcd75",
		"theme": {
			"style": "desert", "sky": ["41a6f6", "ffcd75", "ffe9b0"], "far": "d9a066", "mid": "b8763a", "hill": "e0b060", "forest": "a86a3a",
			"swap": {3: [8, 1.0], 1: [8, 0.4]}, "enemy_remap": {"G": "u", "L": "y", "t": "e"},
			"spike_remap": {"w": "y", "l": "u", "g": "e"}, "platform": "crumble", "ice": false, "storm": "ffcd75", "traps": true,
			"ground": {"L": "y", "G": "o", "t": "u", "n": "e"}, "ground_key": "desert", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "sand", "ambient": "fff0d0",
		},
	},
]

## Jefes finales (nivel 20 de cada mundo). Cada uno lucha con ataques de
## SU mundo (ver boss.gd): `phases` lista los ataques de cada fase (de 3 a
## 4 fases segun el jefe; cambian por tramos de vida), `mash` las pruebas de
## pulsaciones de cada fase [pulsaciones, segundos reales, variante] y
## `mash_name` como se llaman en ese jefe. `wave` = obstaculo de sus
## oleadas (0 pinchos, 3 llamas).
## Ataques comunes: wave, double_wave, wall, boulder, orb, double_orb,
## feint (finta), pillars (columnas de alturas mezcladas), tap (techo muy
## bajo) y rapid (prueba de pulsaciones).
## Ataques tematicos: roots, spores (Verdantia); fire_rain, geysers,
## magma_wave (Infernus); shards, mirror (Amethystia); spears, avalanche,
## quake (Frostfall); hands, burrow, sandstorm (Solaris).
const BOSSES := [
	{"name": "THE ANCIENT ROOT", "sprite": "boss_root", "hp": 12, "color": "38b764", "wave": 0, "mash_name": "ENREDADERA",
		"phases": [["roots", "orb", "spores"], ["roots", "spores", "pillars", "rapid"], ["roots", "double_orb", "pillars", "tap", "rapid", "feint"]],
		"mash": [[6, 2.6, 0], [6, 2.2, 2], [8, 2.4, 2]]},
	{"name": "THE INFERNAL KING", "sprite": "boss_king", "hp": 15, "color": "ef7d57", "wave": 3, "mash_name": "CADENAS DE FUEGO",
		"phases": [["fire_rain", "orb", "wave"], ["geysers", "fire_rain", "double_orb", "rapid"], ["magma_wave", "geysers", "fire_rain", "pillars", "rapid", "feint"]],
		"mash": [[6, 2.3, 0], [6, 2.0, 1], [8, 2.2, 2]]},
	{"name": "THE CRYSTAL EMPRESS", "sprite": "boss_empress", "hp": 18, "color": "f29cb5", "wave": 0, "needs_reflect": true, "mash_name": "ESPEJO ROTO",
		"phases": [["mirror", "shards", "tap"], ["mirror", "shards", "pillars", "rapid"], ["double_orb", "shards", "tap", "pillars", "rapid"], ["mirror", "double_orb", "shards", "pillars", "tap", "rapid", "feint"]],
		"mash": [[6, 2.2, 0], [6, 1.9, 2], [8, 2.0, 4], [8, 1.8, 2]]},
	{"name": "THE FROZEN TITAN", "sprite": "boss_titan", "hp": 21, "color": "73eff7", "wave": 0, "mash_name": "HIELO PERPETUO",
		"phases": [["spears", "quake", "orb"], ["avalanche", "spears", "quake", "rapid"], ["avalanche", "quake", "pillars", "double_orb", "rapid"], ["spears", "avalanche", "quake", "pillars", "tap", "rapid", "feint"]],
		"mash": [[6, 2.1, 0], [6, 1.8, 5], [8, 1.9, 2], [10, 2.2, 5]]},
	{"name": "THE SAND DEVOURER", "sprite": "boss_worm", "hp": 24, "color": "ffcd75", "wave": 0, "mash_name": "FAUCES DEL DESIERTO",
		"phases": [["burrow", "hands", "orb"], ["sandstorm", "hands", "burrow", "rapid"], ["burrow", "hands", "double_orb", "pillars", "rapid"], ["sandstorm", "burrow", "hands", "pillars", "tap", "double_orb", "rapid", "feint"]],
		"mash": [[6, 2.0, 1], [8, 2.0, 5], [8, 1.7, 2], [10, 2.0, 4]]},
]

## Economia por mundos (ver tools/simulacion_economia.py):
## WORLD_REWARD multiplica las recompensas fijas (primera vez, jefe, retos,
## modos y maestria); WORLD_COIN, las monedas recogidas en la partida.
## Repetir un mundo que ya has dejado atras paga REPLAY_FACTOR.
const WORLD_REWARD := [1.0, 2.0, 3.4, 5.2, 7.5]
const WORLD_COIN := [1.0, 1.5, 2.1, 2.8, 3.6]
const REPLAY_FACTOR := 0.6

## Hora del dia de cada nivel (se repite cada cinco).
const LEVEL_TIMES := [0.20, 0.40, 0.56, 0.80, 0.05]
## Diamantes por superar por primera vez los niveles 5, 10, 15 y 20.
const MILESTONE_DIAMONDS := [1, 2, 3, 5]


static func world_count() -> int:
	return WORLDS.size()


static func world_reward(world: int) -> float:
	return float(WORLD_REWARD[clampi(world, 0, WORLD_REWARD.size() - 1)])


## Monedas por superar un nivel por primera vez.
static func first_clear_coins(world: int, level: int) -> int:
	return int((60.0 + 5.0 * float(level)) * world_reward(world))


static func theme(world: int) -> Dictionary:
	var entry: Dictionary = WORLDS[clampi(world, 0, WORLDS.size() - 1)]
	return entry["theme"]


## Dificultad global del nivel (0.25 al empezar, mas de 1 al final).
static func difficulty(world: int, level: int) -> float:
	return 0.20 + float(world) * 0.18 + float(level) / 19.0 * 0.24


## Tramo del nivel dentro de su mundo: 1-4, 5-8, 9-12, 13-16 y 17-19.
static func band(level: int) -> int:
	return clampi(int(float(level) / 4.0), 0, 4)


static func difficulty_name(world: int, level: int) -> String:
	if level >= LEVELS_PER_WORLD - 1:
		return "JEFE FINAL"
	var curve: Array = WORLD_CURVE[clampi(world, 0, WORLD_CURVE.size() - 1)]
	var index: int = int(roundf(lerpf(float(curve[0]), float(curve[1]), float(band(level)) / 4.0)))
	return DIFFICULTY_NAMES[clampi(index, 0, DIFFICULTY_NAMES.size() - 1)]


## Parametros completos de un nivel (indices desde 0).
static func level_def(world: int, level: int) -> Dictionary:
	var d: float = difficulty(world, level)
	var is_final: bool = level == LEVELS_PER_WORLD - 1
	# Patrones disponibles: se van desbloqueando por orden de dureza.
	var unlocked: int = clampi(5 + band(level) * 2 + world * 2, 5, 19)
	# Cada nivel tiene dos patrones protagonistas distintos.
	var focus_a: int = 1 + (level * 3 + world) % (unlocked - 1)
	var focus_b: int = 1 + (level * 5 + world * 2 + 2) % (unlocked - 1)
	var meters: float = 260.0 + float(level) * 18.0 + float(world) * 40.0
	if is_final:
		meters += 240.0
	return {
		"world": world, "level": level,
		"name": "%d-%d" % [world + 1, level + 1],
		"final": is_final,
		"speed": 360.0 + float(world) * 80.0 + float(level) * 4.0,
		"speed_gain": 30.0 + float(world) * 5.0,
		"goal_px": meters * PIXELS_PER_METER,
		"meters": int(meters),
		"difficulty": clampf(d, 0.0, 1.0),
		# Las ventanas de timing se estrechan en cada mundo.
		"window_scale": [1.25, 1.05, 0.92, 0.82, 0.72][clampi(world, 0, 4)],
		"unlocked": unlocked, "focus": [focus_a, focus_b],
		"seed": 1000 + world * 100 + level,
		"time": LEVEL_TIMES[level % LEVEL_TIMES.size()],
		"band": band(level),
		"encounters": encounters(world, level),
		"coins": first_clear_coins(world, level),
		# Contrarreloj: tiempo objetivo (exige aprovechar hielo y rebotes).
		"par_time": int(meters * PIXELS_PER_METER / (360.0 + float(world) * 80.0 + float(level) * 4.0) * 0.93) if not is_final else 90 + world * 18,
	}


## DIRECTOR DE ENCUENTROS (configurable). Encuentros multiples por nivel:
## varias criaturas del mundo seguidas, nunca todas a la vez.
##   ENCOUNTER_BASE    encuentros en el nivel 6 de cada mundo
##   ENCOUNTER_STEP    encuentros extra por tramo (6-8, 9-12, 13-16, 17-19)
##   ENCOUNTER_MAX     tope por nivel
##   ENCOUNTER_LENGTH  criaturas por encuentro [minimo, maximo] por tramo
##   ENCOUNTER_GAP     separacion entre criaturas (1 = normal; menos = mas
##                     seguidas, nunca por debajo del margen de su ataque)
##   ENCOUNTER_COMBO   probabilidad de un salto de otra altura entre dos
## Los niveles 1-4 presentan a los enemigos (sin encuentros multiples) y el
## nivel 5 los combina a todos.
const ENCOUNTER_BASE := 2
const ENCOUNTER_STEP := 1
const ENCOUNTER_MAX := 6
const ENCOUNTER_LENGTH := [[2, 2], [2, 3], [2, 3], [3, 4], [3, 4]]
const ENCOUNTER_GAP := [1.0, 0.95, 0.88, 0.8, 0.72]
const ENCOUNTER_COMBO := [0.15, 0.25, 0.32, 0.4, 0.5]


static func encounters(world: int, level: int) -> Dictionary:
	if level < 4 or level >= LEVELS_PER_WORLD - 1:
		return {"count": 0}
	if level == 4:
		return {"count": 2, "min": 3, "max": 5, "gap": 1.0, "combo": 0.2}
	var b: int = band(level)
	var count: int = mini(ENCOUNTER_BASE + ENCOUNTER_STEP * (b - 1) + int(float(world) / 2.0), ENCOUNTER_MAX)
	var length: Array = ENCOUNTER_LENGTH[b]
	var extra: int = 1 if world >= 3 else 0
	return {
		"count": count,
		"min": int(length[0]),
		"max": mini(int(length[1]) + extra, 5),
		"gap": maxf(float(ENCOUNTER_GAP[b]) - 0.03 * float(world), 0.62),
		"combo": float(ENCOUNTER_COMBO[b]),
	}


## Objetivo numerico de un modo de dominio.
static func mode_target(mode: String, world: int, level: int) -> int:
	if mode == "precision":
		return mini(60 + world * 5 + band(level) * 2, 88)
	if mode == "perfect_combo":
		return 8 + world * 3 + band(level) * 2
	if mode == "speed":
		return int(level_def(world, level)["par_time"])
	return 0


static func mode_text(mode_index: int, world: int, level: int) -> String:
	var mode: Dictionary = MODES[mode_index]
	var text: String = Loc.s(String(mode["desc"]))
	if String(mode["id"]) == "speed" and level >= LEVELS_PER_WORLD - 1:
		return Loc.s("DERRÓTALO EN %d SEGUNDOS") % mode_target("speed", world, level)
	if text.contains("%d"):
		text = text % mode_target(String(mode["id"]), world, level)
	return text


## Diamantes por superar un nivel por primera vez.
static func first_clear_diamonds(world: int, level: int) -> int:
	if (level + 1) % 5 != 0:
		return 0
	var index: int = int(float(level + 1) / 5.0) - 1
	return int(MILESTONE_DIAMONDS[clampi(index, 0, 3)]) + world


## Retos opcionales de un nivel: tres distintos, que rotan de nivel en nivel.
## Tipos: no_damage, combo, legendary, perfect y precision (porcentaje).
static func challenges(world: int, level: int) -> Array:
	var all: Array = [
		{"type": "no_damage", "target": 0, "text": "NINGUNA ACCIÓN NORMAL"},
		{"type": "combo", "target": 4 + world * 2 + int(float(level) / 4.0), "text": "COMBO PERFECTO DE %d"},
		{"type": "legendary", "target": 1 + int(float(level) / 6.0) + int(float(world) / 2.0), "text": "%d ACCIONES LEGENDARY"},
		{"type": "perfect", "target": 4 + int(float(level) / 3.0) + world, "text": "%d ACCIONES PERFECT"},
		{"type": "precision", "target": mini(45 + world * 6 + level, 90), "text": "PRECISIÓN DEL %d%%"},
		{"type": "kills", "target": 0, "text": "DERROTA A TODOS LOS ENEMIGOS"},
		{"type": "coins", "target": 20 + level * 2 + world * 8, "text": "RECOGE %d MONEDAS"},
	]
	var result: Array = []
	for offset in [0, 3, 5]:
		var entry: Dictionary = all[(level + int(offset)) % all.size()]
		var text: String = entry["text"]
		if text.contains("%d"):
			text = text % int(entry["target"])
		result.append({"type": entry["type"], "target": entry["target"], "text": text})
	return result
