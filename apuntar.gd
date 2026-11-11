extends Node

@export var tecla = "chispazo"
@export var alcance = 2.0
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 1
@export var cadencia = 0.3
@export var danio_remate = 2   # daño del 3.er golpe del combo
@onready var pj = get_parent()

var origen = Vector3.ZERO   # de dónde sale el rayo
var hasta = Vector3.ZERO    # dónde termina el rayo
var espera = 0.0
var combo = 0   # golpes seguidos; al soltar la tecla vuelve a 0


func _physics_process(delta):
	espera -= delta
	if not Input.is_action_pressed(tecla):
		combo = 0
	if Input.is_action_pressed(tecla) and espera <= 0.001:
		espera = cadencia
		combo += 1
		var este_danio = danio
		if combo == 3:   # el remate del combo
			este_danio = danio_remate
			combo = 0
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


# El rayo no se ve: se pone una chispa naranja donde pega (o donde termina).
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
