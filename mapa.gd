extends CanvasLayer

# Mapa estilo metroidvania, dibujado en 2D (sin segunda camara: es pesado en web).
# - Al empezar lee los pisos y paredes del nivel (sus CollisionShape3D) como rectangulos.
# - El mundo se divide en celdas de 6 x 6 m; se descubren la celda de Ceniza y sus vecinas.
# - La etapa actual (y las ya pasadas) se ven en tenue aunque no se hayan recorrido: asi se sabe por donde ir.
# - Minimapa arriba a la derecha con una flecha al objetivo; con M el mapa completo (pausa el juego).
# - Iconos: Ceniza (TU), objetivo, salidas (sellos), antorchas, llaves, boveda y jefe.

@export var celda = 6.0
@export var tamano_mini = Vector2(240, 150)
@export var escala_mini = 4.0          # pixeles por metro en el minimapa
const MURO = Color("#5A5A72")
const AIRE_TENUE = Color(0.22, 0.17, 0.36, 0.4)   # pasillos que se conocen pero no se recorrieron
const FINO = 1.5                                   # metros de cada cuadrito de pasillo tenue
const TABLA = Color("#9A9AB4")
const DORADO = Color("#F2C14E")
const ROJO = Color("#E8433A")
const VERDE = Color("#7BD389")
const MORADO = Color(0.7, 0.5, 1.0)
const FONDO = Color(0, 0, 0, 0.7)
const NIEBLA = Color(0.22, 0.17, 0.36, 0.85)   # celdas recorridas (el aire por donde se camina)
# Donde va el nombre de cada etapa en el mapa grande (metros).
const ANCLAS = [Vector2(24, 6), Vector2(88, 15), Vector2(162, 6), Vector2(146, -23)]

var rects = []          # [Rect2 en metros, es_tabla]
var vistas = {}         # Vector2i -> true
var piezas = []         # lo que se dibuja: [Rect2, color], se rehace al descubrir algo
var antorchas = []      # posiciones (Vector2)
var boveda = null       # Vector2 o null
var mundo = Rect2()     # lo que ocupa todo el nivel
var aire = []           # cuadritos de FINO m donde se puede caminar (Vector2i)
var jugador = null
var etapas = null
var etapa_vista = -1    # con que etapa se armaron las piezas
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
		if not cuerpo is StaticBody3D or cs.shape == null or cs.disabled or cuerpo.is_in_group("sellos"):
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
	# Donde hay aire (no roca): asi la parte no recorrida se dibuja como pasillos y no como bloques.
	var macizos = rects.filter(func(par): return not par[1]).map(func(par): return par[0])
	for fx in range(floori(mundo.position.x / FINO), ceili(mundo.end.x / FINO)):
		for fy in range(floori(mundo.position.y / FINO), ceili(mundo.end.y / FINO)):
			var centro = Vector2((fx + 0.5) * FINO, (fy + 0.5) * FINO)
			var libre = true
			for m in macizos:
				if m.has_point(centro):
					libre = false
					break
			if libre:
				aire.append(Vector2i(fx, fy))
	var cofre = nivel.find_child("CofreBoveda", true, false)
	if cofre != null:
		boveda = Vector2(cofre.global_position.x, cofre.global_position.y)
	print("mapa: ", rects.size(), " piezas de nivel, ", antorchas.size(), " antorchas")


func _process(delta):
	tiempo += delta
	if etapas == null:
		etapas = get_tree().get_first_node_in_group("etapas")
	if Input.is_action_just_pressed("mapa"):
		alternar()
	var rehacer = false
	if etapas != null and etapas.actual != etapa_vista:
		etapa_vista = etapas.actual
		rehacer = true
	if jugador != null and is_instance_valid(jugador):
		var c = celda_de(jugador.global_position)
		if not vistas.has(c):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					vistas[c + Vector2i(dx, dy)] = true
			rehacer = true
	if rehacer and not rects.is_empty():
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
	# El HUD y el panel de la etapa se esconden mientras se mira el mapa.
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.visible = not abierto
	if etapas != null:
		etapas.caja_objetivo.visible = not abierto


func celda_de(p):
	return Vector2i(floori(p.x / celda), floori(p.y / celda))


