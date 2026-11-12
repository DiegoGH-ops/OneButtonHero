extends Control
## Avisos emergentes apilados en la parte superior ("COMPRA REALIZADA",
## "LOGRO DESBLOQUEADO"...). Cada aviso entra, espera y se desvanece solo.

const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelPanel = preload("res://scripts/pixel_panel.gd")
const Pal = preload("res://scripts/palette.gd")

const MAX_VISIBLE := 4

var _slots: Array = [false, false, false, false]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_toast(text: String, color: Color = Pal.YELLOW) -> void:
	var slot: int = _slots.find(false)
	if slot < 0:
		slot = 0
	_slots[slot] = true
	var box: Control = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var width: float = maxf(float(text.length()) * 18.0 + 56.0, 320.0)
	var panel: PixelPanel = PixelPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.accent = color
	box.add_child(panel)
	panel.position = Vector2(-width * 0.5, 0.0)
	panel.size = Vector2(width, 44.0)
	var label: PixelLabel = PixelLabel.new()
	label.text = text
	label.px = 3.0
	label.color = color
	box.add_child(label)
	label.position = Vector2(0.0, 12.0)
	var y: float = 104.0 + float(slot) * 52.0
	box.position = Vector2(640.0, y - 30.0)
	box.modulate.a = 0.0
	var tween: Tween = box.create_tween()
	tween.tween_property(box, "position:y", y, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(box, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.0)
	tween.tween_property(box, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_release.bind(slot, box))


func _release(slot: int, box: Control) -> void:
	_slots[slot] = false
	box.queue_free()
