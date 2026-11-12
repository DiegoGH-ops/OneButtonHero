extends RefCounted
## Datos de la campana: 5 mundos x 20 niveles.
## Cada nivel se define con parametros (velocidad, longitud, dificultad,
## patrones disponibles, patrones protagonistas, semilla fija...) de modo que
## su recorrido es siempre el mismo y se puede aprender. La curva no se
## reinicia al cambiar de mundo: cada mundo empieza mas arriba que el anterior.

const LEVELS_PER_WORLD := 20
const PIXELS_PER_METER := 48.0
const DIFFICULTY_NAMES := ["MEDIA", "MEDIA-ALTA", "ALTA", "MUY ALTA", "EXTREMA", "BRUTAL"]

## Mundos. `theme` describe su aspecto: cielo (arriba, medio, horizonte),
## capas del fondo, recoloreado del suelo, arboles y particulas ambientales.
const WORLDS := [
	{
		"name": "VERDANTIA", "subtitle": "THE ANCIENT FOREST", "color": "38b764",
		"theme": {
			"sky": ["3b5dc9", "41a6f6", "73eff7"], "far": "94b0c2", "mid": "566c86", "hill": "2e946e", "forest": "257179",
			"ground": {}, "ground_key": "", "trees": 1.0, "tree_tint": "ffffff", "decor": true, "particles": "pollen", "ambient": "ffffff",
		},
	},
	{
		"name": "INFERNUS", "subtitle": "THE BURNING DEPTHS", "color": "ef7d57",
		"theme": {
			"sky": ["1a1c2c", "5d275d", "ef7d57"], "far": "5d275d", "mid": "3a1a2e", "hill": "7a2a3a", "forest": "2a1420",
			"ground": {"L": "o", "G": "r", "t": "p", "n": "k"}, "ground_key": "inferno", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "embers", "ambient": "ffd2b8",
		},
	},
	{
		"name": "AMETHYSTIA", "subtitle": "THE CRYSTAL VEIL", "color": "b13e53",
		"theme": {
			"sky": ["29366f", "5d275d", "f29cb5"], "far": "8a6fb0", "mid": "5d3a7a", "hill": "7a3f8c", "forest": "3a2a5e",
			"ground": {"L": "m", "G": "p", "t": "n", "n": "k"}, "ground_key": "amethyst", "trees": 0.6, "tree_tint": "d0a0ff", "decor": false, "particles": "sparkles", "ambient": "f0d8ff",
		},
	},
	{
		"name": "FROSTFALL", "subtitle": "THE FROZEN KINGDOM", "color": "73eff7",
		"theme": {
			"sky": ["3b5dc9", "94b0c2", "f4f4f4"], "far": "dfe9f0", "mid": "94b0c2", "hill": "b8d4e6", "forest": "6f8fb0",
			"ground": {"L": "w", "G": "c", "t": "B", "n": "b"}, "ground_key": "frost", "trees": 0.7, "tree_tint": "c8e8ff", "decor": false, "particles": "snow", "ambient": "e0f0ff",
		},
	},
	{
		"name": "SOLARIS", "subtitle": "THE LOST DUNES", "color": "ffcd75",
		"theme": {
			"sky": ["41a6f6", "ffcd75", "ffe9b0"], "far": "d9a066", "mid": "b8763a", "hill": "e0b060", "forest": "a86a3a",
			"ground": {"L": "y", "G": "o", "t": "u", "n": "e"}, "ground_key": "desert", "trees": 0.0, "tree_tint": "ffffff", "decor": false, "particles": "sand", "ambient": "fff0d0",
		},
	},
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
	return 0.25 + float(world) * 0.14 + float(level) / 19.0 * 0.30


static func difficulty_name(world: int, level: int) -> String:
	var d: float = difficulty(world, level)
	var index: int = clampi(int((d - 0.25) / 0.16), 0, DIFFICULTY_NAMES.size() - 1)
	return DIFFICULTY_NAMES[index]


## Parametros completos de un nivel (indices desde 0).
static func level_def(world: int, level: int) -> Dictionary:
	var d: float = difficulty(world, level)
	var is_final: bool = level == LEVELS_PER_WORLD - 1
	# Patrones disponibles: se van desbloqueando por orden de dureza.
	var unlocked: int = clampi(5 + int(float(level) * 0.45 + float(world) * 1.5), 5, 16)
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
		"speed": 360.0 + float(world) * 45.0 + float(level) * 5.0,
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
	}


## Diamantes por superar un nivel por primera vez.
static func first_clear_diamonds(world: int, level: int) -> int:
	if (level + 1) % 5 != 0:
		return 0
	var index: int = int(float(level + 1) / 5.0) - 1
	return int(MILESTONE_DIAMONDS[clampi(index, 0, 3)]) + world
