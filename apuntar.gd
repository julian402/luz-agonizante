extends Node

@export var tecla = "chispazo"
@export var alcance = 2.0
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 1
@export var cadencia = 0.3
@export var danio_remate = 2   # daño del 3.er golpe del combo
# Desde el Personaje ya no es un rayo: es una bola delante de Ceniza (se falla menos).
@export var radio_golpe = 0.9
@export var distancia_golpe = 1.1
# Empujoncito hacia adelante al atacar (m/s) y lo que dura la animación.
@export var empujon = 2.0
@export var tiempo_animacion = 0.2
@export var ventana_combo = 0.55
@onready var pj = get_parent()

var origen = Vector3.ZERO   # de dónde sale el rayo
var hasta = Vector3.ZERO    # dónde termina el rayo
var espera = 0.0
var reloj_combo = 0.0
var combo = 0   # golpes seguidos; vuelve a 0 al expirar la ventana de combo
var bola_golpe = SphereShape3D.new()
var consulta_golpe = PhysicsShapeQueryParameters3D.new()


func _ready():
	bola_golpe.radius = radio_golpe
	consulta_golpe.shape = bola_golpe
	consulta_golpe.exclude = [pj.get_rid()]


func _physics_process(delta):
	espera -= delta
	reloj_combo = maxf(reloj_combo - delta, 0.0)
	if reloj_combo <= 0.0:
		combo = 0
	if Input.is_action_pressed(tecla) and espera <= 0.001:
		espera = cadencia
		reloj_combo = ventana_combo
		combo += 1
		var este_danio = danio
		var remate = combo == 3
		if remate:   # el remate del combo
			este_danio = danio_remate
			combo = 0
		animar_ataque()
		mostrar_arco(remate)
		if remate:
			Efectos.temblar(pj, 0.08, 0.15)
		if desde == 0:
			golpe_cercano(este_danio)
		else:
			golpe_rayo(este_danio)


# Una bola delante del pecho: le pega a todo lo que toque, no solo a lo del centro.
func golpe_cercano(este_danio):
	var adelante = -pj.global_basis.z
	var centro = pj.global_position + Vector3(0, 0.9, 0) + adelante * distancia_golpe
	bola_golpe.radius = radio_golpe
	consulta_golpe.transform = Transform3D(Basis.IDENTITY, centro)
	var tocados = pj.get_world_3d().direct_space_state.intersect_shape(consulta_golpe, 8)
	var golpeados = []
	for t in tocados:
		var c = t.collider
		if c in golpeados or not c.has_method("recibir_golpe"):
			continue
		golpeados.append(c)
		mostrar_chispa(c.global_position + Vector3(0, 1, 0) - adelante * 0.3, 0.3)
		print("le dio a ", c.name, " a ", snappedf(pj.global_position.distance_to(c.global_position), 0.01), " m")
		c.recibir_golpe(este_danio)
	if golpeados.is_empty():
		print("no le dio a nada")


# Desde la cámara o el mouse se sigue usando el rayo del Taller 8.
func golpe_rayo(este_danio):
	var golpe = lanzar_rayo()
	if golpe.is_empty():
		print("no le dio a nada en ", alcance, " m")
		mostrar_chispa(hasta, 0.12)
		return
	mostrar_chispa(golpe.position, 0.3)
	var d = snappedf(origen.distance_to(golpe.position), 0.01)
	print("le dio a ", golpe.collider.name, " a ", d, " m")
	if golpe.collider.has_method("recibir_golpe"):
		golpe.collider.recibir_golpe(este_danio)


func lanzar_rayo():
	var hacia
	if desde == 0:   # desde el pecho, hacia donde mira el personaje
		origen = pj.global_position + Vector3(0, 0.8, 0)
		hacia = origen - pj.global_basis.z * alcance
	else:            # desde la cámara, por un punto de la pantalla
		var cam = get_viewport().get_camera_3d()
		var punto = get_viewport().get_visible_rect().size / 2
		if desde == 2:
			punto = get_viewport().get_mouse_position()
		origen = cam.project_ray_origin(punto)
		hacia = origen + cam.project_ray_normal(punto) * alcance
	hasta = hacia
	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)


# Usa los enchufes del Personaje: animación y empujón (sin tocar personaje.gd).
# Si la esquiva está activa (ya usa accion y empuje), no se pisa.
func animar_ataque():
	var esquiva = pj.get_node_or_null("Esquivar")
	if esquiva != null and esquiva.estado == 1:
		return
	if pj.accion != "" or pj.empuje != Vector3.ZERO:
		return
	pj.accion = "attack-melee-right"
	var empuje = -pj.global_basis.z * empujon
	empuje.y = 0.0
	pj.empuje = empuje
	get_tree().create_timer(0.1).timeout.connect(func():
		if pj.empuje == empuje:
			pj.empuje = Vector3.ZERO)
	get_tree().create_timer(tiempo_animacion).timeout.connect(func():
		if pj.accion == "attack-melee-right":
			pj.accion = "")


# Medio arco delante de Ceniza: de arriba hacia abajo, como un tajo.
# Golpe normal naranja; el remate es blanco y más grande.
func mostrar_arco(remate):
	var adentro = 0.6
	var afuera = 1.3
	var color = Color(1.0, 0.7, 0.28, 0.75)
	var dura = 0.12
	if remate:
		afuera = 1.7
		color = Color(1, 1, 1, 0.9)
		dura = 0.18
	var malla = ImmediateMesh.new()
	malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var pasos = 12
	for i in pasos + 1:
		# De 75 grados (arriba) a -45 grados (abajo), mirando hacia adelante (-z).
		var a = deg_to_rad(lerpf(75.0, -45.0, float(i) / pasos))
		var dir = Vector3(0, sin(a), -cos(a))
		malla.surface_add_vertex(dir * adentro)
		malla.surface_add_vertex(dir * afuera)
	malla.surface_end()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	var arco = MeshInstance3D.new()
	arco.mesh = malla
	arco.material_override = mat
	arco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.get_parent().add_child(arco)
	arco.global_transform = Transform3D(pj.global_basis.orthonormalized(), pj.global_position + Vector3(0, 0.9, 0))
	var t = arco.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, dura)
	t.tween_callback(arco.queue_free)


# El golpe se marca con una chispa naranja donde pega (o donde termina).
func mostrar_chispa(punto, tamano):
	var chispa = MeshInstance3D.new()
	var bola = SphereMesh.new()
	bola.radius = tamano
	bola.height = tamano * 2
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#FFB347")
	# Se dibuja encima del modelo: si no, queda escondida dentro del Coloso.
	mat.no_depth_test = true
	bola.material = mat
	chispa.mesh = bola
	var luz = OmniLight3D.new()
	luz.light_color = Color("#FFB347")
	luz.light_energy = 3.0
	luz.omni_range = 2.5
	chispa.add_child(luz)
	pj.get_parent().add_child(chispa)
	chispa.global_position = punto
	# Dura 0.1 s y se borra.
	get_tree().create_timer(0.1).timeout.connect(chispa.queue_free)
