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


# --- Enchufes de la V2 ---

# Explosion corta de cuadritos de color. Se borra sola cuando termina.
static func chispas(padre, pos, color, cantidad = 12):
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.amount = cantidad
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = color
	var q = QuadMesh.new()
	q.material = m
	p.mesh = q
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


# El enemigo se pone del color, se encoge en 0.25 s y suelta chispas.
# Uso: await Efectos.muerte($Modelo, color) antes del queue_free().
static func muerte(modelo, color):
	if not is_instance_valid(modelo):
		return
	var tinte = StandardMaterial3D.new()
	tinte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinte.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinte.albedo_color = Color(color.r, color.g, color.b, 0.85)
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = tinte
	var centro = modelo.global_position + Vector3(0, 0.8, 0)
	# Las chispas van en el nivel (el abuelo del modelo): el enemigo se borra despues.
	var padre = modelo.get_parent().get_parent() if modelo.get_parent() != null else null
	if padre == null:
		padre = modelo.get_tree().current_scene
	if padre != null:
		chispas(padre, centro, color, 24)
	var t = modelo.create_tween()
	t.tween_property(modelo, "scale", modelo.scale * 0.1, 0.25)
	await t.finished


# Anillo plano en el piso que crece y se borra (aterrizajes, picadas, golpes fuertes).
static func anillo(padre, pos, color, radio = 1.5):
	var malla = TorusMesh.new()
	malla.inner_radius = 0.85
	malla.outer_radius = 1.0
	malla.rings = 24
	malla.ring_segments = 6
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	var a = MeshInstance3D.new()
	a.mesh = malla
	a.material_override = m
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(a)
	a.global_position = pos + Vector3(0, 0.05, 0)
	a.scale = Vector3(0.2, 0.2, 0.2)
	var t = a.create_tween()
	t.tween_property(a, "scale", Vector3(radio, 0.3, radio), 0.3)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, 0.3)
	t.tween_callback(a.queue_free)
