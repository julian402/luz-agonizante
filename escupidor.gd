extends CharacterBody3D

# Escupidor: esqueleto de veneno que pelea de lejos.
# Se queda a 6-10 m de Ceniza, grita (aviso), escupe una bola verde y recarga.
# Si Ceniza se le acerca a menos de 4 m, camina hacia atras sin caerse.

enum Estado { QUIETO, ACERCARSE, APUNTAR, DISPARAR, RECARGA, ALEJARSE }

@export var vida = 3.0
@export var rango_ver = 12.0
@export var rango_perder = 15.0
@export var distancia_min = 6.0     # le gusta estar entre min y max
@export var distancia_max = 10.0
@export var distancia_huir = 4.0
@export var rapidez = 2.0
@export var rapidez_huir = 2.5
@export var tiempo_aviso = 0.6
@export var tiempo_disparo = 0.5
@export var tiempo_recarga = 2.0
@export var rapidez_bola = 7.0
@export var danio_bola = 8
@export var patrulla_rango = 3.0
@export var orbe_valor = 40
const COLOR = Color("#7CFF4F")
const ORBE = preload("res://orbe.tscn")
const BARRA = preload("res://barra_enemigo.tscn")
const PROYECTIL = preload("res://proyectil.tscn")

var estado = Estado.QUIETO
var reloj = 0.0
var reloj_aturdido = 0.0
var jugador = null
var origen_x = 0.0
var dir_patrulla = 1.0
var vida_max = 0.0
var barra = null
var aviso = null
var luz_mano = null
var apuntado = Vector3.ZERO   # donde estaba Ceniza al gritar
var empujon = Vector3.ZERO
var reloj_empujon = 0.0
var muerto = false
var rayo_suelo: PhysicsRayQueryParameters3D
var rayo_pared: PhysicsRayQueryParameters3D
var rayo_vista: PhysicsRayQueryParameters3D
@onready var anim = get_node_or_null("Modelo/AnimationPlayer")


func _ready():
	add_to_group("enemigos")
	jugador = get_tree().get_first_node_in_group("jugador")
	origen_x = global_position.x
	rayo_suelo = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 3)
	rayo_suelo.exclude = [get_rid()]
	rayo_pared = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
	rayo_pared.exclude = [get_rid()]
	# La vista solo choca con paredes (capa 1); Ceniza tambien esta en la 1.
	rayo_vista = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
	rayo_vista.exclude = [get_rid()]
	vida_max = vida
	barra = BARRA.instantiate()
	barra.position = Vector3(0, 2.0, 0)
	add_child(barra)
	aviso = Label3D.new()
	aviso.text = "!"
	aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aviso.no_depth_test = true
	aviso.position = Vector3(0, 2.5, 0)
	aviso.font_size = 130
	aviso.outline_size = 18
	aviso.pixel_size = 0.008
	aviso.modulate = COLOR
	aviso.visible = false
	add_child(aviso)
	_preparar_modelo()


