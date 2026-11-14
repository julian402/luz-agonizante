extends Area3D

# Luz que cura. La suelta un enemigo al morir o se pone a mano en el nivel.
@export var valor = 30
var tiempo = 0.0
@onready var malla = $Malla


func _ready():
	body_entered.connect(_entra)


# Flota arriba y abajo para que se note.
func _process(delta):
	tiempo += delta
	malla.position.y = 0.15 * sin(tiempo * 3.0)


func _entra(cuerpo):
	var salud = cuerpo.get_node_or_null("Salud")
	if salud == null:
		return
	salud.curar(valor)
	print("orbe +", valor, " cuadro ", Engine.get_physics_frames())
	queue_free()
