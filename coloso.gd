extends CharacterBody3D

enum Estado { QUIETO, ACERCARSE, AVISO, GOLPE, RECARGA, HUIR }

@export var rapidez = 2.0
# Como el Carronero: espera hasta ver a Ceniza y la suelta si se aleja.
@export var rango_ver = 10.0
@export var rango_perder = 14.0
@export var rango_ataque = 1.5
@export var tiempo_aviso = 0.5
@export var tiempo_recarga = 1.0
@export var alcance_golpe = 1.8
@export var danio = 1
@export var vida = 100.0
@export var vida_huida = 30.0
@export var danio_prueba = 25.0
@export var patrulla_rango = 3.0
# La luz que suelta al morir.
@export var orbe_valor = 50
const COLOR = Color("#FF3B30")   # ojos, chispas y muerte
const ORBE = preload("res://orbe.tscn")
const BARRA = preload("res://barra_enemigo.tscn")
# Es pesado: al recibir un golpe retrocede poco (m/s y segundos).
@export var retroceso = 1.0
@export var tiempo_retroceso = 0.1
# true en el jefe: al morir le avisa a la Partida que se cumplio la meta.
@export var es_meta = false

var estado = Estado.QUIETO
var reloj = 0.0
var jugador = null
@onready var anim = $Modelo/AnimationPlayer
var barra = null      # la vida encima de la cabeza
var aviso = null      # el "!" antes del mazazo
var destello = null   # luz roja: se enciende en el aviso
var vida_max = 0.0
var empujon = Vector3.ZERO
var reloj_empujon = 0.0
var origen_x = 0.0
var dir_patrulla = -1.0
var enfurecido = false
var muerto = false
var rayo_suelo: PhysicsRayQueryParameters3D
var rayo_pared: PhysicsRayQueryParameters3D


func _ready():
	add_to_group("enemigos")
	if es_meta:
		add_to_group("meta")   # el mapa lo marca con una estrella
	Esqueleto.preparar($Modelo, COLOR, 9.0)
	jugador = get_tree().get_first_node_in_group("jugador")
	origen_x = global_position.x
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	rayo_suelo = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 3)
	rayo_suelo.exclude = [get_rid()]
	rayo_pared = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
	rayo_pared.exclude = [get_rid()]
	vida_max = vida
	barra = BARRA.instantiate()
	barra.position = Vector3(0, 3.3, 0)
	barra.ancho = 1.2
	barra.scale = Vector3(1.2, 1.2, 1.2)
	add_child(barra)
	aviso = Label3D.new()
	aviso.text = "!"
	aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aviso.no_depth_test = true
	aviso.position = Vector3(0, 3.8, 0)
	aviso.font_size = 160
	aviso.pixel_size = 0.008
	aviso.outline_size = 32
	aviso.modulate = Color("#E8433A")
	aviso.visible = false
	add_child(aviso)
	destello = OmniLight3D.new()
	destello.light_color = Color("#E8433A")
	destello.light_energy = 0.0
	destello.omni_range = 3.5
	destello.position = Vector3(0, 1.5, 0)
	add_child(destello)
	mostrar_vida()


func _physics_process(delta):
	velocity += get_gravity() * delta
	if muerto:
		velocity.x = 0.0
		move_and_slide()
		return
	if jugador == null:
		velocity.z = 0.0
		move_and_slide()
		return
	reloj = maxf(reloj - delta, 0.0)
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	match estado:
		Estado.QUIETO:
			if es_meta:
				mirar_a(jugador.global_position)
				frenar("idle")
			else:
				patrullar()
		Estado.ACERCARSE:
			ir_a(jugador.global_position)
		Estado.AVISO:
			mirar_a(jugador.global_position)
			frenar("interact-right")
			# La luz roja crece durante el aviso: cuando esta al maximo, viene el golpe.
			destello.light_energy = 4.0 * (1.0 - reloj / maxf(tiempo_aviso, 0.01))
		Estado.GOLPE:
			frenar("attack-melee-right")
			golpear()
		Estado.RECARGA:
			frenar("idle")
		Estado.HUIR:
			# Huir es perseguir con la flecha al revés.
			var lejos = global_position - jugador.global_position
			ir_a(global_position + lejos)
	# El retroceso se suma despues: ir_a y frenar ya pusieron la velocidad.
	if reloj_empujon > 0.0:
		reloj_empujon -= delta
		velocity.x += empujon.x
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


# Desde cada estado solo se puede pasar a uno: el ciclo del ataque.
func decidir():
	# Va primero: le gana a cualquier estado, también al AVISO.
	if vida <= vida_huida:
		return Estado.HUIR
	var d = distancia()
	var dy = absf(jugador.global_position.y - global_position.y)
	match estado:
		Estado.QUIETO:
			if d <= rango_ver and dy <= 3.0:
				return Estado.ACERCARSE
		Estado.ACERCARSE:
			if d > rango_perder or dy > 4.8:
				return Estado.QUIETO
			if d <= rango_ataque and dy <= 2.2:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE if (d <= rango_perder and dy <= 4.0) else Estado.QUIETO
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	aviso.visible = estado == Estado.AVISO
	if estado != Estado.AVISO:
		destello.light_energy = 1.6 if enfurecido else 0.0
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


