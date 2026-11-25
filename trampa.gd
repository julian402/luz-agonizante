extends Node3D

# Trampas del nivel. Solo dañan a Ceniza (grupo "jugador"); los enemigos las ignoran.
# Todas AVISAN antes de pegar: el chiste es leerlas y pasar en el momento justo.
#
#  PINCHOS  fila de pinchos en el piso. ciclo = 0: siempre afuera.
#           ciclo > 0: escondidos -> brillan en rojo (aviso) -> salen -> se esconden.
#  HACHA    cuchilla que cuelga del techo y oscila como un pendulo.
#  CHORRO   respiradero de sombra: burbujea (aviso) y lanza una columna morada hacia arriba.
#           Pega y lanza a Ceniza por el aire (tambien sirve para subir si se usa bien).

enum Tipo { PINCHOS, HACHA, CHORRO }

@export var tipo = Tipo.PINCHOS
@export var ancho = 2.0          # PINCHOS: metros de pinchos
@export var largo = 6.0          # HACHA: del techo al centro de la cuchilla
@export var amplitud = 55.0      # HACHA: grados a cada lado
@export var periodo = 2.6        # HACHA: segundos de ida y vuelta
@export var ciclo = 0.0          # PINCHOS/CHORRO: segundos de un ciclo completo (0 = siempre activo)
@export var fase = 0.0           # 0..1, para que dos trampas iguales no vayan juntas
@export var danio = 15
@export var lanzar = 0.0         # velocidad hacia arriba que le da a Ceniza al pegarle

const AVISO = 0.6                # segundos de aviso antes de que salgan pinchos o chorro
const ACTIVO = 1.0               # segundos que quedan afuera
const ROJO = Color("#E8433A")
const MORADO = Color(0.62, 0.35, 1.0)

var t = 0.0
var area = Area3D.new()
var forma = CollisionShape3D.new()
var dentro = []                  # cuerpos de Ceniza que tocan la trampa
var activo = true
var piezas = Node3D.new()        # lo que se mueve (pinchos que suben, columna del chorro, cuchilla)
var brillo = StandardMaterial3D.new()
var luz = OmniLight3D.new()
var particulas = null
var columna = null
var mat_columna = null


func _ready():
	add_to_group("trampas")
	t = fase * maxf(ciclo if ciclo > 0.0 else periodo, 0.01)
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	area.body_entered.connect(func(b): if b.is_in_group("jugador"): dentro.append(b))
	area.body_exited.connect(func(b): dentro.erase(b))
	add_child(piezas)
	match tipo:
		Tipo.PINCHOS: _armar_pinchos()
		Tipo.HACHA: _armar_hacha()
		Tipo.CHORRO: _armar_chorro()
	area.add_child(forma)
	if luz.get_parent() == null:
		add_child(luz)


func _metal(color = Color(0.55, 0.55, 0.6)):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.7
	m.roughness = 0.35
	return m


func _armar_pinchos():
	var cono = CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.16
	cono.height = 0.6
	cono.radial_segments = 6
	cono.material = _metal()
	brillo.albedo_color = Color(0.5, 0.2, 0.2)
	brillo.emission_enabled = true
	brillo.emission = ROJO
	brillo.emission_energy_multiplier = 0.4
	var punta = CylinderMesh.new()
	punta.top_radius = 0.0
	punta.bottom_radius = 0.07
	punta.height = 0.22
	punta.radial_segments = 6
	punta.material = brillo
	var n = maxi(2, roundi(ancho / 0.32))
	for i in n:
		for fila in [-0.25, 0.25]:
			var x = -ancho * 0.5 + (i + 0.5) * ancho / n + (0.08 if fila > 0 else 0.0)
			var m = MeshInstance3D.new()
			m.mesh = cono
			m.position = Vector3(x, 0.3, fila)
			piezas.add_child(m)
			var p = MeshInstance3D.new()
			p.mesh = punta
			p.position = Vector3(x, 0.52, fila)
			piezas.add_child(p)
	# Base oscura para que se vean aunque esten escondidos.
	var base = MeshInstance3D.new()
	var caja = BoxMesh.new()
	caja.size = Vector3(ancho + 0.2, 0.08, 1.0)
	caja.material = _metal(Color(0.15, 0.12, 0.12))
	base.mesh = caja
	base.position.y = 0.04
	add_child(base)
	var b = BoxShape3D.new()
	b.size = Vector3(ancho, 0.55, 1.5)
	forma.shape = b
	forma.position.y = 0.3
	add_child(area)
	luz.light_color = ROJO
	luz.light_energy = 0.0
	luz.omni_range = ancho * 0.6 + 1.0
	luz.position.y = 0.6
	if ciclo > 0.0:
		piezas.position.y = -0.55


