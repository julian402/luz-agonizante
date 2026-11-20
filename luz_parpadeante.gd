extends OmniLight3D
# Tarea B nivel 1: la antorcha parpadea con ruido (cambia suave, no salta como randf)

@export var energia_base = 2.0
@export var amplitud = 0.3      # sube o baja hasta un 30 %
@export var velocidad = 4.0
@export var semilla = 0      # 0 = una al azar, para que no parpadeen todas iguales
@export var apagar_en = 0.0     # segundos para apagarse (0 = nunca se apaga)
@export var llama: Node3D
@export var distancia_activa = 28.0

var ruido = FastNoiseLite.new()
var tiempo = 0.0
var acumulado = 0.0
const INTERVALO_LUZ = 0.05
var camara: Camera3D = null
var particulas: Array = []
var activa = true


func _ready():
	ruido.seed = semilla if semilla != 0 else randi()
	ruido.frequency = 1.0
	camara = get_viewport().get_camera_3d()
	if get_parent() != null:
		particulas = get_parent().find_children("*", "CPUParticles3D", true, false)


func _process(delta):
	tiempo += delta
	acumulado += delta
	if acumulado < INTERVALO_LUZ:
		return
	var paso = acumulado
	acumulado = 0.0

	if not is_instance_valid(camara):
		camara = get_viewport().get_camera_3d()
	if is_instance_valid(camara):
		var en_rango = global_position.distance_to(camara.global_position) <= distancia_activa
		if en_rango != activa:
			activa = en_rango
			for p in particulas:
				if is_instance_valid(p):
					p.emitting = activa
		if not activa and apagar_en <= 0.0:
			return

	# nivel 2: despues de un tiempo la antorcha se va apagando
	if apagar_en > 0 and tiempo > apagar_en:
		energia_base = lerp(energia_base, 0.0, 1 - exp(-1.5 * paso))

	var valor = ruido.get_noise_1d(tiempo * velocidad)   # entre -1 y 1
	light_energy = energia_base * (1 + amplitud * valor)

	if llama != null:
		llama.visible = light_energy > 0.05