# Se llama igual que en la diana del Taller 8: el rayo ya la sabe usar.
func recibir_golpe(cuanto):
	if muerto:
		return
	vida -= cuanto
	Efectos.chispas(get_parent(), global_position + Vector3(0, 1.6, 0), COLOR, 14)
	print(name, " vida ", vida)
	mostrar_vida()
	if es_meta and not enfurecido and vida > 0.0 and vida <= vida_max * 0.5:
		enfurecido = true
		rapidez *= 1.25
		tiempo_recarga = minf(tiempo_recarga, 1.4)
		destello.light_energy = 1.6
		Efectos.numero(get_parent(), global_position + Vector3(0, 3.6, 0), "¡FURIA!", Color("#E8433A"))
	# Que el golpe se sienta: blanco, numero, pausa corta y retroceso.
	Efectos.destello($Modelo, 0.1)
	Efectos.numero(get_parent(), global_position + Vector3(0, 2.8, 0), "-" + str(cuanto), Color.WHITE)
	if jugador != null:
		var dx = global_position.x - jugador.global_position.x
		var dir = signf(dx) if absf(dx) > 0.05 else 1.0
		empujon = Vector3(dir * retroceso, 0.0, 0.0)
		reloj_empujon = tiempo_retroceso
	if vida <= 0:
		Efectos.hitstop(get_tree(), 0.12)
		print(name, " vencido")
		soltar_orbe()
		if es_meta:
			var partida = get_tree().get_first_node_in_group("partida")
			if partida != null:
				partida.avisar_meta()
		morir()
		return
	if estado != Estado.AVISO and estado != Estado.GOLPE:
		tocar("hit")
	Efectos.hitstop(get_tree(), 0.05 if cuanto < 2 else 0.12)


# Animacion Death, se encoge con chispas y se borra.
func morir():
	muerto = true
	aviso.visible = false
	barra.visible = false
	destello.light_energy = 0.0
	collision_layer = 0
	tocar("die")
	await get_tree().create_timer(0.7).timeout
	await Efectos.muerte($Modelo, COLOR)
	queue_free()


# El aviso le da tiempo al jugador: el golpe mira DÓNDE ESTÁ AHORA.
func golpear():
	Efectos.temblar(self, 0.18, 0.22)
	var dx = absf(jugador.global_position.x - global_position.x)
	var dy = absf(jugador.global_position.y - global_position.y)
	if dx > alcance_golpe or dy > 2.2:
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


func patrullar():
	if patrulla_rango <= 0.1 or not is_on_floor() or distancia() > 26.0:
		frenar("idle")
		return
	if global_position.x >= origen_x + patrulla_rango:
		dir_patrulla = -1.0
	elif global_position.x <= origen_x - patrulla_rango:
		dir_patrulla = 1.0
	if not _hay_suelo_adelante(dir_patrulla) or _hay_pared_adelante(dir_patrulla):
		dir_patrulla = -dir_patrulla
		if not _hay_suelo_adelante(dir_patrulla) or _hay_pared_adelante(dir_patrulla):
			frenar("idle")
			return
	velocity.x = dir_patrulla * rapidez * 0.4
	basis = Basis.looking_at(Vector3(dir_patrulla, 0.0, 0.0))
	tocar("walk")


func ir_a(destino):
	var dx = destino.x - global_position.x
	if absf(dx) <= 0.15:
		frenar("idle")
		return
	var dir_x = signf(dx)
	basis = Basis.looking_at(Vector3(dir_x, 0.0, 0.0))
	if is_on_floor() and (not _hay_suelo_adelante(dir_x) or _hay_pared_adelante(dir_x)):
		velocity.x = 0.0
		tocar("idle")
		return
	velocity.x = dir_x * rapidez
	tocar("walk")


func mirar_a(destino):
	var dx = destino.x - global_position.x
	if absf(dx) > 0.15:
		basis = Basis.looking_at(Vector3(signf(dx), 0.0, 0.0))


func _hay_suelo_adelante(dir_x: float) -> bool:
	rayo_suelo.from = global_position + Vector3(dir_x * 0.85, 0.5, 0.0)
	rayo_suelo.to = global_position + Vector3(dir_x * 0.85, -1.2, 0.0)
	return not get_world_3d().direct_space_state.intersect_ray(rayo_suelo).is_empty()


func _hay_pared_adelante(dir_x: float) -> bool:
	rayo_pared.from = global_position + Vector3(0.0, 1.0, 0.0)
	rayo_pared.to = global_position + Vector3(dir_x * 0.95, 1.0, 0.0)
	return not get_world_3d().direct_space_state.intersect_ray(rayo_pared).is_empty()


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	tocar(animacion)


# Traduce al esqueleto. Es pesado: corre lento y el mazazo se prepara todo el aviso.
func tocar(nombre):
	var r = 1.0
	match nombre:
		"walk":
			r = 0.6
		"interact-right", "attack-melee-right":
			r = Esqueleto.rapidez_aviso(tiempo_aviso)
		"hit":
			r = 3.0
		"die":
			r = 1.6
	Esqueleto.tocar(anim, nombre, r)


func distancia():
	return global_position.distance_to(jugador.global_position)


func mostrar_vida():
	barra.poner(maxf(vida, 0.0), vida_max)
