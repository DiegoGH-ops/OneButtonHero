extends Button
## Boton de un poder activable (Turbo, Onda, Tiempo). Muestra el icono, la
## tecla asociada y la recarga como un velo que se va vaciando.

const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

var icon_sprite: String = "icon_bolt"
var key_label: String = "1"
var power_name: String = ""
## 0 = listo, 1 = recien usado.
var cooldown: float = 0.0:
	set(value):
		if not is_equal_approx(cooldown, value):
			cooldown = value
			queue_redraw()
## El poder esta en marcha.
var running: bool = false:
	set(value):
		if running != value:
			running = value
			queue_redraw()

var _time: float = 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)


func _process(delta: float) -> void:
	_time += delta
	if running or (cooldown <= 0.0 and is_hovered()):
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var is_ready: bool = cooldown <= 0.0 and not running
	var border: Color = Pal.INK
	if running:
		border = Pal.YELLOW if int(_time * 8.0) % 2 == 0 else Pal.ORANGE
	elif is_ready:
		border = Pal.LIME
	draw_rect(Rect2(0.0, 6.0, w, h - 6.0), Pal.INK)
	var lift: float = 0.0 if not is_ready else (-4.0 if is_hovered() else 0.0)
	draw_rect(Rect2(0.0, lift, w, h - 6.0), border)
	var fill: Color = Pal.BLUE if is_ready else Pal.SLATE
	if running:
		fill = Pal.TEAL
	draw_rect(Rect2(4.0, lift + 4.0, w - 8.0, h - 14.0), fill)
	draw_rect(Rect2(4.0, lift + 4.0, w - 8.0, 4.0), fill.lightened(0.3))
	var sz: Vector2 = PixelArt.size_of(icon_sprite, 5.0)
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0) if is_ready or running else Color(0.55, 0.55, 0.65, 1.0)
	PixelArt.draw(self, icon_sprite, Vector2(roundf((w - sz.x) * 0.5), lift + 10.0), 5.0, tint)
	# Velo de recarga: se vacia de arriba abajo.
	if cooldown > 0.0 and not running:
		var inner: float = h - 14.0
		draw_rect(Rect2(4.0, lift + 4.0, w - 8.0, inner * clampf(cooldown, 0.0, 1.0)), Color(Pal.INK, 0.6))
	PixelFont.draw_text_shadowed(self, key_label, Vector2(8.0, lift + h - 30.0), 2.0, Pal.YELLOW, Pal.INK, true)
	var name_w: float = PixelFont.text_width(power_name, 2.0)
	PixelFont.draw_text_shadowed(self, power_name, Vector2(roundf((w - name_w) * 0.5), h + 2.0), 2.0, Pal.WHITE, Pal.INK, true)
