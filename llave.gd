extends Area3D

# Llave dorada que flota y gira. Cuando Ceniza la toca, avisa a las Etapas.
signal recogida

@export var nombre = "Llave"
var tiempo = 0.0
var base_y = 0.0
var tomada = false
@onready var malla = $Malla


func _ready():
	add_to_group("llaves")
	base_y = position.y
	body_entered.connect(_entra)
	# Aparece con un anillo y chispas: que se note que salio.
	Efectos.anillo(get_parent(), global_position + Vector3(0, -0.8, 0), Color("#F2C14E"), 2.0)
	Efectos.chispas(get_parent(), global_position, Color("#F2C14E"), 20)


func _process(delta):
	tiempo += delta
	malla.rotation.y += delta * 2.0
	position.y = base_y + 0.15 * sin(tiempo * 3.0)


func _entra(cuerpo):
	if tomada or cuerpo.get_node_or_null("Salud") == null:
		return
	tomada = true
	Efectos.chispas(get_parent(), global_position, Color("#F2C14E"), 30)
	Efectos.anillo(get_parent(), cuerpo.global_position, Color("#F2C14E"), 2.5)
	Efectos.numero(get_parent(), global_position + Vector3(0, 0.8, 0), nombre.to_upper() + "!", Color("#F2C14E"))
	recogida.emit()
	queue_free()
