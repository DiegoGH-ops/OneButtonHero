extends RefCounted
## Estado global del ciclo de dia y noche y de la partida en curso.
## `time` avanza de 0 a 1 de forma continua:
##   0.00 amanecer · 0.12 manana · 0.32 mediodia · 0.52 atardecer · 0.68 noche
## Todos los elementos visuales consultan estas funciones para adaptar
## cielo, luz ambiental, sombras y resplandores.

const Pal = preload("res://scripts/palette.gd")

enum Phase { DAWN, MORNING, NOON, SUNSET, NIGHT }

const PHASE_NAMES := ["AMANECER", "MAÑANA", "MEDIODÍA", "ATARDECER", "NOCHE"]
const PHASE_STARTS := [0.0, 0.12, 0.32, 0.52, 0.68]
## Fraccion del ciclo en la que el sol esta sobre el horizonte.
const SUN_SPAN := 0.70
const GROUND_Y := 560.0

static var time: float = 0.2
## Huecos del nivel (misma lista que usa el generador).
static var holes: Array = []
## Datos de la partida que consultan monedas y efectos.
static var player_pos: Vector2 = Vector2.ZERO
static var magnet_radius: float = 0.0
static var run_speed: float = 340.0
## Aspecto del mundo actual (ver campaign.gd). Vacio = bosque por defecto.
static var theme: Dictionary = {}
## Tramos de hielo (Frostfall) como Vector2(inicio, fin).
static var ice: Array = []
## Modificadores de las mejoras para las criaturas (ver creature.gd).
static var warn_factor: float = 1.0
static var mash_factor: float = 1.0
static var counter_factor: float = 1.0
## Perseguidores esquivados desde el ultimo fotograma (lo lee game.gd).
static var dodges: int = 0


static func phase() -> int:
	var t: float = fposmod(time, 1.0)
	var result: int = Phase.DAWN
	for i in PHASE_STARTS.size():
		var start: float = PHASE_STARTS[i]
		if t >= start:
			result = i
	return result


static func phase_name() -> String:
	return PHASE_NAMES[phase()]


## 0 = pleno dia, 1 = noche cerrada (con transiciones suaves).
static func darkness() -> float:
	var t: float = fposmod(time, 1.0)
	if t < 0.08:
		return 1.0 - smoothstep(0.0, 0.08, t)
	if t < 0.58:
		return 0.0
	if t < 0.74:
		return smoothstep(0.58, 0.74, t)
	return 1.0


## Calidez del atardecer / amanecer (0..1).
static func warmth() -> float:
	var t: float = fposmod(time, 1.0)
	var dawn: float = 1.0 - clampf(absf(t - 0.04) / 0.10, 0.0, 1.0)
	var dusk: float = 1.0 - clampf(absf(t - 0.60) / 0.12, 0.0, 1.0)
	return maxf(dawn, dusk)


## Luz ambiental con la que se tine el mundo.
static func ambient() -> Color:
	var day: Color = Color(1.0, 1.0, 1.0)
	var warm: Color = Color(1.0, 0.74, 0.58)
	var night: Color = Color(0.60, 0.64, 0.95)
	return (day.lerp(warm, warmth() * 0.8).lerp(night, darkness())) * theme_color("ambient", Color(1.0, 1.0, 1.0))


## Posicion del sol en pantalla (1280x720). Sale por la izquierda.
static func sun_position() -> Vector2:
	var s: float = fposmod(time, 1.0) / SUN_SPAN
	return Vector2(lerpf(60.0, 1220.0, s), 610.0 - sin(s * PI) * 500.0)


static func sun_visible() -> bool:
	return fposmod(time, 1.0) < SUN_SPAN


static func moon_position() -> Vector2:
	var m: float = clampf((fposmod(time, 1.0) - 0.64) / 0.40, 0.0, 1.0)
	return Vector2(lerpf(80.0, 1200.0, m), 600.0 - sin(m * PI) * 470.0)


## Inclinacion de las sombras: largas al amanecer y al atardecer.
static func shadow_skew() -> float:
	var t: float = fposmod(time, 1.0)
	if t < SUN_SPAN:
		return clampf((0.5 - t / SUN_SPAN) * 3.2, -1.6, 1.6)
	var m: float = clampf((t - 0.64) / 0.40, 0.0, 1.0)
	return clampf((0.5 - m) * 2.0, -1.0, 1.0)


## Modulacion que anula la luz ambiental: la usan los objetos que brillan
## con luz propia (monedas, llamas, espectros) para no oscurecerse de noche.
static func unlit() -> Color:
	var amb: Color = ambient()
	return Color(1.0 / maxf(amb.r, 0.2), 1.0 / maxf(amb.g, 0.2), 1.0 / maxf(amb.b, 0.2))


static func shadow_alpha() -> float:
	return lerpf(0.26, 0.10, darkness())


## De noche los puntos valen mas.
static func score_multiplier() -> float:
	return 1.5 if darkness() > 0.6 else 1.0


## Color del tema actual (hex) o `fallback` si el tema no lo define.
static func theme_color(key: String, fallback: Color) -> Color:
	if theme.has(key):
		return Color(String(theme[key]))
	return fallback


static func is_ice(x: float) -> bool:
	for item in ice:
		var span: Vector2 = item
		if x > span.x and x < span.y:
			return true
	return false


static func is_ground(x: float) -> bool:
	for item in holes:
		var hole: Vector2 = item
		if x > hole.x and x < hole.y:
			return false
	return true
