extends Node

# Pone las trampas en el nivel (sin tocar nivel.tscn). Cada una se da con un punto en el aire
# del pasillo; el piso (o el techo, para el hacha) se busca con un rayo.
# Van de menos a mas: la etapa 1 enseña, la 3 pide leer bien los tiempos.

const TRAMPA = preload("res://trampa.gd")
const P = 0   # Tipo.PINCHOS
const H = 1   # Tipo.HACHA
const C = 2   # Tipo.CHORRO

# [tipo, x, y en el aire del pasillo, { opciones }]
const LISTA = [
	# --- Etapa 1: Las Tumbas (enseña cada trampa sola) ---
	[P, 12.0, 1.0, {"ancho": 2.0}],                                   # primeros pinchos: un salto
	[H, 20.0, -11.0, {"periodo": 2.8}],                               # primera hacha, en la cripta
	[C, 37.5, -13.0, {"ciclo": 3.6}],                                 # primer chorro
	# --- Etapa 2: Las Catacumbas (combinadas con enemigos) ---
	[C, 61.0, 1.0, {"ciclo": 3.2, "lanzar": 13.0}],                   # al pie del campanario: tambien impulsa hacia arriba
	[P, 72.0, 1.0, {"ancho": 3.0, "ciclo": 3.0}],                     # pinchos que salen y entran
	[H, 108.5, 3.0, {"periodo": 2.4, "fase": 0.25}],                   # entre el paso central y la torre este
	[C, 71.0, -13.0, {"ciclo": 3.4, "fase": 0.5}],                    # alcantarillas
	[P, 105.0, -17.0, {"ancho": 2.5}],                                # fondo del pozo de las alcantarillas
	# --- Etapa 3: La Guardia (seguidas, hay que leer los tiempos) ---
	[H, 135.0, 3.0, {"periodo": 2.2, "fase": 0.5}],
	[P, 143.5, 1.0, {"ancho": 3.0, "ciclo": 2.6}],                    # bajo el escalon: se puede esquivar por arriba
	[P, 148.5, -3.0, {"ancho": 2.0}],                                 # en el foso del Guardian
	[C, 170.5, 1.0, {"ciclo": 3.0, "fase": 0.3}],
	[H, 176.0, 3.0, {"periodo": 2.0, "amplitud": 45.0}],                # cuida la boca del pozo
	# --- Etapa final: el Trono (chorros a los lados de la Sombra Madre) ---
	[C, 150.0, -27.0, {"ciclo": 4.0}],
	[C, 166.0, -27.0, {"ciclo": 4.0, "fase": 0.5}],
]

const DANIO = { P: 12, H: 18, C: 10 }
const LANZAR = { P: 7.0, H: 4.0, C: 11.0 }


func _ready():
	# Espera a que la fisica del nivel exista para tirar los rayos.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nivel = get_tree().current_scene.get_node_or_null("Nivel")
	if nivel == null:
		return
	var espacio = nivel.get_world_3d().direct_space_state
	for d in LISTA:
		var desde = Vector3(d[1], d[2], 0)
		var hacia = desde + (Vector3.UP if d[0] == H else Vector3.DOWN) * 20.0
		var q = PhysicsRayQueryParameters3D.create(desde, hacia, 1)
		q.collide_with_areas = false
		var golpe = espacio.intersect_ray(q)
		if golpe.is_empty():
			push_warning("trampa sin piso/techo en " + str(desde))
			continue
		var t = TRAMPA.new()
		t.tipo = d[0]
		t.danio = DANIO[d[0]]
		t.lanzar = LANZAR[d[0]]
		for k in d[3]:
			t.set(k, d[3][k])
		t.name = ["Pinchos", "Hacha", "Chorro"][d[0]] + "_%d" % roundi(d[1])
		if d[0] == H:
			# Del techo hasta 1 m sobre el piso: la cuchilla pasa a la altura del pecho de Ceniza.
			var q2 = PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 20.0, 1)
			var piso = espacio.intersect_ray(q2)
			var y_piso = piso.position.y if not piso.is_empty() else golpe.position.y - 7.0
			t.largo = golpe.position.y - (y_piso + 1.0)
			# Que la cuchilla y la cadena no atraviesen ninguna plataforma: se abre solo hasta donde hay aire.
			var libre = _amplitud_libre(espacio, golpe.position, t.largo)
			if libre < t.amplitud:
				t.amplitud = libre
			if t.amplitud < 20.0:
				push_warning("hacha con poco espacio en " + str(desde) + ": " + str(t.amplitud) + " grados")
		t.position = Vector3(d[1], golpe.position.y, 0)   # Nivel esta en el origen
		nivel.add_child(t)
	print("trampas: ", get_tree().get_nodes_in_group("trampas").size())


# Mayor angulo (grados, igual a cada lado) en que el hacha no toca nada solido ni plataformas.
# Prueba la cuchilla (esfera un poco mas grande que ella) y la cadena (un rayo) cada grado.
func _amplitud_libre(espacio, pivote: Vector3, largo: float) -> float:
	var bola = SphereShape3D.new()
	bola.radius = 0.95
	var q = PhysicsShapeQueryParameters3D.new()
	q.shape = bola
	q.collision_mask = 3   # solidos y plataformas que se atraviesan
	var libre = 90.0
	for lado in [-1.0, 1.0]:
		var g = 0.0
		while g <= 90.0:
			var a = deg_to_rad(g) * lado
			var dir = Vector3(sin(a), -cos(a), 0)
			q.transform = Transform3D(Basis(), pivote + dir * largo)
			var choca = _toca_nivel(espacio.intersect_shape(q, 8))
			if not choca:
				var r = PhysicsRayQueryParameters3D.create(pivote + dir * 0.3, pivote + dir * (largo - 0.8), 3)
				var h = espacio.intersect_ray(r)
				choca = not h.is_empty() and _es_nivel(h.collider)
			if choca:
				break
			g += 1.0
		libre = minf(libre, g - 4.0)   # 3 grados de margen
	return maxf(libre, 0.0)


func _toca_nivel(choques) -> bool:
	for c in choques:
		if _es_nivel(c.collider):
			return true
	return false


# Solo cuenta el escenario: ni enemigos, ni Ceniza, ni los sellos (que se abren).
func _es_nivel(o) -> bool:
	return o is StaticBody3D and not o.is_in_group("sellos")
