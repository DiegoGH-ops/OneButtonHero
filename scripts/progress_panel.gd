extends Control
## Pantalla de progreso: misiones (7 categorias, mas de 220), logros (15
## categorias, 6 niveles) y estadisticas con titulos e insignias.
## Se abre como pantalla superpuesta desde el menu principal.

signal closed

const UI = preload("res://scripts/ui.gd")
const PixelFont = preload("res://scripts/pixel_font.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const Pal = preload("res://scripts/palette.gd")
const Missions = preload("res://scripts/missions.gd")
const Achievements = preload("res://scripts/achievements.gd")

const TABS := ["MISIONES", "LOGROS", "ESTADÍSTICAS"]
const STATE_NAMES := ["NO INICIADA", "EN PROGRESO", "¡COMPLETADA!", "RECOMPENSA DISPONIBLE", "RECLAMADA"]
const STATE_COLORS := ["566c86", "73eff7", "a7f070", "ffcd75", "38b764"]
const STATS := [
	["high_score", "RÉCORD DE PUNTOS"], ["run_distance", "MEJOR DISTANCIA (M)"], ["run", "PARTIDAS JUGADAS"],
	["distance", "DISTANCIA TOTAL (M)"], ["coins_picked", "MONEDAS RECOGIDAS"], ["gems_picked", "GEMAS RECOGIDAS"],
	["kills", "ENEMIGOS DERROTADOS"], ["boss_kill", "JEFES DERROTADOS"], ["level_unique", "NIVELES SUPERADOS"],
	["three_star_levels", "NIVELES CON 3 ESTRELLAS"], ["best_combo", "MEJOR COMBO PERFECTO"], ["perfects", "ACCIONES PERFECT"],
	["legendaries", "ACCIONES LEGENDARY"], ["jump", "SALTOS"], ["rapid_success", "RAPID SIX SUPERADOS"],
	["flawless", "NIVELES SIN DAÑO"], ["turbo_clear", "NIVELES A 2X"], ["nights", "NOCHES SUPERADAS"],
	["missions_claimed", "MISIONES COBRADAS"], ["death", "CAÍDAS"],
]

## Zona de la lista desplazable.
const LIST := Rect2(64.0, 214.0, 1152.0, 448.0)
const ACH_LIST := Rect2(300.0, 214.0, 916.0, 448.0)
const MISSION_ROW := 86.0
const ACH_ROW := 74.0

var _tab: int = 0
var _tab_buttons: Array = []
var _canvas: Control
var _list_input: Control
var _mission_cat: int = 0
var _ach_cat: int = 0
var _scroll: float = 0.0
var _scroll_target: float = 0.0
var _hits: Array = []
var _flashes: Dictionary = {}
var _floaters: Array = []
var _time: float = 0.0
var _claim_all: PixelButton
var _title_button: PixelButton
var _busy: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = UI.SCREEN
	visible = false
	UI.dim(self, 0.85)
	UI.panel(self, Rect2(32.0, 24.0, 1216.0, 672.0))
	UI.label(self, "PROGRESO", Vector2(64.0, 46.0), 6.0, Pal.YELLOW, 0)
	var close_button: PixelButton = UI.button(self, "X", Rect2(1150.0, 40.0, 70.0, 54.0), 4.0)
	close_button.fill = Pal.RED
	close_button.fill_hot = Pal.ORANGE
	close_button.pressed.connect(close)
	for i in TABS.size():
		var tab: PixelButton = UI.button(self, TABS[i], Rect2(470.0 + float(i) * 222.0, 42.0, 212.0, 48.0), 3.0)
		tab.pressed.connect(_select_tab.bind(i))
		_tab_buttons.append(tab)
	_canvas = UI.layer(self, "Canvas")
	_canvas.draw.connect(_draw_content)
	_canvas.clip_contents = false
	_list_input = Control.new()
	_list_input.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_list_input)
	_list_input.position = Vector2(64.0, 96.0)
	_list_input.size = Vector2(1170.0, 580.0)
	_list_input.gui_input.connect(_on_list_input)
	_claim_all = UI.button(self, "RECLAMAR TODO", Rect2(964.0, 100.0, 252.0, 44.0), 2.0)
	_claim_all.fill = Pal.GREEN
	_claim_all.fill_hot = Pal.LIME
	_claim_all.pressed.connect(_on_claim_all)
	_title_button = UI.button(self, "TÍTULO", Rect2(64.0, 600.0, 560.0, 50.0), 2.0)
	_title_button.pressed.connect(_cycle_title)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_scroll_by(1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_scroll_by(-1.0)
		get_viewport().set_input_as_handled()


func open() -> void:
	GameData.refresh_missions()
	Sfx.play_music("reward")
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_select_tab(0)
	var first: PixelButton = _tab_buttons[0]
	first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	# Lo recien completado deja de mostrarse como "COMPLETADA".
	GameData.mark_missions_seen()
	GameData.save_data()
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_scroll = lerpf(_scroll, _scroll_target, minf(delta * 14.0, 1.0))
	for key in _flashes.keys():
		_flashes[key] = float(_flashes[key]) - delta
		if float(_flashes[key]) <= 0.0:
			_flashes.erase(key)
	var alive: Array = []
	for item in _floaters:
		var f: Dictionary = item
		f["t"] = float(f["t"]) + delta
		if float(f["t"]) < 1.2:
			alive.append(f)
	_floaters = alive
	_canvas.queue_redraw()


func _select_tab(tab: int) -> void:
	_tab = tab
	_scroll = 0.0
	_scroll_target = 0.0
	for i in _tab_buttons.size():
		var button: PixelButton = _tab_buttons[i]
		button.selected = i == _tab
	_claim_all.visible = tab == 0
	_title_button.visible = tab == 2
	_refresh_title_button()
	_canvas.queue_redraw()


# ---------------------------------------------------------------- entrada --

func _on_list_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_by(0.5)
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_by(-0.5)
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var at: Vector2 = mouse.position + _list_input.position
	for item in _hits:
		var hit: Array = item
		var rect: Rect2 = hit[0]
		if rect.has_point(at):
			_on_hit(String(hit[1]), String(hit[2]))
			_list_input.accept_event()
			return


func _on_hit(kind: String, value: String) -> void:
	if kind == "mcat":
		_mission_cat = int(value)
		_scroll_target = 0.0
		Sfx.play("click")
	elif kind == "acat":
		_ach_cat = int(value)
		_scroll_target = 0.0
		Sfx.play("click")
	elif kind == "claim":
		_claim(value)


func _scroll_by(rows: float) -> void:
	var step: float = MISSION_ROW if _tab == 0 else ACH_ROW
	_scroll_target = clampf(_scroll_target + rows * step * 2.0, 0.0, _max_scroll())


func _max_scroll() -> float:
	if _tab == 0:
		return maxf(float(GameData.missions_of(String(Missions.CATEGORIES[_mission_cat])).size()) * MISSION_ROW - LIST.size.y, 0.0)
	if _tab == 1:
		return maxf(float(_ach_list().size()) * ACH_ROW - ACH_LIST.size.y, 0.0)
	return 0.0


## Cobro con proteccion contra doble clic: GameData ya impide cobrar dos
## veces, y aqui se ignora cualquier pulsacion mientras se procesa.
func _claim(id: String) -> void:
	if _busy:
		return
	_busy = true
	var paid: Dictionary = GameData.claim_mission(id)
	if not paid.is_empty():
		Sfx.play("buy")
		_flashes[id] = 0.6
		var text: String = "+%d" % int(paid["coins"])
		if int(paid["diamonds"]) > 0:
			text += "  " + Loc.s("+%d DIAMANTES") % int(paid["diamonds"])
		_floaters.append({"id": id, "text": text, "t": 0.0})
	_busy = false


func _on_claim_all() -> void:
	if _busy:
		return
	_busy = true
	var total: Dictionary = GameData.claim_all(String(Missions.CATEGORIES[_mission_cat]))
	if int(total["count"]) > 0:
		Sfx.play("unlock")
		_floaters.append({"id": "", "text": Loc.s("%d MISIONES: +%d MONEDAS +%d DIAMANTES") % [int(total["count"]), int(total["coins"]), int(total["diamonds"])], "t": 0.0})
	else:
		Sfx.play("error")
	_busy = false


func _cycle_title() -> void:
	var titles: Array = GameData.unlocked_titles()
	if titles.is_empty():
		Sfx.play("error")
		return
	var index: int = titles.find(GameData.title)
	var next: String = "" if index == titles.size() - 1 else String(titles[index + 1])
	GameData.set_title(next)
	Sfx.play("click")
	_refresh_title_button()


func _refresh_title_button() -> void:
	var current: String = GameData.title if GameData.title != "" else "SIN TÍTULO"
	_title_button.caption = Loc.s("TÍTULO: ") + Loc.s(current)
	_title_button.disabled = GameData.unlocked_titles().is_empty()


# ------------------------------------------------------------------ dibujo --

func _text(text: String, pos: Vector2, px: float, color: Color) -> void:
	PixelFont.draw_text_shadowed(_canvas, text, pos.round(), px, color, Pal.INK)


func _text_right(text: String, right: float, y: float, px: float, color: Color) -> void:
	_text(text, Vector2(right - PixelFont.text_width(text, px), y), px, color)


func _chip(rect: Rect2, label: String, color: Color, selected: bool, badge: int, kind: String, value: String) -> void:
	_canvas.draw_rect(rect, Pal.INK)
	_canvas.draw_rect(rect.grow(-3.0), color.darkened(0.15) if selected else Pal.NAVY.lerp(Pal.INK, 0.4))
	if selected:
		_canvas.draw_rect(Rect2(rect.position.x + 3.0, rect.end.y - 6.0, rect.size.x - 6.0, 3.0), Pal.WHITE)
	var w: float = PixelFont.text_width(label, 2.0)
	_text(label, Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + rect.size.y * 0.5 - 7.0), 2.0, Pal.WHITE if selected else color)
	if badge > 0:
		var at: Vector2 = Vector2(rect.end.x - 6.0, rect.position.y + 4.0)
		var pulse: float = 1.0 + 0.15 * sin(_time * 6.0)
		_canvas.draw_circle(at, 11.0 * pulse, Pal.RED)
		var t: String = str(mini(badge, 99))
		_text(t, at - Vector2(PixelFont.text_width(t, 2.0) * 0.5, 7.0), 2.0, Pal.WHITE)
	_hits.append([rect, kind, value])


