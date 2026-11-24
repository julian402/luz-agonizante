extends Area3D

# Bola que viaja en linea recta en el plano del juego (z = 0).
# Le pega a quien tenga Salud, se rompe con paredes y con el ataque de Ceniza.
# Uso: var p = PROYECTIL.instantiate(); padre.add_child(p); p.lanzar(desde, dir, 7.0, 8, Color("#7CFF4F"))

@export var vida = 3.0
var direccion = Vector3.RIGHT
var rapidez = 7.0
var danio = 8
var color = Color("#7CFF4F")
var dueno = null   # quien la lanzo: no se pega a si mismo
var rota = false


func _ready():
	add_to_group("rompibles")
	body_entered.connect(_al_tocar)


func lanzar(desde, dir, nueva_rapidez, nuevo_danio, nuevo_color):
	global_position = Vector3(desde.x, desde.y, 0.0)
	dir.z = 0.0
	direccion = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
	rapidez = nueva_rapidez
	danio = nuevo_danio
	color = nuevo_color
	var mat = $Malla.material_override
	if mat != null:
		mat = mat.duplicate()
		mat.albedo_color = color
		mat.emission = color
		$Malla.material_override = mat
	$Luz.light_color = color
	$Rastro.color = color


func _physics_process(delta):
	if rota:
		return
	global_position += direccion * rapidez * delta
	global_position.z = 0.0
	vida -= delta
	if vida <= 0.0:
		romper()


func _al_tocar(cuerpo):
	if rota or cuerpo == dueno or cuerpo.is_in_group("enemigos"):
		return
	var salud = cuerpo.get_node_or_null("Salud")
	if salud != null:
		# Si Ceniza esquiva, es_invulnerable() la protege sola dentro de recibir_golpe.
		salud.recibir_golpe(danio)
		romper()
		return
	# Cualquier otro cuerpo (paredes, pisos) la rompe.
	romper()


# El ataque de Ceniza la busca con recibir_golpe: se rompe y no hace nada mas.
func recibir_golpe(_cuanto):
	romper()


func romper():
	if rota:
		return
	rota = true
	Efectos.chispas(get_parent(), global_position, color, 10)
	queue_free()
