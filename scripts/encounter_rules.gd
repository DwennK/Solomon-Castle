class_name EncounterRules
extends RefCounted

const TYPES: Array[String] = ["crossfire","pursuit","ward","ambush"]

static func populate(data: Dictionary,rng: RandomNumberGenerator, difficulty: int = 0) -> void:
	var offset: int = rng.randi_range(0,3)
	data.encounters = []
	data.tactical_version = 1
	data.tactical_cover = []
	var order: Array[int] = room_order(data)
	var rest_room: int = -1
	var candidates: Array[int] = []
	for room: int in order:
		if room!=0 and room!=int(data.optional_room) and room!=data.rooms.size()-1: candidates.append(room)
	var smaller: Array[int] = []
	for room: int in candidates:
		if data.rooms[room][2]<12 or data.rooms[room][3]<12: smaller.append(room)
	if not smaller.is_empty(): candidates=smaller
	if not candidates.is_empty(): rest_room=candidates[mini(2,candidates.size()-1)]
	var combat_index: int = 0
	var small_index: int = 0
	for i: int in order:
		if i==0 or (i==data.rooms.size()-1 and not data.boss.is_empty()): continue
		var r: Array = data.rooms[i]
		var center_cell: Vector2i = Dungeon.room_center(r)
		if i==rest_room:
			data.encounters.append({"room":i,"type":"rest","tempo":"rest","triggered":false})
			data.props.append({"id":"rest_%d"%i,"kind":"rest_font","pos":Dungeon.pair(TowerLayout.open_position(data.grid,r,center_cell)),"opened":false,"room":i})
			continue
		var type: String = TYPES[(combat_index+offset)%TYPES.size()]
		var tempo: String = "setpiece" if r[2]>=12 and r[3]>=12 else ["skirmish","pressure"][small_index%2]
		if tempo!="setpiece": small_index+=1
		combat_index+=1
		var group: Array = []
		match type:
			"crossfire": group=["archer","archer","skeleton","ghoul"]
			"pursuit": group=["ghoul","sorcerer","skeleton","imp"]
			"ward": group=["sorcerer","skeleton","skeleton","archer"]
			"ambush": group=["ghoul","skeleton","archer","skeleton"]
		if tempo=="skirmish": group=group.slice(0,2)
		elif tempo=="pressure": group=group.slice(0,3 if int(data.number)<5 else 4)
		else:
			group.append("zombie" if type=="ward" else "imp")
			if int(data.number)>=9: group.append("knight" if type=="crossfire" else "ghost")
		if difficulty>=2 and type=="pursuit" and group.size()>2: group[2]="imp"
		if difficulty>=3 and type=="ambush" and group.size()>2: group[2]="ghost"
		var affix: String = ""
		if tempo=="setpiece" and int(data.number)>=3:
			affix=["bulwark","ritualist","brood"][(int(data.number)+i+offset)%3]
			group[-1]={"bulwark":"knight","ritualist":"sorcerer","brood":"zombie"}[affix]
		data.encounters.append({"room":i,"type":type,"tempo":tempo,"triggered":false})
		if tempo!="skirmish": furnish_combat_room(data,i)
		var used: Array[Vector2i] = []
		for prop: Dictionary in data.props: used.append(Vector2i(Dungeon.vec(prop.pos)/Dungeon.CELL))
		for j: int in range(group.size()):
			var role: String = "charger" if group[j]=="ghoul" else ("warden" if type=="ward" and j==0 else ("artillery" if type=="pursuit" and group[j]=="sorcerer" else ("flanker" if group[j]=="skeleton" else "")))
			var elite_kind: String = affix if j==group.size()-1 else ""
			if elite_kind=="ritualist": role="artillery"
			var desired: Vector2i = formation_cell(data,i,type,j)
			var p: Vector2 = free_position(data.grid,r,desired,used)
			used.append(Vector2i(p/Dungeon.CELL))
			data.enemies.append({"id":"enemy_%d_%d"%[i,j],"kind":group[j],"pos":Dungeon.pair(p),"home_pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"role":role,"encounter_room":i,"dormant":type=="ambush","awakened":false,"elite":not elite_kind.is_empty(),"elite_kind":elite_kind})
	# One deliberate detour: the reward is disclosed before the player awakens its guards.
	var optional: int = int(data.optional_room)
	var room: Array = data.rooms[optional]
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
	data.props.append({"id":"trial_%d"%optional,"kind":"reliquary","pos":Dungeon.pair(center),"opened":false,"phase":"idle","room":optional})
	var trial_used: Array[Vector2i] = []
	for entity: Dictionary in data.enemies+data.props: trial_used.append(Vector2i(Dungeon.vec(entity.pos)/Dungeon.CELL))
	for j: int in range(3):
		var point: Vector2 = free_position(data.grid,room,Vector2i(room[0]+2+j*2,room[1]+room[3]-3),trial_used)
		trial_used.append(Vector2i(point/Dungeon.CELL))
		data.enemies.append({"id":"trial_guard_%d"%j,"kind":"ghoul" if j==0 else "skeleton","pos":Dungeon.pair(point),"hp":-1.0,"dead":false,"role":"charger" if j==0 else "flanker","trial":true,"dormant":true,"awakened":false,"encounter_room":optional})
	var font_room: int = 1 if optional!=1 else 2
	room=data.rooms[font_room]
	data.props.append({"id":"blood_font","kind":"blood_font","pos":Dungeon.pair(TowerLayout.open_position(data.grid,room,Vector2i(room[0]+room[2]/2,room[1]+2))),"opened":false})

# Geometry is read from the saved floor, so existing maps gain the behavior safely.
static func room_bounds(data: Dictionary,room: int) -> Rect2:
	if room<0 or room>=data.rooms.size(): return Rect2()
	var r: Array = data.rooms[room]
	return Rect2(r[0]*Dungeon.CELL,r[1]*Dungeon.CELL,r[2]*Dungeon.CELL,r[3]*Dungeon.CELL)

static func inside_combat_area(data: Dictionary,room: int,point: Vector2) -> bool:
	return room>=0 and room_bounds(data,room).grow(-Dungeon.CELL*1.5).has_point(point)

static func home_position(data: Dictionary,enemy: Dictionary) -> Vector2:
	var room: int = int(enemy.get("encounter_room",-1))
	if room<0 or room>=data.rooms.size(): return Dungeon.vec(enemy.pos)
	return TowerLayout.open_position(data.grid,data.rooms[room],Dungeon.room_center(data.rooms[room]))

static func may_pursue(data: Dictionary,enemy: Dictionary,point: Vector2) -> bool:
	var room: int = int(enemy.get("encounter_room",-1))
	if room<0 or room>=data.rooms.size(): return true
	var allowance: float = 448.0 if enemy.get("role","")=="charger" else 128.0
	return room_bounds(data,room).grow(allowance).has_point(point)

static func defensive_position(dungeon: Dungeon,enemy: Dictionary,target: Vector2,preferred: float) -> Vector2:
	var room: int = int(enemy.get("encounter_room",-1))
	var r: Array = dungeon.data.rooms[room]
	var best: Vector2 = home_position(dungeon.data,enemy)
	var score: float = INF
	# Stay away from doorways and choose a reachable line of fire instead of
	# streaming through the doorway when the player retreats around a corner.
	for y: int in range(r[1]+2,r[1]+r[3]-2):
		for x: int in range(r[0]+2,r[0]+r[2]-2):
			var point: Vector2 = Dungeon.to_world(Vector2i(x,y))
			if not dungeon.walkable(point,20): continue
			var candidate: float = absf(point.distance_to(target)-preferred)
			if not dungeon.visible_line(point,target): candidate+=600.0
			candidate+=point.distance_to(Dungeon.vec(enemy.get("home_pos",enemy.pos)))*0.8
			if candidate<score: score=candidate;best=point
	return best

static func room_order(data: Dictionary) -> Array[int]:
	var order: Array[int] = [0]
	var cursor: int = 0
	while cursor<order.size():
		var current: int = order[cursor]
		cursor+=1
		for link: Array in data.get("links",[]):
			if current not in link: continue
			var neighbor: int = link[1] if link[0]==current else link[0]
			if neighbor not in order: order.append(neighbor)
	for i: int in range(data.rooms.size()):
		if i not in order: order.append(i)
	return order

static func formation_cell(data: Dictionary,room: int,type: String,index: int) -> Vector2i:
	var r: Array = data.rooms[room]
	var center: Vector2i = Dungeon.room_center(r)
	var approach: Vector2i = Vector2i.DOWN
	var order: Array[int] = room_order(data)
	for link: Array in data.get("links",[]):
		if room not in link: continue
		var neighbor: int = link[1] if link[0]==room else link[0]
		if order.find(neighbor)>=order.find(room): continue
		var offset: Vector2i = Dungeon.room_center(data.rooms[neighbor])-center
		approach=Vector2i(signi(offset.x),0) if absi(offset.x)>absi(offset.y) else Vector2i(0,signi(offset.y))
		break
	var side: Vector2i = Vector2i(-approach.y,approach.x)
	var spread: int = maxi(2,mini(r[2],r[3])/2-2)
	match type:
		"crossfire":
			if index<2: return center+(side*spread+approach*spread)*(-1 if index==0 else 1)
		"ward":
			if index==0: return center-approach
			return center+approach+side*((index%3)-1)*2
		"pursuit":
			if index==0: return center+approach*2
			if index==1: return center-approach*2
		"ambush":
			return center+side*spread*(-1 if index%2==0 else 1)+approach*(index/2-1)*2
	return center+side*((index%3)-1)*2-approach*(index/3+1)

static func free_position(grid: Array,r: Array,desired: Vector2i,used: Array[Vector2i]) -> Vector2:
	var best: Vector2 = TowerLayout.open_position(grid,r,desired)
	var score: float = INF
	for y: int in range(r[1]+2,r[1]+r[3]-2):
		for x: int in range(r[0]+2,r[0]+r[2]-2):
			var cell: Vector2i = Vector2i(x,y)
			if grid[y][x]!="." or cell in used: continue
			var d: float = Vector2(cell).distance_squared_to(Vector2(desired))
			if d<score: score=d;best=Dungeon.to_world(cell)
	return best

static func furnish_combat_room(data: Dictionary,room: int) -> void:
	var r: Array = data.rooms[room]
	var center: Vector2i = Dungeon.room_center(r)
	# One off-centre masonry pillar gives cover without closing an aisle or doorway.
	if r[2]>=12 and r[3]>=12:
		var cell: Vector2i = center+Vector2i(3,0)
		var occupied: bool = data.props.any(func(p: Dictionary)->bool:return Dungeon.vec(p.pos).distance_to(Dungeon.to_world(cell))<96)
		if data.grid[cell.y][cell.x]=="." and not occupied:
			var row: String = data.grid[cell.y]
			data.grid[cell.y]=row.substr(0,cell.x)+"#"+row.substr(cell.x+1)
			data.tactical_cover.append([cell.x,cell.y])
	var used: Array[Vector2i] = []
	for p: Dictionary in data.props: used.append(Vector2i(Dungeon.vec(p.pos)/Dungeon.CELL))
	var pos: Vector2 = free_position(data.grid,r,center+Vector2i(-2,2),used)
	data.props.append({"id":"brazier_%d"%room,"kind":"brazier","pos":Dungeon.pair(pos),"opened":false,"room":room})
