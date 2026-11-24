extends Node

@onready var pj = get_parent()
@onready var salud = pj.get_node("Salud")
@onready var modelo = pj.get_node("Modelo")

var parpadeando = false

func _ready():
	salud.golpeado.connect(_al_golpe)

func _al_golpe(danio):
	var esquiva = pj.get_node_or_null("Esquivar")
	if esquiva == null or esquiva.estado != 1:
		pj.empuje = pj.basis.z * 6.0
		_quitar_empuje()
	var cam = get_viewport().get_camera_3d()
	if cam != null and cam.has_method("temblar"):
		if danio >= 20:
			cam.temblar(0.25, 0.3)
		else:
			cam.temblar(0.15, 0.2)
	Efectos.numero(pj.get_parent(), pj.global_position + Vector3(0, 2, 0), "-" + str(danio), Color.RED)
	if pj.accion == "":
		pj.accion = "hit"
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(pj) and pj.accion == "hit":
				pj.accion = "")
	if not parpadeando:
		_parpadear()

func _quitar_empuje():
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(pj):
		return
	var esquiva = pj.get_node_or_null("Esquivar")
	if esquiva == null or esquiva.estado != 1:
		pj.empuje = Vector3.ZERO

func _parpadear():
	parpadeando = true
	while is_instance_valid(salud) and is_instance_valid(modelo) and salud.es_invulnerable():
		modelo.visible = not modelo.visible
		await get_tree().create_timer(0.05).timeout
	if is_instance_valid(modelo):
		modelo.visible = true
	parpadeando = false
