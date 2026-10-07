class_name DungeonInterior
extends RefCounted
## Aligned masonry and paving derived from the actual walkable boundary.
const WALL_FACE_HEIGHT: float = 128.0
const COPING: float = 24.0
var dungeon: Dungeon
var room_cells: Dictionary = {}
var wall_cells: Array[Vector2i] = []
var wall_details: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var theme: int = 0
var dressing: DungeonDressing
var boundaries: Array[Dictionary] = []
var inlays: Dictionary = {}

func _init(owner_dungeon: Dungeon) -> void:
	dungeon = owner_dungeon
	theme = 0 if int(dungeon.data.number)<7 else (1 if int(dungeon.data.number)<11 else 2)
	for index: int in range(dungeon.data.rooms.size()):
		var room: Array = dungeon.data.rooms[index]
		for y: int in range(room[1],room[1]+room[3]):
			for x: int in range(room[0],room[0]+room[2]): room_cells[Vector2i(x,y)] = index
	for cell: Vector2i in dungeon.cells:
		for side: Vector2i in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			if not dungeon.cells.has(cell+side):
				boundaries.append({"cell":cell,"side":side})
				if cell+side not in wall_cells: wall_cells.append(cell+side)
	dressing = DungeonDressing.new(self)
	for index: int in range(dressing.styles.size()):
		if dressing.styles[index] in ["chapel","crypt"]:
			inlays[index] = Rect2i(Dungeon.room_center(dungeon.data.rooms[index])-Vector2i(2,2),Vector2i(4,4))
	for prop: Dictionary in dungeon.data.props:
		if prop.kind=="torch":
			var p: Vector2 = dressing.prop_positions.get(prop.id,Dungeon.vec(prop.pos)+Vector2(0,32))
			lights.append({"pos":p,"color":Color("e9aa6b"),"window":false,"torch":true,"room":dungeon.room_at(p),"radius":310.0,"energy":0.34})
	wall_details.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.pos.y<b.pos.y)

func mount_decorations(actors: Node2D) -> void:
	for detail: Dictionary in wall_details:
		var decoration: DungeonDecoration = DungeonDecoration.new()
		decoration.environment = self
		decoration.setup(detail,detail.texture)
		actors.add_child(decoration)

func floor_variant(cell: Vector2i) -> int:
	var index: int = room_cells.get(cell,-1)
	if index<0: return 1
	var room: Array = dungeon.data.rooms[index]
	# A single slate course borders every room; corridor mouths become stone thresholds.
	if cell.x==room[0] or cell.x==room[0]+room[2]-1 or cell.y==room[1] or cell.y==room[1]+room[3]-1: return 1
	return {"chapel":0,"library":2,"prison":1,"crypt":0,"laboratory":1,"ruins":2}[dressing.styles[index]]

func render(canvas: Node2D) -> void:
	for cell: Vector2i in dungeon.cells:
		var variant: int = floor_variant(cell)
		var texture: Texture2D = EnvironmentArt.FLOORS[variant]
		var source_size: Vector2 = texture.get_size()/4.0
		var source: Rect2 = Rect2(Vector2(posmod(cell.x,4),posmod(cell.y,4))*source_size,source_size)
		var room: int = room_cells.get(cell,-1)
		if inlays.has(room) and inlays[room].has_point(cell):
			texture = EnvironmentArt.INLAY
			source_size = texture.get_size()/4.0
			source = Rect2(Vector2(cell-inlays[room].position)*source_size,source_size)
		var tint: Color = [Color("979d9d"),Color("c0c5c5"),Color("b8bab7")][variant]
		if not room_cells.has(cell): tint = Color("9aa6ac")
		canvas.draw_texture_rect_region(texture,Rect2(Vector2(cell*64),Vector2(64,64)),source,tint)
	for edge: Dictionary in boundaries: draw_contact(canvas,edge.cell,edge.side)
	# Only real exposed edges get wall faces. Openings stay open, including corridor turns.
	for edge: Dictionary in boundaries: draw_wall(canvas,edge.cell,edge.side)

func draw_contact(canvas: Node2D,cell: Vector2i,side: Vector2i) -> void:
	var p: Vector2 = Vector2(cell*64)
	for band: int in range(7):
		var depth: float = band*4.0
		var shade: Color = Color(0.01,0.016,0.025,(1.0-band/7.0)*0.23)
		if side==Vector2i.UP: canvas.draw_rect(Rect2(p+Vector2(0,depth),Vector2(64,4)),shade)
		elif side==Vector2i.DOWN: canvas.draw_rect(Rect2(p+Vector2(0,60-depth),Vector2(64,4)),Color(shade,shade.a*0.55))
		elif side==Vector2i.LEFT: canvas.draw_rect(Rect2(p+Vector2(depth,0),Vector2(4,64)),shade)
		else: canvas.draw_rect(Rect2(p+Vector2(60-depth,0),Vector2(4,64)),shade)

