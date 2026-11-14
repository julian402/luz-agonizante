extends CanvasLayer

# El HUD no guarda la vida, solo la muestra.
@onready var texto = $Texto
# La oscuridad cambia la vida cada cuadro: solo se escribe si cambia el entero.
var ultimo = -1


func _ready():
	var pj = get_tree().get_first_node_in_group("jugador")
	var salud = pj.get_node("Salud")
	salud.cambio.connect(mostrar)
	# Al empezar todavia no hay golpes: se muestra la vida inicial.
	mostrar(salud.vida)


func mostrar(vida):
	var entero = roundi(vida)
	if entero == ultimo:
		return
	ultimo = entero
	texto.text = "Vida: " + str(entero)
	print("HUD -> ", texto.text)
