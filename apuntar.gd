extends Node

@export var tecla = "chispazo"
@export var alcance = 2.0
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 1
@export var cadencia = 0.3
@export var danio_remate = 2   # daño del 3.er golpe del combo
@onready var pj = get_parent()

var origen = Vector3.ZERO   # de dónde sale el rayo
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
			return
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
	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)
