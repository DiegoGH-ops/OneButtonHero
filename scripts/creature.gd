extends Area2D
## Criaturas del bestiario (bestiary.gd). Un solo script con un
## comportamiento por arquetipo; todas se manejan con el unico boton:
##   CHASER    - llega por detras con aviso; hay que saltar cuando alcanza.
##   SENTINEL  - escudo y lanza con ritmo fijo; solo es vulnerable al brillar.
##   BRUTE     - aguanta varios golpes y avanza: hay que pulsar muy rapido.
##   SHIFTER   - alterna entre el suelo y el aire; su sombra anuncia el cambio.
##   HOPPER    - salta en el sitio; se cruza por debajo o se salta al aterrizar.
##   SHOOTER   - torreta que dispara a ras de suelo (saltar o cortar).
##   BURROWER  - escondido bajo tierra; sale de golpe al acercarse.
##   SPLITTER  - al morir se divide en dos trozos que vienen detras.
##   BARRICADE - muro de cajas imposible de saltar: pulsacion rapida.
## Ademas, PROJECTILE es la bala de la torreta.

const PixelArt = preload("res://scripts/pixel_art.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const Pal = preload("res://scripts/palette.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Bestiary = preload("res://scripts/bestiary.gd")

## Arquetipos (mismos valores que Bestiary.Archetype).
const CHASER := 0
const SENTINEL := 1
const BRUTE := 2
const SHIFTER := 3
const HOPPER := 4
const SHOOTER := 5
const BURROWER := 6
const SPLITTER := 7
const BARRICADE := 8
const PROJECTILE := 9
const GROUND_Y := 560.0
const POINTS := [70, 90, 120, 70, 60, 70, 60, 50, 150, 20]

## Para game.gd: 100 + arquetipo (no se confunde con los enemigos clasicos).
var kind: int = 100
var archetype: int = 0
var hp: int = 1
var dead: bool = false
## El heroe puede golpearla con pulsaciones muy seguidas.
var mash: bool = false
var creature_name: String = ""

## Datos para lights.gd.
var glow_radius: float = 50.0
var glow_color: Color = Pal.YELLOW
var glow_day: float = 0.2

var _sprite: String = "boar"
var _remap: Dictionary = {}
var _remap_key: String = ""
var _px: float = 4.0
var _adj: float = 1.0
var _time: float = 0.0
var _state: int = 0
var _timer: float = 0.0
var _y: float = 0.0
var _flash: float = 0.0
var _blocked: float = 0.0
var _shots: int = 0
var _is_mini: bool = false
var _active: bool = false
var _passed: bool = false
var _max_hp: int = 1
var _shape: RectangleShape2D
var _collider: CollisionShape2D


func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	_shape = RectangleShape2D.new()
	_collider = CollisionShape2D.new()
	_collider.shape = _shape
	add_child(_collider)


## Configura la criatura `index` (0-4) del mundo `world`, o una barricada
## (index = -1) o un proyectil (index = -2). `position` es su base en el suelo.
func setup(world: int, index: int) -> void:
	if index == -1:
		archetype = BARRICADE
		creature_name = "BARRICADA"
		_sprite = "crate"
		_adj = 1.0 + 0.12 * float(world)
	elif index == -2:
		archetype = PROJECTILE
		creature_name = "PROYECTIL"
	else:
		var data: Array = Bestiary.entry(world, index)
		creature_name = data[0]
		archetype = data[1]
		_sprite = data[2]
		_remap = data[3]
		_adj = data[4]
		_remap_key = "%d_%d" % [world, index]
	kind = 100 + archetype
	_time = fposmod(position.x * 0.0071, 3.0)
	var visible_now: bool = true
	match archetype:
		CHASER:
			_box(44.0, 30.0)
			visible_now = false
		SENTINEL:
			_box(36.0, 52.0)
		BRUTE:
			hp = int(roundf(4.0 * _adj))
			mash = true
			_px = 6.0
			_box(60.0, 120.0)
		BARRICADE:
			hp = int(roundf(6.0 * _adj))
			mash = true
			_box(44.0, 200.0)
		SHIFTER:
			_box(34.0, 34.0)
			glow_color = Pal.CYAN
			add_to_group("glow")
		HOPPER:
			_box(40.0, 30.0)
		SHOOTER:
			_box(40.0, 46.0)
		BURROWER:
			_box(34.0, 52.0)
			visible_now = false
		SPLITTER:
			_box(44.0, 32.0)
		_:
			_box(26.0, 18.0)
			_y = -16.0
			glow_color = Pal.ORANGE
			add_to_group("glow")
	_max_hp = hp
	_set_active(visible_now)
	_place()


## Version pequena de la criatura divisible.
func make_mini() -> void:
	_is_mini = true
	_px = 2.5
	_box(26.0, 20.0)
	_place()


func _box(w: float, h: float) -> void:
	_shape.size = Vector2(w, h)
	_collider.position = Vector2(0.0, -h * 0.5)


func _place() -> void:
	_collider.position.y = _y - _shape.size.y * 0.5


## Activa o desactiva su presencia (los ocultos no danan ni se atacan).
func _set_active(value: bool) -> void:
	_active = value
	set_deferred("monitorable", value)
	if value and not is_in_group("enemies"):
		add_to_group("enemies")
	elif not value and is_in_group("enemies"):
		remove_from_group("enemies")


func get_points() -> int:
	return POINTS[clampi(archetype, 0, POINTS.size() - 1)]


## Golpe del heroe. Puntos si muere, -1 si aguanta y 0 si lo bloquea.
func hit() -> int:
	if dead or not _active:
		return 0
	if archetype == SENTINEL and _state != 2:
		_blocked = 0.35
		Sfx.play("hit", 1.4)
		return 0
	hp -= 1
	if hp > 0:
		_flash = 0.15
		# Cada golpe la empuja un poco (pulsacion rapida).
		position.x += 26.0 * Daylight.mash_factor
		return -1
	dead = true
	_set_active(false)
	if archetype == SPLITTER and not _is_mini:
		_split()
	queue_free()
	return get_points()


func _split() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for offset in [120.0, 250.0]:
		var piece: Area2D = get_script().new()
		piece.position = Vector2(position.x + float(offset), GROUND_Y)
		parent.call_deferred("add_child", piece)
		piece.call_deferred("_setup_piece", _remap, _remap_key, _sprite)


func _setup_piece(color_map: Dictionary, remap_key: String, sprite: String) -> void:
	archetype = SPLITTER
	kind = 100 + archetype
	_remap = color_map
	_remap_key = remap_key
	_sprite = sprite
	make_mini()
	_set_active(true)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_blocked = maxf(_blocked - delta, 0.0)
	var hero: Vector2 = Daylight.player_pos
	var dx: float = global_position.x - hero.x
	var speed: float = Daylight.run_speed
	match archetype:
		CHASER:
			_process_chaser(dx, hero, speed, delta)
		SENTINEL:
			var guard: float = 1.0
			var thrust: float = 0.35
			var recover: float = 0.6 * Daylight.counter_factor / _adj
			var t: float = fposmod(_time, guard + thrust + recover)
			_state = 0 if t < guard else (1 if t < guard + thrust else 2)
			# La lanza se extiende hacia delante durante la estocada.
			if _state == 1:
				_shape.size = Vector2(96.0, 52.0)
				_collider.position = Vector2(-30.0, -26.0)
			else:
				_box(36.0, 52.0)
		BRUTE, BARRICADE:
			# Avanza hacia el heroe mas despacio que el: hay tiempo justo.
			if dx < 260.0 and hp > 0:
				position.x += (speed - 70.0 * _adj) * delta
		SHIFTER:
			var period: float = 1.4 / _adj
			_state = int(_time / period) % 2
			_y = -130.0 if _state == 1 else 0.0
			_place()
		HOPPER:
			var hop: float = absf(sin(_time * PI / (1.0 / _adj)))
			_y = -130.0 * hop
			_place()
		SHOOTER:
			_timer -= delta
			if dx > 240.0 and dx < 900.0 * Daylight.warn_factor and _shots < 2 and _timer <= 0.0:
				if _state == 0:
					_state = 1
					_timer = 0.45
				else:
					_state = 0
					_timer = 1.7 / _adj
					_shots += 1
					_fire()
		BURROWER:
			if not _active and dx < 240.0 * Daylight.warn_factor * (1.0 / _adj):
				_set_active(true)
				_flash = 0.2
				Sfx.play("land", 0.6)
		PROJECTILE:
			position.x -= 230.0 * delta
	modulate = Daylight.unlit() if archetype == PROJECTILE or archetype == SHIFTER else Color(1.0, 1.0, 1.0)
	if dx < -900.0 and (archetype != CHASER or _passed):
		queue_free()
	queue_redraw()


func _process_chaser(dx: float, hero: Vector2, speed: float, delta: float) -> void:
	if _state == 0:
		# Espera escondido; al pasar el heroe aparece detras de el.
		if dx < 0.0:
			_state = 1
			position.x = hero.x - 560.0 * Daylight.warn_factor
			_set_active(true)
			Sfx.play("error", 0.7)
		return
	position.x += (speed + 200.0 * _adj) * delta
	if not _passed and global_position.x > hero.x + 60.0:
		_passed = true
		Daylight.dodges += 1


func _fire() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var bullet: Area2D = get_script().new()
	bullet.position = Vector2(position.x - 40.0, GROUND_Y)
	parent.call_deferred("add_child", bullet)
	bullet.call_deferred("setup", 0, -2)
	Sfx.play("attack", 0.6)


func _draw() -> void:
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	if _flash > 0.0:
		tint = Color(3.0, 3.0, 3.0, 1.0)
	var top: float = _y - _shape.size.y
	var hero_x: float = Daylight.player_pos.x
	match archetype:
		CHASER:
			if _state == 0:
				return
			var lift: float = roundf(absf(sin(_time * 16.0)) * -4.0)
			PixelArt.draw_skin(self, _sprite, Vector2(-28.0, -36.0 + lift), 4.0, tint, _remap, _remap_key)
			# Aviso en el borde izquierdo de la pantalla mientras se acerca.
			if not _passed:
				var screen_left: float = hero_x - 300.0 - global_position.x
				if screen_left > 0.0:
					var gap: float = hero_x - global_position.x
					var blink: bool = gap < 160.0 or int(_time * 8.0) % 2 == 0
					var arrow: String = "<<" if gap > 160.0 else "¡SALTA!"
					PixelFont.draw_text_shadowed(self, arrow, Vector2(screen_left, -120.0), 4.0, Pal.RED if blink else Pal.YELLOW, Pal.INK, true)
		SENTINEL:
			PixelArt.draw_skin(self, _sprite, Vector2(-24.0, -52.0), 4.0, tint, _remap, _remap_key)
			var spear_len: float = 60.0 if _state == 1 else 18.0
			draw_rect(Rect2(-18.0 - spear_len, -34.0, spear_len, 6.0), Pal.SILVER)
			draw_rect(Rect2(-26.0 - spear_len, -36.0, 10.0, 10.0), Pal.WHITE)
			if _state == 2:
				PixelArt.draw_glow(self, Vector2(0.0, -26.0), 56.0, Color(Pal.LIME, 0.7))
				PixelFont.draw_text_shadowed(self, "¡AHORA!", Vector2(-40.0, -96.0), 3.0, Pal.LIME, Pal.INK, true)
			else:
				# Escudo levantado.
				draw_rect(Rect2(-24.0, -48.0, 10.0, 40.0), Pal.YELLOW if _blocked > 0.0 else Pal.STEEL)
		BRUTE, BARRICADE:
			if archetype == BARRICADE:
				for k in 4:
					PixelArt.draw(self, "crate", Vector2(-24.0, -48.0 * float(k + 1)), 4.0, tint)
			else:
				PixelArt.draw_skin(self, _sprite, Vector2(-42.0, -78.0), _px, tint, _remap, _remap_key)
				# Garrote levantado: le da su altura.
				draw_rect(Rect2(-6.0, -124.0, 12.0, 48.0), Pal.BROWN)
				draw_rect(Rect2(-12.0, -132.0, 24.0, 18.0), Pal.DARK_BROWN)
			# Golpes que le quedan y aviso.
			var label: String = "¡PULSA RÁPIDO! x%d" % hp
			PixelFont.draw_text_shadowed(self, label, Vector2(-PixelFont.text_width(label, 2.0) * 0.5, top - 30.0), 2.0, Pal.YELLOW if int(_time * 6.0) % 2 == 0 else Pal.ORANGE, Pal.INK, true)
			for i in _max_hp:
				draw_rect(Rect2(-float(_max_hp) * 7.0 + float(i) * 14.0, top - 10.0, 10.0, 6.0), Pal.RED if i < hp else Pal.SLATE)
		SHIFTER:
			# Sombra/fantasma de la proxima posicion.
			var period: float = 1.4 / _adj
			var left: float = period - fposmod(_time, period)
			if left < 0.4:
				var next_y: float = 0.0 if _state == 1 else -130.0
				PixelArt.draw_skin(self, _sprite, Vector2(-20.0, next_y - 40.0), 4.0, Color(1.0, 1.0, 1.0, 0.3), _remap, _remap_key)
			draw_rect(Rect2(-18.0, -4.0, 36.0, 4.0), Color(0.0, 0.0, 0.0, 0.3))
			PixelArt.draw_skin(self, _sprite, Vector2(-20.0, _y - 40.0), 4.0, tint, _remap, _remap_key)
		HOPPER:
			var shrink: float = clampf(1.0 + _y / 260.0, 0.4, 1.0)
			draw_rect(Rect2(-20.0 * shrink, -4.0, 40.0 * shrink, 4.0), Color(0.0, 0.0, 0.0, 0.3))
			PixelArt.draw_skin(self, _sprite, Vector2(-24.0, _y - 36.0), 4.0, tint, _remap, _remap_key)
		SHOOTER:
			var aim: Color = Color(2.0, 1.4, 1.0, 1.0) if _state == 1 else tint
			PixelArt.draw_skin(self, _sprite, Vector2(-24.0, -48.0), 4.0, aim, _remap, _remap_key)
			if _state == 1:
				PixelArt.draw_glow(self, Vector2(-30.0, -20.0), 30.0, Color(Pal.ORANGE, 0.8))
		BURROWER:
			if not _active:
				# Monticulo de tierra que tiembla y suelta polvo al acercarse.
				var near: bool = global_position.x - hero_x < 520.0 * Daylight.warn_factor
				var shake: float = sin(_time * 40.0) * 2.0 if near else 0.0
				draw_rect(Rect2(-22.0 + shake, -10.0, 44.0, 10.0), Pal.BROWN)
				draw_rect(Rect2(-14.0 + shake, -16.0, 28.0, 6.0), Pal.DARK_BROWN)
				if near:
					PixelFont.draw_text_shadowed(self, "!", Vector2(-6.0, -60.0), 4.0, Pal.RED, Pal.INK, true)
					for k in 3:
						var dust: float = fposmod(_time * 3.0 + float(k) * 0.33, 1.0)
						draw_rect(Rect2(-20.0 + float(k) * 16.0, -16.0 - dust * 26.0, 6.0, 6.0), Color(Pal.SILVER, 1.0 - dust))
			else:
				PixelArt.draw_skin(self, _sprite, Vector2(-20.0, -48.0), 4.0, tint, _remap, _remap_key)
		SPLITTER:
			var squash: float = 1.0 + 0.08 * sin(_time * 8.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(squash, 2.0 - squash))
			PixelArt.draw_skin(self, _sprite, Vector2(-6.0 * _px, -9.0 * _px), _px, tint, _remap, _remap_key)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			PixelArt.draw_glow(self, Vector2(0.0, -16.0), 26.0, Color(Pal.ORANGE, 0.8))
			draw_rect(Rect2(-12.0, -24.0, 24.0, 16.0), Pal.ORANGE)
			draw_rect(Rect2(-8.0, -20.0, 12.0, 8.0), Pal.YELLOW)
			for k in 3:
				draw_rect(Rect2(14.0 + float(k) * 10.0, -20.0 + float(k % 2) * 4.0, 6.0, 6.0), Color(Pal.RED, 0.8 - float(k) * 0.25))
	# Aviso "!" cuando el boton atacara (no en los que tienen su propio aviso).
	var player: Node = get_tree().get_first_node_in_group("player")
	if _active and not dead and player != null and player.has_method("is_enemy_in_reach") and not mash and archetype != SENTINEL:
		if bool(player.call("is_enemy_in_reach", self)):
			PixelFont.draw_text_shadowed(self, "!", Vector2(-10.0, top - 44.0), 4.0, Pal.YELLOW, Pal.INK, true)
