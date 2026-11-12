extends RefCounted
## Suma de todos los buffs activos: cosmeticos EQUIPADOS, power-ups activos y
## nodos del arbol de mejoras. Solo cuenta lo equipado: al cambiar de
## cosmetico el buff anterior desaparece automaticamente.
##
##   Buffs.stat("reach")   -> porcentaje / valor acumulado
##   Buffs.factor("coins") -> 1 + porcentaje / 100
##
## Las mejoras de "afinidad" potencian el buff del cosmetico equipado en su
## ranura (por ejemplo, +25% al buff de la espada).

const Catalog = preload("res://scripts/catalog.gd")

## Como se muestra cada stat: [texto, unidad]. Unidad "%", "MS", "PX", "S",
## "+" (numero) o "" (interruptor: solo el nombre).
const STATS := {
	"reach": ["ALCANCE DE ATAQUE", "%"],
	"vreach": ["ALCANCE VERTICAL DEL TAJO", "%"],
	"points": ["PUNTOS", "%"],
	"coins": ["MONEDAS", "%"],
	"gems": ["PROBABILIDAD DE GEMAS", "%"],
	"magnet": ["RADIO DEL IMÁN", "PX"],
	"jump_cut": ["CONTROL DEL SALTO CORTO", "%"],
	"jump_height": ["ALTURA MÁXIMA DE SALTO", "%"],
	"glide": ["CAÍDA MÁS LENTA AL MANTENER", "%"],
	"hang": ["SUSPENSIÓN EN LO ALTO", "%"],
	"bounce": ["FUERZA DEL SUPER REBOTE", "%"],
	"stomp_bounce": ["REBOTE TRAS PISOTÓN", "%"],
	"run_speed": ["VELOCIDAD DE CARRERA", "%"],
	"good": ["VENTANA GOOD", "%"],
	"perfect": ["VENTANA PERFECT", "%"],
	"legend": ["VENTANA LEGENDARY", "%"],
	"land": ["VENTANA DE ATERRIZAJE", "%"],
	"coyote": ["MARGEN AL DEJAR UN BORDE", "MS"],
	"buffer": ["MARGEN DE PULSACIÓN ANTICIPADA", "MS"],
	"ice_grip": ["AGARRE EN HIELO", "%"],
	"mash": ["FUERZA DE PULSACIÓN", "%"],
	"crit": ["PROB. DE GOLPE DOBLE A ACORAZADOS", "%"],
	"warn": ["TIEMPO DE AVISO", "%"],
	"combo_start": ["COMBO INICIAL", "+"],
	"combo_points": ["PUNTOS DE COMBO", "%"],
	"jump_points": ["PUNTOS POR SALTO PERFECTO", "%"],
	"attack_points": ["PUNTOS POR ATAQUE PERFECTO", "%"],
	"legend_points": ["PUNTOS POR ACCIÓN LEGENDARY", "%"],
	"stomp_points": ["PUNTOS POR PISOTÓN", "%"],
	"bounce_points": ["PUNTOS POR SUPER REBOTE", "%"],
	"land_points": ["PUNTOS POR ATERRIZAJE", "%"],
	"dodge_points": ["PUNTOS POR ESQUIVA", "%"],
	"reflect_points": ["PUNTOS POR PROYECTIL CORTADO", "%"],
	"chain": ["PREMIO DE CADENA", "%"],
	"slowmo": ["TIEMPO BALA EN LEGENDARY", "+"],
	"rank_bonus": ["NOTA DE RANGO", "+"],
	"stomp": ["RADIO DEL PISOTÓN", "PX"],
	"bounty": ["MONEDAS POR ENEMIGO", "+"],
	"combo_coins": ["MONEDAS POR ACCIÓN PERFECTA", "+"],
	"reflect_coins": ["MONEDAS POR PROYECTIL CORTADO", "+"],
	"counter": ["VENTANA DEL CONTRAGOLPE", "%"],
	"shield_break": ["ROMPEESCUDOS", "+"],
	"boss_damage": ["PROB. DE DAÑO EXTRA AL JEFE", "%"],
	"boss_reflect": ["DEVUELVE ORBES CON GOOD", ""],
	"sword_affinity": ["POTENCIA DE LA ESPADA EQUIPADA", "%"],
	"skin_affinity": ["POTENCIA DEL HÉROE EQUIPADO", "%"],
	"trail_affinity": ["POTENCIA DE LA ESTELA EQUIPADA", "%"],
	"aura_affinity": ["POTENCIA DEL AURA EQUIPADA", "%"],
	"hitbox": ["CUERPO MÁS ESTRECHO", "PX"],
	"ledge": ["AGARRE DE BORDE", "PX"],
	"hole_sight": ["AVISO EN EL BORDE DE LOS HUECOS", ""],
	"storm_clear": ["VISIBILIDAD EN TORMENTAS", "%"],
	"projectile_slow": ["PROYECTILES MÁS LENTOS", "%"],
	"chaser_slow": ["PERSEGUIDORES MÁS LENTOS", "%"],
	"brute_slow": ["BRUTOS MÁS LENTOS", "%"],
	"no_split": ["LOS DIVISIBLES NO SE DIVIDEN", ""],
	"quick_retry": ["REINTENTO RÁPIDO", ""],
	"diamond_sense": ["DIAMANTE OCULTO GARANTIZADO", ""],
	"phoenix": ["SOBREVIVE A UN GOLPE", ""],
	"hawk": ["MARCA DE SALTO PERFECT", ""],
	"interest": ["INTERÉS DE TUS AHORROS", "%"],
	"level_coins": ["MONEDAS AL SUPERAR NIVELES", "%"],
	"replay": ["PAGA EN MUNDOS YA SUPERADOS", "%"],
	"world_coins": ["MONEDAS POR MUNDO CONQUISTADO", "%"],
	"boss_coins": ["BOTÍN DE JEFES", "%"],
	"chest": ["MONEDAS DE COFRES", "%"],
	"gem_coins": ["MONEDAS POR GEMA", "+"],
	"milestone": ["PREMIO POR DISTANCIA", "%"],
	"combo_reward": ["PREMIO POR COMBOS LARGOS", "%"],
	"night_coins": ["PREMIO NOCTURNO", "%"],
	"rush": ["FIEBRE DEL ORO", "S"],
	"shards": ["FRAGMENTOS DE DIAMANTE", "+"],
	"mode_diamonds": ["PROB. DE DIAMANTE EXTRA EN MODOS", "%"],
	"diamond_discount": ["DESCUENTO EN DIAMANTES", "%"],
	"boss_diamonds": ["DIAMANTES POR JEFE", "+"],
	"star_diamonds": ["PROB. DE DIAMANTE EXTRA CON 3 ESTRELLAS", "%"],
	"challenge_coins": ["PAGA DE LOS RETOS", "%"],
	"mission": ["PAGA DE LAS MISIONES", "%"],
	"login": ["PREMIO DIARIO", "%"],
	"mode_coins": ["PAGA DE LOS MODOS", "%"],
	"achievement": ["PAGA DE LOS LOGROS", "%"],
	"star_coins": ["MONEDAS POR ESTRELLA NUEVA", "+"],
	"weekly": ["PAGA DEL DESAFÍO SEMANAL", "%"],
	"daredevil": ["ESPECIALIZACIÓN TEMERARIO", ""],
	"methodical": ["ESPECIALIZACIÓN METÓDICO", ""],
	"fury": ["ESPECIALIZACIÓN FURIA", ""],
	"zen": ["ESPECIALIZACIÓN SERENIDAD", ""],
}

