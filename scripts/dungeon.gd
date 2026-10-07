class_name Dungeon
extends Node2D

const CELL: int = 64
const WIDTH: int = 65
const HEIGHT: int = 51
var data: Dictionary = {}
var astar: AStarGrid2D
var cells: Dictionary = {}
var revealed: Dictionary = {}
var visited_rooms: Dictionary = {}
var visibility_revision: int = 0
var sight_origin: Vector2i = Vector2i(-1,-1)
const SIGHT_RADIUS: int = 12
const VISIBILITY_VERSION: int = 1
var village: bool = false
var interior: DungeonInterior

static func generate(seed_value: int, floor_number: int, difficulty: int = 0) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + floor_number * 7919 + difficulty * 982451653
	var layout: Dictionary = TowerLayout.generate(rng,floor_number)
	var rooms: Array = layout.rooms
	var grid: Array = layout.grid
	var enemies: Array = []
	var props: Array = []
	for i: int in range(rooms.size()):
		var r: Array = rooms[i]
		for kind: String in ["chest","urn","torch"]:
			var desired: Vector2i = Vector2i(r[0]+2 if kind!="urn" else r[0]+r[2]-3,r[1]+2)
			props.append({"id":"%s_%d"%[kind,i],"kind":kind,"pos":pair(TowerLayout.open_position(grid,r,desired)),"opened":false})
	var boss: String = {4:"king",8:"plague",11:"demon",13:"lich"}.get(floor_number,"")
	if floor_number == 13:
		var guard_room: int = rooms.size()-2 if int(layout.optional_room)!=rooms.size()-2 else rooms.size()-3
		var guard_pos: Vector2 = to_world(room_center(rooms[guard_room]))
		enemies.append({"id":"guardian","kind":"demon","pos":pair(guard_pos),"hp":-1.0,"dead":false})
	var gate_cells: Array = []
	var key_chest: String = ""
	if not boss.is_empty():
		gate_cells = layout.gate_cells
		var key_rooms: Array = range(1,rooms.size()-1).filter(func(i: int)->bool:return i!=int(layout.optional_room))
		key_chest = "chest_%d"%key_rooms[rng.randi_range(0,key_rooms.size()-1)]
		var p: Vector2 = to_world(room_center(rooms[-1]))
		enemies.append({"id":"boss","kind":boss,"pos":[p.x,p.y],"hp":-1.0,"dead":false})
	var result: Dictionary = {"grid":grid,"rooms":rooms,"enemies":enemies,"props":props,"loot":[],"revealed":[],"boss":boss,"boss_dead":false,"key_chest":key_chest,"has_key":false,"gate_open":boss.is_empty(),"gate_cells":gate_cells,"guardian_dead":floor_number!=13,"entry":pair(to_world(room_center(rooms[0]))),"exit":pair(to_world(room_center(rooms[-1]))+Vector2(0,-128)),"number":floor_number}
	for key: String in ["links","shapes","optional_room","gate_position","layout_version"]: result[key]=layout[key]
	EncounterRules.populate(result,rng,difficulty)
	ProgressionRules.prepare_floor(result)
	LootRules.prepare_floor(result,seed_value,difficulty)
	return result

static func room_center(r: Array) -> Vector2i:
	return Vector2i(int(r[0])+int(r[2]/2),int(r[1])+int(r[3]/2))

static func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell*CELL)+Vector2.ONE*CELL/2.0

static func pair(p: Vector2) -> Array:
	return [p.x,p.y]

static func vec(a: Array) -> Vector2:
	return Vector2(float(a[0]),float(a[1]))

