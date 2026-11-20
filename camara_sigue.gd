extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 1.35, 9.2)
@export var altura_mira = 1.6
@export var adelanto_x = 1.25
@export var suavizado_x = 5.5
@export var suavizado_y = 4.2
@export var limite_min = Vector2(7.5, 0)
@export var limite_max = Vector2(278.5, 0)

var temblor = 0.0
var t_temblor = 0.0
var mirada_actual = 0.0


func temblar(fuerza, duracion):
	temblor = maxf(temblor, fuerza)
	t_temblor = maxf(t_temblor, duracion)


func _foco_objetivo() -> Vector3:
	var pos = objetivo.global_position
	var fx = clampf(pos.x + mirada_actual, limite_min.x, limite_max.x)
	var fy = pos.y + altura_mira
	var fz = clampf(pos.z, limite_min.y, limite_max.y)
	return Vector3(fx, fy, fz)


func _ready():
	top_level = true
	var foco = _foco_objetivo()
	look_at_from_position(foco + distancia, foco)


func _physics_process(delta):
	var dir_x = 0.0
	if "velocity" in objetivo and absf(objetivo.velocity.x) > 0.4:
		dir_x = signf(objetivo.velocity.x) * adelanto_x
	mirada_actual = lerpf(mirada_actual, dir_x, 3.0 * delta)

	var destino = _foco_objetivo() + distancia
	global_position.x = lerpf(global_position.x, destino.x, minf(suavizado_x * delta, 1.0))
	global_position.y = lerpf(global_position.y, destino.y, minf(suavizado_y * delta, 1.0))
	global_position.z = lerpf(global_position.z, destino.z, minf(suavizado_x * delta, 1.0))

	if t_temblor > 0.0:
		t_temblor = maxf(t_temblor - delta, 0.0)
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * temblor
		if t_temblor <= 0.0:
			temblor = 0.0
