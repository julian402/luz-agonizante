class_name Esqueleto
extends RefCounted

# Ayudas para los enemigos hechos con los modelos Skely (Carronero, Coloso, Escupidor).
# Los scripts siguen pidiendo los nombres viejos ("idle", "walk", "attack-melee-right"...)
# y aqui se traducen a las animaciones del esqueleto.

# En el Attack del Skely la mano pega al segundo 1.1: el aviso se ajusta para que
# el tajo caiga justo cuando entra el dano.
const GOLPE_ATTACK = 1.1

const NOMBRES = {
	"idle": "Idle",
	"walk": "Run",
	"interact-right": "Attack",       # el aviso: levanta el brazo (preparacion del golpe)
	"attack-melee-right": "Attack",   # sigue la misma animacion: no se reinicia
	"hit": "Hit",
	"die": "Death",
	"scream": "Scream",
}
# Las que no se cortan con "Idle" mientras estan sonando.
const DE_UNA_VEZ = ["Attack", "Hit", "Death", "Scream"]


# Bucles, ojos brillantes del color dado y un brillo tenue en los huesos
# (con el contraste nuevo, sin esto se pierden en lo negro). Se llama en _ready().
static func preparar(modelo, color_ojos, energia = 8.0, brillo_huesos = 0.35):
	var anim = modelo.get_node_or_null("AnimationPlayer")
	if anim != null:
		for n in ["Idle", "Run"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D and mat.resource_name.begins_with("EyeGlow"):
				var ojos = mat.duplicate()
				ojos.albedo_color = color_ojos
				ojos.emission_enabled = true
				ojos.emission = color_ojos
				ojos.emission_energy_multiplier = energia
				mi.set_surface_override_material(i, ojos)
			elif mat is StandardMaterial3D and brillo_huesos > 0.0:
				var huesos = mat.duplicate()
				huesos.emission_enabled = true
				huesos.emission = color_ojos.lerp(Color.WHITE, 0.6)
				huesos.emission_texture = mat.albedo_texture
				huesos.emission_energy_multiplier = brillo_huesos
				mi.set_surface_override_material(i, huesos)


# Pone la animacion (nombre viejo o nuevo) con su rapidez.
# No reinicia la que ya suena, y "Idle"/"Run" no cortan un ataque o un golpe a medias.
static func tocar(anim, nombre, rapidez = 1.0):
	if anim == null:
		return
	var n = NOMBRES.get(nombre, nombre)
	if not anim.has_animation(n):
		return
	var actual = anim.current_animation
	if actual == n:
		anim.speed_scale = rapidez
		return
	if actual in DE_UNA_VEZ and anim.is_playing() and n in ["Idle", "Run"]:
		return
	if anim.assigned_animation == "Death":
		return
	anim.speed_scale = rapidez
	anim.play(n, 0.12)


# Rapidez del Attack para que el golpe caiga cuando termina un aviso de "segundos".
static func rapidez_aviso(segundos):
	return GOLPE_ATTACK / maxf(segundos, 0.1)
