extends StaticBody3D

@export var vida = 4


func recibir_golpe(danio):
	vida -= danio
	print(name, ": vida ", vida)
	if vida <= 0:
		print(name, " destruida")
		queue_free()
