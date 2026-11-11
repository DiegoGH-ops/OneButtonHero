extends RefCounted
## Atajos para construir la interfaz por codigo con los controles pixel art.
## El juego usa una resolucion fija de 1280x720 (el motor la escala), por eso
## la interfaz se coloca con coordenadas absolutas.

const PixelLabel = preload("res://scripts/pixel_label.gd")
const PixelButton = preload("res://scripts/pixel_button.gd")
const PixelPanel = preload("res://scripts/pixel_panel.gd")

const SCREEN := Vector2(1280.0, 720.0)


## Contenedor invisible a pantalla completa que no intercepta el raton.
static func layer(parent: Node, node_name: String) -> Control:
	var c: Control = Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.position = Vector2.ZERO
	c.size = SCREEN
	return c


static func label(parent: Node, text: String, pos: Vector2, px: float, color: Color, align: int = 1) -> PixelLabel:
	var l: PixelLabel = PixelLabel.new()
	l.text = text
	l.px = px
	l.color = color
	l.align = align
	parent.add_child(l)
	l.position = pos
	return l


static func button(parent: Node, text: String, rect: Rect2, px: float = 4.0) -> PixelButton:
	var b: PixelButton = PixelButton.new()
	b.caption = text
	b.px = px
	parent.add_child(b)
	b.position = rect.position
	b.size = rect.size
	return b


static func panel(parent: Node, rect: Rect2) -> PixelPanel:
	var p: PixelPanel = PixelPanel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.position = rect.position
	p.size = rect.size
	return p


## Velo oscuro que bloquea los clics hacia lo que haya detras.
static func dim(parent: Node, alpha: float = 0.6) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(0.05, 0.05, 0.1, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)
	r.position = Vector2.ZERO
	r.size = SCREEN
	return r
