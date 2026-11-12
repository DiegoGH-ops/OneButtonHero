extends RefCounted
## Bestiario: cinco enemigos propios por mundo, CADA UNO CON SU PROPIA IA
## (creature.gd). La complejidad crece de mundo en mundo:
##   Verdantia   - un patron claro por enemigo (ensenan las reglas).
##   Infernus    - dos fases: preparacion visible y ataque.
##   Amethystia  - exigen timing: golpes precisos, apariciones, imitacion.
##   Frostfall   - varias piezas: manadas, lanzas, ondas, bolas que crecen.
##   Solaris     - combinan patrones y cambian al acercarte.
## Todos se superan con el unico boton: atacar cuando son vulnerables
## (el boton ataca solo si hay un enemigo atacable delante) o saltar /
## pasar por debajo cuando no lo son.
##
## `intro` es el nivel (indice desde 0) en que aparece por primera vez en su
## mundo; desde ahi puede salir en los niveles siguientes y combinarse.

enum Behavior {
	BOAR_CHARGER, ROOT_SENTINEL, FROG_LEAPER, SPORE_SHOOTER, MOLE_POPPER,
	DEVIL_BULL, INFERNAL_BRUTE, WISP_SHIFTER, GARGOYLE_BOMBER, MAGMA_SPLITTER,
	PRISM_GUARDIAN, CRYSTAL_BLINKER, GOLEM_COLOSSUS, CRYSTAL_MIMIC, GEODE_BURSTER,
	WOLF_PACK, SKELETON_LANCER, YETI_POUNDER, SNOWMAN_ROLLER, ICE_WORM,
	DUNE_SERPENT, STALKER_SCORPION, GIANT_BEETLE, MUMMY_SUMMONER, LIVING_SAND,
}

const INTRO_LEVELS := [0, 4, 8, 12, 15]

