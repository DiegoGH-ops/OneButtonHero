extends RefCounted
## Sistema de timing: clasifica una accion segun lo cerca del peligro que se
## ejecuto. Cuanto mas se apura (menos margen), mejor categoria.
## Todas las ventanas estan en segundos y son configurables aqui.

enum Rating { NONE, NORMAL, GOOD, PERFECT, LEGENDARY }

const NAMES := ["", "", "GOOD", "PERFECT", "LEGENDARY"]
## Margen maximo (sobre el ultimo instante seguro) de cada categoria.
## Equivalen a ventanas de 45 ms (Legendary), 80 ms (Perfect) y 210 ms (Good).
const LEGENDARY_WINDOW := 0.045
const PERFECT_WINDOW := 0.125
const GOOD_WINDOW := 0.335
## Mas alla de este margen no habia peligro cerca: la accion no se evalua.
const MAX_WINDOW := 1.0
## Puntos extra y carga de Soul Reaper por categoria.
const BONUS := [0, 0, 10, 40, 120]
const CHARGE := [0.0, 0.0, 0.04, 0.2, 0.4]
## Acciones perfectas seguidas necesarias para cada multiplicador.
const COMBO_STEPS := [[20, 5.0], [12, 4.0], [8, 3.0], [5, 2.0], [3, 1.5]]
const RANK_NAMES := ["D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_TITLES := ["SUPERVIVIENTE", "AVENTURERO", "COMBATIENTE", "EXPERTO", "MAESTRO", "ÉLITE", "LEGENDARIO"]
const RANK_SCORES := [0.0, 26.0, 42.0, 56.0, 70.0, 82.0, 92.0]


## Categoria segun el margen `slack` (segundos). `scale` ensancha o estrecha
## las ventanas (cada mundo de la campana usa la suya).
static func rate(slack: float, scale: float = 1.0) -> int:
	if slack < 0.0:
		return Rating.NONE
	if slack <= LEGENDARY_WINDOW * scale:
		return Rating.LEGENDARY
	if slack <= PERFECT_WINDOW * scale:
		return Rating.PERFECT
	if slack <= GOOD_WINDOW * scale:
		return Rating.GOOD
	if slack <= MAX_WINDOW:
		return Rating.NORMAL
	return Rating.NONE


## Multiplicador de valentia segun las acciones perfectas consecutivas.
static func combo_multiplier(perfects: int) -> float:
	for item in COMBO_STEPS:
		var step: Array = item
		if perfects >= int(step[0]):
			return float(step[1])
	return 1.0


## Rango (0 = D ... 6 = SSS) a partir de una nota de 0 a 100.
static func rank_for(score: float) -> int:
	var rank: int = 0
	for i in RANK_SCORES.size():
		if score >= float(RANK_SCORES[i]):
			rank = i
	return rank
