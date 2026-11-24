extends Area3D

# Luz que cura. La suelta un enemigo al morir o se pone a mano en el nivel.
@export var valor = 30
@export var rango_iman = 2.2
@export var rapidez_iman = 6.5
var tiempo = 0.0
var jugador = null
@onready var malla = $Malla


func _ready():
	body_entered.connect(_entra)
	jugador = get_tree().get_first_node_in_group("jugador")


# Flota arriba y abajo, y se atrae suavemente cuando Ceniza pasa cerca.
func _process(delta):
	tiempo += delta
	malla.position.y = 0.15 * sin(tiempo * 3.0)
	if is_instance_valid(jugador):
		var objetivo = jugador.global_position + Vector3(0, 0.9, 0)
		if global_position.distance_to(objetivo) <= rango_iman:
			global_position = global_position.move_toward(objetivo, rapidez_iman * delta)


func _entra(cuerpo):
	var salud = cuerpo.get_node_or_null("Salud")
	if salud == null:
		return
	salud.curar(valor)
	Efectos.anillo(get_parent(), cuerpo.global_position, Color("#F2C14E"), 1.6)
	Efectos.numero(get_parent(), global_position + Vector3(0, 0.6, 0), "+" + str(valor), Color("#6BE36B"))
	print("orbe +", valor, " cuadro ", Engine.get_physics_frames())
	queue_free()
