extends RefCounted
## Efectos visuales reutilizables: rafagas de particulas y textos flotantes.

const PixelLabel = preload("res://scripts/pixel_label.gd")


## Rafaga de particulas cuadradas (aspecto pixel) que se elimina sola.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float, life: float, size: float, gravity_y: float, spread: float, dir: Vector2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2(0.0, gravity_y)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	var timer: SceneTreeTimer = parent.get_tree().create_timer(life + 0.4, false)
	timer.timeout.connect(p.queue_free)


## Texto que sube y se desvanece ("+10", "+50"...).
static func popup(parent: Node, pos: Vector2, text: String, color: Color, px: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label: PixelLabel = PixelLabel.new()
	label.text = text
	label.px = px
	label.color = color
	label.outline = true
	parent.add_child(label)
	label.position = pos
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", pos.y - 56.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tween.tween_callback(label.queue_free)


## Onda de impacto: anillo de cuadraditos que se expande y se desvanece.
static func ring(parent: Node, pos: Vector2, color: Color, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var line: Line2D = Line2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in 17:
		var angle: float = float(i) / 16.0 * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	line.points = points
	line.width = 6.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	parent.add_child(line)
	line.position = pos
	line.scale = Vector2(0.2, 0.2)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.35)
	tween.tween_callback(line.queue_free)
