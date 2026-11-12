extends Area2D
## Punto debil de un jefe. Solo es golpeable mientras el jefe esta
## vulnerable; avisa al jefe de cada golpe recibido.

var kind: int = 5
var boss: Node


func hit() -> int:
	if boss != null and boss.has_method("on_core_hit"):
		boss.call("on_core_hit")
	return 0
