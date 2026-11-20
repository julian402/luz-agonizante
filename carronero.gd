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
@export var patrulla_rango = 4.0
# La luz que suelta al morir.
@export var orbe_valor = 30
const ORBE = preload("res://orbe.tscn")
const BARRA = preload("res://barra_enemigo.tscn")
var barra = null
var aviso = null
var vida_max = 0.0
var empujon = Vector3.ZERO
var reloj_empujon = 0.0
var reloj_aturdido = 0.0

var estado = Estado.QUIETO
var reloj = 0.0
var jugador = null
var origen_x = 0.0
var dir_patrulla = 1.0
var dir_ataque = 1.0
var rayo_suelo: PhysicsRayQueryParameters3D
var rayo_pared: PhysicsRayQueryParameters3D
@onready var anim = get_node_or_null("Modelo/AnimationPlayer")


func _ready():
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
		velocity.z = 0.0
		move_and_slide()
		return
	reloj = maxf(reloj - delta, 0.0)
	reloj_aturdido = maxf(reloj_aturdido - delta, 0.0)

	if reloj_aturdido > 0.0:
		frenar("idle")
	else:
		var nuevo = decidir()
		if nuevo != estado:
			cambiar_a(nuevo)
		match estado:
			Estado.QUIETO:
				patrullar()
			Estado.ACERCARSE:
				ir_a(jugador.global_position)
			Estado.AVISO:
				mirar_a(jugador.global_position)
				frenar("interact-right")
			Estado.GOLPE:
				frenar("attack-melee-right")
				golpear()
			Estado.RECARGA:
				frenar("idle")

	if reloj_empujon > 0.0:
		reloj_empujon = maxf(reloj_empujon - delta, 0.0)
		velocity.x += empujon.x

	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func decidir():
	var d = distancia()
	var dy = absf(jugador.global_position.y - global_position.y)
	match estado:
		Estado.QUIETO:
			if d <= rango_ver and dy <= 2.4:
				return Estado.ACERCARSE
		Estado.ACERCARSE:
			if d > rango_perder or dy > 4.2:
				return Estado.QUIETO
			if d <= rango_ataque and dy <= 1.8:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE if (d <= rango_perder and dy <= 3.5) else Estado.QUIETO
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	aviso.visible = estado == Estado.AVISO
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
		var dx = jugador.global_position.x - global_position.x
		if absf(dx) > 0.05:
			dir_ataque = signf(dx)
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


func recibir_golpe(cuanto):
	vida -= cuanto
	barra.poner(maxf(vida, 0.0), vida_max)
	Efectos.destello($Modelo, 0.1)
	Efectos.numero(get_parent(), global_position + Vector3(0, 2, 0), "-" + str(cuanto), Color.WHITE)
	if jugador != null:
		var dx = global_position.x - jugador.global_position.x
		var dir = signf(dx) if absf(dx) > 0.05 else 1.0
		empujon = Vector3(dir * 4.0, 0.0, 0.0)
		reloj_empujon = 0.15
	if estado != Estado.GOLPE:
		reloj_aturdido = 0.12
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
	if _hay_suelo_adelante(dir_ataque) and not _hay_pared_adelante(dir_ataque):
		empujon = Vector3(dir_ataque * 6.5, 0.0, 0.0)
		reloj_empujon = 0.12
	var dx = absf(jugador.global_position.x - global_position.x)
	var dy = absf(jugador.global_position.y - global_position.y)
	if dx > alcance_golpe or dy > 1.6:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m")
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


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
	velocity.x = dir_patrulla * rapidez * 0.45
	basis = Basis.looking_at(Vector3(dir_patrulla, 0.0, 0.0))
	if anim != null:
		anim.play("walk")


func ir_a(destino):
	var dx = destino.x - global_position.x
	if absf(dx) <= 0.15:
		frenar("idle")
		return
	var dir_x = signf(dx)
	basis = Basis.looking_at(Vector3(dir_x, 0.0, 0.0))
	if is_on_floor() and (not _hay_suelo_adelante(dir_x) or _hay_pared_adelante(dir_x)):
		velocity.x = 0.0
		if anim != null:
			anim.play("idle")
		return
	velocity.x = dir_x * rapidez
	if anim != null:
		anim.play("walk")


func mirar_a(destino):
	var dx = destino.x - global_position.x
	if absf(dx) > 0.15:
		basis = Basis.looking_at(Vector3(signf(dx), 0.0, 0.0))


func _hay_suelo_adelante(dir_x: float) -> bool:
	rayo_suelo.from = global_position + Vector3(dir_x * 0.65, 0.5, 0.0)
	rayo_suelo.to = global_position + Vector3(dir_x * 0.65, -1.2, 0.0)
	return not get_world_3d().direct_space_state.intersect_ray(rayo_suelo).is_empty()


func _hay_pared_adelante(dir_x: float) -> bool:
	rayo_pared.from = global_position + Vector3(0.0, 0.8, 0.0)
	rayo_pared.to = global_position + Vector3(dir_x * 0.75, 0.8, 0.0)
	return not get_world_3d().direct_space_state.intersect_ray(rayo_pared).is_empty()


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	if anim != null:
		anim.play(animacion)


func distancia():
	return global_position.distance_to(jugador.global_position)