func draw_wall(canvas: Node2D,cell: Vector2i,side: Vector2i) -> void:
	var p: Vector2 = Vector2(cell*64)
	var stone: Texture2D = EnvironmentArt.MASONRY
	var masonry_slice: float = stone.get_width()/4.0
	if side==Vector2i.UP:
		var height: float = 64.0 if dungeon.cells.has(cell+Vector2i.UP*2) else WALL_FACE_HEIGHT
		var rect: Rect2 = Rect2(p-Vector2(0,height),Vector2(64,height))
		var tint: Color = Color("9b9f9f")
		canvas.draw_texture_rect_region(stone,rect,Rect2(posmod(cell.x,4)*masonry_slice,0,masonry_slice,stone.get_height()*height/WALL_FACE_HEIGHT),tint)
		# Continuous cornice and a weight-bearing skirting at the exact wall/floor junction.
		cap(canvas,Rect2(p-Vector2(0,height+14),Vector2(64,14)),cell)
		canvas.draw_rect(Rect2(p-Vector2(0,9),Vector2(64,9)),Color("363b3b"))
		canvas.draw_line(p-Vector2(0,9),p+Vector2(64,-9),Color("666b67"),2.0)
		canvas.draw_line(p,p+Vector2(64,0),Color("111b20"),3.0)
		for horizontal: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT]:
			if not dungeon.cells.has(cell+horizontal):
				var x: float = p.x-COPING if horizontal==Vector2i.LEFT else p.x+64
				cap(canvas,Rect2(x,p.y-height-14,COPING,14),cell)
	elif side==Vector2i.LEFT or side==Vector2i.RIGHT:
		var x: float = p.x-COPING if side==Vector2i.LEFT else p.x+64
		var top: float = p.y
		if not dungeon.cells.has(cell+Vector2i.UP): top -= 64.0 if dungeon.cells.has(cell+Vector2i.UP*2) else WALL_FACE_HEIGHT
		cap(canvas,Rect2(x,top,COPING,p.y+64-top),cell)
		var inner: float = p.x if side==Vector2i.LEFT else p.x+64
		canvas.draw_line(Vector2(inner,p.y),Vector2(inner,p.y+64),Color("172126"),4.0)
	else:
		canvas.draw_rect(Rect2(p+Vector2(0,64),Vector2(64,34)),Color("171f23"))
		cap(canvas,Rect2(p+Vector2(0,64),Vector2(64,20)),cell)
		canvas.draw_line(p+Vector2(0,64),p+Vector2(64,64),Color("727875"),2.0)
		for horizontal: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT]:
			if not dungeon.cells.has(cell+horizontal):
				var x: float = p.x-COPING if horizontal==Vector2i.LEFT else p.x+64
				cap(canvas,Rect2(x,p.y+64,COPING,20),cell)

func cap(canvas: Node2D,rect: Rect2,cell: Vector2i) -> void:
	var texture: Texture2D = EnvironmentArt.FLOORS[0]
	var sample: Vector2 = texture.get_size()/4.0
	canvas.draw_texture_rect_region(texture,rect,Rect2(Vector2(posmod(cell.x,4),posmod(cell.y,4))*sample,sample),Color("616b70"))
	canvas.draw_rect(rect,Color("182329"),false,1.0)
	canvas.draw_line(rect.position+Vector2(1,1),Vector2(rect.end.x-1,rect.position.y+1),Color("8b9390"),1.0)

func source_reaches(source: Dictionary,p: Vector2) -> bool:
	var room: int = dungeon.room_at(p)
	if room>=0 and source.get("room",-1)>=0 and room!=int(source.room): return false
	return dungeon.visible_line(source.pos,p)

func sample_light(p: Vector2) -> Dictionary:
	var ambient: Color = [Color("bec5c7"),Color("b2bec8"),Color("bcb9c5")][theme]
	var best: float = 0.0
	var direction: Vector2 = Vector2(-0.6,-0.8)
	var light_color: Color = Color("bacdd8")
	for source: Dictionary in lights:
		var strength: float = pow(maxf(0.0,1.0-p.distance_to(source.pos)/float(source.radius)),2)
		if strength>best and source_reaches(source,p):
			best = strength; light_color = source.color; direction = (source.pos-p).normalized()
	return {"color":ambient.lerp(light_color.lightened(0.16),best*0.45),"direction":direction,"strength":best}
