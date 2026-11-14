extends Area3D

# La zona no quita ni da vida: solo le dice a la Salud donde esta.
@export_enum("luz", "penumbra") var tipo = 0


func _ready():
	body_entered.connect(_entra)
	body_exited.connect(_sale)


func _entra(cuerpo):
	contar(cuerpo, 1)


func _sale(cuerpo):
	contar(cuerpo, -1)


# Solo le importa a quien tenga Salud (Ceniza). Las cajas y enemigos no.
func contar(cuerpo, cuanto):
	var salud = cuerpo.get_node_or_null("Salud")
	if salud == null:
		return
	if tipo == 0:
		salud.en_luz += cuanto
	else:
		salud.en_penumbra += cuanto
