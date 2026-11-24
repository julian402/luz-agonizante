extends CanvasLayer

# Mapa estilo metroidvania, dibujado en 2D (sin segunda camara: es pesado en web).
# - Al empezar lee los pisos y paredes del nivel (sus CollisionShape3D) como rectangulos.
# - El mundo se divide en celdas de 6 x 6 m; se descubren la celda de Ceniza y sus vecinas.
# - Minimapa arriba a la derecha; con M el mapa completo (pausa el juego).
# - Iconos: Ceniza, antorchas, boveda y jefe (meta). Los enemigos NO salen.

@export var celda = 6.0
@export var tamano_mini = Vector2(240, 150)
@export var escala_mini = 4.0          # pixeles por metro en el minimapa
const MURO = Color("#4A4A5E")
const TABLA = Color("#8A8AA0")
const DORADO = Color("#F2C14E")
const FONDO = Color(0, 0, 0, 0.7)
const NIEBLA = Color(0.2, 0.16, 0.32, 0.75)   # celdas vistas (el aire por donde se camina)

var rects = []          # [Rect2 en metros, es_tabla]
var vistas = {}         # Vector2i -> true
var piezas = []         # lo que se dibuja: [Rect2, color], se rehace al descubrir algo
var antorchas = []      # posiciones (Vector2)
var boveda = null       # Vector2 o null
var mundo = Rect2()     # lo que ocupa todo el nivel
var jugador = null
var abierto = false
var tiempo = 0.0
var fuente = null
@onready var lienzo = Control.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	add_to_group("mapa")
	fuente = ThemeDB.fallback_font
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)
	jugador = get_tree().get_first_node_in_group("jugador")
	# Espera un cuadro: el nivel termina de ponerse en su lugar.
	await get_tree().process_frame
	leer_nivel()


func leer_nivel():
	var nivel = get_tree().current_scene.get_node_or_null("Nivel")
	if nivel == null:
		nivel = get_tree().current_scene
	var primero = true
	for cs in nivel.find_children("*", "CollisionShape3D", true, false):
		var cuerpo = cs.get_parent()
		if not cuerpo is StaticBody3D or cs.shape == null or cs.disabled:
			continue
		var caja: AABB
		if cs.shape is BoxShape3D:
			caja = AABB(-cs.shape.size * 0.5, cs.shape.size)
		else:
			caja = cs.shape.get_debug_mesh().get_aabb()
		caja = cs.global_transform * caja
		var r = Rect2(caja.position.x, caja.position.y, caja.size.x, caja.size.y)
		if r.size.x < 0.05 or r.size.y < 0.05:
			continue
		var es_tabla = cuerpo.collision_layer == 2
		rects.append([r, es_tabla])
		mundo = r if primero else mundo.merge(r)
		primero = false
	for a in get_tree().get_nodes_in_group("antorchas"):
		if nivel.is_ancestor_of(a):
			antorchas.append(Vector2(a.global_position.x, a.global_position.y))
	var cofre = nivel.find_child("CofreBoveda", true, false)
	if cofre != null:
		boveda = Vector2(cofre.global_position.x, cofre.global_position.y)
	print("mapa: ", rects.size(), " piezas de nivel, ", antorchas.size(), " antorchas")


func _process(delta):
	tiempo += delta
	if Input.is_action_just_pressed("mapa"):
		alternar()
	if jugador != null and is_instance_valid(jugador):
		var c = celda_de(jugador.global_position)
		if not vistas.has(c):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					vistas[c + Vector2i(dx, dy)] = true
			rehacer_piezas()
	lienzo.queue_redraw()


func alternar():
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null and partida.estado != 0:   # la partida ya termino
		return
	if get_tree().paused and not abierto:   # otra cosa pauso (una cinematica)
		return
	abierto = not abierto
	get_tree().paused = abierto
	# El HUD se esconde mientras se mira el mapa.
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.visible = not abierto


func celda_de(p):
	return Vector2i(floori(p.x / celda), floori(p.y / celda))


func visto(p):
	return vistas.has(celda_de(p))


# Cada rectangulo se corta en las celdas vistas: solo aparece lo recorrido.
func rehacer_piezas():
	piezas.clear()
	for c in vistas:
		piezas.append([Rect2(c.x * celda, c.y * celda, celda, celda), NIEBLA])
	for par in rects:
		var r = par[0]
		var color = TABLA if par[1] else MURO
		var c0 = celda_de(r.position)
		var c1 = celda_de(r.end - Vector2(0.001, 0.001))
		for cx in range(c0.x, c1.x + 1):
			for cy in range(c0.y, c1.y + 1):
				if vistas.has(Vector2i(cx, cy)):
					var corte = r.intersection(Rect2(cx * celda, cy * celda, celda, celda))
					if corte.has_area():
						piezas.append([corte, color])


func _dibujar():
	var pantalla = lienzo.size
	if abierto:
		_dibujar_completo(pantalla)
	else:
		_dibujar_mini(pantalla)


