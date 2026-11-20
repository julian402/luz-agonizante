extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "esquivar"
@export var duracion = 0.26
@export var recarga = 0.65
@export var distancia = 4.2
@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var esquivas_aire = 1


func _physics_process(delta):
	if pj.is_on_floor():
		esquivas_aire = 1
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla) and puede():
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:   # 0.001 y no 0: restar 1/60 no da exacto
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA


func puede():
	return pj.is_on_floor() or esquivas_aire > 0


func empezar():
	if not pj.is_on_floor():
		esquivas_aire = max(esquivas_aire - 1, 0)
	estado = Estado.ACTIVA
	tiempo = duracion
	var dir_input = Input.get_axis("move_left", "move_right")
	if absf(dir_input) > 0.1:
		pj.basis = Basis.looking_at(Vector3(signf(dir_input), 0.0, 0.0))
	var dir_x = signf(-pj.basis.z.x)
	if absf(dir_x) < 0.1:
		dir_x = 1.0
	pj.empuje = Vector3(dir_x * (distancia / duracion), 0.0, 0.0)
	pj.multiplicador = 0.0
	pj.accion = "crouch"
	print("empieza: ", tecla)
	var salud = pj.get_node_or_null("Salud")
	if salud != null:
		salud.proteger(duracion)
	var modelo = pj.get_node_or_null("Modelo")
	if modelo != null:
		Efectos.destello(modelo, 0.08)


func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.empuje = Vector3.ZERO
	pj.multiplicador = 1.0
	pj.accion = ""
	print("vulnerable")
	print("termina: ", tecla)
