extends CanvasLayer

# El HUD no guarda la vida, solo la muestra.
@onready var barra = $Vida
@onready var lenta = $Lenta      # la barra blanca de atras: baja despacio y muestra lo perdido
@onready var numero = $Numero
@onready var texto_zona = $Zona
@onready var borde = $Borde      # bordes de pantalla: rojos al golpe, oscuros en la oscuridad
@onready var fin = $Fin
var salud = null
var pj = null
var relleno = null
var tiempo = 0.0
var rojo = 0.0                   # cuanto rojo queda del ultimo golpe (0.7 -> 0 en 0.3 s)

# Lo que baja la barra blanca por segundo.
@export var rapidez_lenta = 40.0
# Con menos de esto la barra parpadea en rojo.
@export var vida_baja = 30.0

const DORADO = Color("#F2C14E")
const GRIS = Color("#8A93B8")
const MORADO = Color("#6B3FA0")
const ROJO = Color("#E8433A")
const OSCURO = Color(0.08, 0.02, 0.15)


func _ready():
	# La Partida lo busca por el grupo para mostrar el final.
	add_to_group("hud")
	pj = get_tree().get_first_node_in_group("jugador")
	salud = pj.get_node("Salud")
	salud.cambio.connect(mostrar)
	salud.golpeado.connect(_al_golpe)
	barra.max_value = maxf(salud.vida_inicial, salud.vida)
	lenta.max_value = barra.max_value
	lenta.value = salud.vida
	# Cada barra tiene su propio relleno: si no, cambiar el color cambia todos.
	relleno = barra.get_theme_stylebox("fill").duplicate()
	barra.add_theme_stylebox_override("fill", relleno)
	# Al empezar todavia no hay golpes: se muestra la vida inicial.
	mostrar(salud.vida)


func mostrar(vida):
	# La vida maxima sube al pasar de etapa.
	if salud.vida_inicial > barra.max_value:
		barra.max_value = salud.vida_inicial
		lenta.max_value = barra.max_value
	barra.value = vida
	numero.text = str(roundi(vida)) + " / " + str(roundi(barra.max_value))
	# Si se cura, la blanca sube de una vez.
	if vida > lenta.value:
		lenta.value = vida


# Solo los golpes de enemigos (la oscuridad no llama esto).
func _al_golpe(_danio):
	rojo = 0.7
	Efectos.chispas(pj.get_parent(), pj.global_position + Vector3(0, 1.0, 0), ROJO, 14)


# En la luz la vida no cambia y no llega la senal: la zona se mira cada cuadro.
func _process(delta):
	tiempo += delta
	lenta.value = move_toward(lenta.value, salud.vida, rapidez_lenta * delta)
	rojo = maxf(rojo - delta * 0.7 / 0.3, 0.0)

	var color = DORADO
	var oscuro = 0.0
	if salud.en_luz > 0:
		texto_zona.text = "A SALVO" if salud.vida >= salud.vida_inicial else "A SALVO  ·  CURANDO +" + str(roundi(salud.regen_luz)) + "/s"
	elif salud.en_penumbra > 0:
		color = GRIS
		oscuro = 0.4
		texto_zona.text = "PENUMBRA  -" + str(roundi(salud.penumbra)) + "/s"
	else:
		color = MORADO
		# Late: para que se note que algo esta pasando.
		oscuro = 0.75 + 0.2 * sin(tiempo * 6.0)
		texto_zona.text = "OSCURIDAD  -" + str(roundi(salud.oscuridad)) + "/s"
	texto_zona.modulate = color.lightened(0.3)

	# Vida baja: la barra parpadea en rojo dos veces por segundo.
	if salud.vida > 0 and salud.vida < vida_baja and fmod(tiempo, 0.5) < 0.25:
		relleno.bg_color = ROJO
	else:
		relleno.bg_color = color

	# El golpe le gana a la zona: el rojo se ve aunque este a oscuras.
	var tinte = OSCURO.lerp(ROJO, clampf(rojo / 0.4, 0.0, 1.0) if rojo > 0 else 0.0)
	tinte.a = maxf(oscuro, rojo)
	borde.modulate = tinte


# Lo llama la Partida al terminar. El HUD no decide quien gana, solo lo muestra.
func mostrar_fin(titulo, detalle, color):
	fin.text = titulo + "\n" + detalle
	fin.modulate = color
	fin.visible = true
