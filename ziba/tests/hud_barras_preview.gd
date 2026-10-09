extends Node

## Escena de PRUEBA (no forma parte del juego): muestra el HUD circular aislado
## y modifica vida/escudo con el tiempo para comprobar que las barras siguen
## actualizándose tras reorganizarlas en ESCUDO (izq) | retrato | VIDA (der).

@onready var _stats: EstadisticasJugador = $Estadisticas

func _ready() -> void:
	# Escudo a ~35 % y vida a ~70 % para distinguir claramente ambas medias lunas.
	await get_tree().create_timer(0.4).timeout
	_stats.resistencia = 35.0
	_stats.resistencia_cambiada.emit(_stats.resistencia, _stats.resistencia_max)
	_stats.vida = 70.0
	_stats.vida_cambiada.emit(_stats.vida, _stats.vida_max)