## [nombre, comportamiento, sprite, remapeo de color, ajuste de dificultad,
##  espacio que necesita en el nivel, consejo de la primera aparicion]
## Espacios: "chase" (llega por detras), "front" (delante, con hueco para el
## ataque), "mash" (pulsacion rapida), "ranged" (dispara desde lejos),
## "split" (se divide), "wide" (ocupa mucho recorrido) y "mover" (avanza
## hacia el heroe y necesita pista libre delante).
const WORLDS := [
	[
		["JABALÍ SALVAJE", Behavior.BOAR_CHARGER, "boar", {"g": "u", "w": "y"}, 1.0, "chase", "VIENE POR DETRÁS: SALTA CUANDO TE ALCANCE"],
		["CENTINELA DE RAÍZ", Behavior.ROOT_SENTINEL, "sentinel", {"b": "G", "B": "L", "l": "u"}, 1.0, "front", "SOLO SE PUEDE ATACAR CUANDO BRILLA. SI NO, SÁLTALO"],
		["RANA SALTARINA", Behavior.FROG_LEAPER, "frog", {}, 1.0, "mover", "AVANZA A SALTOS: ATÁCALA EN EL SUELO O PASA POR DEBAJO"],
		["SETA ESCUPIDORA", Behavior.SPORE_SHOOTER, "turret", {"l": "r", "g": "u", "d": "e"}, 1.0, "ranged", "ESCUPE ESPORAS RODANTES: SÁLTALAS O CÓRTALAS"],
		["TOPO ESPINOSO", Behavior.MOLE_POPPER, "mole", {}, 1.0, "front", "EL MONTÍCULO TIEMBLA: SALDRÁ DE GOLPE. GOLPÉALO AL SALIR"],
	],
	[
		["DIABLO CORREDOR", Behavior.DEVIL_BULL, "boar", {"g": "r", "w": "y", "k": "e"}, 1.1, "mover", "ESCARBA Y EMBISTE: GOLPÉALO ANTES O DURANTE LA CARGA"],
		["BRUTO INFERNAL", Behavior.INFERNAL_BRUTE, "brute", {"g": "r", "y": "o"}, 1.0, "mash", "PULSA RÁPIDO SOLO CUANDO BAJE EL GARROTE"],
		["FUEGO FATUO", Behavior.WISP_SHIFTER, "wisp", {"c": "o", "w": "y"}, 1.0, "front", "CAMBIA DE ALTURA: SU SOMBRA ANUNCIA DÓNDE ESTARÁ"],
		["GÁRGOLA ÍGNEA", Behavior.GARGOYLE_BOMBER, "turret", {"l": "d", "g": "r"}, 1.1, "wide", "SUELTA FUEGO DESDE ARRIBA Y LUEGO SE LANZA EN PICADO"],
		["MAGMA DIVISIBLE", Behavior.MAGMA_SPLITTER, "blob", {"r": "o", "w": "y"}, 1.0, "split", "AL MORIR SE DIVIDE: PREPÁRATE PARA LOS TROZOS"],
	],
	[
		["GUARDIÁN PRISMA", Behavior.PRISM_GUARDIAN, "sentinel", {"b": "p", "B": "m", "l": "c"}, 1.15, "front", "SOLO CAE CON UN GOLPE PERFECT. SI NO, TE REPELE"],
		["ESPÍRITU DE CRISTAL", Behavior.CRYSTAL_BLINKER, "wisp", {"c": "m", "w": "w"}, 1.15, "front", "SE TELETRANSPORTA: GOLPÉALO CUANDO SE MATERIALICE"],
		["GÓLEM COLOSO", Behavior.GOLEM_COLOSSUS, "brute", {"g": "p", "y": "c"}, 1.15, "mash", "AL AGRIETARSE SE ENFURECE Y CARGA: PULSA SIN PARAR"],
		["SALTACRISTAL", Behavior.CRYSTAL_MIMIC, "frog", {"G": "p", "L": "m"}, 1.15, "front", "IMITA TUS SALTOS: NO SALTES CERCA DE ÉL, ATÁCALO"],
		["GEODA DIVISIBLE", Behavior.GEODE_BURSTER, "blob", {"r": "p", "w": "c"}, 1.15, "split", "ESTALLA EN CRISTALES SALTARINES SI NO LA ROMPES ANTES"],
	],
	[
		["LOBO GLACIAR", Behavior.WOLF_PACK, "wolf", {"g": "l", "w": "c"}, 1.25, "wide", "AÚLLA Y LLEGA CON SU MANADA: TRES LOBOS SEGUIDOS"],
		["ESQUELETO LANCERO", Behavior.SKELETON_LANCER, "sentinel", {"b": "w", "B": "l", "l": "w"}, 1.25, "ranged", "LANZA JABALINAS QUE SE CLAVAN: SÁLTALAS Y ATÁCALO AL RECARGAR"],
		["YETI BRUTAL", Behavior.YETI_POUNDER, "brute", {"g": "w", "y": "B"}, 1.25, "mash", "GOLPEA EL SUELO: SALTA LA ONDA Y MACHÁCALO MIENTRAS ESTÁ ATURDIDO"],
		["MUÑECO LANZANIEVE", Behavior.SNOWMAN_ROLLER, "turret", {"l": "w", "g": "B"}, 1.25, "ranged", "SUS BOLAS CRECEN AL RODAR: CÓRTALAS PEQUEÑAS O SÁLTALAS"],
		["GUSANO DE HIELO", Behavior.ICE_WORM, "mole", {"u": "B", "o": "c"}, 1.25, "front", "EXCAVA HACIA TI Y EMERGE: GOLPÉALO CUANDO ASOME"],
	],
	[
		["SERPIENTE DE LAS DUNAS", Behavior.DUNE_SERPENT, "boar", {"g": "y", "w": "r"}, 1.35, "mover", "ONDULA SIN PARAR: ATACA CUANDO BAJE, PASA CUANDO SUBA"],
		["ESCORPIÓN ACECHANTE", Behavior.STALKER_SCORPION, "mole", {"u": "o", "o": "r"}, 1.35, "front", "EMERGE Y LANZA EL AGUIJÓN: ATACA TRAS LA ESTOCADA"],
		["ESCARABAJO GIGANTE", Behavior.GIANT_BEETLE, "brute", {"g": "t", "y": "y"}, 1.35, "wide", "EMPUJA UNA BOLA: SALTA LA BOLA Y MACHACA AL ESCARABAJO"],
		["MOMIA GUARDIANA", Behavior.MUMMY_SUMMONER, "sentinel", {"b": "w", "B": "l", "l": "y"}, 1.35, "front", "INVOCA MANOS DEL SUELO: SÁLTALAS Y GOLPÉALA AL DESVENDARSE"],
		["ARENA VIVIENTE", Behavior.LIVING_SAND, "blob", {"r": "y", "w": "o"}, 1.35, "mover", "SE DESHACE Y SE REHACE MÁS ADELANTE: TRES GOLPES"],
	],
]


static func entry(world: int, index: int) -> Array:
	var list: Array = WORLDS[clampi(world, 0, WORLDS.size() - 1)]
	return list[clampi(index, 0, list.size() - 1)]


## Consejo de la primera aparicion de un enemigo.
static func tip(world: int, index: int) -> String:
	return String(entry(world, index)[6])


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
