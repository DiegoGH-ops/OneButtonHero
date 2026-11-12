extends Button
## Boton de velocidad 2X de la partida (esquina superior derecha).
## Pequeno y discreto: icono de velocidad (doble flecha) e indicador "2X".
## Encendido cambia de color, brilla y sus flechas se mueven; al pulsarlo
## lanza una onda. Desactivado (modo infinito y jefes) se ve apagado con un
## candado y no responde.

signal turbo_changed(on: bool)

const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const Pal = preload("res://scripts/palette.gd")

var on: bool = false
var available: bool = true

var _time: float = 0.0
var _pulse: float = 0.0
var _hover: float = 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style_name, empty)


func _ready() -> void:
	pressed.connect(_on_pressed)


func set_state(is_on: bool, is_available: bool) -> void:
	on = is_on and is_available
	available = is_available
	disabled = not is_available
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	queue_redraw()


func _on_pressed() -> void:
	if not available:
		Sfx.play("error")
		return
	on = not on
	_pulse = 1.0
	Sfx.play("upgrade" if on else "click", 1.3 if on else 1.0)
	turbo_changed.emit(on)


func _process(delta: float) -> void:
	# Tiempo real: no le afecta la velocidad del juego.
	var real: float = delta / maxf(Engine.time_scale, 0.05)
	_time += real
	_pulse = maxf(_pulse - real * 2.5, 0.0)
	_hover = move_toward(_hover, 1.0 if is_hovered() and available else 0.0, real * 9.0)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var accent: Color = Pal.ORANGE if on else Pal.STEEL
	if not available:
		accent = Pal.SLATE
	if on:
		PixelArt.draw_glow(self, Vector2(w * 0.5, h * 0.5), w * 0.9, Color(Pal.ORANGE, 0.35 + 0.15 * sin(_time * 6.0)))
	# Onda de activacion.
	if _pulse > 0.0:
		var grow: float = (1.0 - _pulse) * 22.0
		draw_rect(Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0), Color(Pal.YELLOW, _pulse * 0.6), false, 3.0)
	var lift: float = -2.0 * _hover
	draw_rect(Rect2(2.0, 4.0, w - 2.0, h - 4.0), Color(0.0, 0.0, 0.0, 0.4))
	draw_rect(Rect2(0.0, lift, w, h - 4.0), Pal.INK)
	draw_rect(Rect2(3.0, 3.0 + lift, w - 6.0, h - 10.0), accent.darkened(0.45) if not on else accent.darkened(0.15))
	draw_rect(Rect2(3.0, 3.0 + lift, w - 6.0, 3.0), accent.lightened(0.3))
	# Icono: doble flecha que corre cuando el modo esta activo.
	var shift: float = fposmod(_time * 30.0, 6.0) if on else 0.0
	var icon_color: Color = Pal.WHITE if available else Pal.SILVER
	for k in 2:
		var x0: float = 10.0 + float(k) * 10.0 + shift
		for row in 5:
			var dx: float = float(2 - absi(row - 2)) * 3.0
			draw_rect(Rect2(x0 + dx, 12.0 + float(row) * 4.0 + lift, 4.0, 4.0), icon_color)
	var label: String = "2X"
	PixelFont.draw_text_shadowed(self, label, Vector2(w - PixelFont.text_width(label, 3.0) - 10.0, 13.0 + lift), 3.0, Pal.YELLOW if on else icon_color, Pal.INK)
	if not available:
		# Candado: no disponible en este modo.
		draw_rect(Rect2(w - 16.0, h - 18.0, 10.0, 8.0), Pal.SILVER)
		draw_rect(Rect2(w - 14.0, h - 23.0, 6.0, 5.0), Color(0.0, 0.0, 0.0, 0.0))
		draw_rect(Rect2(w - 15.0, h - 24.0, 2.0, 6.0), Pal.SILVER)
		draw_rect(Rect2(w - 9.0, h - 24.0, 2.0, 6.0), Pal.SILVER)
	elif on:
		var bar: float = 0.5 + 0.5 * sin(_time * 8.0)
		draw_rect(Rect2(6.0, h - 9.0 + lift, (w - 12.0) * bar, 3.0), Pal.YELLOW)