func _draw_content() -> void:
	_hits = []
	if _tab == 0:
		_draw_missions()
	elif _tab == 1:
		_draw_achievements()
	else:
		_draw_stats()
	for item in _floaters:
		var f: Dictionary = item
		var k: float = float(f["t"]) / 1.2
		var y: float = 620.0 - k * 60.0
		var w: float = PixelFont.text_width(String(f["text"]), 3.0)
		_text(String(f["text"]), Vector2(640.0 - w * 0.5, y), 3.0, Color(Pal.YELLOW, 1.0 - k))


# --- misiones ----------------------------------------------------------------

func _draw_missions() -> void:
	var width: float = 128.0
	for i in Missions.CATEGORIES.size():
		var cat: String = Missions.CATEGORIES[i]
		var count: int = 0
		for item in GameData.missions_of(cat):
			if GameData.mission_state(item) in [2, 3]:
				count += 1
		_chip(Rect2(64.0 + float(i) * (width + 4.0), 100.0, width, 44.0), String(Missions.CATEGORY_NAMES[i]), Missions.category_color(cat), i == _mission_cat, count, "mcat", str(i))
	var cat_id: String = Missions.CATEGORIES[_mission_cat]
	var list: Array = GameData.missions_of(cat_id)
	var done: int = 0
	for item in list:
		if GameData.mission_state(item) == 4:
			done += 1
	var info: String = Loc.s("%d / %d COBRADAS") % [done, list.size()]
	if cat_id == "diaria":
		info += Loc.s("  -  NUEVAS EN ") + _time_left(1)
	elif cat_id == "semanal":
		info += Loc.s("  -  NUEVAS EN ") + _time_left(7)
	elif GameData.admin_active():
		info += "  -  MODO ADMINISTRADOR: NO SE REGISTRA PROGRESO"
	_text(info, Vector2(64.0, 162.0), 2.0, Pal.SILVER if not GameData.admin_active() else Pal.ORANGE)
	_text_right(Loc.s("%d MISIONES EN TOTAL") % Missions.all().size(), 1216.0, 162.0, 2.0, Pal.STEEL)
	var top: float = LIST.position.y - _scroll
	for i in list.size():
		var y: float = top + float(i) * MISSION_ROW
		if y + MISSION_ROW < LIST.position.y or y > LIST.end.y:
			continue
		_mission_row(list[i], y)
	_scrollbar(LIST, _max_scroll())


