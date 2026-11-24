extends Node

# Estallido de luz: el poder de Ceniza.
# Cada golpe que le da a un enemigo carga la llama. Llena, con K suelta una onda de luz
# que le pega a todo alrededor, rompe las bolas de veneno y la protege un instante.

@export var tecla = "poder"
@export var maximo = 100.0
@export var por_golpe = 14.0
@export var radio = 4.5
@export var danio = 3
@export var proteccion = 0.4
const DORADO = Color("#F2C14E")
@onready var pj = get_parent()

var energia = 0.0
var forma = SphereShape3D.new()
var consulta = PhysicsShapeQueryParameters3D.new()


func _ready():
	forma.radius = radio
	consulta.shape = forma
	consulta.collide_with_areas = true
	consulta.exclude = [pj.get_rid()]


func sumar(cuanto):
	var antes = energia
	energia = minf(energia + cuanto, maximo)
	if antes < maximo and energia >= maximo:
		Efectos.numero(pj.get_parent(), pj.global_position + Vector3(0, 2.2, 0), "¡ESTALLIDO LISTO!  [K]", DORADO)


func listo():
	return energia >= maximo


func _physics_process(_delta):
	if Input.is_action_just_pressed(tecla) and listo():
		estallar()


func estallar():
	energia = 0.0
	var centro = pj.global_position + Vector3(0, 0.9, 0)
	var salud = pj.get_node_or_null("Salud")
	if salud != null:
		salud.proteger(proteccion)
	if pj.accion == "":
		pj.accion = "poder"
		get_tree().create_timer(0.35).timeout.connect(func():
			if pj.accion == "poder":
				pj.accion = "")
	# Se ve: dos anillos, chispas, un fogonazo de luz y la camara tiembla.
	Efectos.anillo(pj.get_parent(), pj.global_position, DORADO, radio)
	Efectos.anillo(pj.get_parent(), pj.global_position + Vector3(0, 0.9, 0), Color(1, 1, 1, 0.8), radio * 0.6)
	Efectos.chispas(pj.get_parent(), centro, DORADO, 36)
	Efectos.temblar(pj, 0.25, 0.3)
	var luz = OmniLight3D.new()
	luz.light_color = Color(1, 0.85, 0.5)
	luz.light_energy = 8.0
	luz.omni_range = radio + 3.0
	pj.get_parent().add_child(luz)
	luz.global_position = centro
	var t = luz.create_tween()
	t.tween_property(luz, "light_energy", 0.0, 0.5)
	t.tween_callback(luz.queue_free)
	# Le pega a todo lo que este dentro del radio.
	consulta.transform = Transform3D(Basis.IDENTITY, centro)
	var tocados = []
	for r in pj.get_world_3d().direct_space_state.intersect_shape(consulta, 32):
		var c = r.collider
		if c in tocados or c == pj or not c.has_method("recibir_golpe"):
			continue
		tocados.append(c)
		c.recibir_golpe(danio)
	Efectos.hitstop(get_tree(), 0.1)
	print("estallido: le dio a ", tocados.size())