func visto(p):
	return vistas.has(celda_de(p))


# Celda conocida: recorrida, o de una etapa ya abierta (la actual o una pasada).
func conocida(c):
	if vistas.has(c):
		return true
	if etapas == null:
		return false
	var centro = Vector3((c.x + 0.5) * celda, (c.y + 0.5) * celda, 0)
	return etapas.etapa_de(centro) <= etapas.actual


# Lo recorrido: celdas con niebla y paredes claras. Lo conocido sin recorrer: solo los pasillos en tenue.
func rehacer_piezas():
	piezas.clear()
	for f in aire:
		var centro = Vector2((f.x + 0.5) * FINO, (f.y + 0.5) * FINO)
		var c = celda_de(centro)
		if not vistas.has(c) and conocida(c):
			piezas.append([Rect2(f.x * FINO, f.y * FINO, FINO, FINO), AIRE_TENUE])
	for c in vistas:
		piezas.append([Rect2(c.x * celda, c.y * celda, celda, celda), NIEBLA])
	for par in rects:
		var r = par[0]
		var c0 = celda_de(r.position)
		var c1 = celda_de(r.end - Vector2(0.001, 0.001))
		for cx in range(c0.x, c1.x + 1):
			for cy in range(c0.y, c1.y + 1):
				var c = Vector2i(cx, cy)
				if not vistas.has(c):
					continue
				var color = TABLA if par[1] else MURO
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
	_iconos(a_pantalla, caja, 1.0, false)
	# Flecha al objetivo si queda fuera del minimapa.
	var obj = _objetivo()
	if obj != null:
		var p = a_pantalla.call(obj)
		if not caja.grow(-6).has_point(p):
			var dir = (p - caja.get_center()).normalized()
			var borde = _al_borde(caja.grow(-12), caja.get_center(), dir)
			_flecha(borde, dir, 9.0, DORADO.lerp(Color.WHITE, 0.3 + 0.3 * sin(tiempo * 6.0)))
	lienzo.draw_string(fuente, caja.position + Vector2(6, caja.size.y - 6), "M: MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))


func _dibujar_completo(pantalla):
	lienzo.draw_rect(Rect2(Vector2.ZERO, pantalla), Color(0.02, 0.02, 0.04, 1.0))
	var margen = Vector2(50, 120)
	var area = Rect2(margen, pantalla - margen * 2)
	var escala = minf(area.size.x / maxf(mundo.size.x, 1.0), area.size.y / maxf(mundo.size.y, 1.0))
	var desfase = area.position + (area.size - mundo.size * escala) * 0.5
	var a_pantalla = func(p): return desfase + Vector2(p.x - mundo.position.x, mundo.end.y - p.y) * escala
	for pieza in piezas:
		var r = pieza[0]
		var esq = a_pantalla.call(Vector2(r.position.x, r.end.y))
		lienzo.draw_rect(Rect2(esq, r.size * escala).grow(0.3), pieza[1])
	_nombres_etapas(a_pantalla)
	_iconos(a_pantalla, Rect2(Vector2.ZERO, pantalla), 1.4, true)
	# Encabezado: titulo, etapa y objetivo.
	lienzo.draw_string(fuente, Vector2(0, 46), "MAPA DE LAS RUINAS", HORIZONTAL_ALIGNMENT_CENTER, pantalla.x, 30, DORADO)
	if etapas != null:
		var linea = etapas.panel_etapa.text + "     " + etapas.panel_objetivo.text
		lienzo.draw_string(fuente, Vector2(0, 82), linea, HORIZONTAL_ALIGNMENT_CENTER, pantalla.x, 19, Color(1, 1, 1, 0.9))
	_leyenda(pantalla)


# Nombre de cada etapa con su estado: completada, actual o bloqueada.
func _nombres_etapas(a_pantalla):
	if etapas == null:
		return
	for i in etapas.ETAPAS.size():
		var e = etapas.ETAPAS[i]
		var estado = "BLOQUEADA"
		var color = Color(0.6, 0.6, 0.65)
		if i < etapas.actual or (i == etapas.actual and etapas.hecho):
			estado = "COMPLETADA"
			color = VERDE
		elif i == etapas.actual:
			estado = "ESTÁS AQUÍ"
			color = DORADO
		var p = a_pantalla.call(ANCLAS[i])
		var t1 = str(i + 1) + ". " + e["nombre"]
		var ancho = maxf(fuente.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, fuente.get_string_size(estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 20
		var caja = Rect2(p - Vector2(ancho * 0.5, 22), Vector2(ancho, 44))
		lienzo.draw_rect(caja, Color(0.03, 0.03, 0.06, 0.85))
		lienzo.draw_rect(caja, Color(color, 0.8), false, 2.0 if i == etapas.actual else 1.0)
		lienzo.draw_string(fuente, caja.position + Vector2(0, 19), t1, HORIZONTAL_ALIGNMENT_CENTER, ancho, 16, Color.WHITE if i <= etapas.actual else Color(1, 1, 1, 0.5))
		lienzo.draw_string(fuente, caja.position + Vector2(0, 37), estado, HORIZONTAL_ALIGNMENT_CENTER, ancho, 13, color)


func _leyenda(pantalla):
	var cosas = [["tu", "Ceniza (tú)"], ["objetivo", "Objetivo"], ["sello", "Salida cerrada"], ["antorcha", "Antorcha (a salvo)"], ["llave", "Llave"], ["enemigo", "Enemigo pendiente"], ["jefe", "Sombra Madre"]]
	var tam = 15
	var anchos = []
	var total = 0.0
	for c in cosas:
		var w = 26.0 + fuente.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 26.0
		anchos.append(w)
		total += w
	var x = (pantalla.x - total) * 0.5
	var y = pantalla.y - 52
	lienzo.draw_rect(Rect2(x - 14, y - 20, total + 28, 40), Color(1, 1, 1, 0.05))
	for i in cosas.size():
		_icono(cosas[i][0], Vector2(x + 9, y), 1.0)
		lienzo.draw_string(fuente, Vector2(x + 24, y + 5), cosas[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, 0.85))
		x += anchos[i]
	var vistas_pct = mini(100, roundi(100.0 * vistas.size() / maxi(1, int(ceil(mundo.size.x / celda) * ceil(mundo.size.y / celda)))))
	lienzo.draw_string(fuente, Vector2(0, pantalla.y - 14), "Explorado: %d%%      M: volver al juego" % vistas_pct, HORIZONTAL_ALIGNMENT_CENTER, pantalla.x, 14, Color(1, 1, 1, 0.55))


func _objetivo():
	if etapas == null:
		return null
	var p = etapas.objetivo_pos()
	if p == null:
		return null
	return Vector2(p.x, p.y)


func _iconos(a_pantalla, limite, tam, grande):
	for a in antorchas:
		if visto(a):
			var p = a_pantalla.call(a)
			if limite.has_point(p):
				_icono("antorcha", p, tam)
	if boveda != null and visto(boveda):
		var p = a_pantalla.call(boveda)
		if limite.has_point(p):
			lienzo.draw_rect(Rect2(p - Vector2(4, 4) * tam, Vector2(8, 8) * tam), Color("#C98A3B"))
	# Enemigos que faltan, solo en la etapa de "derrota N".
	if etapas != null and etapas.ETAPAS[etapas.actual]["tipo"] == "matar" and not etapas.hecho:
		for e in etapas.enemigos_vivos():
			var p = a_pantalla.call(Vector2(e.global_position.x, e.global_position.y + 1.0))
			if limite.has_point(p):
				_icono("enemigo", p, tam)
	# Salidas: los sellos de la etapa actual siempre; los demas si ya se vieron.
	for s in get_tree().get_nodes_in_group("sellos"):
		if not is_instance_valid(s) or s.abierto:
			continue
		var sp = Vector2(s.global_position.x, s.global_position.y)
		var de_esta = etapas != null and etapas.sellos[etapas.actual].has(s)
		if not (de_esta or visto(sp)):
			continue
		var med = Vector2(s.caja.x, s.caja.y) * 0.5
		var p0 = a_pantalla.call(Vector2(sp.x - med.x, sp.y + med.y))
		var p1 = a_pantalla.call(Vector2(sp.x + med.x, sp.y - med.y))
		var r = Rect2(p0, (p1 - p0).abs().max(Vector2(3, 3) * tam)).intersection(limite)
		if r.has_area():
			lienzo.draw_rect(r, Color(MORADO, 0.6 + 0.3 * sin(tiempo * 4.0)))
			if grande and de_esta:
				_etiqueta(r.get_center() + Vector2(0, -r.size.y * 0.5 - 12), "SALIDA", MORADO)
	for l in get_tree().get_nodes_in_group("llaves"):
		var lp = Vector2(l.global_position.x, l.global_position.y)
		if visto(lp) or (etapas != null and etapas.llave == l):
			var p = a_pantalla.call(lp)
			if limite.has_point(p):
				_icono("llave", p, tam)
	for m in get_tree().get_nodes_in_group("meta"):
		var mp = Vector2(m.global_position.x, m.global_position.y + 1.5)
		if visto(mp) or (etapas != null and etapas.actual == etapas.ETAPAS.size() - 1):
			var p = a_pantalla.call(mp)
			if limite.has_point(p):
				_icono("jefe", p, tam)
	# Objetivo: anillo que late.
	var obj = _objetivo()
	if obj != null:
		var p = a_pantalla.call(obj)
		if limite.has_point(p):
			_icono("objetivo", p, tam)
			if grande:
				_etiqueta(p + Vector2(0, -22 * tam), "OBJETIVO", DORADO)
	if jugador != null:
		var p = a_pantalla.call(Vector2(jugador.global_position.x, jugador.global_position.y + 0.9))
		_icono("tu", p, tam)
		if grande:
			_etiqueta(p + Vector2(0, 20 * tam), "TÚ", Color.WHITE)


func _icono(tipo, p, tam):
	match tipo:
		"tu":
			var late = 1.0 + 0.25 * sin(tiempo * 6.0)
			lienzo.draw_circle(p, 6.0 * tam * late, Color(1, 1, 1, 0.3))
			lienzo.draw_circle(p, 3.5 * tam, Color.WHITE)
		"antorcha":
			lienzo.draw_circle(p, 6.0 * tam, Color(DORADO, 0.25))
			lienzo.draw_circle(p, 2.6 * tam, DORADO)
		"llave":
			var d = 5.0 * tam
			lienzo.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), Color("#FFE08A"))
		"sello":
			lienzo.draw_rect(Rect2(p - Vector2(2.5, 7) * tam, Vector2(5, 14) * tam), MORADO)
		"enemigo":
			lienzo.draw_circle(p, 3.0 * tam, ROJO)
		"jefe":
			_estrella(p, 7.0 * tam, ROJO)
		"objetivo":
			var f = fmod(tiempo, 1.0)
			lienzo.draw_arc(p, (6.0 + 10.0 * f) * tam, 0, TAU, 24, Color(DORADO, 1.0 - f), 2.0)
			lienzo.draw_arc(p, 6.0 * tam, 0, TAU, 20, DORADO, 2.0)


func _etiqueta(p, texto, color):
	var w = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10
	lienzo.draw_rect(Rect2(p - Vector2(w * 0.5, 9), Vector2(w, 17)), Color(0, 0, 0, 0.75))
	lienzo.draw_string(fuente, p + Vector2(-w * 0.5, 5), texto, HORIZONTAL_ALIGNMENT_CENTER, w, 13, color)


func _al_borde(caja, centro, dir):
	var tx = INF
	var ty = INF
	if absf(dir.x) > 0.001:
		tx = (caja.size.x * 0.5) / absf(dir.x)
	if absf(dir.y) > 0.001:
		ty = (caja.size.y * 0.5) / absf(dir.y)
	return centro + dir * minf(tx, ty)


func _flecha(p, dir, r, color):
	var lado = Vector2(-dir.y, dir.x)
	lienzo.draw_colored_polygon(PackedVector2Array([p + dir * r, p - dir * r * 0.6 + lado * r * 0.7, p - dir * r * 0.6 - lado * r * 0.7]), color)


func _estrella(c, r, color):
	var puntos = PackedVector2Array()
	for i in 10:
		var a = -PI / 2 + i * PI / 5
		var rr = r if i % 2 == 0 else r * 0.45
		puntos.append(c + Vector2(cos(a), sin(a)) * rr)
	lienzo.draw_colored_polygon(puntos, color)
