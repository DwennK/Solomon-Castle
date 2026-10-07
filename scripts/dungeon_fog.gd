class_name DungeonFog
extends Node2D
## Opaque content mask with a faint, empty architectural silhouette above it.
## Seeing the structure never discovers its contents or adds it to the minimap.
class UnexploredStructure extends Node2D:
	var fog: DungeonFog

	func _draw() -> void:
		var dungeon: Dungeon = fog.world.dungeon
		var interior: DungeonInterior = dungeon.interior
		var texture: Texture2D = EnvironmentArt.FLOORS[1]
		var sample: Vector2 = texture.get_size()/4.0
		for cell: Vector2i in dungeon.cells:
			if dungeon.explored_position(Dungeon.to_world(cell)): continue
			# Neutral paving does not disclose a room's furnishings or special inlay.
			var source: Rect2 = Rect2(Vector2(posmod(cell.x,4),posmod(cell.y,4))*sample,sample)
			draw_texture_rect_region(texture,Rect2(Vector2(cell*Dungeon.CELL),Vector2.ONE*Dungeon.CELL),source,Color("879299"))
		for edge: Dictionary in interior.boundaries:
			if dungeon.explored_position(Dungeon.to_world(edge.cell)): continue
			interior.draw_contact(self,edge.cell,edge.side)
			interior.draw_wall(self,edge.cell,edge.side)

var world: GameWorld
var revision: int = -1
var clear_cells: Dictionary = {}
var bands: Array[Rect2] = []
var structure: UnexploredStructure
var ambience: Polygon2D

func _ready() -> void:
	z_index = 100
	# Keep the interface outside this world-space shading, and leave a broad,
	# readable pool around the mage instead of an opaque flashlight circle.
	ambience = Polygon2D.new()
	ambience.z_index = -1
	var bounds: Rect2 = Rect2(-4*Dungeon.CELL,-4*Dungeon.CELL,(Dungeon.WIDTH+8)*Dungeon.CELL,(Dungeon.HEIGHT+8)*Dungeon.CELL)
	ambience.polygon = PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	var shade: ShaderMaterial = ShaderMaterial.new()
	shade.shader = preload("res://assets/shaders/dungeon_ambience.gdshader")
	ambience.material = shade
	add_child(ambience)
	structure = UnexploredStructure.new()
	structure.fog = self
	structure.z_index = 1
	structure.modulate = Color(0.25,0.28,0.32,1.0)
	add_child(structure)
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(world.player): return
	(ambience.material as ShaderMaterial).set_shader_parameter("hero_position",world.player.position-Vector2(0,24))
	if revision!=world.dungeon.visibility_revision:
		rebuild()
		revision = world.dungeon.visibility_revision
		queue_redraw()
		structure.queue_redraw()
	# Tall sprites must not spill out of a black room into its visible doorway.
	# Modulation leaves intentional visibility states (e.g. an opened gate) intact.
	for actor: Node2D in world.actors.get_children():
		if actor==world.player: continue
		var known: bool = world.dungeon.explored_position(actor.position)
		if actor is WorldProp and actor.record.id=="gate":
			known = clear_cells.has(Vector2i((actor.position/Dungeon.CELL).floor()))
		actor.modulate.a = 1.0 if known else 0.0

func rebuild() -> void:
	clear_cells.clear()
	bands.clear()
	var dungeon: Dungeon = world.dungeon
	for cell: Vector2i in dungeon.cells:
		if not dungeon.explored_position(Dungeon.to_world(cell)): continue
		clear_cells[cell] = true
		# Reveal masonry bordering known floor, never an adjacent room's floor.
		for side: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP]:
			if not dungeon.cells.has(cell+side): clear_cells[cell+side] = true
		if not dungeon.cells.has(cell+Vector2i.UP):
			for height: int in [2,3]:
				var wall: Vector2i = cell+Vector2i.UP*height
				if dungeon.cells.has(wall): break
				clear_cells[wall] = true
	# Merge opaque cells into horizontal strips: no per-frame grid or raycast work.
	for y: int in range(-4,Dungeon.HEIGHT+4):
		var start: int = -4
		for x: int in range(-4,Dungeon.WIDTH+5):
			var clear: bool = clear_cells.has(Vector2i(x,y)) or x==Dungeon.WIDTH+4
			if clear and start<x: bands.append(Rect2(start*Dungeon.CELL,y*Dungeon.CELL,(x-start)*Dungeon.CELL,Dungeon.CELL))
			if clear: start=x+1

func _draw() -> void:
	for band: Rect2 in bands: draw_rect(band,Color.BLACK)
