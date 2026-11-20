extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 1.35, 8.6)
@export var altura_mira = 1.65
@export var adelanto_x = 1.15
@export var suavizado = 5.5
@export var limite_min = Vector2(-56, 0)
@export var limite_max = Vector2(204, 0)

# Limites horizontales por piso (Bioma I..IV) para no mostrar vacio fuera de los muros.
const PISOS = [
	{"y_min": -10.0, "x_min": 7.5, "x_max": 196.5, "piso_y": 0.0},
	{"y_min": -30.0, "x_min": -48.5, "x_max": 196.5, "piso_y": -20.0},
	{"y_min": -50.0, "x_min": -48.5, "x_max": 92.5, "piso_y": -40.0},
	{"y_min": -999.0, "x_min": 47.5, "x_max": 92.5, "piso_y": -60.0},
]

var temblor = 0.0
var t_temblor = 0.0
var mirada_actual = 0.0


func temblar(fuerza, duracion):
	temblor = maxf(temblor, fuerza)
	t_temblor = maxf(t_temblor, duracion)


func _limites_para_y(y: float) -> Dictionary:
	for p in PISOS:
		if y > p.y_min:
			return p
	return PISOS[-1]


func _foco_objetivo() -> Vector3:
	var pos = objetivo.global_position
	var lim = _limites_para_y(pos.y)
	var fx = clampf(pos.x + mirada_actual, lim.x_min, lim.x_max)
	# En piso normal mantiene encuadre limpio; al caer por un pozo sigue libremente.
	var fy = pos.y
	if absf(pos.y - lim.piso_y) < 0.6:
		fy = lim.piso_y
	var fz = clampf(pos.z, limite_min.y, limite_max.y)
	return Vector3(fx, fy + altura_mira, fz)


func _ready():
	top_level = true
	var foco = _foco_objetivo()
	look_at_from_position(foco + distancia, foco)


func _physics_process(delta):
	# Adelanto suave estilo Dead Cells hacia donde corre el jugador.
	var dir_x = 0.0
	if "velocity" in objetivo and absf(objetivo.velocity.x) > 0.4:
		dir_x = signf(objetivo.velocity.x) * adelanto_x
	mirada_actual = lerpf(mirada_actual, dir_x, 3.0 * delta)

	var destino = _foco_objetivo() + distancia
	global_position = global_position.lerp(destino, minf(suavizado * delta, 1.0))
	if t_temblor > 0.0:
		t_temblor = maxf(t_temblor - delta, 0.0)
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * temblor
		if t_temblor <= 0.0:
			temblor = 0.0
