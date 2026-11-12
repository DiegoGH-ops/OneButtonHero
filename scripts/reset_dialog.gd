extends Control
## Borrado de progreso con TRES confirmaciones. Nada se borra hasta pulsar el
## boton final de la tercera ventana, que solo se activa al escribir
## exactamente BORRAR TODO. Cancelar (o Escape) en cualquier paso cierra sin
## tocar nada. Para evitar accidentes:
##   - cada ventana tarda un momento en aceptar pulsaciones y su "CONTINUAR"
##     esta en otro sitio, asi un doble clic no atraviesa dos ventanas;
##   - el foco inicial esta en CANCELAR y el boton final no admite teclado,
##     de modo que Intro nunca borra;
##   - el borrado se ejecuta una sola vez aunque se pulse dos veces.
## Se conservan los ajustes (sonido, graficos, controles) y la configuracion
## y el codigo de administrador.

signal finished(deleted: bool)

const UI = preload("res://scripts/ui.gd")
const Pal = preload("res://scripts/palette.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const PixelPanel = preload("res://scripts/pixel_panel.gd")

const CONFIRM_TEXT := "BORRAR TODO"
## Tiempo que cada ventana ignora las pulsaciones al aparecer.
const ARM_TIME := 0.7

enum Step { ASK, WARN, FINAL, DONE }

var _step: int = Step.ASK
var _time: float = 0.0
var _box: Control
var _canvas: Control
var _buttons: Array = []
var _input: LineEdit
var _delete_button: PixelButton
var _deleted: bool = false
var _closing: bool = false


func _ready() -> void:
	position = Vector2.ZERO
	size = UI.SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.86)
	shade.size = UI.SCREEN
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Paneles y botones debajo; textos encima (no tapan los botones).
	_box = UI.layer(self, "Box")
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UI.layer(self, "Canvas")
	_canvas.draw.connect(_draw_step)
	_show(Step.ASK)


func _process(delta: float) -> void:
	_time += delta
	var armed: bool = _time >= ARM_TIME
	for item in _buttons:
		var b: PixelButton = item
		if is_instance_valid(b) and b != _delete_button and b.get_meta("arm", false):
			b.disabled = not armed
	if _delete_button != null and is_instance_valid(_delete_button):
		_delete_button.disabled = not (armed and _matches()) or _deleted
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _step == Step.DONE:
			_close()
		else:
			_cancel()


func _matches() -> bool:
	return _input != null and is_instance_valid(_input) and _input.text == CONFIRM_TEXT


# ------------------------------------------------------------------ pasos --

func _clear() -> void:
	for child in _box.get_children():
		child.queue_free()
	_buttons = []
	_input = null
	_delete_button = null


func _button(text: String, rect: Rect2, fill: Color, hot: Color, action: Callable, arm: bool) -> PixelButton:
	var b: PixelButton = UI.button(_box, text, rect, 3.0)
	b.fill = fill
	b.fill_hot = hot
	b.pressed.connect(action)
	b.set_meta("arm", arm)
	if arm:
		b.disabled = true
	_buttons.append(b)
	return b


