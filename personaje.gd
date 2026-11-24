extends CharacterBody3D

enum Estado { QUIETO, CORRER, AIRE }
# altura del salto que se puede hacer desde cada estado (en el aire es el 2.º salto)
const ALTURA = [1.5, 1.5, 1.0]   # metros, en el orden del enum

@export var camara: Camera3D
@export var speed_caminar = 6.0
@export var speed_correr = 6.0
@export var tiempo_arranque = 0.12
@export var gravedad = 25.0
@onready var anim = $Modelo/AnimationPlayer

# Nombres viejos (los que usan los scripts) -> animacion del modelo KayKit y su rapidez.
# Asi apuntar.gd y esquivar.gd siguen pidiendo "crouch", "attack-melee-right", etc.
const ANIM = {
	"idle": ["Idle", 1.0],
	"sprint": ["Running_A", 1.1],
	"jump": ["Jump_Start", 1.4],
	"fall": ["Jump_Idle", 1.0],
	"attack-melee-right": ["1H_Melee_Attack_Chop", 4.0],
	"attack-melee-left": ["1H_Melee_Attack_Slice_Diagonal", 4.0],
	"attack-remate": ["1H_Melee_Attack_Slice_Horizontal", 3.5],
	"crouch": ["Dodge_Forward", 1.6],
	"hit": ["Hit_A", 2.0],
	"die": ["Death_A", 1.0],
}
const EN_BUCLE = ["Idle", "Running_A", "Jump_Idle"]
# Armas del pack que Ceniza no usa (se queda con las dagas).
const OCULTAR = ["1H_Crossbow", "2H_Crossbow", "Throwable"]

# Enchufes: otros scripts (las acciones del juego) cambian estas tres variables.
var multiplicador = 1.0     # 1 = rapidez normal, 0.5 = la mitad, 0 = quieto
var empuje = Vector3.ZERO   # velocidad extra en m/s (dash, retroceso)
var accion = ""             # animación de la acción; "" = ninguna
var avance = Vector3.ZERO   # la parte de la velocidad que dan las teclas
var estado = Estado.QUIETO
var altura = 0.0
var saltos = 0   # vuelve a 0 al tocar el suelo
var soltar_plataforma = 0.0
var reloj_coyote = 0.0
var reloj_buffer_salto = 0.0
var forma_plataforma = CapsuleShape3D.new()
var plataformas_ignoradas = {}   # plataformas que el cuerpo está atravesando
var plataforma_soltada = null    # la tabla de la que se bajó con abajo + saltar
const AYUDA_SUBIR = 1.0          # si el tope de la tabla queda hasta 1 m sobre los pies, sube a ella
var consulta_plataforma = PhysicsShapeQueryParameters3D.new()
var consulta_suelo: PhysicsRayQueryParameters3D


func _ready():
	if camara == null:
		camara = get_viewport().get_camera_3d()
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	forma_plataforma.radius = 0.37
	forma_plataforma.height = 1.75
	consulta_plataforma.shape = forma_plataforma
	consulta_plataforma.collision_mask = 2
	consulta_plataforma.exclude = [get_rid()]
	consulta_suelo = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 2)
	consulta_suelo.exclude = [get_rid()]
	for n in EN_BUCLE:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for n in OCULTAR:
		var arma = $Modelo.find_child(n, true, false)
		if arma != null:
			arma.visible = false