func _dibujar_mini(pantalla):
	var caja = Rect2(Vector2(pantalla.x - tamano_mini.x - 20, 20), tamano_mini)
	lienzo.draw_rect(caja.grow(3), Color(0.85, 0.72, 0.42, 0.6), false, 2.0)
	lienzo.draw_rect(caja, FONDO)
	if jugador == null:
		return
	var centro = Vector2(jugador.global_position.x, jugador.global_position.y)
	var a_pantalla = func(p): return caja.get_center() + Vector2(p.x - centro.x, -(p.y - centro.y)) * escala_mini
	for pieza in piezas:
		var r = pieza[0]
		var esq = a_pantalla.call(Vector2(r.position.x, r.end.y))
		var rr = Rect2(esq, r.size * escala_mini).intersection(caja)
		if rr.has_area():
			lienzo.draw_rect(rr, pieza[1])
	_iconos(a_pantalla, caja, 1.0)
	lienzo.draw_string(fuente, caja.position + Vector2(6, caja.size.y - 6), "M: MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))


func _dibujar_completo(pantalla):
	lienzo.draw_rect(Rect2(Vector2.ZERO, pantalla), Color(0.02, 0.02, 0.04, 0.97))
	var margen = Vector2(60, 90)
	var area = Rect2(margen, pantalla - margen * 2)
	var escala = minf(area.size.x / maxf(mundo.size.x, 1.0), area.size.y / maxf(mundo.size.y, 1.0))
	var desfase = area.position + (area.size - mundo.size * escala) * 0.5
	var a_pantalla = func(p): return desfase + Vector2(p.x - mundo.position.x, mundo.end.y - p.y) * escala
	for pieza in piezas:
		var r = pieza[0]
		var esq = a_pantalla.call(Vector2(r.position.x, r.end.y))
		lienzo.draw_rect(Rect2(esq, r.size * escala), pieza[1])
	_iconos(a_pantalla, Rect2(Vector2.ZERO, pantalla), 1.4)
	lienzo.draw_string(fuente, Vector2(0, 55), "MAPA DE LAS RUINAS", HORIZONTAL_ALIGNMENT_CENTER, pantalla.x, 32, DORADO)
	var vistas_pct = 0
	var total = maxi(1, int(ceil(mundo.size.x / celda) * ceil(mundo.size.y / celda)))
	vistas_pct = mini(100, roundi(100.0 * vistas.size() / total))
	var leyenda = "●  Ceniza     ●  Antorcha (a salvo)     ◆  Llave     ▮  Sello     ★  Sombra Madre     Explorado: %d%%     M: volver" % vistas_pct
	lienzo.draw_string(fuente, Vector2(0, pantalla.y - 40), leyenda, HORIZONTAL_ALIGNMENT_CENTER, pantalla.x, 18, Color(1, 1, 1, 0.85))


func _iconos(a_pantalla, limite, tam):
	for a in antorchas:
		if visto(a):
			var p = a_pantalla.call(a)
			if limite.has_point(p):
				lienzo.draw_circle(p, 7.0 * tam, Color(DORADO, 0.25))
				lienzo.draw_circle(p, 3.0 * tam, DORADO)
	if boveda != null and visto(boveda):
		var p = a_pantalla.call(boveda)
		if limite.has_point(p):
			lienzo.draw_rect(Rect2(p - Vector2(4, 4) * tam, Vector2(8, 8) * tam), Color("#C98A3B"))
	# Sellos (morado) y llaves (dorado) que ya se vieron.
	for s in get_tree().get_nodes_in_group("sellos"):
		if is_instance_valid(s) and not s.abierto and visto(Vector2(s.global_position.x, s.global_position.y)):
			var med = Vector2(s.caja.x, s.caja.y) * 0.5
			var p0 = a_pantalla.call(Vector2(s.global_position.x - med.x, s.global_position.y + med.y))
			var p1 = a_pantalla.call(Vector2(s.global_position.x + med.x, s.global_position.y - med.y))
			var r = Rect2(p0, (p1 - p0).abs().max(Vector2(3, 3) * tam)).intersection(limite)
			if r.has_area():
				lienzo.draw_rect(r, Color(0.7, 0.5, 1.0, 0.6 + 0.3 * sin(tiempo * 4.0)))
	for l in get_tree().get_nodes_in_group("llaves"):
		var lp = Vector2(l.global_position.x, l.global_position.y)
		if visto(lp):
			var p = a_pantalla.call(lp)
			if limite.has_point(p):
				var d = 5.0 * tam
				lienzo.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), Color("#FFE08A"))
	for m in get_tree().get_nodes_in_group("meta"):
		var mp = Vector2(m.global_position.x, m.global_position.y + 1.5)
		if visto(mp):
			var p = a_pantalla.call(mp)
			if limite.has_point(p):
				_estrella(p, 7.0 * tam, Color("#E8433A"))
	if jugador != null:
		var p = a_pantalla.call(Vector2(jugador.global_position.x, jugador.global_position.y + 0.9))
		var late = 1.0 + 0.25 * sin(tiempo * 6.0)
		lienzo.draw_circle(p, 6.0 * tam * late, Color(1, 1, 1, 0.3))
		lienzo.draw_circle(p, 3.5 * tam, Color.WHITE)


func _estrella(c, r, color):
	var puntos = PackedVector2Array()
	for i in 10:
		var a = -PI / 2 + i * PI / 5
		var rr = r if i % 2 == 0 else r * 0.45
		puntos.append(c + Vector2(cos(a), sin(a)) * rr)
	lienzo.draw_colored_polygon(puntos, color)