const SLOT_AFFINITY := {"skin": "skin_affinity", "sword": "sword_affinity", "trail": "trail_affinity", "aura": "aura_affinity"}

static var _cache: Dictionary = {}
static var _dirty: bool = true


## Llamar cuando cambie algo equipado o comprado.
static func invalidate() -> void:
	_dirty = true


static func _add(target: Dictionary, buff: Dictionary, times: float) -> void:
	for key in buff:
		target[key] = float(target.get(key, 0.0)) + float(buff[key]) * times


static func _rebuild() -> void:
	var base: Dictionary = {}
	for item in Catalog.POWERUPS:
		var entry: Dictionary = item
		if GameData.is_powerup_active(String(entry["id"])):
			_add(base, entry["buff"], 1.0)
	for item in Catalog.TREE:
		var node: Dictionary = item
		var level: int = GameData.node_level(String(node["id"]))
		if level > 0:
			_add(base, node["buff"], float(level))
	# Los cosmeticos equipados se suman al final, potenciados por su afinidad.
	for slot in ["skin", "sword", "trail", "aura"]:
		var equipped_entry: Dictionary = GameData.equipped_item(String(slot))
		var bonus: float = float(base.get(SLOT_AFFINITY[slot], 0.0))
		_add(base, equipped_entry.get("buff", {}), 1.0 + bonus / 100.0)
	_cache = base
	_dirty = false


static func stat(name: String) -> float:
	if _dirty:
		_rebuild()
	return float(_cache.get(name, 0.0))


static func factor(name: String) -> float:
	return maxf(1.0 + stat(name) / 100.0, 0.05)


static func has(name: String) -> bool:
	return stat(name) > 0.0


## Multiplicador de afinidad de una ranura de cosmetico (1.0 = sin mejora).
static func affinity(slot: String) -> float:
	return 1.0 + stat(String(SLOT_AFFINITY.get(slot, ""))) / 100.0


## Texto de un buff: "ALCANCE DE ATAQUE +2.5%".
static func describe(buff: Dictionary, mult: float = 1.0) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in buff:
		var info: Array = STATS.get(String(key), [String(key), "+"])
		var value: float = float(buff[key]) * mult
		var unit: String = info[1]
		var label: String = Loc.s(String(info[0]))
		if unit == "":
			parts.append(label)
			continue
		var prefix: String = "+" if value >= 0.0 else ""
		var number: String = str(snappedf(value, 0.1)).trim_suffix(".0")
		if unit == "+":
			parts.append("%s %s%s" % [label, prefix, number])
		else:
			parts.append("%s %s%s%s" % [label, prefix, number, unit])
	return ", ".join(parts)
