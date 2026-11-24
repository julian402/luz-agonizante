extends Node

# Las etapas de la partida: Tumbas -> Catacumbas -> Guardia -> Trono (jefe).
# Cada etapa tiene un objetivo. Al cumplirlo se rompe el Sello de luz que cierra la siguiente,
# la camara se aleja para mostrarla y aparece su titulo. La ultima es la Sombra Madre.
# Si Ceniza pierde todas las vidas, la partida vuelve a empezar en la etapa a la que habia llegado.

const SELLO = preload("res://sello.gd")
const LLAVE = preload("res://llave.tscn")
const DORADO = Color("#F2C14E")
const ROJO = Color("#E8433A")

# vista: lo que muestra la camara alejada (x, y, ancho, alto en metros).
# sellos: los que se rompen al TERMINAR esta etapa (centro x, y, ancho, alto).
const ETAPAS = [
	{
		"numero": "ETAPA 1", "nombre": "LAS TUMBAS",
		"objetivo": "Vence al Coloso de la Cripta y toma su llave",
		"tipo": "guardian", "guardian": "ColosoCripta", "llave_nombre": "Llave de la Cripta",
		"vista": Rect2(0, -19, 60, 29), "inicio": Vector3(5, 0.1, 0),
		"sellos": [[46.0, 4.75, 0.6, 9.5], [56.5, -9.75, 0.6, 8.5]],
	},
	{
		"numero": "ETAPA 2", "nombre": "LAS CATACUMBAS",
		"objetivo": "Derrota a %d enemigos de las catacumbas",
		"tipo": "matar", "meta": 6,
		"vista": Rect2(44, -19, 88, 47), "inicio": Vector3(48, 0.1, 0),
		"sellos": [[130.0, 4.25, 0.6, 8.5], [130.0, -9.75, 0.6, 8.5]],
	},
	{
		"numero": "ETAPA 3", "nombre": "LA GUARDIA",
		"objetivo": "Vence al Guardián y toma la Llave del Trono",
		"tipo": "guardian", "guardian": "ColosoMuralla", "llave_nombre": "Llave del Trono",
		"vista": Rect2(126, -21, 68, 31), "inicio": Vector3(133, 0.1, 0),
		"sellos": [[183.25, -19.5, 13.5, 0.6]],
	},
	{
		"numero": "ETAPA FINAL", "nombre": "EL TRONO DE LA SOMBRA",
		"objetivo": "Derrota a la Sombra Madre",
		"tipo": "jefe",
		"vista": Rect2(96, -30, 100, 13), "inicio": Vector3(183, -27.9, 0),
		"sellos": [],
	},
]

# static: sobrevive a recargar la escena (reintento desde la etapa alcanzada).
static var etapa_guardada = 0

@export var intro = true          # cinematica al empezar
@export var vida_extra = 20.0     # vida maxima que gana Ceniza al pasar de etapa

var actual = 0
var sellos = []                   # por etapa: lista de sellos
var enemigos = []                 # por etapa: enemigos que habia al empezar
var llave = null
var guardian = null
var pos_guardian = Vector3.ZERO
var jefe = null
var hecho = false
var jugador = null
var camara = null
var entorno = null
var cinematica = null             # el Tween de la cinematica, o null
var reloj = 0.0

