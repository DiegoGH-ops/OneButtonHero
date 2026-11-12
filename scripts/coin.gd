extends Area2D
## Objeto recogible: moneda, gema, rubi, corazon (vida), estrella (poder
## temporal) o cofre. Gira, flota y, si hay iman, vuela hacia el heroe.

const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")

enum Kind { COIN, GEM, RUBY, HEART, STAR, CHEST }

const VALUES := [10, 50, 25, 0, 0, 0]
const SPIN_FRAMES := ["coin_0", "coin_1", "coin_2", "coin_1"]
const RUBY_REMAP := {"y": "r", "o": "p", "w": "o"}

var kind: int = Kind.COIN
var value: int = 10
var collected: bool = false

## Datos para lights.gd (resplandor).
var glow_radius: float = 30.0
var glow_color: Color = Pal.YELLOW
var glow_day: float = 0.0

var _time: float = 0.0
var _pulled: bool = false


func _ready() -> void:
	add_to_group("coins")
	add_to_group("glow")
	# Desfase segun la posicion: las filas de monedas ondulan como una ola.
	_time = absf(position.x) * 0.012


func setup(p_kind: int) -> void:
	kind = clampi(p_kind, 0, VALUES.size() - 1)
	value = VALUES[kind]
	match kind:
		Kind.GEM:
			glow_radius = 46.0
			glow_color = Pal.CYAN
			glow_day = 0.25
		Kind.RUBY:
			glow_radius = 38.0
			glow_color = Pal.RED
			glow_day = 0.15
		Kind.HEART:
			glow_radius = 50.0
			glow_color = Pal.RED
			glow_day = 0.3
		Kind.STAR:
			glow_radius = 60.0
			glow_color = Pal.YELLOW
			glow_day = 0.4
		Kind.CHEST:
			glow_radius = 54.0
			glow_color = Pal.YELLOW
			glow_day = 0.2
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	modulate = Daylight.unlit()
	# Iman: las monedas cercanas vuelan hacia el heroe.
	if kind <= Kind.RUBY and Daylight.magnet_radius > 0.0:
		var to_hero: Vector2 = Daylight.player_pos + Vector2(0.0, -28.0) - global_position
		var dist: float = to_hero.length()
		if _pulled or dist < Daylight.magnet_radius:
			_pulled = true
			if dist > 1.0:
				global_position += to_hero / dist * minf(dist, (Daylight.run_speed + 560.0) * delta)
	queue_redraw()


## Marca el objeto como recogido y lo elimina.
func collect() -> void:
	if collected:
		return
	collected = true
	set_deferred("monitorable", false)
	queue_free()


func _draw() -> void:
	var bob: float = roundf(sin(_time * 4.0) * 4.0)
	match kind:
		Kind.GEM:
			PixelArt.draw(self, "gem", Vector2(-20.0, -18.0 + bob), 4.0)
			for i in 3:
				var angle: float = _time * 2.5 + float(i) * TAU / 3.0
				var p: Vector2 = Vector2(cos(angle), sin(angle)) * 28.0 + Vector2(0.0, bob)
				draw_rect(Rect2(snappedf(p.x, 4.0) - 2.0, snappedf(p.y, 4.0) - 2.0, 4.0, 4.0), Pal.WHITE)
		Kind.HEART:
			var beat: float = 1.0 + 0.08 * sin(_time * 8.0)
			draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(beat, beat))
			PixelArt.draw(self, "heart", Vector2(-18.0, -16.0), 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Kind.STAR:
			draw_set_transform(Vector2(0.0, bob), sin(_time * 3.0) * 0.25, Vector2.ONE)
			PixelArt.draw(self, "star", Vector2(-18.0, -18.0), 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Kind.CHEST:
			PixelArt.draw_shadow(self, "chest", Vector2(0.0, 0.0), 4.0, Daylight.shadow_skew(), Daylight.shadow_alpha())
			PixelArt.draw(self, "chest", Vector2(-24.0, -36.0), 4.0)
		_:
			var frame: int = int(_time * 8.0) % 4
			var sprite: String = SPIN_FRAMES[frame]
			if kind == Kind.RUBY:
				PixelArt.draw_skin(self, sprite, Vector2(-16.0, -16.0 + bob), 4.0, Color(1.0, 1.0, 1.0, 1.0), RUBY_REMAP, "ruby")
			else:
				PixelArt.draw(self, sprite, Vector2(-16.0, -16.0 + bob), 4.0)
