extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 2.2, 9.5)
@export var altura_mira = 1.3
@export var suavizado = 4.0
@export var limite_min = Vector2(-12, -10)   # x y z mínimas
@export var limite_max = Vector2(12, 10)     # x y z máximas

var temblor = 0.0
var t_temblor = 0.0

func temblar(fuerza, duracion):
	temblor = maxf(temblor, fuerza)
	t_temblor = maxf(t_temblor, duracion)

func _ready():
	top_level = true
	# Se orienta UNA vez, mirando al objetivo.
	var mira = objetivo.global_position + Vector3(0, altura_mira, 0)
	look_at_from_position(mira + distancia, mira)


func _physics_process(delta):
	var foco = objetivo.global_position
	foco.x = clamp(foco.x, limite_min.x, limite_max.x)
	foco.z = clamp(foco.z, limite_min.y, limite_max.y)
	var destino = foco + Vector3(0, altura_mira, 0) + distancia
	global_position = global_position.lerp(destino, suavizado * delta)
	if t_temblor > 0.0:
		t_temblor = maxf(t_temblor - delta, 0.0)
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * temblor
		if t_temblor <= 0.0:
			temblor = 0.0
