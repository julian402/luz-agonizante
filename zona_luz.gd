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
		if cuanto > 0 and salud.en_luz == 0 and cuerpo.is_inside_tree():
			Efectos.anillo(cuerpo.get_parent(), cuerpo.global_position, Color(1, 0.82, 0.4, 0.8), 1.0)
		# Cada antorcha es un punto de control: si pierde una vida, vuelve aqui.
		if cuanto > 0 and salud.has_method("marcar_punto"):
			salud.marcar_punto(get_parent().global_position)
		salud.en_luz += cuanto
	else:
		salud.en_penumbra += cuanto
