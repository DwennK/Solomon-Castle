class_name DungeonDressing
extends RefCounted
## Architectural bays, not a scatter pass. Saved gameplay records remain untouched.
const TYPES: Array[String] = ["chapel","library","prison","crypt","laboratory","ruins"]
const DECOR: Texture2D = EnvironmentArt.FURNITURE
const DECOR_REGIONS: Array[Rect2] = EnvironmentArt.FURNITURE_REGIONS
var owner_ref: WeakRef
var interior: DungeonInterior:
	get: return owner_ref.get_ref() as DungeonInterior
var styles: Array[String] = []
var prop_positions: Dictionary = {}
var occupied: Array[Rect2] = []

func _init(owner_interior: DungeonInterior) -> void:
	owner_ref = weakref(owner_interior)
	for index: int in range(interior.dungeon.data.rooms.size()):
		var style: String = TYPES[(index+(int(interior.dungeon.data.number)-1)*2)%TYPES.size()]
		if index==0 or (index==interior.dungeon.data.rooms.size()-1 and not interior.dungeon.data.get("boss","").is_empty()): style = "chapel"
		styles.append(style)
		build_room(index,style)

func build_room(index: int,style: String) -> void:
	var room: Array = interior.dungeon.data.rooms[index]
	var area: Rect2 = Rect2(room[0]*64,room[1]*64,room[2]*64,room[3]*64)
	var top: float = area.position.y
	var left: float = area.position.x
	var width: float = area.size.x
	# Interactive objects occupy service bays; both rendering and interaction use these feet.
	place_prop("chest_%d"%index,Vector2(left+100,top+58),Vector2(80,42))
	place_prop("urn_%d"%index,Vector2(area.end.x-84,top+42),Vector2(42,28))
	place_prop("torch_%d"%index,Vector2(left+34,top+minf(230,area.size.y*0.40)),Vector2(52,28))
	# The north facade has clear corner supports, one focal furnishing and one window bay.
	add_architecture(0,Vector2(left+6,top+6),138,true)
	add_architecture(0,Vector2(area.end.x-6,top+6),138,true)
	var kind: int = TYPES.find(style)
	var focal: Vector2 = Vector2(left+width*0.40,top)
	if style in ["chapel","crypt"]: focal.x = left+width*0.46
	var object_width: float = [156.0,150.0,108.0,170.0,156.0,150.0][kind]
	var depth: float = [26.0,16.0,-10.0,34.0,26.0,24.0][kind]
	add_furniture(kind,focal+Vector2(0,depth),object_width,top)
	# A second bookcase creates an intentional library wall, rather than assorted props.
	if style=="library" and width>=768:
		add_furniture(1,Vector2(left+width*0.62,top+16),140,top)
	var window_p: Vector2 = Vector2(left+width*0.75,top-12)
	if style=="library" and width>=768: window_p.x = left+width*0.80
	if add_architecture(1,window_p,102,false):
		interior.lights.append({"pos":Vector2(window_p.x,top+26),"color":Color("829eac"),"window":true,"room":index,"radius":260.0,"energy":0.19})
	if style in ["chapel","prison"]:
		add_architecture(3,Vector2(left+width*0.20,top-23),70,false)

func place_prop(id: String,p: Vector2,footprint: Vector2) -> void:
	if not interior.dungeon.walkable(p,22): return
	# Avoid door mouths even when a corridor happens to connect to this bay.
	if not wall_clear(Vector2(p.x,interior.dungeon.data.rooms[interior.dungeon.room_at(p)][1]*64),footprint.x) and not id.begins_with("torch"):
		return
	prop_positions[id] = p
	occupied.append(Rect2(p-Vector2(footprint.x/2,footprint.y),footprint))

func wall_clear(p: Vector2,width: float) -> bool:
	var first: int = floori((p.x-width/2-4)/64)
	var last: int = floori((p.x+width/2+4)/64)
	var row: int = floori((p.y-1)/64)
	for x: int in range(first,last+1):
		if interior.dungeon.cells.has(Vector2i(x,row)): return false
	return true

func add_furniture(kind: int,foot: Vector2,width: float,wall_y: float) -> bool:
	var texture: Texture2D = EnvironmentArt.furniture(kind)
	var height: float = width*texture.get_height()/texture.get_width()
	if not wall_clear(Vector2(foot.x,wall_y),width): return false
	var bounds: Rect2 = Rect2(foot-Vector2(width/2,height),Vector2(width,height))
	if overlaps(bounds): return false
	occupied.append(bounds.grow(10))
	interior.wall_details.append({"kind":kind,"pos":foot,"height":height,"texture":texture,"grounded":kind!=2,"wall_base_y":wall_y})
	return true

func add_architecture(kind: int,foot: Vector2,height: float,grounded: bool) -> bool:
	var texture: Texture2D = EnvironmentArt.architecture(kind)
	var width: float = height*texture.get_width()/texture.get_height()
	var wall_y: float = floorf((foot.y+24)/64)*64
	if not wall_clear(Vector2(foot.x,wall_y),width): return false
	var bounds: Rect2 = Rect2(foot-Vector2(width/2,height),Vector2(width,height))
	if overlaps(bounds): return false
	occupied.append(bounds.grow(8))
	interior.wall_details.append({"kind":10+kind,"pos":foot,"height":height,"texture":texture,"grounded":grounded,"wall_base_y":wall_y})
	return true

func overlaps(bounds: Rect2) -> bool:
	for other: Rect2 in occupied:
		if other.intersects(bounds): return true
	return false