# Interfaz (se arma en codigo).
var capa = CanvasLayer.new()
var panel_etapa = Label.new()
var panel_objetivo = Label.new()
var titulo = Label.new()
var subtitulo = Label.new()
var texto_obj = Label.new()
var franja_arriba = ColorRect.new()
var franja_abajo = ColorRect.new()
var saltar_txt = Label.new()
var barra_jefe = ProgressBar.new()
var nombre_jefe = Label.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("etapas")
	_armar_interfaz()
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("jugador")
	camara = get_viewport().get_camera_3d()
	var we = get_tree().current_scene.find_child("WorldEnvironment", true, false)
	if we != null:
		entorno = we.environment
	var nivel = get_tree().current_scene.get_node_or_null("Nivel")
	# Sellos de cada etapa.
	for i in ETAPAS.size():
		var lista = []
		for s in ETAPAS[i]["sellos"]:
			var sello = SELLO.new()
			sello.name = "Sello%d" % (i + 1)
			nivel.add_child(sello)
			sello.armar(Vector2(s[0], s[1]), Vector2(s[2], s[3]))
			lista.append(sello)
		sellos.append(lista)
		enemigos.append([])
	# Enemigos de cada etapa (para contar los que caen).
	for e in get_tree().get_nodes_in_group("enemigos"):
		enemigos[etapa_de(e.global_position)].append(e)
	for m in get_tree().get_nodes_in_group("meta"):
		jefe = m
	# Reintento: se salta lo que ya estaba hecho.
	actual = clampi(etapa_guardada, 0, ETAPAS.size() - 1)
	for i in actual:
		for s in sellos[i]:
			s.abrir(true)
	if actual > 0 and jugador != null:
		jugador.global_position = ETAPAS[actual]["inicio"]
		var salud = jugador.get_node_or_null("Salud")
		if salud != null:
			salud.punto = ETAPAS[actual]["inicio"]
		if camara != null and "posicion_suave" in camara:
			camara.posicion_suave = jugador.global_position + Vector3(0, 3, 9.2)
			camara.global_position = camara.posicion_suave
	empezar_etapa(actual)
	if intro:
		mostrar_cinematica(actual, null)


# En que etapa queda un punto del mapa.
func etapa_de(p):
	if p.y < -19.0:
		return 3
	if p.x < 46.0 and p.y > -5.0:
		return 0
	if p.x < 56.5 and p.y <= -5.0:
		return 0
	if p.x < 130.0:
		return 1
	return 2


func empezar_etapa(i):
	actual = i
	hecho = false
	llave = null
	guardian = null
	var e = ETAPAS[i]
	if e["tipo"] == "guardian":
		# El guardian de la etapa: al caer suelta la llave.
		guardian = get_tree().current_scene.get_node("Nivel").find_child(e["guardian"], true, false)
		if guardian != null:
			pos_guardian = guardian.global_position
	if e["tipo"] == "llave":
		_soltar_llave(e["llave"], "Llave de la Cripta")
	actualizar_panel()


func _soltar_llave(pos, nombre):
	llave = LLAVE.instantiate()
	llave.nombre = nombre
	# La posicion va ANTES de add_child: la llave guarda su altura en _ready para flotar.
	llave.position = pos   # Nivel esta en el origen: local = global
	get_tree().current_scene.get_node("Nivel").add_child(llave)
	llave.recogida.connect(completar)


func _process(delta):
	reloj += delta
	# Si se gano la partida, el proximo intento empieza desde el principio.
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null and partida.estado == 1:
		etapa_guardada = 0
	if cinematica != null:
		# Saltar la cinematica.
		if Input.is_action_just_pressed("saltar") or Input.is_action_just_pressed("chispazo"):
			cinematica.custom_step(100.0)
		return
	if get_tree().paused or hecho:
		_actualizar_jefe()
		return
	var e = ETAPAS[actual]
	match e["tipo"]:
		"matar":
			if caidos(actual) >= e["meta"]:
				completar()
		"guardian":
			if guardian != null:
				if _vivo(guardian):
					pos_guardian = guardian.global_position
				elif llave == null:
					# El Guardian cae y suelta la llave.
					_soltar_llave(pos_guardian + Vector3(0, 1.2, 0), e["llave_nombre"])
					guardian = null
	actualizar_panel()
	_actualizar_jefe()


func _vivo(n):
	return is_instance_valid(n) and not n.get("muerto")


func caidos(i):
	var n = 0
	for en in enemigos[i]:
		if not _vivo(en):
			n += 1
	return n


