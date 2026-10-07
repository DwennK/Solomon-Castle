class_name TowerLayout
extends RefCounted
## Seeded irregular partitions, a connected room graph, loops and an optional leaf.
## The terminal chamber has one isolated approach, regardless of graph crossings.
static func generate(rng: RandomNumberGenerator, number: int) -> Dictionary:
	var transpose: bool = rng.randf()<0.5
	var plan_width: int = Dungeon.HEIGHT if transpose else Dungeon.WIDTH
	var plan_height: int = Dungeon.WIDTH if transpose else Dungeon.HEIGHT
	# Reserve two generous combat rooms before subdividing the remaining space.
	var span: int = plan_width-19
	var half: int = span/2
	var regions: Array[Rect2i] = [Rect2i(3,3,half,15),Rect2i(3+half,3,span-half,15),Rect2i(3,18,span,plan_height-21)]
	var target: int = rng.randi_range(7,9) if number<4 else rng.randi_range(8,11)
	while regions.size()<target:
		var candidates: Array[int] = []
		for i: int in range(2,regions.size()):
			if regions[i].size.x>=22 or regions[i].size.y>=22: candidates.append(i)
		if candidates.is_empty(): break
		candidates.sort_custom(func(a: int,b: int)->bool:return regions[a].get_area()>regions[b].get_area())
		var index: int = candidates[rng.randi_range(0,mini(2,candidates.size()-1))]
		var r: Rect2i = regions[index]
		var vertical: bool = r.size.x>=22 and (r.size.y<22 or rng.randf()<float(r.size.x)/float(r.size.x+r.size.y))
		var extent: int = r.size.x if vertical else r.size.y
		var cut: int = rng.randi_range(11,extent-11)
		regions[index] = Rect2i(r.position,Vector2i(cut,r.size.y) if vertical else Vector2i(r.size.x,cut))
		regions.append(Rect2i(r.position+(Vector2i(cut,0) if vertical else Vector2i(0,cut)),Vector2i(r.size.x-cut,r.size.y) if vertical else Vector2i(r.size.x,r.size.y-cut)))
	var rooms: Array = []
	for r: Rect2i in regions:
		var spacious: bool = rooms.size()<2
		var w: int = rng.randi_range(12 if spacious else 8,mini(18 if spacious else 15,r.size.x-3))
		var h: int = rng.randi_range(12 if spacious else 8,mini(16 if spacious else 14,r.size.y-3))
		rooms.append([rng.randi_range(r.position.x+1,r.end.x-w-2),rng.randi_range(r.position.y+1,r.end.y-h-2),w,h])
	# Pick an entry on the opposite side to the terminal chamber, then mirror the whole plan.
	var first: int = 2
	for i: int in range(2,rooms.size()):
		if rooms[i][0]<rooms[first][0]: first=i
	var entry_room: Array = rooms.pop_at(first)
	rooms.push_front(entry_room)
	var links: Array = []
	var connected: Array[int] = [0]
	while connected.size()<rooms.size():
		var best: float = INF
		var edge: Array = []
		for a: int in connected:
			for b: int in range(rooms.size()):
				if b in connected: continue
				var cost: float = Vector2(Dungeon.room_center(rooms[a])).distance_to(Vector2(Dungeon.room_center(rooms[b])))
				if cost<best: best=cost;edge=[a,b]
		links.append(edge)
		connected.append(edge[1])
	var degrees: Array[int] = []
	degrees.resize(rooms.size());degrees.fill(0)
	for edge: Array in links: degrees[edge[0]]+=1;degrees[edge[1]]+=1
	var optional: int = 1
	for i: int in range(1,rooms.size()):
		if degrees[i]==1: optional=i;break
	var extra: Array = []
	for a: int in range(rooms.size()):
		for b: int in range(a+1,rooms.size()):
			if a==optional or b==optional or [a,b] in links or [b,a] in links: continue
			extra.append([a,b])
	extra.sort_custom(func(a: Array,b: Array)->bool:return Vector2(Dungeon.room_center(rooms[a[0]])).distance_squared_to(Vector2(Dungeon.room_center(rooms[a[1]])))<Vector2(Dungeon.room_center(rooms[b[0]])).distance_squared_to(Vector2(Dungeon.room_center(rooms[b[1]]))))
	var loop_count: int = rng.randi_range(2,4)
	for i: int in range(mini(loop_count,extra.size())):
		var index: int = rng.randi_range(0,mini(3,extra.size()-1))
		links.append(extra.pop_at(index))
	var tiles: Dictionary = {}
	var shapes: Array[String] = []
	for i: int in range(rooms.size()):
		var shape: String = ["hall","octagon","cross","pillars"][rng.randi_range(0,3)] if i>0 else "hall"
		if rooms[i][2]>=12 and rooms[i][3]>=12: shape="octagon"
		shapes.append(shape)
		carve_room(tiles,rooms[i],shape)
	var leaf: Array = rooms[optional]
	var protected_leaf: Rect2i = Rect2i(leaf[0],leaf[1],leaf[2],leaf[3]).grow(3)
	var bounds: Rect2i = Rect2i(2,2,plan_width-16,plan_height-4)
	for edge: Array in links:
		carve_corridor(tiles,Dungeon.room_center(rooms[edge[0]]),Dungeon.room_center(rooms[edge[1]]),rng.randf()<0.5,protected_leaf if optional not in edge else Rect2i(),bounds,2 if optional not in edge and links.find(edge)%3==0 else 1)
	var terminal: Array = [plan_width-11,rng.randi_range(5,plan_height-17),8,rng.randi_range(10,13)]
	var center: Vector2i = Dungeon.room_center(terminal)
	var anchor: int = 0
	var distance: float = INF
	for i: int in range(rooms.size()):
		if i==optional: continue
		var d: float = Vector2(Dungeon.room_center(rooms[i])).distance_to(Vector2(plan_width-14,center.y))
		if d<distance: distance=d;anchor=i
	carve_corridor(tiles,Dungeon.room_center(rooms[anchor]),Vector2i(plan_width-15,center.y),false,protected_leaf,bounds)
	carve_corridor(tiles,Vector2i(plan_width-15,center.y),center,true)
	carve_room(tiles,terminal,"hall")
	links.append([anchor,rooms.size()]);rooms.append(terminal);shapes.append("sanctum")
	var gate: Array = [[plan_width-13,center.y-1],[plan_width-13,center.y],[plan_width-13,center.y+1]]
	var gate_pos: Vector2i = Vector2i(plan_width-14,center.y)
	var mirror_x: bool = rng.randf()<0.5
	var mirror_y: bool = rng.randf()<0.5
	var final_tiles: Dictionary = {}
	for c: Vector2i in tiles: final_tiles[mirror(Vector2i(c.y,c.x) if transpose else c,mirror_x,mirror_y)]=true
	for r: Array in rooms:
		if transpose:
			var swapped: Array = [r[1],r[0],r[3],r[2]]
			r.assign(swapped)
		if mirror_x: r[0]=Dungeon.WIDTH-r[0]-r[2]
		if mirror_y: r[1]=Dungeon.HEIGHT-r[1]-r[3]
	for c: Array in gate:
		var m: Vector2i = mirror(Vector2i(c[1],c[0]) if transpose else Vector2i(c[0],c[1]),mirror_x,mirror_y)
		c[0]=m.x;c[1]=m.y
	gate_pos=mirror(Vector2i(gate_pos.y,gate_pos.x) if transpose else gate_pos,mirror_x,mirror_y)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row += "." if final_tiles.has(Vector2i(x,y)) else "#"
		grid.append(row)
	return {"rooms":rooms,"grid":grid,"links":links,"shapes":shapes,"optional_room":optional,"gate_cells":gate,"gate_position":Dungeon.pair(Dungeon.to_world(gate_pos)),"layout_version":3}