func _time_left(days: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local: float = Time.get_unix_time_from_system() + float(bias) * 60.0
	var seconds: float
	if days == 1:
		seconds = 86400.0 - fposmod(local, 86400.0)
	else:
		var day: int = int(floor(local / 86400.0))
		var next_week_day: int = (int(floor(float(day + 3) / 7.0)) + 1) * 7 - 3
		seconds = float(next_week_day) * 86400.0 - local
	seconds = maxf(seconds, 0.0)
	var hours: int = int(seconds / 3600.0)
	if hours >= 24:
		return "%d D %d H" % [int(hours / 24.0), hours % 24]
	return Loc.s("%d H %d MIN") % [hours, int(fposmod(seconds, 3600.0) / 60.0)]


func _mission_row(mission: Dictionary, y: float) -> void:
	var id: String = mission["id"]
	var state: int = GameData.mission_state(mission)
	var target: int = int(mission["target"])
	var value: int = mini(GameData.mission_progress(mission), target)
	var rect: Rect2 = Rect2(LIST.position.x, y, LIST.size.x, MISSION_ROW - 6.0)
	var visible_part: Rect2 = rect.intersection(LIST)
	if visible_part.size.y <= 0.0:
		return
	var cat_color: Color = Missions.category_color(String(mission["cat"]))
	var fill: Color = Pal.NAVY.lerp(Pal.INK, 0.35)
	if state == 4:
		fill = Pal.TEAL.lerp(Pal.INK, 0.55)
	elif state >= 2:
		fill = Pal.TEAL.lerp(Pal.NAVY, 0.3).lerp(Pal.WHITE, 0.06 + 0.04 * sin(_time * 5.0))
	_canvas.draw_rect(visible_part, Pal.INK)
	_canvas.draw_rect(visible_part.grow(-3.0), fill)
	var flash: float = float(_flashes.get(id, 0.0))
	if flash > 0.0:
		_canvas.draw_rect(visible_part.grow(-3.0), Color(Pal.WHITE, flash * 0.6))
	if visible_part.size.y < rect.size.y - 2.0:
		return
	_canvas.draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(8.0, rect.size.y - 6.0)), cat_color)
	var hidden: bool = String(mission["cat"]) == "secreta" and state == 0
	var label_name: String = "???" if hidden else Missions.title(mission)
	var desc: String = (Loc.s("PISTA: ") + Missions.hint(mission)) if hidden else Missions.text(mission)
	_text(label_name, rect.position + Vector2(24.0, 10.0), 3.0, Pal.WHITE if state < 4 else Pal.SILVER)
	# Dificultad.
	var diff: int = int(mission["diff"])
	var diff_name: String = Missions.DIFFICULTIES[clampi(diff, 0, 4)]
	var name_w: float = PixelFont.text_width(label_name, 3.0)
	var chip: Rect2 = Rect2(rect.position.x + 36.0 + name_w, rect.position.y + 10.0, PixelFont.text_width(diff_name, 2.0) + 14.0, 20.0)
	_canvas.draw_rect(chip, Color(String(Missions.DIFFICULTY_COLORS[clampi(diff, 0, 4)])).darkened(0.45))
	_text(diff_name, chip.position + Vector2(7.0, 3.0), 2.0, Color(String(Missions.DIFFICULTY_COLORS[clampi(diff, 0, 4)])))
	_text(Missions.category_name(String(mission["cat"])), Vector2(chip.end.x + 12.0, rect.position.y + 13.0), 2.0, cat_color)
	_text(desc, rect.position + Vector2(24.0, 38.0), 2.0, Pal.SILVER)
	# Barra de progreso con la meta.
	var bar: Rect2 = Rect2(rect.position + Vector2(24.0, 60.0), Vector2(430.0, 12.0))
	_canvas.draw_rect(bar, Pal.INK)
	var ratio: float = float(value) / float(maxi(target, 1))
	var bar_color: Color = Pal.LIME if state >= 2 else cat_color
	_canvas.draw_rect(Rect2(bar.position + Vector2(2.0, 2.0), Vector2((bar.size.x - 4.0) * ratio, 8.0)), bar_color)
	_text("%s / %s" % [_short(value), _short(target)], bar.position + Vector2(bar.size.x + 12.0, -3.0), 2.0, Pal.WHITE)
	# Recompensa.
	var reward: String = Loc.s("+%s MONEDAS") % _short(GameData.mission_coins(mission))
	if int(mission["gems"]) > 0:
		reward += "  " + Loc.s("+%d DIAMANTES") % int(mission["gems"])
	_text(reward, Vector2(rect.position.x + 640.0, rect.position.y + 60.0), 2.0, Pal.YELLOW)
	# Estado y boton de cobro.
	var state_color: Color = Color(String(STATE_COLORS[state]))
	if state == 2 or state == 3:
		var button: Rect2 = Rect2(rect.end.x - 210.0, rect.position.y + 12.0, 196.0, 50.0)
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		_canvas.draw_rect(button.grow(2.0 + pulse * 2.0), Color(Pal.YELLOW, 0.35 * pulse))
		_canvas.draw_rect(button, Pal.INK)
		_canvas.draw_rect(button.grow(-3.0), Pal.GREEN.lerp(Pal.LIME, pulse * 0.4))
		var label: String = "RECLAMAR"
		_text(label, Vector2(button.position.x + (button.size.x - PixelFont.text_width(label, 3.0)) * 0.5, button.position.y + 14.0), 3.0, Pal.WHITE)
		_text_right(STATE_NAMES[state], button.position.x - 14.0, rect.position.y + 13.0, 2.0, state_color)
		_hits.append([button, "claim", id])
	else:
		_text_right(STATE_NAMES[state], rect.end.x - 18.0, rect.position.y + 26.0, 3.0 if state == 4 else 2.0, state_color)


