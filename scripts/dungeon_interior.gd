class_name DungeonInterior
extends RefCounted
## Static environment art. Uses the existing navigation grid without adding blockers.
const MATERIALS: Texture2D = preload("res://assets/art/dungeon_v3/materials.png")
const ARCHITECTURE: Texture2D = preload("res://assets/art/dungeon_v3/architecture.png")
var dungeon: Dungeon
var floors: Array[Texture2D] = []
var masonry: Texture2D
var ornaments: Array[Texture2D] = []
var room_cells: Dictionary = {}
var wall_cells: Array[Vector2i] = []
var wall_details: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var theme: int = 0

func _init(owner_dungeon: Dungeon) -> void:
	dungeon = owner_dungeon
	theme = 0 if int(dungeon.data.number)<7 else (1 if int(dungeon.data.number)<11 else 2)
	var half: Vector2 = MATERIALS.get_size()/2
	floors.append(region(MATERIALS,Rect2(Vector2.ZERO,half)))
	floors.append(region(MATERIALS,Rect2(Vector2(half.x,0),half)))
	masonry = region(MATERIALS,Rect2(Vector2(0,half.y),half))
	# ImageGen placed the tall architecture above the low props, at y=600.
	for rect: Rect2 in [Rect2(172,8,244,585),Rect2(634,8,278,585),Rect2(1120,20,270,573),Rect2(92,605,355,389),Rect2(516,672,480,292),Rect2(1020,604,470,399)]:
		ornaments.append(region(ARCHITECTURE,rect))
	for index: int in range(dungeon.data.rooms.size()):
		var room: Array = dungeon.data.rooms[index]
		for y: int in range(room[1],room[1]+room[3]):
			for x: int in range(room[0],room[0]+room[2]): room_cells[Vector2i(x,y)] = index
		var top: float = room[1]*Dungeon.CELL
		var left: float = room[0]*Dungeon.CELL
		var right: float = (room[0]+room[2])*Dungeon.CELL
		for x: float in [left+18,right-18]:
			add_detail(0,Vector2(x,top+4),170)
		# Recesses live in solid wall cells, never across a corridor mouth.
		for fraction: float in [0.24,0.76]:
			var p: Vector2 = Vector2(lerpf(left,right,fraction),top)
			var c: Vector2i = Vector2i((p/64).floor())+Vector2i.UP
			if dungeon.cells.has(c) or dungeon.cells.has(c+Vector2i.LEFT) or dungeon.cells.has(c+Vector2i.RIGHT): continue
			var kind: int = 2 if (index+int(fraction*10))%2==0 else 1
			add_detail(kind,p,154)
			if kind==2: lights.append({"pos":p+Vector2(0,64),"color":Color("70c7cc") if theme<2 else Color("aa91da"),"window":true})
		for p: Vector2 in [Vector2(left+55,top+51),Vector2(right-55,top+51)]:
			add_detail(3,p,46)
			lights.append({"pos":p-Vector2(0,16),"color":Color("ffb962"),"window":false})
		# Small chips hug the perimeter, below all actors and interactions.
		add_detail(4,Vector2(right-37,top+room[3]*64-22),34)
	for y: int in range(Dungeon.HEIGHT):
		for x: int in range(Dungeon.WIDTH):
			var cell: Vector2i = Vector2i(x,y)
			if not dungeon.cells.has(cell) and dungeon.adjacent_open(cell): wall_cells.append(cell)
	wall_details.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.y<b.pos.y)

