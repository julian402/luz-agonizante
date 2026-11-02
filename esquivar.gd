extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "esquivar"
@export var duracion = 0.3
@export var recarga = 1.0
@export var distancia = 4.0
@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0


func _physics_process(delta):
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
	return pj.is_on_floor()   # solo en el suelo


func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	pj.empuje = -pj.basis.z * (distancia / duracion)
	pj.multiplicador = 0.0
	pj.accion = "crouch"
	print("empieza: ", tecla)
	print("invulnerable")


func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.empuje = Vector3.ZERO
	pj.multiplicador = 1.0
	pj.accion = ""
	print("vulnerable")
	print("termina: ", tecla)
