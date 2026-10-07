class_name DungeonFog
extends Node2D
## Covers the whole world layer, including light pools, loot and spell effects.
## Entered rooms stay lit; corridors are uncovered only along unobstructed sightlines.
var world: GameWorld
var revision: int = -1
var clear_cells: Dictionary = {}
var bands: Array[Rect2] = []

func _ready() -> void:
	z_index = 100
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(world.player): return
	if revision!=world.dungeon.visibility_revision:
		rebuild()
		revision = world.dungeon.visibility_revision
		queue_redraw()
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
