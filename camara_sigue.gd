extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 1.35, 9.2)
@export var altura_mira = 1.6
@export var adelanto_x = 1.25
@export var suavizado_x = 5.5
@export var suavizado_y = 4.5
@export var limite_min = Vector2(8.0, -26.2)   # x y y minimas
@export var limite_max = Vector2(196.0, 26.5)   # x y y maximas

var temblor = 0.0
var t_temblor = 0.0
var mirada_actual = 0.0
var posicion_suave = Vector3.ZERO


func temblar(fuerza, duracion):
	temblor = maxf(temblor, fuerza)
	t_temblor = maxf(t_temblor, duracion)


func _foco_objetivo() -> Vector3:
	var pos = objetivo.global_position
	var fx = clampf(pos.x + mirada_actual, limite_min.x, limite_max.x)
	var fy = clampf(pos.y + altura_mira, limite_min.y, limite_max.y)
	return Vector3(fx, fy, pos.z)


func _ready():
	top_level = true
	var foco = _foco_objetivo()
	look_at_from_position(foco + distancia, foco)
	posicion_suave = global_position


func _physics_process(delta):
	var dir_x = 0.0
	if "velocity" in objetivo and absf(objetivo.velocity.x) > 0.4:
		dir_x = signf(objetivo.velocity.x) * adelanto_x
	mirada_actual = lerpf(mirada_actual, dir_x, 3.0 * delta)

	var destino = _foco_objetivo() + distancia
	posicion_suave.x = lerpf(posicion_suave.x, destino.x, 1.0 - exp(-suavizado_x * delta))
	posicion_suave.y = lerpf(posicion_suave.y, destino.y, 1.0 - exp(-suavizado_y * delta))
	posicion_suave.z = lerpf(posicion_suave.z, destino.z, 1.0 - exp(-suavizado_x * delta))
	global_position = posicion_suave

	if t_temblor > 0.0:
		t_temblor = maxf(t_temblor - delta, 0.0)
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * temblor
		if t_temblor <= 0.0:
			temblor = 0.0
