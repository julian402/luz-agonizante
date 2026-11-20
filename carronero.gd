extends CharacterBody3D

enum Estado { QUIETO, ACERCARSE, AVISO, GOLPE, RECARGA }

@export var rapidez = 4.5
@export var rango_ver = 10.0
@export var rango_perder = 14.0
@export var rango_ataque = 1.5
@export var tiempo_aviso = 0.4
@export var tiempo_recarga = 1.5
@export var alcance_golpe = 1.5
@export var danio = 10
@export var vida = 4.0
# La luz que suelta al morir.
@export var orbe_valor = 30
const ORBE = preload("res://orbe.tscn")
const BARRA = preload("res://barra_enemigo.tscn")
var barra = null
var aviso = null
var vida_max = 0.0
var empujon = Vector3.ZERO
var reloj_empujon = 0.0

var estado = Estado.QUIETO
var reloj = 0.0
var jugador = null
@onready var anim = get_node_or_null("Modelo/AnimationPlayer")


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	vida_max = vida
	barra = BARRA.instantiate()
	barra.position = Vector3(0, 2, 0)
	add_child(barra)
	aviso = Label3D.new()
	aviso.text = "!"
	aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aviso.no_depth_test = true
	aviso.position = Vector3(0, 2.5, 0)
	aviso.font_size = 130
	aviso.pixel_size = 0.008
	aviso.modulate = Color("#E8433A")
	aviso.visible = false
	add_child(aviso)


func _physics_process(delta):
	velocity += get_gravity() * delta
	if jugador == null:
		move_and_slide()
		return
	reloj = maxf(reloj - delta, 0.0)
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	match estado:
		Estado.QUIETO:
			frenar("idle")
		Estado.ACERCARSE:
			ir_a(jugador.global_position)
		Estado.AVISO:
			frenar("interact-right")
		Estado.GOLPE:
			frenar("attack-melee-right")
			golpear()
		Estado.RECARGA:
			frenar("idle")
	if reloj_empujon > 0.0:
		reloj_empujon = maxf(reloj_empujon - delta, 0.0)
		velocity.x += empujon.x
		velocity.z += empujon.z
	move_and_slide()


func decidir():
	var d = distancia()
	match estado:
		Estado.QUIETO:
			if d <= rango_ver:
				return Estado.ACERCARSE
		Estado.ACERCARSE:
			if d > rango_perder:
				return Estado.QUIETO
			if d <= rango_ataque:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	aviso.visible = estado == Estado.AVISO
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


func recibir_golpe(cuanto):
	vida -= cuanto
	barra.poner(maxf(vida, 0.0), vida_max)
	Efectos.destello($Modelo, 0.1)
	Efectos.numero(get_parent(), global_position + Vector3(0, 2, 0), "-" + str(cuanto), Color.WHITE)
	if jugador != null:
		var lejos = global_position - jugador.global_position
		lejos.y = 0.0
		empujon = lejos.normalized() * 4.0
		reloj_empujon = 0.15
	print(name, " vida ", vida)
	if vida <= 0:
		print(name, " vencido")
		Efectos.hitstop(get_tree(), 0.12)
		soltar_orbe()
		queue_free()
		return
	Efectos.hitstop(get_tree(), 0.05 if cuanto < 2 else 0.12)


# Se agrega despues (deferred): morir pasa en medio del rayo del Chispazo.
func soltar_orbe():
	var orbe = ORBE.instantiate()
	orbe.valor = orbe_valor
	orbe.position = global_position + Vector3(0, 0.8, 0)
	get_parent().add_child.call_deferred(orbe)


func golpear():
	if distancia() > alcance_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m")
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	if hacia.length() > 0.001:
		var dir = hacia.normalized()
		velocity.x = dir.x * rapidez
		velocity.z = dir.z * rapidez
		basis = Basis.looking_at(dir)
	if anim != null:
		anim.play("walk")


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	if anim != null:
		anim.play(animacion)


# En 3D: el nivel tiene pisos uno encima de otro y no se ve a traves del techo.
func distancia():
	return global_position.distance_to(jugador.global_position)
