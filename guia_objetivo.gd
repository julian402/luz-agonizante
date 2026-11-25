extends CanvasLayer

# Guia hacia el objetivo de la etapa:
#  - Un rombo dorado con "OBJETIVO" flota sobre lo que hay que hacer (guardian, llave, jefe,
#    o el enemigo mas cercano en la etapa de "derrota N").
#  - Si no esta en pantalla, una flecha dorada en el borde apunta hacia alla y dice a cuantos metros.

const DORADO = Color("#F2C14E")
const MARGEN = 56.0

var etapas = null
var jugador: Node3D = null
var camara: Camera3D = null
var lienzo = Control.new()
var marca = Node3D.new()
var rombo = MeshInstance3D.new()
var texto = Label3D.new()
var objetivo = null        # Vector3 o null
var t = 0.0


func _ready():
	layer = 3
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)
	await get_tree().process_frame
	etapas = get_tree().get_first_node_in_group("etapas")
	jugador = get_tree().get_first_node_in_group("jugador")
	var nivel = get_tree().current_scene.get_node_or_null("Nivel")
	if nivel == null:
		return
	# Marca 3D: rombo dorado que gira y el texto "OBJETIVO" (se ven a traves de las paredes).
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DORADO
	mat.no_depth_test = true
	mat.render_priority = 10
	var caja = BoxMesh.new()
	caja.size = Vector3(0.32, 0.32, 0.32)
	caja.material = mat
	rombo.mesh = caja
	rombo.rotation_degrees = Vector3(0, 0, 45)
	rombo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marca.add_child(rombo)
	texto.text = "OBJETIVO"
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.no_depth_test = true
	texto.render_priority = 10
	texto.pixel_size = 0.006
	texto.font_size = 34
	texto.outline_size = 12
	texto.modulate = DORADO
	texto.outline_modulate = Color(0.03, 0.03, 0.05, 0.95)
	texto.position.y = 0.55
	marca.add_child(texto)
	marca.visible = false
	nivel.add_child(marca)


func _buscar_objetivo():
	if etapas == null or etapas.hecho:
		return null
	var p = etapas.objetivo_pos()
	if p != null:
		return p + Vector3(0, 1.4, 0)
	# Etapa de "derrota N": el enemigo vivo mas cercano de la etapa.
	if etapas.ETAPAS[etapas.actual]["tipo"] == "matar" and jugador != null:
		var mejor = null
		var d_mejor = INF
		for e in etapas.enemigos_vivos():
			var d = e.global_position.distance_to(jugador.global_position)
			if d < d_mejor:
				d_mejor = d
				mejor = e
		if mejor != null:
			return mejor.global_position + Vector3(0, 2.6, 0)
	return null


func _process(delta):
	t += delta
	if camara == null or not is_instance_valid(camara):
		camara = get_viewport().get_camera_3d()
	var mapa = get_tree().get_first_node_in_group("mapa")
	var oculto = get_tree().paused or (mapa != null and mapa.abierto) or jugador == null
	objetivo = null if oculto else _buscar_objetivo()
	if objetivo == null:
		marca.visible = false
	else:
		marca.visible = true
		marca.global_position = objetivo + Vector3(0, 0.12 * sin(t * 3.0), 0)
		rombo.rotation.y = t * 2.0
		var d = objetivo.distance_to(jugador.global_position)
		texto.text = "OBJETIVO" if d < 12.0 else "OBJETIVO  %d m" % roundi(d)
	lienzo.queue_redraw()


func _dibujar():
	if objetivo == null or camara == null:
		return
	var r = lienzo.get_rect()
	var detras = camara.is_position_behind(objetivo)
	var p = camara.unproject_position(objetivo)
	var dentro = Rect2(r.position + Vector2(MARGEN, MARGEN), r.size - Vector2(MARGEN, MARGEN) * 2)
	if not detras and dentro.has_point(p):
		return   # se ve en pantalla: basta la marca 3D
	var centro = r.size * 0.5
	var dir = (p - centro)
	if detras:
		dir = -dir
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	# Punto en el borde del rectangulo interior en esa direccion.
	var esc = minf(
		(dentro.size.x * 0.5) / maxf(absf(dir.x), 0.001),
		(dentro.size.y * 0.5) / maxf(absf(dir.y), 0.001))
	var punta = centro + dir * esc
	var latido = 1.0 + 0.12 * sin(t * 6.0)
	var lado = dir.orthogonal()
	var tam = 22.0 * latido
	var tri = PackedVector2Array([punta + dir * tam, punta - dir * tam * 0.6 + lado * tam * 0.8, punta - dir * tam * 0.6 - lado * tam * 0.8])
	var borde = PackedVector2Array([punta + dir * (tam + 4), punta - dir * (tam * 0.6 + 3) + lado * (tam * 0.8 + 4), punta - dir * (tam * 0.6 + 3) - lado * (tam * 0.8 + 4)])
	lienzo.draw_colored_polygon(borde, Color(0, 0, 0, 0.8))
	lienzo.draw_colored_polygon(tri, DORADO)
	var d = roundi(objetivo.distance_to(jugador.global_position))
	var fuente = ThemeDB.fallback_font
	var cadena = "OBJETIVO  %d m" % d
	var ancho = fuente.get_string_size(cadena, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var pos_txt = punta - dir * 46.0 - Vector2(ancho * 0.5, -6)
	pos_txt.x = clampf(pos_txt.x, 8.0, r.size.x - ancho - 8.0)
	pos_txt.y = clampf(pos_txt.y, 20.0, r.size.y - 8.0)
	lienzo.draw_string_outline(fuente, pos_txt, cadena, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Color.BLACK)
	lienzo.draw_string(fuente, pos_txt, cadena, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DORADO)
