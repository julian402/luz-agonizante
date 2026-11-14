extends OmniLight3D
# Tarea B nivel 1: la antorcha parpadea con ruido (cambia suave, no salta como randf)

@export var energia_base = 2.0
@export var amplitud = 0.3      # sube o baja hasta un 30 %
@export var velocidad = 4.0
@export var semilla = 7
@export var apagar_en = 0.0     # segundos para apagarse (0 = nunca se apaga)
@export var llama: Node3D

var ruido = FastNoiseLite.new()
var tiempo = 0.0


func _ready():
	ruido.seed = semilla
	ruido.frequency = 1.0


func _process(delta):
	tiempo += delta

	# nivel 2: despues de un tiempo la antorcha se va apagando
	if apagar_en > 0 and tiempo > apagar_en:
		energia_base = lerp(energia_base, 0.0, 1 - exp(-1.5 * delta))

	var valor = ruido.get_noise_1d(tiempo * velocidad)   # entre -1 y 1
	light_energy = energia_base * (1 + amplitud * valor)

	if llama != null:
		llama.visible = light_energy > 0.05