func actualizar_panel():
	var e = ETAPAS[actual]
	panel_etapa.text = e["numero"] + "  ·  " + e["nombre"]
	var t = e["objetivo"]
	match e["tipo"]:
		"llave":
			t += "   (0/1)" if not hecho else "   (1/1)"
		"matar":
			t = t % e["meta"] + "   (%d/%d)" % [mini(caidos(actual), e["meta"]), e["meta"]]
		"guardian":
			if guardian == null and llave != null and is_instance_valid(llave):
				t = "¡Toma la " + e["llave_nombre"] + "!"
	panel_objetivo.text = "◆ " + t
	panel_objetivo.modulate = Color(0.6, 1, 0.6) if hecho else Color.WHITE


# Objetivo cumplido: se rompen los sellos, Ceniza se cura y gana vida, y la camara muestra la siguiente.
func completar():
	if hecho:
		return
	hecho = true
	actualizar_panel()
	var siguiente = actual + 1
	if siguiente >= ETAPAS.size():
		return
	etapa_guardada = siguiente
	var salud = jugador.get_node_or_null("Salud") if jugador != null else null
	if salud != null:
		salud.vida_inicial += vida_extra
		salud.curar(salud.vida_inicial)
		salud.punto = ETAPAS[siguiente]["inicio"]
	var rotos = sellos[actual]
	empezar_etapa(siguiente)
	mostrar_cinematica(siguiente, rotos)


