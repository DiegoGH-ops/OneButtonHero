extends CanvasLayer
## Autoload "Transition": fundido a negro entre pantallas.
##   Transition.change_scene("res://scenes/game.tscn")
##   Transition.reload()

const Pal = preload("res://scripts/palette.gd")

var _rect: ColorRect
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
	fade_out.tween_property(_rect, "color:a", 1.0, 0.22)
	await fade_out.finished
	get_tree().paused = false
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, 0.3)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