func _physics_process(delta):
	soltar_plataforma = maxf(soltar_plataforma - delta, 0.0)
	reloj_buffer_salto = maxf(reloj_buffer_salto - delta, 0.0)

	if is_on_floor():
		saltos = 0
		reloj_coyote = 0.12
	else:
		reloj_coyote = maxf(reloj_coyote - delta, 0.0)
		var g = gravedad * (1.25 if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta

	if Input.is_action_just_pressed("saltar"):
		if Input.is_action_pressed("move_down") and is_on_floor() and _sobre_plataforma():
			soltar_plataforma = 0.24
			velocity.y = -2.0
			reloj_coyote = 0.0
			reloj_buffer_salto = 0.0
		else:
			reloj_buffer_salto = 0.12

	if reloj_buffer_salto > 0.0:
		if reloj_coyote > 0.0:
			velocity.y = sqrt(2 * gravedad * ALTURA[Estado.CORRER])
			saltos = 1
			reloj_coyote = 0.0
			reloj_buffer_salto = 0.0
			print("salto 1 · altura ", ALTURA[Estado.CORRER], " m")
		elif saltos < 2:
			velocity.y = sqrt(2 * gravedad * ALTURA[Estado.AIRE])
			saltos = 2
			reloj_buffer_salto = 0.0
			print("salto 2 · altura ", ALTURA[Estado.AIRE], " m")

	if Input.is_action_just_released("saltar") and velocity.y > 0.0:
		velocity.y *= 0.58

	# subiendo o bajando a propósito: se ignoran todas las plataformas atravesables
	var atravesando = soltar_plataforma > 0.0 or velocity.y > 0.05
	set_collision_mask_value(2, not atravesando)
	# si no, solo se ignoran las que el cuerpo ya tiene encima de los pies
	_actualizar_plataformas_ignoradas()

	var entrada = Vector3.ZERO
	if prueba == 0:
		entrada.x = Input.get_axis("move_left", "move_right")
	else:
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		entrada = Vector3(input_dir.x, 0.0, input_dir.y)
	# solo el giro de la cámara en Y, para que la inclinación no afecte
	var giro_cam = camara.global_rotation.y
	var direction = entrada.rotated(Vector3.UP, giro_cam).normalized()

	var corre = Input.is_action_pressed("correr")
	var speed = speed_correr if corre else speed_caminar
	var objetivo = direction * speed * multiplicador
	var paso = speed / tiempo_arranque * delta
	avance = avance.move_toward(objetivo, paso)
	velocity.x = avance.x + empuje.x
	velocity.z = avance.z + empuje.z

	if direction.length() > 0:
		basis = Basis.looking_at(direction)

	move_and_slide()
	if prueba == 0:
		global_position.z = 0.0
	var antes = estado
	estado = elegir_estado()
	altura = ALTURA[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " · salto de ", altura, " m")
	animar()
	_prueba()


func _sobre_plataforma() -> bool:
	consulta_suelo.from = global_position + Vector3(0, 0.2, 0)
	consulta_suelo.to = global_position + Vector3(0, -0.25, 0)
	var r = get_world_3d().direct_space_state.intersect_ray(consulta_suelo)
	if r.is_empty():
		return false
	plataforma_soltada = r.collider
	return true


# Cada tabla atravesable que el cuerpo toca y que queda por encima de los pies:
#  - si el tope está cerca (hasta AYUDA_SUBIR) y no vamos subiendo, el personaje
#    se impulsa un poquito y queda parado encima (no hace falta caer justo con los pies);
#  - si está más alta, se atraviesa (excepción de colisión).
# La tabla que se pisa sigue siendo sólida.
func _actualizar_plataformas_ignoradas():
	consulta_plataforma.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.875, 0))
	var dentro = {}
	var pies = global_position.y
	for r in get_world_3d().direct_space_state.intersect_shape(consulta_plataforma, 8):
		var c = r.collider
		if not c is CollisionObject3D:
			continue
		var caja = _caja_plataforma(c, r.shape)
		var tope = caja.end.y
		if tope <= pies + 0.05:
			continue
		dentro[c] = true
		var encima = global_position.x > caja.position.x - 0.25 and global_position.x < caja.end.x + 0.25
		var subir = encima and tope - pies <= AYUDA_SUBIR and velocity.y <= 0.05
		if subir and soltar_plataforma <= 0.0 and c != plataforma_soltada:
			velocity.y = sqrt(2.0 * gravedad * (tope - pies + 0.15))
	if plataforma_soltada != null and not dentro.has(plataforma_soltada) and soltar_plataforma <= 0.0:
		plataforma_soltada = null
	for c in plataformas_ignoradas.keys():
		if not dentro.has(c) and is_instance_valid(c):
			remove_collision_exception_with(c)
	for c in dentro:
		if not plataformas_ignoradas.has(c):
			add_collision_exception_with(c)
	plataformas_ignoradas = dentro


func _caja_plataforma(c: CollisionObject3D, indice: int) -> AABB:
	var duenio = c.shape_find_owner(indice)
	var forma = c.shape_owner_get_shape(duenio, 0)
	var xf = c.global_transform * c.shape_owner_get_transform(duenio)
	var caja: AABB
	if forma is BoxShape3D:
		caja = AABB(-forma.size * 0.5, forma.size)
	else:
		caja = forma.get_debug_mesh().get_aabb()
	return xf * caja


