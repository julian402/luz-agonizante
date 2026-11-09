extends Node

# Avisa cuando la vida cambia y cuando llega a 0. No sabe quien escucha.
signal cambio(vida)
signal sin_vida

@export var vida = 3
@export var invulnerable = 1.0
# Cuantas veces vuelve al punto antes de perder.
@export var reapariciones = 1
@export var espera_reaparecer = 2.0
var reloj = 0.0
var vida_inicial = 0
var punto = Vector3.ZERO
@onready var pj = get_parent()


func _ready():
	sin_vida.connect(_al_quedar_sin_vida)
	# Se guardan al empezar, antes de cualquier golpe.
	vida_inicial = vida
	punto = pj.global_position


func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)


func recibir_golpe(danio):
	if reloj > 0.001 or vida == 0:
		return
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	cambio.emit(vida)
	if vida == 0:
		sin_vida.emit()


# Se busca aqui y no en _ready(): la Partida quiza todavia no existia.
func _al_quedar_sin_vida():
	if reapariciones > 0:
		reapariciones -= 1
		vida = vida_inicial
		pj.global_position = punto
		# La proteccion al reaparecer es el mismo reloj, pero mas largo.
		reloj = espera_reaparecer
		cambio.emit(vida)
		print("reaparece cuadro ", Engine.get_physics_frames())
		return
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.perder("sin vida")
