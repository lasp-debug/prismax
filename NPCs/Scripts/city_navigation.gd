class_name CityNavigation
extends NavigationRegion3D

## Malla de navegación del mapa procedural del juego.
##
## La ciudad (`generador_ciudad.gd`) se construye al arrancar y NO trae una malla de navegación
## horneada. Sus calles, en cambio, son una retícula regular que el propio generador conoce, así
## que en lugar de hornear geometría (miles de mallas que además cambian con la semilla) la malla
## se compone A MANO a partir de ese trazado:
##
##   1. Se cubre TODO el marco de la ciudad con una cuadrícula de celdas cuadradas.
##   2. Se descartan las celdas que caen dentro de una manzana EDIFICADA (el generador entrega su
##      lista): los ciudadanos caminan por calles y aceras, nunca por dentro de un edificio.
##   3. Cada celda caminable es un cuadrilátero, y los vértices se comparten entre celdas vecinas
##      para que las aristas casen y la malla quede unida de forma fiable.
##
## El resultado es un laberinto de calles por el que el `NPCSpawner` puede elegir destinos
## alcanzables. Funciona con cualquier semilla y con cualquier tamaño de ciudad, porque lee el
## trazado real del generador.

## Generador de la ciudad (el nodo con `generador_ciudad.gd`).
@export var ciudad_path: NodePath
## Lado (m) de cada celda de la cuadrícula de navegación. 3 m = una loseta de acera del kit.
@export var cell_size := 3.0
## Cota (Y) a la que se tiende la malla: la acera, donde apoyan los ciudadanos.
@export var floor_y := 0.0
## Margen extra (m) que se recorta alrededor de cada manzana edificada, para que la malla no
## roce la fachada (el agente tiene radio).
@export var block_margin := 0.6

var _verts := PackedVector3Array()
var _vmap := {}
var _polys: Array = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_navigation()


## Compone la malla en cuanto exista la ciudad. El generador la construye de forma SÍNCRONA en su
## _ready, y este nodo es un hermano posterior, así que normalmente ya la encuentra lista y la
## malla queda montada ANTES de que el NPCSpawner (otro hermano más tarde) empiece a colocar gente.
## Sólo si aún no está, se espera unos fotogramas.
func _build_navigation() -> void:
	var ciudad: Node = get_node_or_null(ciudad_path)
	if ciudad == null:
		push_warning("CityNavigation: no se encontró el generador de la ciudad (%s)" % ciudad_path)
		return
	for _i in 240:
		if ciudad.get_node_or_null("CiudadGenerada") != null:
			break
		await get_tree().process_frame
	var datos: Dictionary = ciudad.call("datos_navegacion")
	if not bool(datos.get("listo", false)):
		push_warning("CityNavigation: el generador todavía no tiene trazado")
		return
	_build_mesh(datos)


func _build_mesh(datos: Dictionary) -> void:
	var off: Vector2 = datos["off"]
	var ext: Vector2 = datos["ext"]
	var hw: float = float(datos["hw"])
	var bloques: Array = datos["bloques"]

	var cell := maxf(1.0, cell_size)
	var origin := off - Vector2(hw, hw)
	var span := ext + Vector2(2.0 * hw, 2.0 * hw)
	var nx := int(round(span.x / cell))
	var ny := int(round(span.y / cell))
	if nx <= 0 or ny <= 0:
		push_warning("CityNavigation: trazado inválido")
		return

	# 1) Rejilla de ocupación: todo caminable salvo lo que cae dentro de una manzana edificada.
	var walk := PackedByteArray()
	walk.resize(nx * ny)
	walk.fill(1)
	for rect_v in bloques:
		var rect: Rect2 = rect_v
		var r := rect.grow(block_margin)
		var i0 := clampi(int(floor((r.position.x - origin.x) / cell)), 0, nx - 1)
		var i1 := clampi(int(ceil((r.end.x - origin.x) / cell)) - 1, 0, nx - 1)
		var j0 := clampi(int(floor((r.position.y - origin.y) / cell)), 0, ny - 1)
		var j1 := clampi(int(ceil((r.end.y - origin.y) / cell)) - 1, 0, ny - 1)
		for j in range(j0, j1 + 1):
			var fila := j * nx
			for i in range(i0, i1 + 1):
				walk[fila + i] = 0

	# 2) Polígonos: cada celda caminable es un cuadrilátero; los vértices se comparten por esquina.
	_verts = PackedVector3Array()
	_vmap = {}
	_polys = []
	for j in ny:
		var fila := j * nx
		for i in nx:
			if walk[fila + i] == 0:
				continue
			var a := _vertex(origin, cell, i, j)
			var b := _vertex(origin, cell, i + 1, j)
			var c := _vertex(origin, cell, i + 1, j + 1)
			var d := _vertex(origin, cell, i, j + 1)
			_polys.append(PackedInt32Array([a, b, c, d]))

	if _polys.is_empty():
		push_warning("CityNavigation: la malla salió vacía")
		return

	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 45.0
	nm.vertices = _verts
	for poly in _polys:
		nm.add_polygon(poly)
	navigation_mesh = nm
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)
	print("[CityNavigation] malla de navegación lista: %d celdas, %d vértices, ciudad %.0fx%.0f m"
			% [_polys.size(), _verts.size(), span.x, span.y])


func _vertex(origin: Vector2, cell: float, i: int, j: int) -> int:
	var key := i * 1000003 + j
	if _vmap.has(key):
		return int(_vmap[key])
	_verts.append(Vector3(origin.x + float(i) * cell, floor_y, origin.y + float(j) * cell))
	var idx := _verts.size() - 1
	_vmap[key] = idx
	return idx