func build(value: Dictionary) -> void:
	data = value
	cells.clear()
	revealed.clear()
	visited_rooms.clear()
	sight_origin = Vector2i(-1,-1)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0,0,WIDTH,HEIGHT)
	astar.cell_size = Vector2(CELL,CELL)
	astar.offset = Vector2(CELL/2.0,CELL/2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var open: bool = data.grid[y][x] == "."
			astar.set_point_solid(Vector2i(x,y),not open)
			if open: cells[Vector2i(x,y)] = true
	# Only wall bands bordering traversable tiles need physics shapes.
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y: int in range(HEIGHT):
		var start: int = -1
		for x: int in range(WIDTH+1):
			var wall: bool = x < WIDTH and not cells.has(Vector2i(x,y)) and adjacent_open(Vector2i(x,y))
			if wall and start < 0: start = x
			if not wall and start >= 0:
				var shape: CollisionShape2D = CollisionShape2D.new()
				var rectangle: RectangleShape2D = RectangleShape2D.new()
				rectangle.size = Vector2((x-start)*CELL,CELL)
				shape.shape = rectangle
				shape.position = Vector2((start+x)*CELL/2.0,y*CELL+CELL/2.0)
				body.add_child(shape)
				start = -1
	# Legacy radius-based discovery cannot prove a room was entered. Only its
	# exploration mask is reset; geometry, enemies, rewards and progress stay intact.
	if int(data.get("visibility_version",0)) == VISIBILITY_VERSION:
		for index: Variant in data.get("visited_rooms",[]):
			if int(index)>=0 and int(index)<data.rooms.size(): visited_rooms[int(index)] = true
		for cell_key: String in data.revealed:
			var bits: PackedStringArray = cell_key.split(",")
			if bits.size()!=2: continue
			var cell: Vector2i = Vector2i(int(bits[0]),int(bits[1]))
			var room: int = room_at(to_world(cell))
			if cells.has(cell) and (room<0 or visited_rooms.has(room)): revealed[cell_key] = true
	if int(data.number)>0:
		interior = DungeonInterior.new(self)
		var lighting: DungeonLighting = DungeonLighting.new()
		lighting.dungeon = self
		add_child(lighting)
	queue_redraw()

func adjacent_open(c: Vector2i) -> bool:
	for dx: int in range(-1,2):
		for dy: int in range(-1,2):
			if cells.has(c+Vector2i(dx,dy)): return true
	return false

func walkable(p: Vector2, margin: float = 0.0) -> bool:
	for offset: Vector2 in [Vector2.ZERO,Vector2(margin,margin),Vector2(-margin,margin),Vector2(margin,-margin),Vector2(-margin,-margin)]:
		if not cells.has(Vector2i(((p+offset)/CELL).floor())): return false
	return true

func visible_line(a: Vector2, b: Vector2) -> bool:
	var count: int = maxi(1, int(a.distance_to(b)/20.0))
	for i: int in range(count+1):
		if not walkable(a.lerp(b,float(i)/count)): return false
	return true

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var aa: Vector2i = Vector2i((a/CELL).floor())
	var bb: Vector2i = Vector2i((b/CELL).floor())
	if not cells.has(aa) or not cells.has(bb): return PackedVector2Array()
	return astar.get_point_path(aa,bb)

func reveal(p: Vector2) -> void:
	if not walkable(p): return
	var cell: Vector2i = Vector2i((p/CELL).floor())
	var room: int = room_at(p)
	if room>=0: visited_rooms[room] = true
	sight_origin = cell
	for x: int in range(maxi(0,cell.x-SIGHT_RADIUS),mini(WIDTH,cell.x+SIGHT_RADIUS+1)):
		for y: int in range(maxi(0,cell.y-SIGHT_RADIUS),mini(HEIGHT,cell.y+SIGHT_RADIUS+1)):
			var c: Vector2i = Vector2i(x,y)
			if Vector2(c-cell).length_squared()>SIGHT_RADIUS*SIGHT_RADIUS: continue
			if discovery_line(p,to_world(c)): revealed["%d,%d"%[x,y]] = true
	visibility_revision += 1

func discovery_open(cell: Vector2i) -> bool:
	if not cells.has(cell): return false
	var room: int = room_at(to_world(cell))
	return room<0 or visited_rooms.has(room)

func discovery_line(a: Vector2,b: Vector2) -> bool:
	# Grid traversal visits every crossed cell, including both sides of a corner.
	# Unlike sampled rays, it cannot jump over a thin wall or a diagonal seam.
	var start: Vector2 = a/CELL
	var finish: Vector2 = b/CELL
	var cell: Vector2i = Vector2i(start.floor())
	var target: Vector2i = Vector2i(finish.floor())
	var direction: Vector2 = finish-start
	var step: Vector2i = Vector2i(int(signf(direction.x)),int(signf(direction.y)))
	var delta: Vector2 = Vector2(INF if direction.x==0 else absf(1.0/direction.x),INF if direction.y==0 else absf(1.0/direction.y))
	var next: Vector2 = Vector2(INF,INF)
	if step.x!=0: next.x = (cell.x+(1 if step.x>0 else 0)-start.x)/direction.x
	if step.y!=0: next.y = (cell.y+(1 if step.y>0 else 0)-start.y)/direction.y
	while true:
		if not discovery_open(cell): return false
		if cell==target: return true
		if is_equal_approx(next.x,next.y):
			if not discovery_open(cell+Vector2i(step.x,0)) or not discovery_open(cell+Vector2i(0,step.y)): return false
			cell += step
			next += delta
		elif next.x<next.y:
			cell.x += step.x
			next.x += delta.x
		else:
			cell.y += step.y
			next.y += delta.y
	return false

func explored_position(p: Vector2) -> bool:
	var room: int = room_at(p)
	if room>=0: return visited_rooms.has(room)
	var cell: Vector2i = Vector2i((p/CELL).floor())
	return revealed.has("%d,%d"%[cell.x,cell.y])

func room_at(p: Vector2) -> int:
	var cell: Vector2 = p/CELL
	for i: int in range(data.rooms.size()):
		var r: Array = data.rooms[i]
		if Rect2(r[0],r[1],r[2],r[3]).has_point(cell): return i
	return -1

func _draw() -> void:
	if interior: interior.render(self)