func elegir_estado():
	if not is_on_floor():
		return Estado.AIRE
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	return Estado.CORRER   # Ceniza no camina: siempre corre


func animacion(n):
	return ANIM.get(n, [n, 1.0])[0]


# Pone la animacion traducida; si ya es la puesta no la reinicia
# (las de una vez, como saltar o morir, se quedan en su ultimo cuadro).
func tocar(n):
	var datos = ANIM.get(n, [n, 1.0])
	if not anim.has_animation(datos[0]):
		return
	if anim.assigned_animation == datos[0]:
		return
	anim.play(datos[0], 0.08, datos[1])


func animar():
	if accion != "":
		tocar(accion)
		return
	match estado:
		Estado.QUIETO:
			tocar("idle")
		Estado.CORRER:
			tocar("sprint")
		Estado.AIRE:
			tocar("jump" if velocity.y > 0 else "fall")


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: en el Inspector del
# Personaje elijan "Prueba" (y, si la prueba usa una acción, escriban su nombre
# en "Accion Prueba"). Con F5 el personaje se mueve solo y escribe los números
# en el panel Output. La última línea de _physics_process() es _prueba().
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s") var prueba = 0
@export var accion_prueba = ""
var _cuadro = 0
var _termino = false
var _y_max = 0.0
var _cuadro_max = 0


func _prueba():
	if prueba == 0 or _termino:
		return
	_cuadro += 1
	var avanzar = "move_up"
	if _cuadro == 1:
		if prueba <= 3:
			_apretar(avanzar)
		if prueba == 4:
			_apretar(accion_prueba)
		return
	var n = _cuadro - 1
	if prueba == 3 and n == 30:
		_apretar(accion_prueba)
	if prueba == 2 and n == 60:
		Input.action_release(avanzar)
	var marcas = []
	if prueba == 1:
		marcas = [1, 2, 3, 5, 10, 15, 20, 30, 60]
	elif prueba == 2:
		marcas = [59, 60, 61, 62, 63, 65, 70, 80, 90]
	elif prueba == 3:
		marcas = [29, 30, 31, 32, 33, 35, 40, 45, 50, 60, 75, 90]
	else:
		marcas = [1, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150]
	if n in marcas:
		print("[prueba] cuadro ", n, ": ", _resumen())
	_cambios(n)
	if global_position.y > _y_max + 0.0001:
		_y_max = global_position.y
		_cuadro_max = n
	if n == marcas[-1]:
		Input.action_release(avanzar)
		_soltar(accion_prueba)
		_termino = true
		if _y_max > 0.01:
			print("[prueba] altura máxima ", snappedf(_y_max, 0.01), " en el cuadro ", _cuadro_max)


func _resumen():
	var t = "posición " + str(global_position.snappedf(0.01))
	t += " · rapidez " + str(snappedf(Vector2(velocity.x, velocity.z).length(), 0.01))
	t += " · y " + str(snappedf(global_position.y, 0.01))
	t += " · animación " + str(anim.current_animation)
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t


# Escribe el cuadro exacto en el que cambia cualquier variable "estado".
var _antes = {}


func _cambios(n):
	for nodo in _con_estado():
		var e = _nombre(nodo)
		if _antes.has(nodo) and _antes[nodo] != e:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", e)
		_antes[nodo] = e


func _con_estado():
	var lista = []
	for nodo in [self] + get_children() + get_tree().get_nodes_in_group("probar"):
		if nodo.get_script() != null and "estado" in nodo:
			lista.append(nodo)
	return lista


func _nombre(nodo):
	var nombres = nodo.get_script().get_script_constant_map().get("Estado", {})
	for k in nombres:
		if nombres[k] == nodo.estado:
			return k
	return str(nodo.estado)


func _apretar(a):
	if a == "":
		print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
	elif not InputMap.has_action(a):
		print("[prueba] falta la acción '", a, "' en el Input Map")
	else:
		Input.action_press(a)


func _soltar(a):
	if a != "" and InputMap.has_action(a):
		Input.action_release(a)