func _show(step: int) -> void:
	_clear()
	_step = step
	_time = 0.0
	var cancel: PixelButton
	match step:
		Step.ASK:
			_panel(Rect2(240.0, 150.0, 800.0, 420.0), Pal.NAVY, Pal.ORANGE)
			cancel = _button("CANCELAR", Rect2(300.0, 470.0, 320.0, 64.0), Pal.GREEN, Pal.LIME, _cancel, false)
			_button("CONTINUAR", Rect2(660.0, 470.0, 320.0, 64.0), Pal.SLATE, Pal.ORANGE, _show.bind(Step.WARN), true)
			Sfx.play("error")
		Step.WARN:
			_panel(Rect2(200.0, 110.0, 880.0, 500.0), Color("3a0f18"), Pal.RED)
			# CONTINUAR cambia de lado para que un doble clic no avance dos veces.
			_button("CONTINUAR", Rect2(260.0, 520.0, 340.0, 64.0), Pal.RED.darkened(0.3), Pal.RED, _show.bind(Step.FINAL), true)
			cancel = _button("CANCELAR", Rect2(680.0, 520.0, 340.0, 64.0), Pal.GREEN, Pal.LIME, _cancel, false)
			Sfx.play("error", 0.8)
		Step.FINAL:
			_panel(Rect2(180.0, 80.0, 920.0, 560.0), Color("120208"), Pal.RED)
			_input = LineEdit.new()
			_input.placeholder_text = "ESCRIBE AQUÍ"
			_input.max_length = 24
			_input.context_menu_enabled = false
			_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
			_input.add_theme_font_size_override("font_size", 30)
			_input.add_theme_color_override("font_color", Pal.WHITE)
			_input.add_theme_color_override("font_placeholder_color", Pal.STEEL)
			_input.add_theme_color_override("caret_color", Pal.RED)
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Pal.INK
			style.border_color = Pal.RED
			style.set_border_width_all(4)
			style.set_content_margin_all(10)
			_input.add_theme_stylebox_override("normal", style)
			_input.add_theme_stylebox_override("focus", style)
			_box.add_child(_input)
			_input.position = Vector2(390.0, 380.0)
			_input.size = Vector2(500.0, 64.0)
			# Intro dentro del campo no hace nada: solo el clic en el boton borra.
			_input.text_submitted.connect(_on_submitted)
			cancel = _button("CANCELAR", Rect2(240.0, 544.0, 360.0, 64.0), Pal.GREEN, Pal.LIME, _cancel, false)
			_delete_button = _button("BORRAR TODO", Rect2(680.0, 544.0, 360.0, 64.0), Pal.RED.darkened(0.2), Pal.RED, _confirm_delete, true)
			_delete_button.focus_mode = Control.FOCUS_NONE
			_delete_button.disabled = true
			Sfx.play("error", 0.6)
		Step.DONE:
			_panel(Rect2(290.0, 180.0, 700.0, 360.0), Pal.NAVY, Pal.LIME)
			var ok: PixelButton = _button("ACEPTAR", Rect2(480.0, 440.0, 320.0, 64.0), Pal.GREEN, Pal.LIME, _close, true)
			ok.grab_focus.call_deferred()
	if cancel != null:
		cancel.grab_focus.call_deferred()
	if _input != null:
		_input.grab_focus.call_deferred()


func _panel(rect: Rect2, fill: Color, accent: Color) -> void:
	var panel: PixelPanel = PixelPanel.new()
	panel.fill = fill
	panel.accent = accent
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	_box.move_child(panel, 0)


func _on_submitted(_text: String) -> void:
	# A proposito: confirmar con Intro no borra.
	Sfx.play("error")


func _cancel() -> void:
	if _closing or _deleted:
		return
	_closing = true
	finished.emit(false)
	queue_free()


## Unico punto que borra. Comprueba todo otra vez y solo se ejecuta una vez.
func _confirm_delete() -> void:
	if _deleted or _step != Step.FINAL or not _matches() or _time < ARM_TIME:
		return
	_deleted = true
	_delete_button.disabled = true
	GameData.reset_progress()
	Sfx.play("gameover")
	_show(Step.DONE)


func _close() -> void:
	if _closing:
		return
	_closing = true
	finished.emit(_deleted)
	queue_free()


# ------------------------------------------------------------------ dibujo --

func _text(text: String, y: float, px: float, color: Color) -> void:
	var w: float = PixelFont.text_width(text, px)
	PixelFont.draw_text_shadowed(_canvas, text, Vector2(roundf(640.0 - w * 0.5), y), px, color, Pal.INK)