func _armar_hacha():
	# Cadena: del pivote (este nodo, pegado al techo) hasta la cuchilla.
	var cadena = MeshInstance3D.new()
	var c = CylinderMesh.new()
	c.top_radius = 0.04
	c.bottom_radius = 0.04
	c.height = largo
	c.material = _metal(Color(0.3, 0.3, 0.33))
	cadena.mesh = c
	cadena.position.y = -largo * 0.5
	piezas.add_child(cadena)
	# Cuchilla: media luna plana que mira a la camara, con filo rojo.
	var hoja = MeshInstance3D.new()
	var d = CylinderMesh.new()
	d.top_radius = 0.8
	d.bottom_radius = 0.8
	d.height = 0.1
	d.radial_segments = 20
	var acero = _metal(Color(0.75, 0.75, 0.8))
	acero.emission_enabled = true   # que se vea aunque este en la oscuridad
	acero.emission = Color(0.55, 0.55, 0.65)
	acero.emission_energy_multiplier = 0.5
	d.material = acero
	hoja.mesh = d
	hoja.rotation_degrees.x = 90
	hoja.scale = Vector3(1.0, 1.0, 0.55)
	hoja.position.y = -largo
	piezas.add_child(hoja)
	brillo.albedo_color = Color(0.4, 0.1, 0.1)
	brillo.emission_enabled = true
	brillo.emission = ROJO
	brillo.emission_energy_multiplier = 1.2
	var filo = MeshInstance3D.new()
	var f = TorusMesh.new()
	f.inner_radius = 0.74
	f.outer_radius = 0.84
	f.rings = 24
	f.material = brillo
	filo.mesh = f
	filo.rotation_degrees.x = 90
	filo.scale = Vector3(1.0, 1.0, 0.55)
	filo.position.y = -largo
	piezas.add_child(filo)
	var s = SphereShape3D.new()
	s.radius = 0.75
	forma.shape = s
	forma.position.y = -largo
	piezas.add_child(area)
	luz.light_color = ROJO
	luz.light_energy = 0.5
	luz.omni_range = 2.5
	luz.position.y = -largo
	piezas.add_child(luz)   # la luz va con la cuchilla


func _armar_chorro():
	# Respiradero: anillo oscuro en el piso con brillo morado.
	var aro = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.35
	tor.outer_radius = 0.6
	tor.material = _metal(Color(0.12, 0.1, 0.15))
	aro.mesh = tor
	aro.position.y = 0.08
	add_child(aro)
	brillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brillo.albedo_color = MORADO
	var fondo = MeshInstance3D.new()
	var disco = CylinderMesh.new()
	disco.top_radius = 0.35
	disco.bottom_radius = 0.35
	disco.height = 0.04
	disco.material = brillo
	fondo.mesh = disco
	fondo.position.y = 0.06
	add_child(fondo)
	# Columna (se ve solo cuando estalla).
	mat_columna = StandardMaterial3D.new()
	mat_columna.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_columna.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_columna.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_columna.albedo_color = Color(MORADO, 0.7)
	columna = MeshInstance3D.new()
	var cil = CylinderMesh.new()
	cil.top_radius = 0.25
	cil.bottom_radius = 0.5
	cil.height = 3.5
	cil.material = mat_columna
	columna.mesh = cil
	columna.position.y = 1.75
	columna.visible = false
	columna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(columna)
	# Burbujas del aviso.
	particulas = CPUParticles3D.new()
	particulas.amount = 16
	particulas.lifetime = 0.6
	particulas.emitting = false
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas.emission_sphere_radius = 0.35
	particulas.direction = Vector3.UP
	particulas.spread = 20.0
	particulas.gravity = Vector3.ZERO
	particulas.initial_velocity_min = 1.0
	particulas.initial_velocity_max = 2.5
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.2
	particulas.color = Color(0.8, 0.6, 1.0)
	var q = QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var mq = StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.vertex_color_use_as_albedo = true
	q.material = mq
	particulas.mesh = q
	particulas.position.y = 0.2
	add_child(particulas)
	var b = BoxShape3D.new()
	b.size = Vector3(1.0, 3.5, 1.5)
	forma.shape = b
	forma.position.y = 1.75
	add_child(area)
	luz.light_color = MORADO
	luz.light_energy = 0.3
	luz.omni_range = 3.0
	luz.position.y = 1.0


