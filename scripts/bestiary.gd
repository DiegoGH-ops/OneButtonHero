extends RefCounted
## Bestiario: cinco enemigos propios por mundo. Cada uno usa uno de los
## comportamientos de creature.gd con su propio nombre, aspecto y ajustes.
## `intro` es el nivel (indice desde 0) en que aparece por primera vez en su
## mundo; desde ahi puede salir en los niveles siguientes y combinarse.

enum Archetype { CHASER, SENTINEL, BRUTE, SHIFTER, HOPPER, SHOOTER, BURROWER, SPLITTER, BARRICADE }

## Consejo que se muestra la primera vez que aparece cada comportamiento.
const TIPS := [
	"VIENE POR DETRÁS: SALTA CUANDO TE ALCANCE",
	"SOLO ES VULNERABLE CUANDO BRILLA. SI NO, SÁLTALO",
	"PULSA MUY RÁPIDO PARA DERRIBARLO ANTES DE QUE TE ALCANCE",
	"CAMBIA DE ALTURA: MIRA SU SOMBRA Y NO SALTES SI ESTÁ ARRIBA",
	"SALTA SOBRE ÉL CUANDO TOQUE EL SUELO O PÁSALO POR DEBAJO",
	"DISPARA A RAS DE SUELO: SALTA O CORTA LOS PROYECTILES",
	"SALE DEL SUELO DE GOLPE: REACCIONA CON UN SALTO",
	"AL MORIR SE DIVIDE: PREPÁRATE PARA LOS TROZOS",
	"PULSA MUY RÁPIDO: CADA GOLPE LA EMPUJA",
]
const INTRO_LEVELS := [0, 4, 8, 12, 15]

## [nombre, comportamiento, sprite, remapeo de color, ajuste de dificultad]
const WORLDS := [
	[
		["JABALÍ SALVAJE", Archetype.CHASER, "boar", {"g": "u", "w": "y"}, 1.0],
		["CENTINELA DE RAÍZ", Archetype.SENTINEL, "sentinel", {"b": "G", "B": "L", "l": "u"}, 1.0],
		["RANA SALTARINA", Archetype.HOPPER, "frog", {}, 1.0],
		["SETA ESCUPIDORA", Archetype.SHOOTER, "turret", {"l": "r", "g": "u", "d": "e"}, 1.0],
		["TOPO ESPINOSO", Archetype.BURROWER, "mole", {}, 1.0],
	],
	[
		["DIABLO CORREDOR", Archetype.CHASER, "boar", {"g": "r", "w": "y", "k": "e"}, 1.1],
		["BRUTO INFERNAL", Archetype.BRUTE, "brute", {"g": "r", "y": "o"}, 1.0],
		["FUEGO FATUO", Archetype.SHIFTER, "wisp", {"c": "o", "w": "y"}, 1.0],
		["GÁRGOLA ÍGNEA", Archetype.SHOOTER, "turret", {"l": "d", "g": "r"}, 1.1],
		["MAGMA DIVISIBLE", Archetype.SPLITTER, "blob", {"r": "o", "w": "y"}, 1.0],
	],
	[
		["GUARDIÁN PRISMA", Archetype.SENTINEL, "sentinel", {"b": "p", "B": "m", "l": "c"}, 1.15],
		["ESPÍRITU DE CRISTAL", Archetype.SHIFTER, "wisp", {"c": "m", "w": "w"}, 1.15],
		["GÓLEM COLOSO", Archetype.BRUTE, "brute", {"g": "p", "y": "c"}, 1.15],
		["SALTACRISTAL", Archetype.HOPPER, "frog", {"G": "p", "L": "m"}, 1.15],
		["GEODA DIVISIBLE", Archetype.SPLITTER, "blob", {"r": "p", "w": "c"}, 1.15],
	],
	[
		["LOBO GLACIAR", Archetype.CHASER, "boar", {"g": "l", "w": "c"}, 1.25],
		["ESQUELETO LANCERO", Archetype.SENTINEL, "sentinel", {"b": "w", "B": "l", "l": "w"}, 1.25],
		["YETI BRUTAL", Archetype.BRUTE, "brute", {"g": "w", "y": "B"}, 1.25],
		["MUÑECO LANZANIEVE", Archetype.SHOOTER, "turret", {"l": "w", "g": "B"}, 1.25],
		["GUSANO DE HIELO", Archetype.BURROWER, "mole", {"u": "B", "o": "c"}, 1.25],
	],
	[
		["SERPIENTE DE LAS DUNAS", Archetype.CHASER, "boar", {"g": "y", "w": "r"}, 1.35],
		["ESCORPIÓN ACECHANTE", Archetype.BURROWER, "mole", {"u": "o", "o": "r"}, 1.35],
		["ESCARABAJO GIGANTE", Archetype.BRUTE, "brute", {"g": "t", "y": "y"}, 1.35],
		["MOMIA GUARDIANA", Archetype.SENTINEL, "sentinel", {"b": "w", "B": "l", "l": "y"}, 1.35],
		["ARENA VIVIENTE", Archetype.SPLITTER, "blob", {"r": "y", "w": "o"}, 1.35],
	],
]


static func entry(world: int, index: int) -> Array:
	var list: Array = WORLDS[clampi(world, 0, WORLDS.size() - 1)]
	return list[clampi(index, 0, list.size() - 1)]


## Enemigos del mundo disponibles en un nivel (indices 0..4).
static func unlocked(_world: int, level: int) -> Array:
	var result: Array = []
	for i in INTRO_LEVELS.size():
		if level >= int(INTRO_LEVELS[i]):
			result.append(i)
	return result


## Enemigo que se estrena en este nivel (-1 si ninguno).
static func introduced(level: int) -> int:
	return INTRO_LEVELS.find(level)
