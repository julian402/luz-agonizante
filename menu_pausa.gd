extends CanvasLayer

# Menu de pausa (Esc): Reanudar, Reiniciar, Salir.
# Se arma en codigo, con los colores del juego: fondo oscuro, dorado de las antorchas y morado de la sombra.
# No se abre durante una cinematica ni con la partida terminada; con el mapa abierto, Esc cierra el mapa.

const DORADO = Color("#F2C14E")
const MORADO = Color(0.62, 0.42, 1.0)
const OSCURO = Color(0.04, 0.03, 0.07)

var abierto = false
var tiempo = 0.0
var raiz = Control.new()
var fondo = ColorRect.new()
var vineta = Control.new()
var caja = PanelContainer.new()
var info = Label.new()
var botones = []
var llama = Control.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	add_to_group("menu_pausa")
	_armar()
	raiz.visible = false


func _unhandled_input(evento):
	if evento.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		if abierto:
			cerrar()
		else:
			abrir()


func abrir():
	var mapa = get_tree().get_first_node_in_group("mapa")
	if mapa != null and mapa.abierto:
		mapa.alternar()   # Esc con el mapa abierto: solo cierra el mapa
		return
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null and partida.estado != 0:
		return
	if get_tree().paused:   # cinematica u otra pausa
		return
	abierto = true
	get_tree().paused = true
	_actualizar_info()
	raiz.visible = true
	raiz.modulate.a = 0.0
	caja.scale = Vector2(0.92, 0.92)
	var t = create_tween().set_parallel()
	t.tween_property(raiz, "modulate:a", 1.0, 0.18)
	t.tween_property(caja, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	botones[0].grab_focus()


func cerrar():
	abierto = false
	raiz.visible = false
	get_tree().paused = false


func _reiniciar():
	abierto = false
	raiz.visible = false
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.reiniciar()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _salir():
	get_tree().quit()


func _process(delta):
	tiempo += delta
	if abierto:
		llama.queue_redraw()
		vineta.queue_redraw()


func _actualizar_info():
	var lineas = []
	var etapas = get_tree().get_first_node_in_group("etapas")
	if etapas != null:
		lineas.append(etapas.panel_etapa.text)
		lineas.append(etapas.panel_objetivo.text)
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		var s = int(partida.tiempo)
		lineas.append("Tiempo restante  %d:%02d" % [s / 60, s % 60])
	info.text = "\n".join(lineas)


func _estilo(fondo_c, borde_c, ancho_borde = 2):
	var s = StyleBoxFlat.new()
	s.bg_color = fondo_c
	s.border_color = borde_c
	s.set_border_width_all(ancho_borde)
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _armar():
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	fondo.color = Color(0.0, 0.0, 0.02, 0.72)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fondo)
	# Vineta: borde morado que respira.
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.draw.connect(func():
		var r = vineta.get_rect()
		var a = 0.18 + 0.06 * sin(tiempo * 2.0)
		for i in 12:
			var g = i * 6.0
			vineta.draw_rect(Rect2(Vector2(g, g), r.size - Vector2(g, g) * 2), Color(MORADO, a * (1.0 - i / 12.0) * 0.35), false, 6.0))
	raiz.add_child(vineta)

	var centro = CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	caja.add_theme_stylebox_override("panel", _estilo(Color(OSCURO, 0.96), Color(DORADO, 0.75), 2))
	caja.custom_minimum_size = Vector2(440, 0)
	caja.resized.connect(func(): caja.pivot_offset = caja.size * 0.5)
	centro.add_child(caja)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	caja.add_child(col)

	# Llamita animada arriba del titulo.
	llama.custom_minimum_size = Vector2(0, 46)
	llama.draw.connect(_dibujar_llama)
	col.add_child(llama)

	var titulo = _texto("PAUSA", 44, DORADO)
	col.add_child(titulo)
	var sub = _texto("LUZ AGONIZANTE", 15, Color(1, 1, 1, 0.55))
	col.add_child(sub)

	var raya = ColorRect.new()
	raya.color = Color(DORADO, 0.35)
	raya.custom_minimum_size = Vector2(0, 2)
	col.add_child(raya)

	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)

	var lista = [["REANUDAR", cerrar], ["REINICIAR", _reiniciar]]
	if not OS.has_feature("web"):   # en el navegador no se puede cerrar la pestaña desde el juego
		lista.append(["SALIR", _salir])
	for par in lista:
		var b = Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
		b.add_theme_color_override("font_hover_color", OSCURO)
		b.add_theme_color_override("font_focus_color", OSCURO)
		b.add_theme_color_override("font_pressed_color", OSCURO)
		b.add_theme_color_override("font_hover_pressed_color", OSCURO)
		b.add_theme_stylebox_override("normal", _estilo(Color(0.1, 0.08, 0.14), Color(MORADO, 0.5), 1))
		b.add_theme_stylebox_override("hover", _estilo(DORADO, DORADO.lightened(0.3), 2))
		b.add_theme_stylebox_override("focus", _estilo(DORADO, DORADO.lightened(0.3), 2))
		b.add_theme_stylebox_override("pressed", _estilo(DORADO.darkened(0.2), DORADO, 2))
		b.pressed.connect(par[1])
		b.mouse_entered.connect(b.grab_focus)
		col.add_child(b)
		botones.append(b)

	var ayuda = _texto("ESC: reanudar    FLECHAS: elegir    ENTER: aceptar", 13, Color(1, 1, 1, 0.45))
	col.add_child(ayuda)
	var controles = _texto("A/D moverse · ESPACIO saltar · SHIFT esquivar · J atacar · K estallido · M mapa", 13, Color(DORADO, 0.6))
	controles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(controles)


func _texto(t, tam, color):
	var l = Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


# La llama de Ceniza: se mueve un poco, como una vela.
func _dibujar_llama():
	var c = Vector2(llama.size.x * 0.5, 40)
	var mueve = sin(tiempo * 7.0) * 1.5
	for capa in [[20.0, Color(DORADO, 0.18)], [15.0, Color("#E8833A")], [10.0, DORADO], [5.0, Color(1, 0.95, 0.8)]]:
		var r = capa[0]
		var puntos = PackedVector2Array()
		for k in 20:
			var a = TAU * k / 20.0
			var p = Vector2(sin(a) * r * 0.62, -cos(a) * r * 0.75)
			if p.y < 0.0:
				p.x *= 1.0 + p.y / (r * 1.5)
				p.y *= 1.6
				p.x += mueve * (-p.y / (r * 1.2))
			puntos.append(c + p + Vector2(0, -r * 0.4))
		llama.draw_colored_polygon(puntos, capa[1])
