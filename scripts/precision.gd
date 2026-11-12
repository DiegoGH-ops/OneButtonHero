extends Node
## Arbitro del timing durante la partida. Evalua saltos, ataques y esquivas
## (timing.gd), mantiene el combo de precision ("courage multiplier"), la
## carga de Soul Reaper y las estadisticas con las que se calcula el rango.

signal rated(rating: int, label: String, pos: Vector2)

const Timing = preload("res://scripts/timing.gd")
const Daylight = preload("res://scripts/daylight.gd")

const GROUND_Y := 560.0
const JUMP_SPEED := 930.0
const GRAVITY := 2500.0

## Ensancha (>1) o estrecha (<1) las ventanas de timing.
var window_scale: float = 1.0
## Acciones perfectas consecutivas.
var perfects: int = 0
var best_combo: int = 0
## Carga de Soul Reaper (0..1).
var soul: float = 0.0
## Recuento para el rango: [ninguna, normal, good, perfect, legendary].
var counts: Array = [0, 0, 0, 0, 0]
## Ultima accion evaluada (para las herramientas de depuracion).
var last_slack: float = 0.0
var last_rating: int = 0

var _pending: Array = []
var _attack_rating: int = 0
var _attack_timer: float = 0.0


func multiplier() -> float:
	return Timing.combo_multiplier(perfects)


## Salto: se mide el margen respecto al ultimo instante en que aun se
## supera el peligro mas cercano. Se premia al pasarlo sin dano.
func on_jump(pos: Vector2, speed: float) -> void:
	var best_left: float = INF
	var danger: Vector3 = Vector3.ZERO
	var is_hole: bool = false
	for node in get_tree().get_nodes_in_group("hazards"):
		if not node.has_method("get_danger"):
			continue
		var d: Vector3 = node.call("get_danger")
		if d.y > pos.x - 4.0 and d.x < best_left:
			best_left = d.x
			danger = d
			is_hole = false
	for item in Daylight.holes:
		var hole: Vector2 = item
		if hole.y > pos.x and hole.x < best_left:
			best_left = hole.x
			danger = Vector3(hole.x, hole.y, 0.0)
			is_hole = true
	if best_left == INF:
		return
	var slack: float = 0.0
	if is_hole:
		# En un hueco el ultimo instante es el propio borde.
		slack = maxf((danger.x - pos.x) / maxf(speed, 1.0), 0.0)
	else:
		# Tiempo que tarda el salto en superar la altura del obstaculo.
		var need: float = danger.z + 6.0
		var disc: float = JUMP_SPEED * JUMP_SPEED - 2.0 * GRAVITY * need
		var rise: float = 0.2
		if disc > 0.0:
			rise = (JUMP_SPEED - sqrt(disc)) / GRAVITY
		slack = (danger.x - (pos.x + 10.0)) / maxf(speed, 1.0) - rise
	last_slack = slack
	var rating: int = Timing.rate(slack, window_scale)
	last_rating = rating
	if rating == Timing.Rating.NONE:
		return
	_pending.append({"left": danger.x, "right": danger.y, "height": danger.z, "rating": rating, "hole": is_hole, "clear": 999.0})


## Ataque: cuanto mas cerca esta el enemigo al pulsar, mejor categoria.
## Devuelve la categoria; se confirma si el golpe acierta (consume_attack).
func on_attack(pos: Vector2, speed: float) -> int:
	var gap: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null:
			continue
		var dx: float = enemy.global_position.x - 18.0 - (pos.x + 10.0)
		if dx > -40.0 and dx < gap:
			gap = dx
	if gap == INF:
		_attack_rating = Timing.Rating.NONE
		return _attack_rating
	last_slack = maxf(gap, 0.0) / maxf(speed, 1.0)
	_attack_rating = Timing.rate(last_slack * 0.65, window_scale)
	last_rating = _attack_rating
	_attack_timer = 0.4
	return _attack_rating


## Categoria del ataque en curso (y la borra). NONE si no habia ninguno.
func consume_attack() -> int:
	var rating: int = _attack_rating if _attack_timer > 0.0 else Timing.Rating.NONE
	_attack_rating = Timing.Rating.NONE
	return rating


## Llamar cada fotograma con la posicion del heroe.
func update(pos: Vector2, delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var feet_height: float = GROUND_Y - pos.y
	for i in range(_pending.size() - 1, -1, -1):
		var entry: Dictionary = _pending[i]
		var left: float = entry["left"]
		var right: float = entry["right"]
		# Holgura minima con la que se sobrevuela el obstaculo (esquiva).
		if not bool(entry["hole"]) and pos.x > left - 12.0 and pos.x < right + 12.0:
			entry["clear"] = minf(float(entry["clear"]), feet_height - 4.0 - float(entry["height"]))
		if pos.x > right + 14.0:
			_pending.remove_at(i)
			_resolve(entry, pos)


func _resolve(entry: Dictionary, pos: Vector2) -> void:
	var rating: int = entry["rating"]
	var label: String = Timing.NAMES[rating]
	var clear: float = entry["clear"]
	# Esquiva perfecta: se paso rozando el peligro.
	if not bool(entry["hole"]) and clear < 12.0:
		if rating < Timing.Rating.PERFECT:
			rating = Timing.Rating.PERFECT
			label = "ESQUIVA PERFECTA"
		if clear < 5.0:
			rating = Timing.Rating.LEGENDARY
	if rating == Timing.Rating.LEGENDARY:
		label = "LAST SECOND"
	register(rating, label, pos)


## Anota una accion evaluada: combo, carga de Soul Reaper y aviso.
func register(rating: int, label: String, pos: Vector2) -> void:
	counts[rating] = int(counts[rating]) + 1
	if rating >= Timing.Rating.PERFECT:
		perfects += 2 if rating == Timing.Rating.LEGENDARY else 1
		best_combo = maxi(best_combo, perfects)
	soul = minf(soul + float(Timing.CHARGE[rating]), 1.0)
	if rating >= Timing.Rating.GOOD:
		rated.emit(rating, label, pos)


## Al recibir dano se pierde el combo y lo que estuviera pendiente.
func on_damage() -> void:
	perfects = 0
	_pending.clear()
	_attack_rating = Timing.Rating.NONE


## Acciones evaluadas en total.
func actions() -> int:
	return int(counts[1]) + int(counts[2]) + int(counts[3]) + int(counts[4])


## Nota de 0 a 100: precision, golpes legendarios, combo maximo y dano.
## Sobrevivir sin arriesgar da una nota baja.
func grade(damage_taken: int) -> float:
	var total: float = float(maxi(actions(), 1))
	var precise: float = float(int(counts[3]) + int(counts[4])) / total
	var legendary: float = minf(float(int(counts[4])) / total * 3.0, 1.0)
	var combo: float = minf(float(best_combo) / 20.0, 1.0)
	var safety: float = [20.0, 12.0, 5.0, 0.0][mini(damage_taken, 3)]
	return precise * 45.0 + legendary * 15.0 + combo * 20.0 + safety