func _short(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%dK" % int(float(value) / 1000.0)
	return str(value)


func _scrollbar(area: Rect2, max_scroll: float) -> void:
	if max_scroll <= 0.0:
		return
	var track: Rect2 = Rect2(area.end.x + 4.0, area.position.y, 8.0, area.size.y)
	_canvas.draw_rect(track, Pal.INK)
	var handle_h: float = maxf(area.size.y * area.size.y / (area.size.y + max_scroll), 30.0)
	var y: float = area.position.y + (area.size.y - handle_h) * (_scroll / max_scroll)
	_canvas.draw_rect(Rect2(track.position.x, y, 8.0, handle_h), Pal.SILVER)


# --- logros -------------------------------------------------------------------

func _ach_list() -> Array:
	var cat: String = "" if _ach_cat == 0 else String(Achievements.CATEGORIES[_ach_cat - 1])
	return Achievements.by_category(cat)


func _draw_achievements() -> void:
	var total: int = Achievements.all().size()
	var owned: int = 0
	for item in Achievements.all():
		if GameData.has_achievement(String(Dictionary(item)["id"])):
			owned += 1
	_text(Loc.s("%d / %d LOGROS") % [owned, total], Vector2(64.0, 108.0), 3.0, Pal.YELLOW)
	_text(Loc.s("PRESTIGIO %d") % GameData.prestige(), Vector2(64.0, 138.0), 2.0, Pal.CYAN)
	if GameData.admin_active():
		_text_right("MODO ADMINISTRADOR: LOS LOGROS ESTÁN EN PAUSA", 1216.0, 112.0, 2.0, Pal.ORANGE)
	# Lista de categorias a la izquierda.
	for i in Achievements.CATEGORIES.size() + 1:
		var label: String = "TODOS" if i == 0 else String(Achievements.CATEGORIES[i - 1])
		_chip(Rect2(64.0, 170.0 + float(i) * 30.0, 220.0, 28.0), label, Pal.SILVER, i == _ach_cat, 0, "acat", str(i))
	var list: Array = _ach_list()
	var top: float = ACH_LIST.position.y - _scroll
	for i in list.size():
		var y: float = top + float(i) * ACH_ROW
		if y + ACH_ROW < ACH_LIST.position.y or y > ACH_LIST.end.y:
			continue
		_ach_row(list[i], y)
	_scrollbar(ACH_LIST, _max_scroll())


func _ach_row(entry: Dictionary, y: float) -> void:
	var rect: Rect2 = Rect2(ACH_LIST.position.x, y, ACH_LIST.size.x, ACH_ROW - 6.0)
	var visible_part: Rect2 = rect.intersection(ACH_LIST)
	if visible_part.size.y <= 0.0:
		return
	var id: String = entry["id"]
	var got: bool = GameData.has_achievement(id)
	var tier: int = int(entry["tier"])
	var color: Color = Achievements.tier_color(tier)
	_canvas.draw_rect(visible_part, Pal.INK)
	_canvas.draw_rect(visible_part.grow(-3.0), color.darkened(0.78) if got else Pal.NAVY.lerp(Pal.INK, 0.45))
	if visible_part.size.y < rect.size.y - 2.0:
		return
	# Brillo animado en los raros y legendarios conseguidos.
	if got and tier >= 2:
		var sweep: float = fposmod(_time * 0.6 + float(id.hash() % 100) / 100.0, 1.6) - 0.3
		var sx: float = rect.position.x + sweep * rect.size.x
		if sx > rect.position.x and sx < rect.end.x - 30.0:
			_canvas.draw_rect(Rect2(sx, rect.position.y + 3.0, 26.0, rect.size.y - 6.0), Color(color, 0.18))
	var secret_locked: bool = bool(entry.get("secret", false)) and not got
	Achievements.draw_medal(_canvas, rect.position + Vector2(38.0, rect.size.y * 0.5), 26.0, tier, Achievements.icon_for(entry), not got)
	var label_name: String = "???" if secret_locked else Achievements.title(entry)
	var desc: String = (Loc.s("PISTA: ") + Achievements.hint(entry)) if secret_locked else Achievements.text(entry)
	_text(label_name, rect.position + Vector2(80.0, 8.0), 3.0, color if got else Pal.WHITE)
	_text(desc, rect.position + Vector2(80.0, 34.0), 2.0, Pal.SILVER)
	_text_right(Achievements.tier_name(tier), rect.end.x - 14.0, rect.position.y + 8.0, 2.0, color)
	if got:
		_text_right(Loc.s("OBTENIDO ") + GameData.achievement_date(id), rect.end.x - 14.0, rect.position.y + 28.0, 2.0, Pal.LIME)
	else:
		var target: int = int(entry["target"])
		var value: int = GameData.achievement_progress(entry)
		var bar: Rect2 = Rect2(rect.end.x - 214.0, rect.position.y + 30.0, 200.0, 10.0)
		_canvas.draw_rect(bar, Pal.INK)
		_canvas.draw_rect(Rect2(bar.position + Vector2(2.0, 2.0), Vector2((bar.size.x - 4.0) * float(value) / float(maxi(target, 1)), 6.0)), color)
		_text_right("%s / %s" % [_short(value), _short(target)], bar.position.x - 10.0, rect.position.y + 28.0, 2.0, Pal.WHITE)
	var reward: String = Achievements.reward_text(entry)
	_text(reward, rect.position + Vector2(80.0, 52.0), 2.0, Pal.YELLOW if not got else Pal.STEEL)


# --- estadisticas -------------------------------------------------------------

func _draw_stats() -> void:
	for i in STATS.size():
		var pair: Array = STATS[i]
		var column: int = i % 2
		var row: int = int(float(i) / 2.0)
		var rect: Rect2 = Rect2(64.0 + float(column) * 580.0, 106.0 + float(row) * 38.0, 572.0, 34.0)
		_canvas.draw_rect(rect, Pal.INK)
		_canvas.draw_rect(rect.grow(-3.0), Pal.NAVY.lerp(Pal.INK, 0.3 if row % 2 == 0 else 0.5))
		_text(String(pair[1]), rect.position + Vector2(16.0, 9.0), 2.0, Pal.WHITE)
		_text_right(str(int(GameData.stats.get(String(pair[0]), 0))), rect.end.x - 16.0, rect.position.y + 9.0, 2.0, Pal.YELLOW)
	_text(Loc.s("PRESTIGIO %d") % GameData.prestige(), Vector2(660.0, 506.0), 3.0, Pal.CYAN)
	_text(Loc.s("MONEDERO %d   DIAMANTES %d") % [GameData.wallet, GameData.diamonds], Vector2(660.0, 540.0), 2.0, Pal.YELLOW)
	# Insignias de los logros de platino o mejor.
	var badges: Array = GameData.badges()
	_text(Loc.s("INSIGNIAS (%d)") % badges.size(), Vector2(64.0, 506.0), 3.0, Pal.YELLOW)
	if badges.is_empty():
		_text("CONSIGUE LOGROS DE PLATINO O MEJOR", Vector2(64.0, 546.0), 2.0, Pal.STEEL)
	for i in mini(badges.size(), 18):
		var entry: Dictionary = badges[i]
		Achievements.draw_medal(_canvas, Vector2(84.0 + float(i) * 30.0, 556.0), 13.0, int(entry["tier"]), Achievements.icon_for(entry), false)
	_text_right("LOS TÍTULOS SE CONSIGUEN CON LOGROS", 1216.0, 620.0, 2.0, Pal.STEEL)
