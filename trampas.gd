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
	[H, 98.0, 3.0, {"periodo": 2.4, "fase": 0.25}],
	[C, 71.0, -13.0, {"ciclo": 3.4, "fase": 0.5}],                    # alcantarillas
	[P, 105.0, -17.0, {"ancho": 2.5}],                                # fondo del pozo de las alcantarillas
	# --- Etapa 3: La Guardia (seguidas, hay que leer los tiempos) ---
	[P, 139.5, 1.0, {"ancho": 3.0, "ciclo": 2.6}],
	[H, 144.0, 3.0, {"periodo": 2.2, "fase": 0.5}],
	[P, 148.5, -3.0, {"ancho": 2.0}],                                 # en el foso del Guardian
	[H, 168.0, 3.0, {"periodo": 2.0}],
	[C, 173.0, 1.0, {"ciclo": 3.0, "fase": 0.3}],
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
		t.position = Vector3(d[1], golpe.position.y, 0)   # Nivel esta en el origen
		nivel.add_child(t)
	print("trampas: ", get_tree().get_nodes_in_group("trampas").size())
