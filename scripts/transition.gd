extends CanvasLayer
## Autoload "Transition": cortinilla pixelada entre pantallas (cuadros que
## crecen en diagonal hasta cubrir la pantalla y luego se encogen).
##   Transition.change_scene("res://scenes/game.tscn")
##   Transition.reload()

const Pal = preload("res://scripts/palette.gd")

const CELL := 40.0

var _rect: ColorRect
var _wipe: Control
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(Pal.INK, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(1280.0, 720.0)
	# El ColorRect solo guarda el progreso (su alfa) y bloquea el raton; lo
	# que se ve es la cortinilla.
	_rect.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	_wipe = Control.new()
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wipe)
	_wipe.position = Vector2.ZERO
	_wipe.size = Vector2(1280.0, 720.0)
	_wipe.draw.connect(_draw_wipe)


func _process(_delta: float) -> void:
	if _busy or _rect.color.a > 0.0:
		_wipe.queue_redraw()


func _draw_wipe() -> void:
	var progress: float = _rect.color.a
	if progress <= 0.0:
		return
	var cols: int = int(1280.0 / CELL) + 1
	var rows: int = int(720.0 / CELL) + 1
	var span: float = float(cols + rows)
	for c in cols:
		for r in rows:
			var threshold: float = float(c + r) / span * 0.6
			var cover: float = clampf((progress - threshold) / 0.4, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var s: float = ceilf(CELL * cover * 0.5) * 2.0
			var center: Vector2 = Vector2(float(c) * CELL + CELL * 0.5, float(r) * CELL + CELL * 0.5)
			_wipe.draw_rect(Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), Pal.INK)


func change_scene(path: String) -> void:
	_run(path)


func reload() -> void:
	_run("")


## Funde a negro, cambia (o recarga) la escena y vuelve a aclarar.
func _run(path: String) -> void:
	if _busy:
		return
	_busy = true
	Engine.time_scale = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out: Tween = create_tween()
	fade_out.tween_property(_rect, "color:a", 1.0, 0.32)
	await fade_out.finished
	get_tree().paused = false
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, 0.36)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