static func mirror(c: Vector2i,x: bool,y: bool) -> Vector2i:
	return Vector2i(Dungeon.WIDTH-1-c.x if x else c.x,Dungeon.HEIGHT-1-c.y if y else c.y)

static func carve_room(tiles: Dictionary,r: Array,shape: String) -> void:
	for y: int in range(r[1],r[1]+r[3]):
		for x: int in range(r[0],r[0]+r[2]):
			var dx: int = mini(x-r[0],r[0]+r[2]-1-x)
			var dy: int = mini(y-r[1],r[1]+r[3]-1-y)
			if shape=="octagon" and dx+dy<2: continue
			if shape=="cross" and dx<2 and dy<2: continue
			if shape=="pillars" and r[2]>=9 and r[3]>=9 and dx==2 and dy==2: continue
			tiles[Vector2i(x,y)]=true

static func carve_corridor(tiles: Dictionary,a: Vector2i,b: Vector2i,horizontal: bool,avoid: Rect2i = Rect2i(),bounds: Rect2i = Rect2i(),radius: int = 1) -> void:
	var cursor: Vector2i = a
	var route: Array[Vector2i] = []
	var blocked: bool = false
	while true:
		route.append(cursor)
		if avoid.has_point(cursor): blocked=true
		if cursor==b: break
		if (horizontal and cursor.x!=b.x) or cursor.y==b.y: cursor.x+=signi(b.x-cursor.x)
		else: cursor.y+=signi(b.y-cursor.y)
	if blocked:
		# Preserve the optional detour in the physical map, not only in graph metadata.
		var navigation: AStarGrid2D = AStarGrid2D.new()
		navigation.region=bounds
		navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		navigation.update()
		for y: int in range(avoid.position.y,avoid.end.y):
			for x: int in range(avoid.position.x,avoid.end.x):
				if bounds.has_point(Vector2i(x,y)): navigation.set_point_solid(Vector2i(x,y))
		route.assign(navigation.get_id_path(a,b))
	for c: Vector2i in route:
		for dx: int in range(-radius,radius+1):
			for dy: int in range(-radius,radius+1): tiles[c+Vector2i(dx,dy)]=true

static func open_position(grid: Array,r: Array,desired: Vector2i) -> Vector2:
	# Positions must fit the actual carved shape, not just its bounding rectangle.
	var best: Vector2i = Dungeon.room_center(r)
	var distance: float = INF
	for y: int in range(r[1]+1,r[1]+r[3]-1):
		for x: int in range(r[0]+1,r[0]+r[2]-1):
			if grid[y][x]!=".": continue
			var c: Vector2i = Vector2i(x,y)
			var d: float = Vector2(c).distance_squared_to(Vector2(desired))
			if d<distance: distance=d;best=c
	return Dungeon.to_world(best)
