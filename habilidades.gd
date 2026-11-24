extends Control

# Barra de habilidades abajo a la izquierda del HUD.
# Solo mira los nodos de Ceniza y los dibuja: combo, doble salto, esquiva y estallido.

const DORADO = Color("#F2C14E")
const GRIS = Color(1, 1, 1, 0.18)
const BLANCO = Color(1, 1, 1, 0.95)
const ANCHO = 150.0
const ALTO = 62.0
const SEPARACION = 10.0

var pj = null
var apuntar = null
var esquivar = null
var poder = null
var fuente = null
var tiempo = 0.0
var panel = StyleBoxFlat.new()
var panel_listo = StyleBoxFlat.new()


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuente = ThemeDB.fallback_font
	pj = get_tree().get_first_node_in_group("jugador")
	if pj != null:
		apuntar = pj.get_node_or_null("Apuntar")
		esquivar = pj.get_node_or_null("Esquivar")
		poder = pj.get_node_or_null("Poder")
	for p in [panel, panel_listo]:
		p.bg_color = Color(0.05, 0.05, 0.08, 0.8)
		p.set_corner_radius_all(8)
		p.set_border_width_all(2)
		p.border_color = Color(0.85, 0.72, 0.42, 0.45)
		p.shadow_color = Color(0, 0, 0, 0.5)
		p.shadow_size = 5
	panel_listo.border_color = DORADO


func _process(delta):
	tiempo += delta
	queue_redraw()


func _draw():
	if pj == null:
		return
	var x = 20.0
	var y = size.y - ALTO - 20.0
	# Combo: 3 golpes, el tercero es el remate (blanco).
	var combo = apuntar.combo if apuntar != null else 0
	_tarjeta(Vector2(x, y), "COMBO", "J", false)
	for i in 3:
		var lleno = i < combo
		var c = (BLANCO if i == 2 else DORADO) if lleno else GRIS
		if i == 2 and combo == 2:
			c = Color(1, 1, 1, 0.45 + 0.4 * sin(tiempo * 14.0))   # el proximo es el remate
		_pip(Vector2(x + 22 + i * 26, y + 44), 8.0 if i == 2 else 6.5, c)
	x += ANCHO + SEPARACION
	# Salto: 2 bolitas, se gastan en el aire.
	var quedan = 2 if pj.is_on_floor() else maxi(0, 2 - maxi(pj.saltos, 1))
	_tarjeta(Vector2(x, y), "SALTO x2", "ESPACIO", false)
	for i in 2:
		_pip(Vector2(x + 22 + i * 26, y + 44), 6.5, Color("#9FC7FF") if i < quedan else GRIS)
	x += ANCHO + SEPARACION
	# Esquiva: barra que se llena en la recarga.
	var carga = 1.0
	if esquivar != null:
		if esquivar.estado == 1:
			carga = 0.0
		elif esquivar.estado == 2:
			carga = clampf(1.0 - esquivar.tiempo / maxf(esquivar.recarga, 0.01), 0.0, 1.0)
	_tarjeta(Vector2(x, y), "ESQUIVA", "SHIFT", false)
	_barra(Vector2(x + 12, y + 38), carga, Color("#9FC7FF") if carga >= 1.0 else Color(0.6, 0.7, 0.9, 0.6))
	x += ANCHO + SEPARACION
	# Estallido: se carga pegando; lleno brilla y late.
	if poder != null:
		var parte = poder.energia / poder.maximo
		var listo = poder.listo()
		_tarjeta(Vector2(x, y), "ESTALLIDO", "K", listo)
		var color = DORADO if listo else Color(0.95, 0.75, 0.3, 0.75)
		if listo:
			color = color.lerp(Color.WHITE, 0.35 + 0.35 * sin(tiempo * 8.0))
		_barra(Vector2(x + 12, y + 38), parte, color)
		if listo:
			draw_string(fuente, Vector2(x, y - 6), "¡LISTO!", HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 16, DORADO)


func _tarjeta(p, titulo, tecla, resaltada):
	draw_style_box(panel_listo if resaltada else panel, Rect2(p, Vector2(ANCHO, ALTO)))
	draw_string(fuente, p + Vector2(12, 22), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))
	# La tecla en una cajita a la derecha.
	var ancho_tecla = fuente.get_string_size(tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	var caja = Rect2(p + Vector2(ANCHO - ancho_tecla - 8, 8), Vector2(ancho_tecla, 18))
	draw_rect(caja, Color(1, 1, 1, 0.12))
	draw_rect(caja, Color(1, 1, 1, 0.35), false, 1.0)
	draw_string(fuente, caja.position + Vector2(5, 14), tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))


func _pip(c, r, color):
	draw_circle(c, r + 2.0, Color(0, 0, 0, 0.6))
	draw_circle(c, r, color)


func _barra(p, parte, color):
	var r = Rect2(p, Vector2(ANCHO - 24, 12))
	draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
	draw_rect(r, Color(1, 1, 1, 0.1))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(parte, 0.0, 1.0), r.size.y)), color)
