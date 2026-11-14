extends CharacterBody3D

enum Estado { ACERCARSE, AVISO, GOLPE, RECARGA, HUIR }

@export var rapidez = 2.0
@export var rango_ataque = 1.5
@export var tiempo_aviso = 0.5
@export var tiempo_recarga = 1.0
@export var alcance_golpe = 1.8
@export var danio = 1
@export var vida = 100.0
@export var vida_huida = 30.0
@export var danio_prueba = 25.0
# La luz que suelta al morir.
@export var orbe_valor = 50
const ORBE = preload("res://orbe.tscn")

var estado = Estado.ACERCARSE
var reloj = 0.0
var jugador = null
@onready var anim = $Modelo/AnimationPlayer
var etiqueta = null   # la vida encima de la cabeza
var destello = null   # luz roja al recibir un golpe


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	etiqueta = Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.position = Vector3(0, 3.2, 0)
	etiqueta.font_size = 96
	etiqueta.pixel_size = 0.008
	etiqueta.outline_size = 24
	etiqueta.modulate = Color("#E8433A")
	add_child(etiqueta)
	destello = OmniLight3D.new()
	destello.light_color = Color("#E8433A")
	destello.light_energy = 0.0
	destello.omni_range = 3.0
	destello.position = Vector3(0, 1.5, 0)
	add_child(destello)
	mostrar_vida()


func _physics_process(delta):
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	match estado:
		Estado.ACERCARSE:
			ir_a(jugador.global_position)
		Estado.AVISO:
			frenar("interact-right")
		Estado.GOLPE:
			frenar("attack-melee-right")
			golpear()
		Estado.RECARGA:
			frenar("idle")
		Estado.HUIR:
			# Huir es perseguir con la flecha al revés.
			var lejos = global_position - jugador.global_position
			ir_a(global_position + lejos)
	move_and_slide()


# Desde cada estado solo se puede pasar a uno: el ciclo del ataque.
func decidir():
	# Va primero: le gana a cualquier estado, también al AVISO.
	if vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.ACERCARSE:
			if distancia() <= rango_ataque:
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
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


# Se llama igual que en la diana del Taller 8: el rayo ya la sabe usar.
func recibir_golpe(cuanto):
	vida -= cuanto
	print(name, " vida ", vida)
	mostrar_vida()
	# Destello rojo de 0.15 s para que se vea el golpe.
	destello.light_energy = 4.0
	get_tree().create_timer(0.15).timeout.connect(apagar_destello)
	if vida <= 0:
		print(name, " vencido")
		soltar_orbe()
		queue_free()


# El aviso le da tiempo al jugador: el golpe mira DÓNDE ESTÁ AHORA.
func golpear():
	if distancia() > alcance_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m")
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


# Se agrega despues (deferred): morir pasa en medio del rayo del Chispazo.
func soltar_orbe():
	var orbe = ORBE.instantiate()
	orbe.valor = orbe_valor
	orbe.position = global_position + Vector3(0, 1, 0)
	get_parent().add_child.call_deferred(orbe)


func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("walk")


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play(animacion)


func distancia():
	var p = jugador.global_position
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()


func mostrar_vida():
	etiqueta.text = str(maxi(int(vida), 0))


func apagar_destello():
	if is_instance_valid(destello):
		destello.light_energy = 0.0
