extends CharacterBody3D

# Espectro: calavera con llama morada que flota alto.
# Para pegarle hay que doble salto + ataque, o esperar a que suba despues de la picada (queda bajo).
# Su ataque es una picada en linea recta que hay que esquivar.
# Le tiene miedo a la luz: nunca entra a una zona del grupo "luz".

enum Estado { FLOTAR, ACERCARSE, AVISO, PICADA, SUBIR }

@export var vida = 2.0
@export var rango_ver = 10.0
@export var rango_perder = 15.0
@export var altura = 3.5          # sobre Ceniza
@export var lado = 3.0            # a un costado de Ceniza
@export var rapidez = 4.0
@export var tiempo_aviso = 0.5
@export var rapidez_picada = 12.0
@export var tiempo_picada = 0.45
@export var rapidez_subir = 2.5
@export var tiempo_subir = 1.2
@export var tiempo_recarga = 0.9
@export var danio = 10
@export var orbe_valor = 35
const COLOR = Color("#9B5CFF")
const ROJO = Color("#FF4A3D")
const ORBE = preload("res://orbe.tscn")
const BARRA = preload("res://barra_enemigo.tscn")

var estado = Estado.FLOTAR
var reloj = 0.0
var recarga = 0.0
var tiempo = 0.0
var inicio = Vector3.ZERO
var jugador = null
var objetivo = Vector3.ZERO     # a donde va la picada
var dir_picada = Vector3.ZERO
var pego = false                # la picada pega una sola vez
var empujon = 0.0               # golpe hacia arriba al recibir dano
var muerto = false
var vida_max = 0.0
var barra = null
var aviso = null
var rayo_vista: PhysicsRayQueryParameters3D
var consulta_luz = PhysicsPointQueryParameters3D.new()
@onready var modelo = $Modelo
@onready var llama = $Llama
@onready var luz = $Luz


func _ready():
	add_to_group("enemigos")
	jugador = get_tree().get_first_node_in_group("jugador")
	inicio = global_position
	# Atraviesa a Ceniza: el dano de la picada se mide por distancia, no por choque.
	if jugador != null:
		add_collision_exception_with(jugador)
	tiempo = randf() * 10.0
	rayo_vista = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
	rayo_vista.exclude = [get_rid()]
	consulta_luz.collide_with_areas = true
	consulta_luz.collide_with_bodies = false
	vida_max = vida
	barra = BARRA.instantiate()
	barra.position = Vector3(0, 0.9, 0)
	add_child(barra)
	aviso = Label3D.new()
	aviso.text = "!"
	aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aviso.no_depth_test = true
	aviso.position = Vector3(0, 1.4, 0)
	aviso.font_size = 130
	aviso.outline_size = 18
	aviso.pixel_size = 0.008
	aviso.modulate = ROJO
	aviso.visible = false
	add_child(aviso)


func _physics_process(delta):
	if muerto:
		return
	tiempo += delta
	reloj = maxf(reloj - delta, 0.0)
	recarga = maxf(recarga - delta, 0.0)
	if jugador == null or not is_instance_valid(jugador):
		velocity = Vector3.ZERO
		return
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	match estado:
		Estado.FLOTAR:
			var meta = inicio + Vector3(sin(tiempo * 0.6) * 3.0, sin(tiempo * 2.0) * 0.4, 0)
			ir_a(meta, 2.0)
		Estado.ACERCARSE:
			var lado_x = signf(global_position.x - jugador.global_position.x)
			if lado_x == 0.0:
				lado_x = 1.0
			var meta = jugador.global_position + Vector3(lado_x * lado, altura + sin(tiempo * 2.0) * 0.3, 0)
			ir_a(meta, rapidez)
		Estado.AVISO:
			velocity = Vector3.ZERO
			# Tiembla y la llama se pone roja.
			modelo.position = Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0)
		Estado.PICADA:
			velocity = dir_picada * rapidez_picada
			if en_luz(global_position + velocity * delta * 3.0):
				# No entra a la luz: corta la picada en el borde.
				reloj = 0.0
				velocity = Vector3.ZERO
			_pegar_si_toca()
		Estado.SUBIR:
			var meta = Vector3(global_position.x, jugador.global_position.y + altura, 0)
			velocity = Vector3(0, signf(meta.y - global_position.y) * rapidez_subir, 0)
			if absf(meta.y - global_position.y) < 0.1:
				velocity.y = 0.0

	if empujon > 0.0:
		velocity.y += empujon
		empujon = maxf(empujon - 30.0 * delta, 0.0)
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	if estado == Estado.PICADA and get_slide_collision_count() > 0:
		# Choco con el piso o una pared: anillo morado y vuelve a subir.
		Efectos.anillo(get_parent(), global_position + Vector3(0, -0.4, 0), COLOR, 1.8)
		Efectos.temblar(self, 0.08, 0.15)
		reloj = 0.0
	# La calavera gira un poco hacia donde va (sin dejar de mirar a la camara).
	if absf(velocity.x) > 0.2:
		modelo.rotation.y = lerp_angle(modelo.rotation.y, 0.6 if velocity.x > 0 else -0.6, 0.15)


