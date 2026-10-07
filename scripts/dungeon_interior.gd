class_name DungeonInterior
extends RefCounted
## Static environment art. Uses the existing navigation grid without adding blockers.
const WALL_FACE_HEIGHT: float = 106.0
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
var dressing: DungeonDressing

func _init(owner_dungeon: Dungeon) -> void:
	dungeon = owner_dungeon
	theme = 0 if int(dungeon.data.number)<7 else (1 if int(dungeon.data.number)<11 else 2)
	var half: Vector2 = MATERIALS.get_size()/2
	floors.append(region(MATERIALS,Rect2(Vector2.ZERO,half)))
	floors.append(region(MATERIALS,Rect2(Vector2(half.x,0),half)))
	masonry = region(MATERIALS,Rect2(Vector2(0,half.y),half))
	# ImageGen placed the tall architecture above the low props, at y=600.
	for rect: Rect2 in [Rect2(187,13,225,572),Rect2(646,11,249,576),Rect2(1123,18,238,562),Rect2(101,617,338,363),Rect2(518,689,470,264),Rect2(1019,604,463,388)]:
		ornaments.append(region(ARCHITECTURE,rect))
	for index: int in range(dungeon.data.rooms.size()):
		var room: Array = dungeon.data.rooms[index]
		for y: int in range(room[1],room[1]+room[3]):
			for x: int in range(room[0],room[0]+room[2]): room_cells[Vector2i(x,y)] = index
	dressing = DungeonDressing.new(self)
	for prop: Dictionary in dungeon.data.props:
		if prop.kind=="torch": lights.append({"pos":Dungeon.vec(prop.pos)+Vector2(0,24),"color":Color("ffa765"),"window":false,"torch":true,"radius":265.0})
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
	wall_details.append({"kind":kind,"pos":pos,"height":height,"grounded":kind in [0,3,4,5]})

func mount_decorations(actors: Node2D) -> void:
	# Same Y-sort parent as the player and chests; never paint standing props into the floor.
	for detail: Dictionary in wall_details:
		var decoration: DungeonDecoration = DungeonDecoration.new()
		decoration.setup(detail,detail.texture if detail.has("texture") else ornaments[detail.kind])
		actors.add_child(decoration)

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
		var exposure: float = 0.72
		if room_index>=0:
			var room: Array = dungeon.data.rooms[room_index]
			var local: Vector2 = (Vector2(cell)-Vector2(room[0],room[1])+Vector2.ONE*0.5)/Vector2(room[2],room[3])
			var edge: float = minf(minf(local.x,1.0-local.x),minf(local.y,1.0-local.y))
			exposure = lerpf(0.51,0.96,smoothstep(0.0,0.32,edge))
		var tint: Color = floor_tint * exposure
		tint.a = 1
		var source_size: float = floors[variant].get_width()/6.0
		canvas.draw_texture_rect_region(floors[variant],rect,Rect2(Vector2(posmod(cell.x,6),posmod(cell.y,6))*source_size,Vector2.ONE*source_size),tint)
	for index: int in range(dungeon.data.rooms.size()): draw_room(canvas,index,floor_tint)
	dressing.draw_floor(canvas)
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
			var face: Rect2 = Rect2(p+Vector2(0,64-WALL_FACE_HEIGHT),Vector2(64,WALL_FACE_HEIGHT))
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

func draw_room(canvas: Node2D,index: int,tint: Color) -> void:
	var room: Array = dungeon.data.rooms[index]
	var area: Rect2 = Rect2(room[0]*64+38,room[1]*64+38,room[2]*64-76,room[3]*64-76)
	var style: String = dressing.styles[index]
	var ceremonial: bool = style in ["chapel","crypt"]
	var bronze: Color = Color("b09b68",0.27 if ceremonial else 0.07)
	canvas.draw_rect(area,Color("1c292b",0.32),false,18)
	canvas.draw_rect(area.grow(10),bronze,false,2)
	canvas.draw_rect(area.grow(-10),Color(bronze,0.19),false,1)
	for corner: Vector2 in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
		canvas.draw_set_transform(corner,PI/4)
		canvas.draw_rect(Rect2(-5,-5,10,10),bronze,false,2)
		canvas.draw_set_transform(Vector2.ZERO)
	if not ceremonial: return
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
	var size: float = 270 if style=="chapel" else 155
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

func sample_light(p: Vector2) -> Dictionary:
	# Cheap actor tinting at a throttled rate; no effect on damage, freeze or flash states.
	var ambient: Color = [Color("d4dbe0"),Color("c3d2e3"),Color("d4cce1")][theme]
	var best: float = 0.0
	var direction: Vector2 = Vector2(-0.6,-0.8)
	var light_color: Color = Color("bacdd8")
	for source: Dictionary in lights:
		var distance: float = p.distance_to(source.pos)
		var strength: float = pow(maxf(0.0,1.0-distance/float(source.get("radius",200.0))),2)
		if strength>best:
			best = strength
			light_color = source.color
			direction = (source.pos-p).normalized()
	return {"color":ambient.lerp(light_color.lightened(0.32),best*0.55),"direction":direction,"strength":best}