# Bucles, ojos brillantes y la luz verde de la mano.
func _preparar_modelo():
	if anim != null:
		for n in ["Idle", "Run"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	Esqueleto.preparar($Modelo, COLOR)
	luz_mano = OmniLight3D.new()
	luz_mano.light_color = COLOR
	luz_mano.light_energy = 0.0
	luz_mano.omni_range = 2.0
	luz_mano.shadow_enabled = false
	var esqueleto = $Modelo.find_child("Skeleton3D", true, false)
	if esqueleto != null and esqueleto.find_bone("mixamorig_RightHand") >= 0:
		var hueso = BoneAttachment3D.new()
		hueso.bone_name = "mixamorig_RightHand"
		esqueleto.add_child(hueso)
		hueso.add_child(luz_mano)
	else:
		luz_mano.position = Vector3(0, 1.3, 0.4)
		add_child(luz_mano)


func _physics_process(delta):
	velocity += get_gravity() * delta
	if muerto or jugador == null or not is_instance_valid(jugador):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	reloj = maxf(reloj - delta, 0.0)
	reloj_aturdido = maxf(reloj_aturdido - delta, 0.0)

	if reloj_aturdido > 0.0:
		frenar("")
	else:
		var nuevo = decidir()
		if nuevo != estado:
			cambiar_a(nuevo)
		match estado:
			Estado.QUIETO:
				patrullar()
			Estado.ACERCARSE:
				caminar(signf(jugador.global_position.x - global_position.x), rapidez, true)
			Estado.ALEJARSE:
				caminar(-signf(jugador.global_position.x - global_position.x), rapidez_huir, false)
			Estado.APUNTAR:
				mirar_a(jugador.global_position)
				frenar("")
			Estado.DISPARAR, Estado.RECARGA:
				mirar_a(jugador.global_position)
				frenar("")

	# Las de una vez (Hit, Attack, Scream) quedan congeladas al terminar: vuelve a Idle.
	if anim != null and not anim.is_playing():
		tocar("Idle")

	if reloj_empujon > 0.0:
		reloj_empujon = maxf(reloj_empujon - delta, 0.0)
		velocity.x += empujon.x

	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func decidir():
	var d = distancia()
	var dy = absf(jugador.global_position.y - global_position.y)
	var lo_ve = d <= rango_ver and dy <= 4.0 and ve_a_ceniza()
	match estado:
		Estado.QUIETO:
			if lo_ve:
				return _elegir_posicion(d)
		Estado.ACERCARSE, Estado.ALEJARSE:
			if d > rango_perder or dy > 5.0:
				return Estado.QUIETO
			if not ve_a_ceniza():
				return Estado.QUIETO
			return _elegir_posicion(d)
		Estado.APUNTAR:
			if reloj <= 0.001:
				return Estado.DISPARAR
		Estado.DISPARAR:
			if reloj <= 0.001:
				return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return _elegir_posicion(d) if lo_ve else Estado.QUIETO
	return estado


# Muy cerca: se aleja. Muy lejos: se acerca. En su distancia: apunta.
func _elegir_posicion(d):
	if d < distancia_huir:
		var atras = -signf(jugador.global_position.x - global_position.x)
		if _hay_suelo_adelante(atras) and not _hay_pared_adelante(atras):
			return Estado.ALEJARSE
		return Estado.APUNTAR   # acorralado: dispara igual
	if d > distancia_max:
		return Estado.ACERCARSE
	if estado == Estado.ALEJARSE and d < distancia_min:
		return Estado.ALEJARSE
	return Estado.APUNTAR


func cambiar_a(nuevo):
	estado = nuevo
	aviso.visible = estado == Estado.APUNTAR
	luz_mano.light_energy = 1.6 if estado == Estado.APUNTAR else 0.0
	match estado:
		Estado.APUNTAR:
			reloj = tiempo_aviso
			apuntado = jugador.global_position + Vector3(0, 0.9, 0)
			# Levanta el brazo todo el aviso: la bola sale cuando el brazo baja.
			tocar("Attack", Esqueleto.rapidez_aviso(tiempo_aviso))
		Estado.DISPARAR:
			reloj = tiempo_disparo
			disparar()
		Estado.RECARGA:
			reloj = tiempo_recarga
			tocar("Idle")
		Estado.QUIETO:
			tocar("Idle")


func disparar():
	# Apunta a donde estaba Ceniza al terminar el grito (se puede esquivar).
	apuntado = jugador.global_position + Vector3(0, 0.9, 0)
	var lado = signf(apuntado.x - global_position.x)
	if lado == 0.0:
		lado = 1.0
	var desde = global_position + Vector3(lado * 0.5, 1.3, 0)
	var bola = PROYECTIL.instantiate()
	bola.dueno = self
	get_parent().add_child(bola)
	bola.lanzar(desde, apuntado - desde, rapidez_bola, danio_bola, COLOR)


func ve_a_ceniza():
	rayo_vista.from = global_position + Vector3(0, 1.3, 0)
	rayo_vista.to = jugador.global_position + Vector3(0, 0.9, 0)
	var golpe = get_world_3d().direct_space_state.intersect_ray(rayo_vista)
	return golpe.is_empty() or golpe.collider == jugador


func recibir_golpe(cuanto):
	if muerto:
		return
	vida -= cuanto
	barra.poner(maxf(vida, 0.0), vida_max)
	Efectos.destello($Modelo, 0.1)
	Efectos.chispas(get_parent(), global_position + Vector3(0, 1.1, 0), COLOR, 10)
	Efectos.numero(get_parent(), global_position + Vector3(0, 2, 0), "-" + str(cuanto), Color.WHITE)
	var dx = global_position.x - jugador.global_position.x
	empujon = Vector3((signf(dx) if absf(dx) > 0.05 else 1.0) * 4.0, 0.0, 0.0)
	reloj_empujon = 0.15
	if vida <= 0:
		morir()
		return
	# Si le pegan mientras apunta, pierde el disparo.
	if estado == Estado.APUNTAR:
		cambiar_a(Estado.RECARGA)
		reloj = 0.8
	reloj_aturdido = 0.2
	tocar("Hit", 3.0)
	Efectos.hitstop(get_tree(), 0.05 if cuanto < 2 else 0.12)


func morir():
	muerto = true
	aviso.visible = false
	barra.visible = false
	luz_mano.light_energy = 0.0
	collision_layer = 0
	Efectos.hitstop(get_tree(), 0.12)
	soltar_orbe()
	tocar("Death", 2.5)
	await get_tree().create_timer(0.6).timeout
	await Efectos.muerte($Modelo, COLOR)
	queue_free()


func soltar_orbe():
	var orbe = ORBE.instantiate()
	orbe.valor = orbe_valor
	orbe.position = global_position + Vector3(0, 0.8, 0)
	get_parent().add_child.call_deferred(orbe)


func patrullar():
	if patrulla_rango <= 0.1 or not is_on_floor() or distancia() > 26.0:
		frenar("Idle")
		return
	if global_position.x >= origen_x + patrulla_rango:
		dir_patrulla = -1.0
	elif global_position.x <= origen_x - patrulla_rango:
		dir_patrulla = 1.0
	if not _hay_suelo_adelante(dir_patrulla) or _hay_pared_adelante(dir_patrulla):
		dir_patrulla = -dir_patrulla
		if not _hay_suelo_adelante(dir_patrulla) or _hay_pared_adelante(dir_patrulla):
			frenar("Idle")
			return
	velocity.x = dir_patrulla * rapidez * 0.5
	basis = Basis.looking_at(Vector3(dir_patrulla, 0.0, 0.0))
	tocar("Run", 0.7)


# mirando: true camina de frente; false camina de espaldas (sigue mirando a Ceniza).
func caminar(dir_x, vel, mirando):
	if dir_x == 0.0:
		frenar("Idle")
		return
	if mirando:
		basis = Basis.looking_at(Vector3(dir_x, 0.0, 0.0))
	else:
		mirar_a(jugador.global_position)
	if is_on_floor() and (not _hay_suelo_adelante(dir_x) or _hay_pared_adelante(dir_x)):
		frenar("Idle")
		return
	velocity.x = dir_x * vel
	tocar("Run", -0.8 if not mirando else 0.9)


func mirar_a(destino):
	var dx = destino.x - global_position.x
	if absf(dx) > 0.15:
		basis = Basis.looking_at(Vector3(signf(dx), 0.0, 0.0))


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	if animacion != "":
		tocar(animacion)


# Solo cambia si es otra animacion (si no, la reinicia cada cuadro).
# Rapidez negativa: la pone al reves (caminar de espaldas).
func tocar(nombre, rapidez_anim = 1.0):
	if anim == null or not anim.has_animation(nombre):
		return
	if anim.current_animation == nombre and signf(anim.get_playing_speed()) == signf(rapidez_anim):
		return
	if rapidez_anim < 0.0:
		anim.play(nombre, 0.15, rapidez_anim, true)
	else:
		anim.play(nombre, 0.15, rapidez_anim)


func _hay_suelo_adelante(dir_x: float) -> bool:
	rayo_suelo.from = global_position + Vector3(dir_x * 0.65, 0.5, 0.0)
	rayo_suelo.to = global_position + Vector3(dir_x * 0.65, -1.2, 0.0)
	return not get_world_3d().direct_space_state.intersect_ray(rayo_suelo).is_empty()


func _hay_pared_adelante(dir_x: float) -> bool:
	rayo_pared.from = global_position + Vector3(0.0, 0.8, 0.0)
	rayo_pared.to = global_position + Vector3(dir_x * 0.75, 0.8, 0.0)
	var golpe = get_world_3d().direct_space_state.intersect_ray(rayo_pared)
	return not golpe.is_empty() and golpe.collider != jugador


func distancia():
	return global_position.distance_to(jugador.global_position)
