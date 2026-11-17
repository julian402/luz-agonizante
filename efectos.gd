class_name Efectos
extends RefCounted

# Efectos de golpe que usan todos (Ceniza, Coloso, Carronero).
# Son "static": se llaman sin crear nada, por ejemplo Efectos.hitstop(get_tree(), 0.05).

# Cuantos hitstop hay andando: el juego vuelve a velocidad normal cuando acaba el ultimo.
static var congelados = 0
static var blanco = null


# Numero que sube 1 m en 0.6 s y desaparece.
static func numero(padre, pos, texto, color):
	var l = Label3D.new()
	l.text = texto
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.008
	padre.add_child(l)
	l.global_position = pos
	var t = l.create_tween()
	t.tween_property(l, "global_position", pos + Vector3(0, 1, 0), 0.6)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)


# Congela el juego un instante: el golpe "pesa".
# El ultimo true del timer: cuenta en tiempo real, no en el tiempo congelado.
static func hitstop(arbol, segundos):
	congelados += 1
	Engine.time_scale = 0.05
	await arbol.create_timer(segundos, true, false, true).timeout
	congelados -= 1
	if congelados <= 0:
		congelados = 0
		Engine.time_scale = 1.0


# Pone blanco todo el modelo un momento (encima de su color, sin cambiarlo).
static func destello(modelo, segundos):
	if blanco == null:
		blanco = StandardMaterial3D.new()
		blanco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blanco.albedo_color = Color(1, 1, 1, 0.85)
		blanco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mallas = modelo.find_children("*", "MeshInstance3D", true, false)
	for m in mallas:
		m.material_overlay = blanco
	await modelo.get_tree().create_timer(segundos, true, false, true).timeout
	for m in mallas:
		if is_instance_valid(m):
			m.material_overlay = null


# Sacude la camara si sabe hacerlo (el temblor lo hace Diomar en camara_sigue.gd).
static func temblar(nodo, fuerza, duracion):
	var cam = nodo.get_viewport().get_camera_3d()
	if cam != null and cam.has_method("temblar"):
		cam.temblar(fuerza, duracion)
