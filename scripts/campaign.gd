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
			"sky": ["3b5dc9", "41a6f6", "73eff7"], "far": "94b0c2", "mid": "566c86", "hill": "2e946e", "forest": "257179",
			"swap": {1: [6, 0.5]}, "enemy_remap": {},
			"spike_remap": {"w": "L", "l": "G", "g": "t", "k": "e"}, "platform": "normal", "ice": false, "storm": "",
			"ground": {}, "ground_key": "", "trees": 1.0, "tree_tint": "ffffff", "decor": true, "particles": "pollen", "ambient": "ffffff",
		},
	},
	{
		"name": "INFERNUS", "subtitle": "THE BURNING DEPTHS", "color": "ef7d57",
		"theme": {
			"sky": ["1a1c2c", "5d275d", "ef7d57"], "far": "5d275d", "mid": "3a1a2e", "hill": "7a2a3a", "forest": "2a1420",
			"swap": {2: [9, 1.0]}, "enemy_remap": {"G": "o", "L": "y", "t": "r"},
			"spike_remap": {"w": "y", "l": "o", "g": "r"}, "platform": "crumble", "ice": false, "storm": "", "lava": true,
			"ground": {"L": "o", "G": "r", "t": "p", "n": "k"}, "ground_key": "inferno", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "embers", "ambient": "ffd2b8",
		},
	},
	{
		"name": "AMETHYSTIA", "subtitle": "THE CRYSTAL VEIL", "color": "b13e53",
		"theme": {
			"sky": ["29366f", "5d275d", "f29cb5"], "far": "8a6fb0", "mid": "5d3a7a", "hill": "7a3f8c", "forest": "3a2a5e",
			"swap": {3: [7, 1.0]}, "enemy_remap": {"G": "m", "L": "w", "t": "p"},
			"spike_remap": {"w": "w", "l": "m", "g": "p"}, "platform": "blink", "ice": false, "storm": "",
			"ground": {"L": "m", "G": "p", "t": "n", "n": "k"}, "ground_key": "amethyst", "trees": 0.6, "tree_tint": "d0a0ff", "decor": false, "particles": "sparkles", "ambient": "f0d8ff",
		},
	},
	{
		"name": "FROSTFALL", "subtitle": "THE FROZEN KINGDOM", "color": "73eff7",
		"theme": {
			"sky": ["3b5dc9", "94b0c2", "f4f4f4"], "far": "dfe9f0", "mid": "94b0c2", "hill": "b8d4e6", "forest": "6f8fb0",
			"swap": {1: [6, 0.6], 4: [10, 1.0]}, "enemy_remap": {"G": "c", "L": "w", "t": "B", "g": "w", "d": "l"},
			"spike_remap": {"w": "w", "l": "c", "g": "B"}, "platform": "normal", "ice": true, "storm": "f4f4f4",
			"ground": {"L": "w", "G": "c", "t": "B", "n": "b"}, "ground_key": "frost", "trees": 0.7, "tree_tint": "c8e8ff", "decor": false, "particles": "snow", "ambient": "e0f0ff",
		},
	},
	{
		"name": "SOLARIS", "subtitle": "THE LOST DUNES", "color": "ffcd75",
		"theme": {
			"sky": ["41a6f6", "ffcd75", "ffe9b0"], "far": "d9a066", "mid": "b8763a", "hill": "e0b060", "forest": "a86a3a",
			"swap": {3: [8, 1.0], 1: [8, 0.4]}, "enemy_remap": {"G": "u", "L": "y", "t": "e"},
			"spike_remap": {"w": "y", "l": "u", "g": "e"}, "platform": "crumble", "ice": false, "storm": "ffcd75", "traps": true,
			"ground": {"L": "y", "G": "o", "t": "u", "n": "e"}, "ground_key": "desert", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "sand", "ambient": "fff0d0",
		},
	},
]

## Jefes finales (nivel 20 de cada mundo). `wave` es el tipo de obstaculo
## de sus oleadas (0 pinchos, 3 llamas) y `phases` los ataques de cada fase:
## wave, double_wave, wall, boulder, orb, double_orb y feint (finta).
const BOSSES := [
	{"name": "THE ANCIENT ROOT", "sprite": "boss_root", "hp": 10, "color": "38b764", "wave": 0,
		"phases": [["wave", "orb"], ["wave", "orb", "double_wave"], ["double_wave", "orb", "feint", "boulder"]]},
	{"name": "THE INFERNAL KING", "sprite": "boss_king", "hp": 13, "color": "ef7d57", "wave": 3,
		"phases": [["wave", "orb"], ["wave", "double_orb", "boulder"], ["double_wave", "double_orb", "feint", "boulder"]]},
	{"name": "THE CRYSTAL EMPRESS", "sprite": "boss_empress", "hp": 16, "color": "f29cb5", "wave": 0, "needs_reflect": true,
		"phases": [["wall", "orb"], ["wall", "double_orb", "feint"], ["wall", "double_orb", "double_wave", "feint"]]},
	{"name": "THE FROZEN TITAN", "sprite": "boss_titan", "hp": 19, "color": "73eff7", "wave": 0,
		"phases": [["wave", "boulder", "orb"], ["double_wave", "orb", "boulder"], ["double_wave", "double_orb", "wall", "feint"]]},
	{"name": "THE SAND DEVOURER", "sprite": "boss_worm", "hp": 22, "color": "ffcd75", "wave": 0,
		"phases": [["wall", "orb", "wave"], ["wall", "double_orb", "double_wave"], ["wall", "double_orb", "double_wave", "boulder", "feint"]]},
]

## Hora del dia de cada nivel (se repite cada cinco).
const LEVEL_TIMES := [0.20, 0.40, 0.56, 0.80, 0.05]
## Diamantes por superar por primera vez los niveles 5, 10, 15 y 20.
const MILESTONE_DIAMONDS := [1, 2, 3, 5]


static func world_count() -> int:
	return WORLDS.size()


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
		"coins": 30 + world * 20 + level * 4,
		# Contrarreloj: tiempo objetivo (exige aprovechar hielo y rebotes).
		"par_time": int(meters * PIXELS_PER_METER / (360.0 + float(world) * 80.0 + float(level) * 4.0) * 0.93) if not is_final else 60 + world * 12,
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
	var text: String = mode["desc"]
	if String(mode["id"]) == "speed" and level >= LEVELS_PER_WORLD - 1:
		return "DERRÓTALO EN %d SEGUNDOS" % mode_target("speed", world, level)
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
