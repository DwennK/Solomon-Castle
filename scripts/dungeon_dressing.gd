class_name DungeonDressing
extends RefCounted
## Deterministic visual dressing, independent from generation and saved gameplay data.
const DECOR: Texture2D = preload("res://assets/art/dungeon_v4/room-decor.png")
const DECALS: Texture2D = preload("res://assets/art/dungeon_v4/floor-decals.png")
# Measured opaque bounds with a two-pixel gutter. Generated cells are NOT uniform:
# the ruined wall crosses x=1330, contaminating the old banner slice.
const DECOR_REGIONS: Array[Rect2] = [
	Rect2(39,14,365,429), Rect2(513,10,304,423),
	Rect2(915,4,386,435), Rect2(1353,2,391,442),
	Rect2(44,446,363,429), Rect2(494,448,337,435),
	Rect2(883,499,469,353), Rect2(1415,447,301,436)
]
const TYPES: Array[String] = ["chapel","library","prison","crypt","laboratory","ruins"]
var owner_ref: WeakRef
var interior: DungeonInterior:
	get: return owner_ref.get_ref() as DungeonInterior
var textures: Array[Texture2D] = []
var decals: Array[Texture2D] = []
var styles: Array[String] = []
var floor_details: Array[Dictionary] = []
var thresholds: Array[Dictionary] = []

func _init(owner_interior: DungeonInterior) -> void:
	owner_ref = weakref(owner_interior)
	for rect: Rect2 in DECOR_REGIONS: textures.append(interior.region(DECOR,rect))
	for i: int in range(6): decals.append(interior.region(DECALS,Rect2((i%3)*512,int(i/3)*512,512,512)))
	for index: int in range(interior.dungeon.data.rooms.size()):
		var style: String = TYPES[(index+(int(interior.dungeon.data.number)-1)*2)%TYPES.size()]
		if index==0: style = "chapel"
		if index==interior.dungeon.data.rooms.size()-1 and not interior.dungeon.data.get("boss","").is_empty(): style = "chapel"
		styles.append(style)
		build_room(index,style)

func build_room(index: int,style: String) -> void:
	var room: Array = interior.dungeon.data.rooms[index]
	var area: Rect2 = Rect2(room[0]*64,room[1]*64,room[2]*64,room[3]*64)
	var y: float = area.position.y
	var left: float = area.position.x
	var right: float = area.end.x
	# Bases stay on solid cells. A fractured arch replaces one regular corner pillar.
	wall_decoration(5 if style in ["ruins","library"] else -1,Vector2(left+10,y),120)
	wall_decoration(5 if style=="crypt" else -1,Vector2(right-10,y),116)
	var focal_kind: int = TYPES.find(style)
	if style=="ruins": focal_kind = 6
	var positions: Array[float] = [0.20 if index%2 else 0.24,0.80]
	for n: int in range(positions.size()):
		var p: Vector2 = Vector2(lerpf(left,right,positions[n]),y)
		var height: float = {"chapel":118.0,"library":116.0,"prison":98.0,"crypt":118.0,"laboratory":108.0,"ruins":78.0}[style]
		var selected_kind: int = focal_kind
		if n==1:
			height *= 0.78
			if style in ["chapel","crypt"]:
				if wall_clear(p,75): interior.add_detail(1,p,94)
				continue
			if style=="laboratory": selected_kind = 1
			if style=="ruins":
				selected_kind = 5
				height = 104
		if wall_decoration(selected_kind,p,height):
			if style=="laboratory" and n==0: interior.lights.append({"pos":p+Vector2(0,28),"color":Color("91d6a8"),"window":false,"radius":180.0})
			elif style=="chapel": interior.lights.append({"pos":p+Vector2(0,34),"color":Color("ffbb70"),"window":false,"radius":175.0})
	# One cold light opening per room, with a different balance from the warm focal pieces.
	var window_p: Vector2 = Vector2(lerpf(left,right,0.62 if index%2==0 else 0.61),y)
	if wall_clear(window_p,62):
		interior.add_detail(2,window_p-Vector2(0,10),80)
		interior.lights.append({"pos":window_p+Vector2(0,54),"beam_origin":window_p-Vector2(0,12),"color":Color("789acb") if style=="crypt" else Color("72b3c0"),"window":true,"radius":245.0})
	if style in ["chapel","prison"]:
		wall_decoration(7,Vector2(lerpf(left,right,0.42),y),68)
	# Uneven candle groups replace the identical pair of corners.
	for fraction: float in ([0.12,0.86] if style in ["chapel","crypt"] else [0.87]):
		var p: Vector2 = Vector2(lerpf(left,right,fraction),y+24)
		interior.add_detail(3,p,25 if fraction<0.5 else 30)
		interior.lights.append({"pos":p-Vector2(0,10),"color":Color("ffc080"),"window":false,"radius":130.0})
	# Wear remains within walkable room bounds and away from the central combat area.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(interior.dungeon.data.number)*739+index*193+room[0]*37+room[1]
	for n: int in range(8):
		var side: int = n%4
		var pos: Vector2
		if side<2: pos = Vector2(left+90 if side==0 else right-90,rng.randf_range(y+90,area.end.y-90))
		else: pos = Vector2(rng.randf_range(left+100,right-100),y+85 if side==2 else area.end.y-85)
		var kind: int = [0,3,0,5][n%4]
		if style=="library": kind = 4 if n%3==0 else 1
		elif style in ["prison","crypt"]: kind = 2 if n%3==0 else 5
		elif style=="laboratory": kind = 2 if n%2==0 else 0
		elif style=="ruins": kind = 3 if n%2==0 else 0
		var width: float = rng.randf_range(85,150)
		if not safe_floor(pos,80): continue
		floor_details.append({"pos":pos,"kind":kind,"width":width,"rotation":rng.randf_range(-PI,PI),"alpha":0.35 if kind==2 else 0.53})
	# Soot under the room brazier reads as wear, not as a new attack indicator.
	floor_details.append({"pos":Vector2(left+area.size.x/2,y+43),"kind":1,"width":115.0,"rotation":0.1,"alpha":0.32})
	build_thresholds(area)

