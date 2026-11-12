extends RefCounted
## Suma de todos los buffs activos: cosmeticos EQUIPADOS, power-ups activos y
## nodos del arbol de mejoras. Solo cuenta lo equipado: al cambiar de
## cosmetico el buff anterior desaparece automaticamente.
##
##   Buffs.stat("reach")   -> porcentaje / valor acumulado
##   Buffs.factor("coins") -> 1 + porcentaje / 100

const Catalog = preload("res://scripts/catalog.gd")

## Como se muestra cada stat: [texto, unidad]. Unidad "%", "MS", "PX" o "".
const STATS := {
	"reach": ["ALCANCE DE ATAQUE", "%"],
	"points": ["PUNTOS", "%"],
	"coins": ["MONEDAS", "%"],
	"gems": ["PROBABILIDAD DE GEMAS", "%"],
	"magnet": ["RADIO DEL IMÁN", "PX"],
	"jump_cut": ["CONTROL DEL SALTO CORTO", "%"],
	"jump_height": ["ALTURA MÁXIMA DE SALTO", "%"],
	"good": ["VENTANA GOOD", "%"],
	"perfect": ["VENTANA PERFECT", "%"],
	"legend": ["VENTANA LEGENDARY", "%"],
	"land": ["VENTANA DE ATERRIZAJE", "%"],
	"coyote": ["MARGEN AL DEJAR UN BORDE", "MS"],
	"buffer": ["MARGEN DE PULSACIÓN ANTICIPADA", "MS"],
	"ice_grip": ["AGARRE EN HIELO", "%"],
	"mash": ["FUERZA DE PULSACIÓN", "%"],
	"warn": ["TIEMPO DE AVISO", "%"],
	"combo_points": ["PUNTOS DE COMBO", "%"],
	"jump_points": ["PUNTOS POR SALTO PERFECTO", "%"],
	"attack_points": ["PUNTOS POR ATAQUE PERFECTO", "%"],
	"chain": ["PREMIO DE CADENA", "%"],
	"stomp": ["RADIO DEL PISOTÓN", "PX"],
	"bounty": ["MONEDAS POR ENEMIGO", ""],
	"combo_coins": ["MONEDAS POR ACCIÓN PERFECTA", ""],
	"counter": ["VENTANA DEL CONTRAGOLPE", "%"],
	"hitbox": ["CUERPO MÁS ESTRECHO", "PX"],
	"ledge": ["AGARRE DE BORDE", "PX"],
	"quick_retry": ["REINTENTO RÁPIDO", ""],
	"diamond_sense": ["DIAMANTE OCULTO GARANTIZADO", ""],
	"phoenix": ["SOBREVIVE A UN GOLPE", ""],
	"hawk": ["MARCA DE SALTO PERFECT", ""],
	"daredevil": ["ESPECIALIZACIÓN TEMERARIO", ""],
	"methodical": ["ESPECIALIZACIÓN METÓDICO", ""],
	"fury": ["ESPECIALIZACIÓN FURIA", ""],
	"zen": ["ESPECIALIZACIÓN SERENIDAD", ""],
}

static var _cache: Dictionary = {}
static var _dirty: bool = true


## Llamar cuando cambie algo equipado o comprado.
static func invalidate() -> void:
	_dirty = true


static func _add(target: Dictionary, buff: Dictionary, times: float) -> void:
	for key in buff:
		target[key] = float(target.get(key, 0.0)) + float(buff[key]) * times


static func _rebuild() -> void:
	_cache = {}
	for slot in ["skin", "sword", "trail", "aura"]:
		var item: Dictionary = GameData.equipped_item(String(slot))
		_add(_cache, item.get("buff", {}), 1.0)
	for item in Catalog.POWERUPS:
		var entry: Dictionary = item
		if GameData.is_powerup_active(String(entry["id"])):
			_add(_cache, entry["buff"], 1.0)
	for item in Catalog.TREE:
		var node: Dictionary = item
		var level: int = GameData.node_level(String(node["id"]))
		if level > 0:
			_add(_cache, node["buff"], float(level))
	_dirty = false


static func stat(name: String) -> float:
	if _dirty:
		_rebuild()
	return float(_cache.get(name, 0.0))


static func factor(name: String) -> float:
	return maxf(1.0 + stat(name) / 100.0, 0.05)


static func has(name: String) -> bool:
	return stat(name) > 0.0


## Texto de un buff: "ALCANCE DE ATAQUE +2.5%".
static func describe(buff: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in buff:
		var info: Array = STATS.get(String(key), [String(key), ""])
		var value: float = float(buff[key])
		var unit: String = info[1]
		if unit == "":
			if value == 1.0 and String(key) != "bounty" and String(key) != "combo_coins":
				parts.append(String(info[0]))
			else:
				parts.append("%s +%d" % [String(info[0]), int(value)])
			continue
		var prefix: String = "+" if value >= 0.0 else ""
		var number: String = str(snappedf(value, 0.1)).trim_suffix(".0")
		parts.append("%s %s%s%s" % [String(info[0]), prefix, number, unit])
	return ", ".join(parts)
