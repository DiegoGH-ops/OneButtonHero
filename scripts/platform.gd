extends StaticBody2D
## Plataforma flotante de un solo sentido. Tres variantes:
##   normal  - siempre solida.
##   crumble - se agrieta al pisarla y cae al poco (Infernus, Solaris).
##   blink   - aparece y desaparece con un ritmo fijo (Amethystia).
## Las variantes solo se usan en la ruta arriesgada, que es opcional.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

const TILE := 32.0
const CRUMBLE_TIME := 0.55
const BLINK_PERIOD := 2.4

var width: float = 192.0
var mode: String = "normal"

var _collider: CollisionShape2D
var _time: float = 0.0
var _crumble: float = -1.0
var _solid: bool = true
var _remap: Dictionary = {}


## `position` debe ser la esquina superior izquierda de la superficie.
func setup(p_width: float, p_mode: String = "normal") -> void:
	width = maxf(p_width, TILE * 2.0)
	mode = p_mode
	collision_layer = 1
	collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width, 20.0)
	_collider = CollisionShape2D.new()
	_collider.shape = shape
	_collider.position = Vector2(width * 0.5, 10.0)
	_collider.one_way_collision = true
	_collider.one_way_collision_margin = 6.0
	add_child(_collider)
	if mode == "blink":
		_remap = {"L": "m", "G": "p", "g": "n", "d": "k"}
	elif mode == "crumble":
		_remap = {"L": "o", "G": "u", "g": "e", "d": "k"}
	set_process(mode != "normal")
	queue_redraw()


func _set_solid(value: bool) -> void:
	if _solid == value:
		return
	_solid = value
	_collider.set_deferred("disabled", not value)


func _process(delta: float) -> void:
	_time += delta
	if mode == "blink":
		# Solida el 70% del ciclo; parpadea antes de desaparecer.
		_set_solid(fposmod(_time, BLINK_PERIOD) < BLINK_PERIOD * 0.7)
	elif mode == "crumble":
		var hero: Vector2 = Daylight.player_pos
		var on_top: bool = hero.x > position.x - 10.0 and hero.x < position.x + width + 10.0 and absf(hero.y - position.y) < 6.0
		if _crumble < 0.0 and on_top:
			_crumble = 0.0
		if _crumble >= 0.0:
			_crumble += delta
			if _crumble > CRUMBLE_TIME:
				_set_solid(false)
	queue_redraw()


func _draw() -> void:
	var alpha: float = 1.0
	var offset: Vector2 = Vector2.ZERO
	if mode == "blink":
		var t: float = fposmod(_time, BLINK_PERIOD)
		if not _solid:
			alpha = 0.18
		elif t > BLINK_PERIOD * 0.55:
			alpha = 0.45 if int(_time * 14.0) % 2 == 0 else 1.0
	elif mode == "crumble" and _crumble >= 0.0:
		if _solid:
			offset = Vector2(sin(_time * 70.0) * 2.0, 0.0)
		else:
			offset = Vector2(0.0, (_crumble - CRUMBLE_TIME) * 600.0)
			alpha = clampf(1.0 - (_crumble - CRUMBLE_TIME) * 2.0, 0.0, 1.0)
	var tiles: int = int(width / TILE)
	for i in tiles:
		var sprite: String = "plat_m"
		if i == 0:
			sprite = "plat_l"
		elif i == tiles - 1:
			sprite = "plat_r"
		PixelArt.draw_skin(self, sprite, Vector2(float(i) * TILE, 0.0) + offset, 4.0, Color(1.0, 1.0, 1.0, alpha), _remap, mode)
	if mode == "crumble" and _crumble >= 0.0 and _solid:
		for k in 4:
			draw_rect(Rect2(float(k) * width / 4.0 + 12.0, 6.0, 4.0, 14.0), Pal.INK)