func decidir():
	var d = distancia()
	match estado:
		Estado.FLOTAR:
			if d <= rango_ver and ve_a_ceniza():
				return Estado.ACERCARSE
		Estado.ACERCARSE:
			if d > rango_perder:
				return Estado.FLOTAR
			var arriba = jugador.global_position + Vector3(0, 0.9, 0)
			var dx = absf(global_position.x - jugador.global_position.x)
			var cerca = dx >= 1.5 and dx <= lado + 1.2   # pica en diagonal, desde un costado
			var alto = global_position.y - arriba.y > 1.5
			if recarga <= 0.0 and cerca and alto and ve_a_ceniza() and not en_luz(arriba):
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.PICADA
		Estado.PICADA:
			if reloj <= 0.001:
				return Estado.SUBIR
		Estado.SUBIR:
			if reloj <= 0.001:
				return Estado.ACERCARSE if d <= rango_perder else Estado.FLOTAR
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	aviso.visible = estado == Estado.AVISO
	modelo.position = Vector3.ZERO
	pintar_llama(ROJO if estado == Estado.AVISO else COLOR)
	match estado:
		Estado.AVISO:
			reloj = tiempo_aviso
		Estado.PICADA:
			reloj = tiempo_picada
			pego = false
			# Va a donde estaba Ceniza al terminar el aviso (se puede esquivar).
			objetivo = jugador.global_position + Vector3(0, 0.9, 0)
			dir_picada = (objetivo - global_position)
			dir_picada.z = 0.0
			dir_picada = dir_picada.normalized()
		Estado.SUBIR:
			reloj = tiempo_subir
			recarga = tiempo_recarga


func _pegar_si_toca():
	if pego:
		return
	var pecho = jugador.global_position + Vector3(0, 0.9, 0)
	if global_position.distance_to(pecho) <= 1.2:
		pego = true
		var salud = jugador.get_node_or_null("Salud")
		if salud != null:
			salud.recibir_golpe(danio)


# Se mueve hacia "meta" sin meterse en la luz.
func ir_a(meta, vel):
	var hacia = meta - global_position
	hacia.z = 0.0
	if hacia.length() < 0.05:
		velocity = Vector3.ZERO
		return
	var paso = hacia.normalized() * minf(vel, hacia.length() * 3.0)
	if en_luz(global_position + paso.normalized() * 0.6):
		# Se queda en el borde esperando, flotando en su lugar.
		velocity = Vector3(0, sin(tiempo * 2.0) * 0.3, 0)
		return
	velocity = paso


func en_luz(punto):
	consulta_luz.position = punto
	for r in get_world_3d().direct_space_state.intersect_point(consulta_luz, 8):
		if r.collider != null and r.collider.is_in_group("luz"):
			return true
	return false


func ve_a_ceniza():
	rayo_vista.from = global_position
	rayo_vista.to = jugador.global_position + Vector3(0, 0.9, 0)
	var golpe = get_world_3d().direct_space_state.intersect_ray(rayo_vista)
	return golpe.is_empty() or golpe.collider == jugador


func recibir_golpe(cuanto):
	if muerto:
		return
	vida -= cuanto
	barra.poner(maxf(vida, 0.0), vida_max)
	Efectos.destello(modelo, 0.1)
	Efectos.chispas(get_parent(), global_position, COLOR, 12)
	Efectos.numero(get_parent(), global_position + Vector3(0, 1, 0), "-" + str(cuanto), Color.WHITE)
	# El golpe lo sube 1 m: el combo aereo se siente.
	empujon = 7.0
	if estado == Estado.AVISO or estado == Estado.PICADA:
		cambiar_a(Estado.SUBIR)
	if vida <= 0:
		morir()
		return
	Efectos.hitstop(get_tree(), 0.05 if cuanto < 2 else 0.12)


func morir():
	muerto = true
	aviso.visible = false
	barra.visible = false
	collision_layer = 0
	llama.emitting = false
	Efectos.hitstop(get_tree(), 0.12)
	var orbe = ORBE.instantiate()
	orbe.valor = orbe_valor
	orbe.position = global_position
	get_parent().add_child.call_deferred(orbe)
	var t = create_tween()
	t.tween_property(luz, "light_energy", 0.0, 0.25)
	await Efectos.muerte(modelo, COLOR)
	queue_free()


func pintar_llama(color):
	llama.color = color
	luz.light_color = color


func distancia():
	return global_position.distance_to(jugador.global_position)
