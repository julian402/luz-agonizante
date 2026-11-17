extends Node3D

# Barra de vida encima de un enemigo. El enemigo llama poner(vida, maxima).
@export var ancho = 1.0
@onready var frente = $Frente


func _ready():
	# Con la vida llena no se muestra: menos cosas en pantalla.
	visible = false


# Siempre de frente a la camara, como un cartel.
func _process(_delta):
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		global_basis = cam.global_basis


func poner(vida, maxima):
	var parte = clampf(float(vida) / maxima, 0.0, 1.0)
	visible = parte < 1.0
	# Se vacia de derecha a izquierda: se achica y se corre a la izquierda.
	frente.scale.x = maxf(parte, 0.001)
	frente.position.x = -ancho * (1.0 - parte) / 2.0
