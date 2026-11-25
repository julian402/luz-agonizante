extends Node

# Contraste solo en la oscuridad. Con luz el juego se ve como siempre; cuando Ceniza entra en
# penumbra u oscuridad, el fondo se apaga y su farol alumbra mas, para que la luz se distinga del fondo.
# Cambia suave (no de golpe) y vuelve a lo normal al llegar a una antorcha.

const OSCURO = {          # valores con Ceniza en plena oscuridad
	"ambiente": 0.06,
	"sol": 0.14,
	"niebla": 0.055,
	"contraste": 1.4,
	"farol": 2.0,
	"alcance": 6.0,
}
const RAPIDEZ = 2.5       # que tan rapido entra y sale el efecto

var entorno: Environment
var sol: DirectionalLight3D
var farol: OmniLight3D
var salud = null
var normal = {}
var nivel = 0.0           # 0 = luz, 0.5 = penumbra, 1 = oscuridad


func _ready():
	var escena = get_parent()
	var we = escena.get_node_or_null("WorldEnvironment")
	entorno = we.environment if we != null else null
	sol = escena.get_node_or_null("DirectionalLight3D")
	farol = escena.get_node_or_null("Personaje/Farol")
	salud = escena.get_node_or_null("Personaje/Salud")
	if entorno == null or sol == null or farol == null or salud == null:
		set_process(false)
		return
	normal = {
		"ambiente": entorno.ambient_light_energy,
		"sol": sol.light_energy,
		"niebla": entorno.fog_density,
		"contraste": entorno.adjustment_contrast,
		"farol": farol.light_energy,
		"alcance": farol.omni_range,
	}


func _process(delta):
	var meta = 0.0
	if salud.en_luz <= 0:
		meta = 0.5 if salud.en_penumbra > 0 else 1.0
	nivel = move_toward(nivel, meta, RAPIDEZ * delta * 0.5)
	var k = smoothstep(0.0, 1.0, nivel)
	entorno.ambient_light_energy = lerpf(normal.ambiente, OSCURO.ambiente, k)
	entorno.fog_density = lerpf(normal.niebla, OSCURO.niebla, k)
	entorno.adjustment_contrast = lerpf(normal.contraste, OSCURO.contraste, k)
	sol.light_energy = lerpf(normal.sol, OSCURO.sol, k)
	farol.light_energy = lerpf(normal.farol, OSCURO.farol, k)
	farol.omni_range = lerpf(normal.alcance, OSCURO.alcance, k)