func safe_floor(p: Vector2,margin: float) -> bool:
	if not interior.dungeon.walkable(p,margin): return false
	for prop: Dictionary in interior.dungeon.data.props:
		if prop.kind!="torch" and p.distance_to(Dungeon.vec(prop.pos))<100: return false
	for key: String in ["entry","exit"]:
		if p.distance_to(Dungeon.vec(interior.dungeon.data[key]))<125: return false
	return true

func wall_clear(p: Vector2,width: float) -> bool:
	# Check every crossed cell, not just three sample points across a wide prop.
	var first: int = floori((p.x-width/2-4)/64)
	var last: int = floori((p.x+width/2+4)/64)
	var row: int = floori((p.y-8)/64)
	for x: int in range(first,last+1):
		if interior.dungeon.cells.has(Vector2i(x,row)): return false
	return true

func wall_decoration(kind: int,p: Vector2,height: float) -> bool:
	var texture: Texture2D = textures[kind] if kind>=0 else interior.ornaments[0]
	var width: float = texture.get_width()/texture.get_height()*height
	if not wall_clear(p,width): return false
	# Furniture bases project slightly onto the floor; wall hangings stay inside the facade.
	var foot_offset: float = {0:18.0,1:12.0,2:0.0,3:16.0,4:14.0,5:3.0,6:6.0,7:-18.0,-1:3.0}[kind]
	interior.wall_details.append({"kind":kind,"pos":p+Vector2(0,foot_offset),"height":height,"texture":texture,"grounded":kind not in [2,7],"wall_base_y":p.y})
	return true

func build_thresholds(area: Rect2) -> void:
	# Only add a decorative threshold where all three corridor cells are open.
	for side: int in range(4):
		var length: int = int((area.size.y if side<2 else area.size.x)/64)
		for offset: int in range(1,length-1):
			var p: Vector2 = area.position+Vector2(0,offset*64+32) if side<2 else area.position+Vector2(offset*64+32,0)
			if side==1: p.x = area.end.x
			if side==3: p.y = area.end.y
			var normal: Vector2 = [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN][side]
			var tangent: Vector2 = normal.orthogonal()
			if not interior.dungeon.walkable(p+normal*32): continue
			if not interior.dungeon.walkable(p+normal*32+tangent*64) or not interior.dungeon.walkable(p+normal*32-tangent*64): continue
			thresholds.append({"pos":p,"vertical":side<2})

func draw_floor(canvas: Node2D) -> void:
	for detail: Dictionary in floor_details:
		canvas.draw_set_transform(detail.pos,detail.rotation,Vector2(1,0.78))
		canvas.draw_texture_rect(decals[detail.kind],Rect2(Vector2.ONE*(-detail.width/2),Vector2.ONE*detail.width),false,Color(0.8,0.85,0.86,detail.alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	for threshold: Dictionary in thresholds:
		canvas.draw_set_transform(threshold.pos,PI/2 if threshold.vertical else 0.0)
		canvas.draw_rect(Rect2(-95,-7,190,14),Color("182225",0.7))
		canvas.draw_line(Vector2(-92,-6),Vector2(92,-6),Color("9a916e",0.4),2)
		canvas.draw_line(Vector2(-92,6),Vector2(92,6),Color("9a916e",0.3),1)
		for x: int in range(-80,81,32): canvas.draw_line(Vector2(x,-5),Vector2(x,5),Color("656757",0.5),1)
	canvas.draw_set_transform(Vector2.ZERO)
