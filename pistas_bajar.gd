extends Node

# Pistas para bajar por las tablas que se atraviesan (S + ESPACIO), sin tocar nivel.tscn.
#  - Los puentes por donde se sigue el camino tienen flechas que bajan y un borde que late.
#  - Al pararse encima, sobre Ceniza sale "S + ESPACIO: BAJAR"; si ya tiene S apretada, solo "ESPACIO".
#  - Cuando Ceniza ya bajo por un puente, ese puente deja de insistir (las flechas quedan tenues).

const PUENTES = [
	"Sector1_Celdas/PuenteCeldas",          # etapa 1: a la cripta
	"CriptaOscura/PuenteCripta",            # etapa 1: al foso de la llave
	"TorresYCampanario/PuentePozoCentral",  # etapa 2: a las alcantarillas
	"MurallasYPozoAbismo/PuenteMuralla",    # etapa 3: al foso del guardian
	"MurallasYPozoAbismo/PA_Top",           # etapa 3: al pozo del trono
]
const CIAN = Color(0.55, 0.85, 1.0)
const DORADO = Color("#F2C14E")

var pj: CharacterBody3D
var puentes = []      # { rect: Rect2 (x, y_tope, ancho), flechas: [], borde, mat, aprendido }
var cartel = Label3D.new()
var t = 0.0


func _ready():
	await get_tree().process_frame
	var escena = get_tree().current_scene
	pj = escena.get_node_or_null("Personaje")
	var nivel = escena.get_node_or_null("Nivel")
	if pj == null or nivel == null:
		return
	for ruta in PUENTES:
		var cuerpo = nivel.get_node_or_null(ruta)
		if cuerpo == null:
			push_warning("pista sin puente: " + ruta)
			continue
		var forma = cuerpo.find_children("*", "CollisionShape3D", true, false)
		if forma.is_empty() or not (forma[0].shape is BoxShape3D):
			continue
		var cs = forma[0]
		var tam = cs.shape.size * cs.global_transform.basis.get_scale()
		var p = cs.global_position
		puentes.append(_armar(nivel, p.x - tam.x * 0.5, p.y + tam.y * 0.5, tam.x))

	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.no_depth_test = true
	cartel.fixed_size = false
	cartel.pixel_size = 0.007
	cartel.font_size = 48
	cartel.outline_size = 16
	cartel.modulate = DORADO
	cartel.outline_modulate = Color(0.03, 0.03, 0.05, 0.95)
	cartel.render_priority = 10
	cartel.visible = false
	nivel.add_child(cartel)


func _armar(nivel, x0, tope, ancho):
	var raiz = Node3D.new()
	raiz.position = Vector3(x0 + ancho * 0.5, tope, 0)
	nivel.add_child(raiz)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(CIAN, 0.6)
	mat.no_depth_test = false
	# Borde de luz en el frente de las tablas: "esto es distinto al piso".
	var borde = MeshInstance3D.new()
	var caja = BoxMesh.new()
	caja.size = Vector3(ancho, 0.09, 0.06)
	caja.material = mat
	borde.mesh = caja
	borde.position = Vector3(0, 0.0, 0.78)
	borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(borde)
	# Las tablas brillan un poco por encima.
	var capa = MeshInstance3D.new()
	var tapa = BoxMesh.new()
	tapa.size = Vector3(ancho, 0.02, 1.5)
	var mat_tapa = mat.duplicate()
	tapa.material = mat_tapa
	capa.mesh = tapa
	capa.position.y = 0.02
	capa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(capa)
	# Flechas (chevrones hechos con dos barritas) que bajan a traves del puente.
	var flechas = []
	var n = maxi(1, int(ancho / 4.0))
	for i in n:
		var f = Node3D.new()
		f.position = Vector3(-ancho * 0.5 + (i + 0.5) * ancho / n, 0.9, 0.9)
		for fila in [0.0, -0.32]:          # doble chevron
			for lado in [-1.0, 1.0]:
				var barra = MeshInstance3D.new()
				var b = BoxMesh.new()
				b.size = Vector3(0.62, 0.13, 0.04)
				b.material = mat
				barra.mesh = b
				barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				barra.position = Vector3(lado * 0.21, fila, 0)
				barra.rotation.z = lado * deg_to_rad(40)
				f.add_child(barra)
		raiz.add_child(f)
		flechas.append(f)
	return {"x0": x0, "x1": x0 + ancho, "tope": tope, "raiz": raiz, "flechas": flechas, "mat": mat, "mat_tapa": mat_tapa, "aprendido": false}


func _process(delta):
	if pj == null:
		return
	t += delta
	var pos = pj.global_position
	var encima = null
	for p in puentes:
		var dentro_x = pos.x > p.x0 - 0.2 and pos.x < p.x1 + 0.2
		# Si Ceniza termino debajo del puente, ya aprendio a bajar por el.
		if dentro_x and pos.y < p.tope - 1.5 and pos.y > p.tope - 8.0:
			p.aprendido = true
		if dentro_x and absf(pos.y - p.tope) < 0.35 and pj.is_on_floor():
			encima = p
		# Se ve de cerca; brilla mas si todavia no se ha usado.
		var dx = maxf(0.0, maxf(p.x0 - pos.x, pos.x - p.x1))
		var cerca = clampf(1.0 - (dx - 4.0) / 8.0, 0.0, 1.0) * clampf(1.0 - (absf(pos.y - p.tope) - 3.0) / 3.0, 0.0, 1.0)
		var fuerza = 0.35 if p.aprendido else 1.0
		var pulso = 0.55 + 0.45 * sin(t * 4.0)
		p.mat.albedo_color.a = cerca * fuerza * (0.35 + 0.5 * pulso)
		p.mat_tapa.albedo_color.a = cerca * fuerza * (0.05 + 0.1 * pulso)
		p.raiz.visible = cerca > 0.01
		for i in p.flechas.size():
			var k = fmod(t * 0.9 + i * 0.33, 1.0)
			p.flechas[i].position.y = 1.4 - 1.4 * k     # bajan hasta las tablas y vuelven a empezar
			p.flechas[i].scale = Vector3.ONE * (1.0 - 0.3 * k)

	if encima != null and not encima.aprendido:
		cartel.visible = true
		cartel.text = "+ ESPACIO: BAJAR" if Input.is_action_pressed("move_down") else "S + ESPACIO: BAJAR"
		cartel.global_position = pos + Vector3(0, 3.3 + 0.06 * sin(t * 5.0), 0.3)
		cartel.modulate.a = 0.75 + 0.25 * sin(t * 6.0)
	else:
		cartel.visible = false