func _draw_step() -> void:
	match _step:
		Step.ASK:
			_text("¿ESTÁS SEGURO DE QUE QUIERES", 200.0, 4.0, Pal.WHITE)
			_text("BORRAR TU PROGRESO?", 244.0, 4.0, Pal.WHITE)
			_text("ESTA ACCIÓN ELIMINA TU PARTIDA GUARDADA.", 320.0, 2.0, Pal.SILVER)
			_text("TUS AJUSTES DE SONIDO, GRÁFICOS Y CONTROLES SE CONSERVAN.", 348.0, 2.0, Pal.SILVER)
			_text("TODAVÍA NO SE HA BORRADO NADA.", 400.0, 2.0, Pal.LIME)
		Step.WARN:
			# Franjas de peligro arriba y abajo.
			for i in 22:
				var x: float = 204.0 + float(i) * 40.0
				_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, 116.0), Vector2(x + 20.0, 116.0), Vector2(x + 8.0, 138.0), Vector2(x - 12.0, 138.0)]), Pal.YELLOW)
			var blink: float = 0.6 + 0.4 * sin(_time * 7.0)
			_draw_warning_sign(Vector2(640.0, 196.0), Color(Pal.YELLOW, blink))
			_text("ADVERTENCIA:", 252.0, 5.0, Pal.RED.lightened(0.3))
			_text("VAS A PERDER TODO TU PROGRESO.", 304.0, 4.0, Pal.WHITE)
			_text("MONEDAS, DIAMANTES, MUNDOS, NIVELES Y ESTRELLAS", 368.0, 2.0, Pal.ORANGE)
			_text("ÁRBOL DE MEJORAS, POWER-UPS Y COSMÉTICOS", 396.0, 2.0, Pal.ORANGE)
			_text("LOGROS, MISIONES, TÍTULOS Y ESTADÍSTICAS", 424.0, 2.0, Pal.ORANGE)
			_text("NO SE PODRÁ RECUPERAR.", 466.0, 3.0, Pal.RED.lightened(0.2))
		Step.FINAL:
			var pulse: float = 0.7 + 0.3 * sin(_time * 5.0)
			_canvas.draw_rect(Rect2(184.0, 84.0, 912.0, 552.0), Color(Pal.RED, 0.12 * pulse), false, 8.0)
			_text("ÚLTIMA CONFIRMACIÓN:", 120.0, 5.0, Pal.RED.lightened(0.3))
			_text("BORRADO PERMANENTE", 174.0, 6.0, Pal.WHITE)
			_text("PARA BORRAR, ESCRIBE EXACTAMENTE:", 262.0, 2.0, Pal.SILVER)
			_text(CONFIRM_TEXT, 292.0, 5.0, Pal.YELLOW)
			var status: String = "EL TEXTO COINCIDE: YA PUEDES BORRAR" if _matches() else "EL BOTÓN SE ACTIVA CUANDO EL TEXTO COINCIDA"
			_text(status, 466.0, 2.0, Pal.LIME if _matches() else Pal.STEEL)
			_text("PULSA CANCELAR O ESCAPE PARA SALIR SIN BORRAR NADA", 500.0, 2.0, Pal.SILVER)
		Step.DONE:
			_text("PROGRESO BORRADO", 230.0, 6.0, Pal.LIME)
			_text("TU PARTIDA SE HA REINICIADO DESDE CERO.", 314.0, 2.0, Pal.WHITE)
			_text("TUS AJUSTES SE HAN CONSERVADO.", 342.0, 2.0, Pal.SILVER)
			_text("¡SUERTE EN TU NUEVA AVENTURA!", 384.0, 3.0, Pal.YELLOW)


func _draw_warning_sign(center: Vector2, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -34.0), center + Vector2(38.0, 30.0), center + Vector2(-38.0, 30.0)])
	_canvas.draw_colored_polygon(pts, color)
	_canvas.draw_rect(Rect2(center + Vector2(-4.0, -14.0), Vector2(8.0, 26.0)), Pal.INK)
	_canvas.draw_rect(Rect2(center + Vector2(-4.0, 18.0), Vector2(8.0, 7.0)), Pal.INK)
