extends CanvasLayer

# El HUD no guarda la vida, solo la muestra.
@onready var texto = $Texto
var salud = null
# La oscuridad cambia la vida cada cuadro: solo se escribe si cambia algo.
var ultimo = ""


func _ready():
	var pj = get_tree().get_first_node_in_group("jugador")
	salud = pj.get_node("Salud")
	salud.cambio.connect(mostrar)
	# Al empezar todavia no hay golpes: se muestra la vida inicial.
	mostrar(salud.vida)


# En la luz la vida no cambia y no llega la senal: la zona se mira cada cuadro.
func _process(_delta):
	mostrar(salud.vida)


func mostrar(vida):
	var nuevo = "Vida: " + str(roundi(vida)) + "   " + zona()
	if nuevo == ultimo:
		return
	ultimo = nuevo
	texto.text = nuevo


# Para que el jugador sepa por que baja la vida.
func zona():
	if salud.en_luz > 0:
		return "(luz)"
	if salud.en_penumbra > 0:
		return "(penumbra)"
	return "(oscuridad)"
