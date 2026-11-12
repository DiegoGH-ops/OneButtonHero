extends Control
## Secuencia especial al derrotar al ultimo jefe: transicion cinematica,
## presentacion del conjunto del Caballero del Abismo pieza a pieza
## (heroe, espada, estela y aura), animacion de desbloqueo y felicitacion.
## Corre en tiempo real y emite "finished" al cerrarse.

signal finished

const UI = preload("res://scripts/ui.gd")
const Pal = preload("res://scripts/palette.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const HeroPreview = preload("res://scripts/hero_preview.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Buffs = preload("res://scripts/buffs.gd")

const SLOTS := ["skin", "sword", "trail", "aura"]
const SLOT_NAMES := ["HÉROE", "ESPADA", "ESTELA", "AURA"]
const IDS := ["skin_abyss", "sword_abyss", "trail_abyss", "aura_abyss"]
## Duracion de cada tramo: oscurecer, intro, 4 piezas.
const INTRO_TIME := 2.6
const PIECE_TIME := 2.4
const CENTER := Vector2(640.0, 400.0)

enum Step { DARKEN, INTRO, PIECES, UNLOCK, DONE }

var _step: int = Step.DARKEN
var _time: float = 0.0
var _step_time: float = 0.0
var _piece: int = -1
var _items: Array = []
var _preview: HeroPreview
var _buttons: Array = []
var _sparks: Array = []
var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = UI.SCREEN
	for i in SLOTS.size():
		_items.append(Catalog.find(Catalog.cosmetics(String(SLOTS[i])), String(IDS[i])))
	_preview = HeroPreview.new()
	_preview.px = 10.0
	_preview.position = CENTER + Vector2(-230.0, 130.0)
	_preview.modulate.a = 0.0
	var override: Dictionary = {}
	for i in SLOTS.size():
		override[SLOTS[i]] = _items[i]
	_preview.override = override
	_preview.hidden_slots = {"sword": true, "trail": true, "aura": true}
	add_child(_preview)
	Sfx.play_music("boss")
	Sfx.set_intensity(0)


## Avanza en tiempo real aunque el motor vaya acelerado.
func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.01)
	_time += real
	_step_time += real
	_update_sparks(real)
	match _step:
		Step.DARKEN:
			if _step_time >= 1.4:
				_go(Step.INTRO)
		Step.INTRO:
			_preview.modulate.a = clampf((_step_time - 1.0) / 1.0, 0.0, 1.0)
			if _step_time >= INTRO_TIME:
				_go(Step.PIECES)
				_reveal(0)
		Step.PIECES:
			if _step_time >= PIECE_TIME:
				if _piece < SLOTS.size() - 1:
					_reveal(_piece + 1)
				else:
					_go(Step.UNLOCK)
					_unlock()
	queue_redraw()


## Una pulsacion adelanta la presentacion (nunca se salta el desbloqueo).
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.pressed
	if pressed and _step == Step.PIECES and _step_time > 0.6:
		_step_time = PIECE_TIME
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		if _step == Step.PIECES and _step_time > 0.6:
			_step_time = PIECE_TIME
			get_viewport().set_input_as_handled()


func _go(step: int) -> void:
	_step = step
	_step_time = 0.0


func _reveal(index: int) -> void:
	_piece = index
	_step_time = 0.0
	_preview.hidden_slots.erase(String(SLOTS[index]))
	Sfx.play("unlock", 0.8 + 0.1 * float(index))
	_burst(_preview.position + Vector2(0.0, -70.0), Pal.VIOLET, 26)


func _unlock() -> void:
	Sfx.play("victory")
	Sfx.play_music("victory")
	_burst(CENTER + Vector2(0.0, -40.0), Pal.VIOLET, 60)
	_burst(CENTER + Vector2(0.0, -40.0), Pal.WHITE, 30)
	_preview.position = CENTER + Vector2(0.0, 90.0)
	var equip: PixelButton = UI.button(self, "EQUIPAR CONJUNTO", Rect2(330.0, 610.0, 300.0, 64.0), 3.0)
	equip.fill = Pal.PURPLE
	equip.fill_hot = Pal.VIOLET
	equip.pressed.connect(_on_equip)
	var go_on: PixelButton = UI.button(self, "CONTINUAR", Rect2(650.0, 610.0, 300.0, 64.0), 3.0)
	go_on.pressed.connect(_on_continue)
	_buttons = [equip, go_on]
	for item in _buttons:
		var b: PixelButton = item
		b.disabled = true
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_enable_buttons)


func _enable_buttons() -> void:
	for item in _buttons:
		var b: PixelButton = item
		b.disabled = false
	var last: PixelButton = _buttons[1]
	last.grab_focus()


