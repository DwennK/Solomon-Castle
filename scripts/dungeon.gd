class_name Dungeon
extends Node2D

const CELL: int = 64
const WIDTH: int = 65
const HEIGHT: int = 51
var data: Dictionary = {}
var astar: AStarGrid2D
var cells: Dictionary = {}
var floor_texture: Texture2D
var wall_texture: Texture2D
var revealed: Dictionary = {}
var village: bool = false

static func generate(seed_value: int, floor_number: int, difficulty: int = 0) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + floor_number * 7919 + difficulty * 982451653
	var tiles: Dictionary = {}
	var rooms: Array = []
	var rows_count: int = 2 if floor_number < 4 else 3
	for row: int in range(rows_count):
		for column_index: int in range(3):
			var col: int = column_index if row % 2 == 0 else 2-column_index
			var x: int = 3+col*20+rng.randi_range(0,2)
			var y: int = 3+row*16+rng.randi_range(0,2)
			var w: int = rng.randi_range(10,14)
			var h: int = rng.randi_range(8,11)
			rooms.append([x,y,w,h])
			for xx: int in range(x,x+w):
				for yy: int in range(y,y+h): tiles[Vector2i(xx,yy)] = true
	for i: int in range(1,rooms.size()):
		var a: Vector2i = room_center(rooms[i-1])
		var b: Vector2i = room_center(rooms[i])
		var cursor: Vector2i = a
		while cursor != b:
			for dx: int in range(-1,2):
				for dy: int in range(-1,2): tiles[cursor+Vector2i(dx,dy)] = true
			if cursor.x != b.x: cursor.x += signi(b.x-cursor.x)
			else: cursor.y += signi(b.y-cursor.y)
	var grid: Array[String] = []
	for y: int in range(HEIGHT):
		var row: String = ""
		for x: int in range(WIDTH): row += "." if tiles.has(Vector2i(x,y)) else "#"
		grid.append(row)
	var enemies: Array = []
	var props: Array = []
	var kinds: Array[String] = ["skeleton","archer","zombie","ghoul","sorcerer","knight","imp","ghost"]
	for i: int in range(rooms.size()):
		var r: Array = rooms[i]
		props.append({"id":"chest_%d"%i,"kind":"chest","pos":[(r[0]+2)*CELL+32,(r[1]+2)*CELL+32],"opened":false})
		props.append({"id":"urn_%d"%i,"kind":"urn","pos":[(r[0]+r[2]-2)*CELL+32,(r[1]+2)*CELL+32],"opened":false})
		props.append({"id":"torch_%d"%i,"kind":"torch","pos":[(r[0]+r[2]/2)*CELL,(r[1])*CELL],"opened":false})
		if i == 0: continue
		var count: int = 3 + mini(4,int(floor_number/3)) + rng.randi_range(0,2)
		for j: int in range(count):
			var kind: String = kinds[rng.randi_range(0,mini(7,1+int(floor_number*0.6)))]
			var p: Vector2 = Vector2((r[0]+3+j%4*2)*CELL+32,(r[1]+3+int(j/4)*2)*CELL+32)
			enemies.append({"id":"enemy_%d_%d"%[i,j],"kind":kind,"pos":[p.x,p.y],"hp":-1.0,"dead":false})
	var boss: String = {4:"king",8:"plague",11:"demon",13:"lich"}.get(floor_number,"")
	if floor_number == 13:
		var guard_pos: Vector2 = to_world(room_center(rooms[-2]))
		enemies.append({"id":"guardian","kind":"demon","pos":pair(guard_pos),"hp":-1.0,"dead":false})
	var gate_cells: Array = []
	var key_chest: String = ""
	if not boss.is_empty():
		var last: Array = rooms[-1]
		var prior: Vector2i = room_center(rooms[-2])
		for offset: int in range(-1,2): gate_cells.append([int(last[0])-1,prior.y+offset])
		key_chest = "chest_%d"%rng.randi_range(1,rooms.size()-2)
		var p: Vector2 = to_world(room_center(rooms[-1]))
		enemies.append({"id":"boss","kind":boss,"pos":[p.x,p.y],"hp":-1.0,"dead":false})
	return {"grid":grid,"rooms":rooms,"enemies":enemies,"props":props,"loot":[],"revealed":[],"boss":boss,"boss_dead":false,"key_chest":key_chest,"has_key":false,"gate_open":boss.is_empty(),"gate_cells":gate_cells,"guardian_dead":floor_number!=13,"entry":pair(to_world(room_center(rooms[0]))),"exit":pair(to_world(room_center(rooms[-1]))+Vector2(0,-128)),"number":floor_number}

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
	floor_texture = Catalog.texture("floor_crypt" if int(data.number)>6 else "floor_stone")
	wall_texture = Catalog.texture("wall")
	cells.clear()
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
	for cell_key: String in data.revealed: revealed[cell_key] = true
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
	var cell: Vector2i = Vector2i((p/CELL).floor())
	for x: int in range(cell.x-7,cell.x+8):
		for y: int in range(cell.y-6,cell.y+7):
			var c: Vector2i = Vector2i(x,y)
			if cells.has(c): revealed["%d,%d"%[x,y]] = true

func room_at(p: Vector2) -> int:
	var cell: Vector2 = p/CELL
	for i: int in range(data.rooms.size()):
		var r: Array = data.rooms[i]
		if Rect2(r[0],r[1],r[2],r[3]).has_point(cell): return i
	return -1

func _draw() -> void:
	if data.is_empty(): return
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var c: Vector2i = Vector2i(x,y)
			var rect: Rect2 = Rect2(Vector2(c*CELL),Vector2.ONE*CELL)
			if cells.has(c):
				if floor_texture: draw_texture_rect_region(floor_texture,rect,Rect2((x%4)*128,(y%4)*128,128,128),Color(0.68,0.74,0.79))
				else: draw_rect(rect,Color("343f46"))
				if not cells.has(c+Vector2i.UP): draw_rect(Rect2(rect.position,Vector2(CELL,20)),Color(0,0,0,0.35))
			elif adjacent_open(c):
				if wall_texture: draw_texture_rect_region(wall_texture,rect,Rect2((x%4)*128,(y%4)*128,128,128),Color("65737d"))
				else: draw_rect(rect,Color("151c25"))
				draw_rect(rect,Color(0.02,0.025,0.04,0.4),false,2)
				if cells.has(c+Vector2i.DOWN):
					draw_rect(Rect2(rect.position+Vector2(0,38),Vector2(CELL,26)),Color("121b23"))
					draw_line(rect.position+Vector2(0,38),rect.position+Vector2(CELL,38),Color("6b6a58"),2)