# Cinematica: (si hay sellos) acerca la camara al sello y lo rompe, despues se aleja
# para mostrar toda la etapa con su titulo, y vuelve a Ceniza.
func mostrar_cinematica(i, rotos):
	if camara == null:
		return
	get_tree().paused = true
	_mostrar_hud(false)
	var e = ETAPAS[i]
	titulo.text = e["numero"]
	subtitulo.text = e["nombre"]
	texto_obj.text = panel_objetivo.text
	for n in [titulo, subtitulo, texto_obj, saltar_txt]:
		n.modulate.a = 0.0
	var desde = camara.global_position
	var vista = e["vista"]
	var centro = vista.get_center()
	# Distancia para que entre todo el ancho (fov vertical 52 en 16:9 -> ~41 grados a cada lado).
	var lejos = maxf(vista.size.x * 0.6, vista.size.y * 1.05) + 4.0
	var punto_vista = Vector3(centro.x, centro.y + 1.0, lejos)
	var niebla = entorno.fog_density if entorno != null else 0.0
	var ambiente = entorno.ambient_light_energy if entorno != null else 0.0
	var t = create_tween()
	cinematica = t
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(franja_arriba, "size:y", 70.0, 0.4)
	t.parallel().tween_property(franja_abajo, "position:y", get_viewport().get_visible_rect().size.y - 70.0, 0.4)
	if rotos != null and not rotos.is_empty():
		var s = rotos[0]
		t.tween_property(camara, "global_position", s.global_position + Vector3(0, 1.0, 11.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(func():
			for r in rotos:
				if is_instance_valid(r):
					r.abrir(false, self)
			Efectos.temblar(jugador, 0.2, 0.3))
		t.tween_interval(0.9)
	# Se aleja: menos niebla y mas luz para que se vea la etapa entera.
	t.tween_property(camara, "global_position", punto_vista, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if entorno != null:
		t.parallel().tween_property(entorno, "fog_density", 0.004, 1.4)
		t.parallel().tween_property(entorno, "ambient_light_energy", 1.4, 1.4)
	t.tween_property(titulo, "modulate:a", 1.0, 0.4)
	t.tween_property(subtitulo, "modulate:a", 1.0, 0.4)
	t.tween_property(texto_obj, "modulate:a", 1.0, 0.4)
	t.parallel().tween_property(saltar_txt, "modulate:a", 0.7, 0.4)
	t.tween_interval(2.4)
	t.tween_property(titulo, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(subtitulo, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(texto_obj, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(saltar_txt, "modulate:a", 0.0, 0.3)
	t.tween_property(camara, "global_position", desde, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if entorno != null:
		t.parallel().tween_property(entorno, "fog_density", niebla, 1.0)
		t.parallel().tween_property(entorno, "ambient_light_energy", ambiente, 1.0)
	t.tween_property(franja_arriba, "size:y", 0.0, 0.3)
	t.parallel().tween_property(franja_abajo, "position:y", get_viewport().get_visible_rect().size.y, 0.3)
	t.finished.connect(func():
		cinematica = null
		# Por si se salto: deja todo como estaba.
		for r in (rotos if rotos != null else []):
			if is_instance_valid(r) and not r.abierto:
				r.abrir(true)
		if entorno != null:
			entorno.fog_density = niebla
			entorno.ambient_light_energy = ambiente
		camara.global_position = desde
		_mostrar_hud(true)
		get_tree().paused = false)


func _mostrar_hud(si):
	panel_etapa.visible = si
	panel_objetivo.visible = si
	for g in ["hud", "mapa"]:
		var n = get_tree().get_first_node_in_group(g)
		if n != null:
			n.visible = si


func _actualizar_jefe():
	var ver = jefe != null and _vivo(jefe) and actual == ETAPAS.size() - 1 and jugador != null \
		and jefe.global_position.distance_to(jugador.global_position) < 22.0 and cinematica == null
	barra_jefe.visible = ver
	nombre_jefe.visible = ver
	if ver:
		barra_jefe.max_value = jefe.vida_max
		barra_jefe.value = maxf(jefe.vida, 0.0)


func _armar_interfaz():
	capa.layer = 4
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var fuente_bonita = func(l, tam, color):
		l.add_theme_font_size_override("font_size", tam)
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", maxi(6, tam / 5))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Panel del objetivo, arriba a la izquierda debajo de la zona.
	fuente_bonita.call(panel_etapa, 16, DORADO)
	panel_etapa.position = Vector2(20, 96)
	fuente_bonita.call(panel_objetivo, 19, Color.WHITE)
	panel_objetivo.position = Vector2(20, 118)
	capa.add_child(panel_etapa)
	capa.add_child(panel_objetivo)
	# Franjas de cine.
	for f in [franja_arriba, franja_abajo]:
		f.color = Color.BLACK
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.size = Vector2(4000, 70)
		capa.add_child(f)
	franja_arriba.size.y = 0.0
	franja_abajo.position.y = 4000.0
	# Titulo grande al centro.
	for par in [[titulo, 30, DORADO, 0.36], [subtitulo, 64, Color.WHITE, 0.43], [texto_obj, 24, Color(0.9, 0.9, 1.0), 0.55]]:
		var l = par[0]
		fuente_bonita.call(l, par[1], par[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_TOP_WIDE)
		l.anchor_top = par[3]
		l.anchor_bottom = par[3]
		l.modulate.a = 0.0
		capa.add_child(l)
	fuente_bonita.call(saltar_txt, 15, Color(1, 1, 1, 0.8))
	saltar_txt.text = "ESPACIO: saltar"
	saltar_txt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	saltar_txt.position = Vector2(-170, -55)
	saltar_txt.modulate.a = 0.0
	capa.add_child(saltar_txt)
	# Barra del jefe arriba al centro.
	var fondo = StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.03, 0.05, 0.9)
	fondo.set_border_width_all(2)
	fondo.border_color = Color(0.7, 0.2, 0.2)
	fondo.set_corner_radius_all(4)
	var relleno = StyleBoxFlat.new()
	relleno.bg_color = ROJO
	relleno.set_corner_radius_all(3)
	barra_jefe.add_theme_stylebox_override("background", fondo)
	barra_jefe.add_theme_stylebox_override("fill", relleno)
	barra_jefe.show_percentage = false
	barra_jefe.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barra_jefe.size = Vector2(560, 20)
	barra_jefe.position = Vector2(-280, -128)
	barra_jefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_jefe.visible = false
	capa.add_child(barra_jefe)
	fuente_bonita.call(nombre_jefe, 20, Color(1, 0.75, 0.7))
	nombre_jefe.text = "SOMBRA MADRE"
	nombre_jefe.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	nombre_jefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_jefe.size = Vector2(560, 26)
	nombre_jefe.position = Vector2(-280, -156)
	nombre_jefe.visible = false
	capa.add_child(nombre_jefe)