func _on_equip() -> void:
	for i in SLOTS.size():
		if GameData.is_owned(String(IDS[i])):
			GameData.equip(String(SLOTS[i]), String(IDS[i]))
	var b: PixelButton = _buttons[0]
	b.caption = "¡EQUIPADO!"
	b.disabled = true
	Sfx.play("unlock", 1.3)


func _on_continue() -> void:
	if _closing:
		return
	_closing = true
	for item in _buttons:
		var b: PixelButton = item
		b.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	queue_free()


# --- Particulas propias (la capa de juego queda detras del telon) -----------

func _burst(origin: Vector2, color: Color, amount: int) -> void:
	for i in amount:
		var angle: float = randf() * TAU
		var speed: float = randf_range(120.0, 460.0)
		_sparks.append({"p": origin, "v": Vector2(cos(angle), sin(angle)) * speed, "life": randf_range(0.6, 1.3), "t": 0.0, "c": color, "s": randf_range(4.0, 9.0)})


func _update_sparks(delta: float) -> void:
	var alive: Array = []
	for item in _sparks:
		var spark: Dictionary = item
		spark["t"] = float(spark["t"]) + delta
		if float(spark["t"]) >= float(spark["life"]):
			continue
		var v: Vector2 = spark["v"]
		v *= 1.0 - 2.2 * delta
		v.y += 160.0 * delta
		spark["v"] = v
		spark["p"] = Vector2(spark["p"]) + v * delta
		alive.append(spark)
	_sparks = alive


# --- Dibujo ------------------------------------------------------------------

func _text(text: String, y: float, px: float, color: Color, x: float = 640.0) -> void:
	var w: float = PixelFont.text_width(text, px)
	PixelFont.draw_text_shadowed(self, text, Vector2(roundf(x - w * 0.5), y), px, color, Pal.INK)


func _draw() -> void:
	# Telon: oscurece la escena hasta el negro del abismo.
	var dark: float = clampf(_time / 1.2, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, UI.SCREEN), Color(Pal.VOID, 0.96 * dark))
	if _step == Step.DARKEN:
		# Grietas violetas que se abren desde el centro.
		var grow: float = clampf(_step_time / 1.3, 0.0, 1.0)
		for i in 9:
			var angle: float = float(i) * TAU / 9.0 + 0.3
			var a: Vector2 = CENTER
			for j in 6:
				var seg: float = 70.0 * grow
				var bend: float = sin(float(i * 7 + j * 3)) * 0.5
				var b: Vector2 = a + Vector2(cos(angle + bend), sin(angle + bend)) * seg
				draw_line(a, b, Color(Pal.VIOLET, grow), 4.0 - float(j) * 0.5)
				a = b
		PixelArt.draw_glow(self, CENTER, 260.0 * grow, Color(Pal.VIOLET, 0.5 * grow))
		return
	# Columna de luz y niebla del abismo.
	var pulse: float = 0.85 + 0.15 * sin(_time * 3.0)
	for i in 14:
		var x: float = fposmod(float(i) * 97.0 + _time * 18.0 * (1.0 + float(i % 3)), 1280.0)
		var y: float = 720.0 - fposmod(_time * 40.0 + float(i) * 61.0, 720.0)
		draw_rect(Rect2(x, y, 4.0, 4.0), Color(Pal.VIOLET, 0.35))
	var hero_at: Vector2 = _preview.position
	draw_rect(Rect2(hero_at.x - 70.0, 0.0, 140.0, hero_at.y), Color(Pal.VIOLET, 0.08 * pulse))
	PixelArt.draw_glow(self, hero_at + Vector2(0.0, -80.0), 220.0 * pulse, Color(Pal.PURPLE, 0.6))
	draw_rect(Rect2(hero_at.x - 140.0, hero_at.y, 280.0, 6.0), Color(Pal.VIOLET, 0.6))

	if _step == Step.INTRO:
		var a: float = clampf(_step_time / 0.6, 0.0, 1.0)
		_text("EL ABISMO TE HA ELEGIDO", 90.0, 5.0, Color(Pal.VIOLET, a))
		_text("HAS DERROTADO AL ÚLTIMO JEFE", 150.0, 3.0, Color(Pal.SILVER, a))
	elif _step == Step.PIECES:
		_draw_piece_card()
	elif _step == Step.UNLOCK:
		_draw_unlock()
	_draw_sparks()


