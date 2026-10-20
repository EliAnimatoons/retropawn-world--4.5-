extends Node2D

# No necesitas configurar el ID manualmente si el nombre del nodo ya es bt1, eli, etc.
# Pero dejamos la variable por si quieres sobreescribirla luego.
@export var id_manual: String = ""

func resaltar(valor: bool):
	var tween = create_tween()
	if valor:
		# Hace un efecto de "brillo" suave
		tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	else:
		# Vuelve a la normalidad
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