func _physics_process(delta):
	t += delta
	match tipo:
		Tipo.PINCHOS: _pinchos()
		Tipo.HACHA: _hacha()
		Tipo.CHORRO: _chorro()
	if activo:
		for b in dentro:
			if is_instance_valid(b):
				_pegar(b)


# En que parte del ciclo va: 0 escondido, 1 aviso, 2 activo.
func _momento():
	var x = fmod(t, ciclo)
	if x < ciclo - AVISO - ACTIVO:
		return [0, 0.0]
	if x < ciclo - ACTIVO:
		return [1, (x - (ciclo - AVISO - ACTIVO)) / AVISO]
	return [2, (x - (ciclo - ACTIVO)) / ACTIVO]


func _pinchos():
	if ciclo <= 0.0:
		activo = true
		brillo.emission_energy_multiplier = 0.4 + 0.2 * sin(t * 3.0)
		return
	var m = _momento()
	activo = m[0] == 2
	match m[0]:
		0:
			piezas.position.y = move_toward(piezas.position.y, -0.55, 0.05)
			brillo.emission_energy_multiplier = 0.2
			luz.light_energy = 0.0
		1:
			# Asoman un poco y brillan cada vez mas: "ya vienen".
			piezas.position.y = -0.55 + 0.15 * m[1] + 0.03 * sin(t * 40.0)
			brillo.emission_energy_multiplier = 0.5 + 3.0 * m[1]
			luz.light_energy = 1.2 * m[1]
		2:
			piezas.position.y = move_toward(piezas.position.y, 0.0, 0.25)
			brillo.emission_energy_multiplier = 1.5
			luz.light_energy = 0.6


func _hacha():
	activo = true
	piezas.rotation.z = deg_to_rad(amplitud) * sin(t * TAU / periodo)


func _chorro():
	var m = _momento()
	activo = m[0] == 2
	match m[0]:
		0:
			particulas.emitting = false
			columna.visible = false
			luz.light_energy = 0.3
			brillo.albedo_color = Color(MORADO, 1.0).darkened(0.4)
		1:
			particulas.emitting = true
			columna.visible = false
			luz.light_energy = 0.3 + 1.5 * m[1]
			brillo.albedo_color = MORADO.lightened(0.4 * m[1])
		2:
			particulas.emitting = false
			columna.visible = true
			# Sale rapido y se apaga al final.
			var s = minf(1.0, m[1] * 6.0)
			columna.scale = Vector3(1.0 + 0.1 * sin(t * 30.0), s, 1.0 + 0.1 * sin(t * 30.0))
			columna.position.y = 1.75 * s
			mat_columna.albedo_color.a = 0.75 * (1.0 - maxf(0.0, m[1] - 0.7) / 0.3)
			luz.light_energy = 2.0


func _pegar(b):
	var salud = b.get_node_or_null("Salud")
	if salud == null or salud.es_invulnerable() or salud.vida <= 0:
		return
	salud.recibir_golpe(danio)
	Efectos.chispas(get_parent(), b.global_position + Vector3(0, 1, 0), ROJO if tipo != Tipo.CHORRO else MORADO, 14)
	if lanzar > 0.0 and "velocity" in b:
		b.velocity.y = lanzar
	if tipo == Tipo.HACHA and "empuje" in b:
		# La cuchilla empuja hacia donde va.
		var va = signf(cos(t * TAU / periodo))
		b.empuje.x = va * 7.0
