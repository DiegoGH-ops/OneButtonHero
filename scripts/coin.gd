extends Area2D
## Moneda (10 puntos) o gema especial (50 puntos). Gira y flota por codigo.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

const SPIN_FRAMES := ["coin_0", "coin_1", "coin_2", "coin_1"]

var special: bool = false
var value: int = 10
var collected: bool = false

var _time: float = 0.0


func _ready() -> void:
	add_to_group("coins")
	# Desfase segun la posicion: las filas de monedas ondulan como una ola.
	_time = position.x * 0.012


func setup(p_special: bool) -> void:
	special = p_special
	value = 50 if special else 10
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Marca la moneda como recogida y la elimina.
func collect() -> void:
	if collected:
		return
	collected = true
	set_deferred("monitorable", false)
	queue_free()


func _draw() -> void:
	var bob: float = roundf(sin(_time * 4.0) * 4.0)
	if special:
		PixelArt.draw(self, "gem", Vector2(-20.0, -18.0 + bob), 4.0)
		# Destellos alrededor de la gema.
		for i in 3:
			var angle: float = _time * 2.5 + float(i) * TAU / 3.0
			var p: Vector2 = Vector2(cos(angle), sin(angle)) * 28.0 + Vector2(0.0, bob)
			draw_rect(Rect2(snappedf(p.x, 4.0) - 2.0, snappedf(p.y, 4.0) - 2.0, 4.0, 4.0), Pal.WHITE)
	else:
		var frame: int = int(_time * 8.0) % 4
		var sprite: String = SPIN_FRAMES[frame]
		PixelArt.draw(self, sprite, Vector2(-16.0, -16.0 + bob), 4.0)
