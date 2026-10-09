extends Node2D

## PRUEBA temporal: reproduce EXACTAMENTE la configuracion de barras del HUD
## (medias lunas ESCUDO izquierda / VIDA derecha) para verla sin depender del
## resto del juego.

@onready var _vida: IndicadorAnillo = $Dial/AnilloVida
@onready var _resist: IndicadorAnillo = $Dial/AnilloResistencia

func _ready() -> void:
	_vida.set_valor(0.7)
	_resist.set_valor(0.35)