func region(texture: Texture2D,rect: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	atlas.filter_clip = true
	return atlas

func add_detail(kind: int,pos: Vector2,height: float) -> void:
	wall_details.append({"kind":kind,"pos":pos,"height":height})

func render(canvas: Node2D) -> void:
	var floor_tint: Color = [Color("929992"),Color("7f969d"),Color("9792aa")][theme]
	var wall_tint: Color = [Color("999b91"),Color("7c9297"),Color("918c9e")][theme]
	# A deep stone silhouette around the architecture gives it thickness in the void.
	for cell: Vector2i in wall_cells:
		canvas.draw_rect(Rect2(Vector2(cell*64)-Vector2(10,38),Vector2(84,106)),Color("0b1015"))
	for cell: Vector2i in dungeon.cells:
		var rect: Rect2 = Rect2(Vector2(cell*64),Vector2(64,64))
		var room_index: int = int(room_cells.get(cell,-1))
		var variant: int = 1 if theme>0 or room_index<0 else 0
		var tint: Color = floor_tint * (0.82 if room_index<0 else 1.0)
		tint.a = 1
		var source_size: float = floors[variant].get_width()/6.0
		canvas.draw_texture_rect_region(floors[variant],rect,Rect2(Vector2(posmod(cell.x,6),posmod(cell.y,6))*source_size,Vector2.ONE*source_size),tint)
	for index: int in range(dungeon.data.rooms.size()): draw_room(canvas,index,floor_tint)
	# Contact shadows inside floors delineate every turn and corridor, without covering actors.
	for cell: Vector2i in dungeon.cells:
		var p: Vector2 = Vector2(cell*64)
		for side: Vector2i in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			if dungeon.cells.has(cell+side): continue
			for band: int in range(8):
				var depth: float = band*4.0
				var shade: Color = Color(0.015,0.021,0.029,(1.0-band/8.0)*0.34)
				if side==Vector2i.UP: canvas.draw_rect(Rect2(p+Vector2(0,depth),Vector2(64,4)),shade)
				elif side==Vector2i.DOWN: canvas.draw_rect(Rect2(p+Vector2(0,60-depth),Vector2(64,4)),Color(shade,shade.a*0.6))
				elif side==Vector2i.LEFT: canvas.draw_rect(Rect2(p+Vector2(depth,0),Vector2(4,64)),shade)
				else: canvas.draw_rect(Rect2(p+Vector2(60-depth,0),Vector2(4,64)),Color(shade,shade.a*0.7))
	# North-facing walls rise into the solid area; their foot stays at the collision edge.
	for cell: Vector2i in wall_cells:
		var p: Vector2 = Vector2(cell*64)
		if dungeon.cells.has(cell+Vector2i.DOWN):
			var face: Rect2 = Rect2(p-Vector2(0,42),Vector2(64,106))
			canvas.draw_texture_rect_region(masonry,face,Rect2(posmod(cell.x,3)*masonry.get_width()/3,0,masonry.get_width()/3,masonry.get_height()),wall_tint)
			canvas.draw_rect(Rect2(face.position,Vector2(64,5)),Color("74766a"))
			canvas.draw_line(p+Vector2(0,63),p+Vector2(64,63),Color("262c2c"),3)
		else:
			canvas.draw_texture_rect_region(floors[1],Rect2(p,Vector2(64,64)),Rect2(posmod(cell.x,6)*104.5,posmod(cell.y,6)*104.5,104.5,104.5),Color("434f55"))
			canvas.draw_rect(Rect2(p+Vector2(5,5),Vector2(54,54)),Color("858576",0.06),false,1)
			if dungeon.cells.has(cell+Vector2i.UP):
				canvas.draw_rect(Rect2(p,Vector2(64,4)),Color("767766"))
				canvas.draw_rect(Rect2(p+Vector2(0,5),Vector2(64,5)),Color("151e23"))
			if dungeon.cells.has(cell+Vector2i.RIGHT): canvas.draw_line(p+Vector2(62,0),p+Vector2(62,64),Color("8b8974"),3)
			if dungeon.cells.has(cell+Vector2i.LEFT): canvas.draw_line(p+Vector2(2,0),p+Vector2(2,64),Color("686f66"),3)
	for detail: Dictionary in wall_details:
		var texture: Texture2D = ornaments[detail.kind]
		var size: Vector2 = texture.get_size()*float(detail.height)/texture.get_height()
		var pos: Vector2 = detail.pos
		canvas.draw_texture_rect(texture,Rect2(pos-Vector2(size.x/2,size.y),size),false,Color("c5c5b9") if detail.kind<3 else Color.WHITE)

func draw_room(canvas: Node2D,index: int,tint: Color) -> void:
	var room: Array = dungeon.data.rooms[index]
	var area: Rect2 = Rect2(room[0]*64+38,room[1]*64+38,room[2]*64-76,room[3]*64-76)
	var bronze: Color = Color("b09b68",0.38)
	canvas.draw_rect(area,Color("1c292b",0.32),false,18)
	canvas.draw_rect(area.grow(10),bronze,false,2)
	canvas.draw_rect(area.grow(-10),Color(bronze,0.19),false,1)
	for corner: Vector2 in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
		canvas.draw_set_transform(corner,PI/4)
		canvas.draw_rect(Rect2(-5,-5,10,10),bronze,false,2)
		canvas.draw_set_transform(Vector2.ZERO)
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
	var size: float = 300 if index%3==0 else 240
	var mosaic_tint: Color = tint*0.86
	mosaic_tint.a = 1
	var points: PackedVector2Array = PackedVector2Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for segment: int in range(96):
		var direction: Vector2 = Vector2.from_angle(segment*TAU/96)
		points.append(center+direction*size*0.457)
		uv.append(Vector2(0.75,0.75)+direction*0.2285)
	canvas.draw_polygon(points,PackedColorArray([mosaic_tint]),uv,MATERIALS)
	# The surrounding dark ring seats the carved medallion in the stonework.
	canvas.draw_arc(center,size*0.457,0,TAU,96,Color("1b272b",0.6),3,true)
