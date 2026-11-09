extends CanvasLayer

# El HUD no guarda la vida, solo la muestra.
@onready var texto = $Texto


func _ready():
	var pj = get_tree().get_first_node_in_group("jugador")
	var salud = pj.get_node("Salud")
	salud.cambio.connect(mostrar)
	# Al empezar todavia no hay golpes: se muestra la vida inicial.
	mostrar(salud.vida)


func mostrar(vida):
	texto.text = "Vida: " + str(vida)
	print("HUD -> ", texto.text)
