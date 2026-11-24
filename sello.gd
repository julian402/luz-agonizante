extends StaticBody3D

# Sello de luz: una pared (o un piso) brillante que cierra el paso a la siguiente etapa.
# Lo crean las Etapas con armar(); se rompe con abrir().

const COLOR = Color(0.62, 0.42, 1.0)
var caja = Vector2.ONE       # ancho y alto en metros
var mat = StandardMaterial3D.new()
var tiempo = 0.0
var abierto = false
var particulas = null


func armar(centro: Vector2, tamano: Vector2):
	caja = tamano
	position = Vector3(centro.x, centro.y, 0)
	collision_layer = 1
	collision_mask = 0
	add_to_group("sellos")
	# Sigue vivo con el juego en pausa: se rompe durante la cinematica.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var forma = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(tamano.x, tamano.y, 4.0)
	forma.shape = box
	add_child(forma)
	# Malla: plano brillante y transparente en el plano del juego.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(COLOR, 0.35)
	var malla = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = Vector3(tamano.x, tamano.y, 0.3)
	malla.mesh = b
	malla.material_override = mat
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla)
	# Motas que suben por el sello.
	particulas = CPUParticles3D.new()
	particulas.amount = 24
	particulas.lifetime = 1.4
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = Vector3(tamano.x * 0.5, tamano.y * 0.5, 0.2)
	particulas.direction = Vector3.UP
	particulas.spread = 10.0
	particulas.gravity = Vector3(0, 0.8, 0)
	particulas.initial_velocity_min = 0.2
	particulas.initial_velocity_max = 0.6
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.0
	particulas.color = Color(0.8, 0.65, 1.0)
	var q = QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var mq = StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.vertex_color_use_as_albedo = true
	q.material = mq
	particulas.mesh = q
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particulas)
	var luz = OmniLight3D.new()
	luz.light_color = COLOR
	luz.light_energy = 0.7
	luz.omni_range = 3.5
	luz.name = "Luz"
	add_child(luz)
	var cartel = Label3D.new()
	cartel.text = "SELLO DE LUZ"
	cartel.font_size = 40
	cartel.outline_size = 10
	cartel.pixel_size = 0.01
	cartel.modulate = Color(0.85, 0.75, 1.0)
	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.position = Vector3(0, minf(tamano.y * 0.5 - 0.5, 2.5), 0.4)
	cartel.name = "Cartel"
	add_child(cartel)


func _process(delta):
	tiempo += delta
	if not abierto:
		mat.albedo_color.a = 0.28 + 0.1 * sin(tiempo * 3.0)


# Se deshace: brilla, suelta chispas, se apaga y desaparece.
# padre_fx: un nodo que no se pausa (los efectos se ven aunque el juego este en pausa).
func abrir(de_golpe = false, padre_fx = null):
	if abierto:
		return
	abierto = true
	collision_layer = 0
	if de_golpe:
		queue_free()
		return
	var centro = global_position
	if padre_fx == null:
		padre_fx = get_parent()
	Efectos.chispas(padre_fx, centro, Color(0.85, 0.7, 1.0), 40)
	Efectos.anillo(padre_fx, centro - Vector3(0, caja.y * 0.5, 0), COLOR, 3.0)
	particulas.emitting = false
	var t = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(mat, "albedo_color", Color(1, 1, 1, 0.9), 0.15)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	t.parallel().tween_property($Luz, "light_energy", 0.0, 0.5)
	t.parallel().tween_property($Cartel, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