func _draw_piece_card() -> void:
	_text("CONJUNTO EXCLUSIVO", 60.0, 3.0, Pal.SILVER)
	_text("CABALLERO DEL ABISMO", 96.0, 6.0, Pal.VIOLET)
	# Contador de piezas.
	for i in SLOTS.size():
		var lit: bool = i <= _piece
		var box: Rect2 = Rect2(560.0 + float(i) * 44.0, 170.0, 30.0, 12.0)
		draw_rect(box, Pal.VIOLET if lit else Pal.SLATE)
	# Ficha de la pieza actual, a la derecha del heroe.
	var item: Dictionary = _items[_piece]
	var slide: float = 1.0 - clampf(_step_time / 0.35, 0.0, 1.0)
	var x: float = 600.0 + slide * 120.0
	var a: float = 1.0 - slide
	var card: Rect2 = Rect2(x, 230.0, 560.0, 300.0)
	draw_rect(card, Color(Pal.INK, 0.9 * a))
	draw_rect(card, Color(Pal.VIOLET, a), false, 4.0)
	var cx: float = x + 280.0
	_text(Loc.s("PIEZA %d DE 4 - %s") % [_piece + 1, Loc.s(String(SLOT_NAMES[_piece]))], 252.0, 2.0, Color(Pal.SILVER, a), cx)
	_text(String(item.get("name", "")), 286.0, 4.0, Color(Pal.WHITE, a), cx)
	_text("MÍTICO", 330.0, 3.0, Color(Catalog.rarity_color("MÍTICO"), a), cx)
	var lines: Array = _wrap(Catalog.cosmetic_desc(item), 40)
	for i in lines.size():
		_text(String(lines[i]), 372.0 + float(i) * 22.0, 2.0, Color(Pal.SILVER, a), cx)
	_text(Loc.s("BUFF: ") + Buffs.describe(item.get("buff", {})), 470.0, 2.0, Color(Pal.LIME, a), cx)
	# Destello de aparicion.
	var flash: float = 1.0 - clampf(_step_time / 0.4, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, UI.SCREEN), Color(Pal.VIOLET, 0.25 * flash))
	if _step_time > 1.0:
		_text("PULSA PARA CONTINUAR", 680.0, 2.0, Color(Pal.STEEL, 0.6 + 0.4 * sin(_time * 4.0)))


func _draw_unlock() -> void:
	# Candado que se rompe y titulo de desbloqueo.
	var t: float = _step_time
	if t < 0.7:
		var shake: float = sin(t * 60.0) * 6.0 * (1.0 - t / 0.7)
		var lock_at: Vector2 = CENTER + Vector2(shake - 30.0, -260.0)
		draw_rect(Rect2(lock_at + Vector2(10.0, -30.0), Vector2(40.0, 34.0)), Pal.SILVER, false, 8.0)
		draw_rect(Rect2(lock_at, Vector2(60.0, 50.0)), Pal.SILVER)
	else:
		var open: float = clampf((t - 0.7) / 0.5, 0.0, 1.0)
		for side in [-1.0, 1.0]:
			var piece_at: Vector2 = CENTER + Vector2(float(side) * (20.0 + open * 160.0) - 15.0, -260.0 + open * open * 300.0)
			draw_rect(Rect2(piece_at, Vector2(30.0, 50.0)), Color(Pal.SILVER, 1.0 - open))
	var a: float = clampf((t - 0.5) / 0.5, 0.0, 1.0)
	var scale_px: float = 7.0 + 2.0 * (1.0 - a)
	_text("¡DESBLOQUEADO!", 70.0, scale_px, Color(Pal.VIOLET, a))
	_text("¡ENHORABUENA, CABALLERO DEL ABISMO!", 150.0, 3.0, Color(Pal.WHITE, a))
	_text("HAS VENCIDO AL ÚLTIMO JEFE Y CONQUISTADO LOS CINCO MUNDOS", 190.0, 2.0, Color(Pal.SILVER, a))
	_text("HÉROE, ESPADA, ESTELA Y AURA YA SON TUYOS", 216.0, 2.0, Color(Pal.LIME, a))
	_text("SOLO LOS QUE LLEGAN AL FINAL PUEDEN LLEVARLO", 560.0, 2.0, Color(Pal.STEEL, a))


func _draw_sparks() -> void:
	for item in _sparks:
		var spark: Dictionary = item
		var k: float = 1.0 - float(spark["t"]) / float(spark["life"])
		var s: float = float(spark["s"]) * k
		draw_rect(Rect2(Vector2(spark["p"]) - Vector2(s, s) * 0.5, Vector2(s, s)), Color(Color(spark["c"]), k))


static func _wrap(text: String, width: int) -> Array:
	# Traduce y corta por palabras (o por caracteres en chino y japones).
	return Loc.wrap(text, width)
