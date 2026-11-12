extends Node2D
## Meta de un nivel de campana: una bandera a cuadros que ondea y brilla.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

var glow_radius: float = 120.0
var glow_color: Color = Pal.YELLOW
var glow_day: float = 0.5

var _time: float = 0.0


func _ready() -> void:
	add_to_group("glow")


func _process(delta: float) -> void:
	_time += delta
	modulate = Daylight.unlit()
	queue_redraw()


func _draw() -> void:
	var wave: float = roundf(sin(_time * 5.0) * 3.0)
	PixelArt.draw(self, "goal_flag", Vector2(-8.0, -224.0 + wave), 8.0)
	draw_rect(Rect2(-8.0, -224.0, 16.0, 224.0), Pal.INK)
	draw_rect(Rect2(-4.0, -220.0, 8.0, 220.0), Pal.SILVER)
	for i in 6:
		var a: float = _time * 2.0 + float(i) * TAU / 6.0
		var p: Vector2 = Vector2(cos(a) * 60.0, -110.0 + sin(a) * 90.0)
		draw_rect(Rect2(snappedf(p.x, 4.0), snappedf(p.y, 4.0), 8.0, 8.0), Color(Pal.YELLOW, 0.8))
