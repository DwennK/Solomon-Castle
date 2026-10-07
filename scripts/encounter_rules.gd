class_name EncounterRules
extends RefCounted

const TYPES: Array[String] = ["crossfire","pursuit","ward","ambush"]

static func populate(data: Dictionary,rng: RandomNumberGenerator, difficulty: int = 0) -> void:
	var offset: int = rng.randi_range(0,3)
	data.encounters = []
	for i: int in range(1,data.rooms.size()):
		if i==data.rooms.size()-1 and not data.boss.is_empty(): continue
		var type: String = TYPES[(i+offset)%TYPES.size()]
		var group: Array = []
		match type:
			"crossfire": group=["archer","archer","skeleton","ghoul"]
			"pursuit": group=["ghoul","skeleton","skeleton","archer"]
			"ward": group=["sorcerer","skeleton","skeleton","archer"]
			"ambush": group=["ghoul","skeleton","archer","skeleton"]
		if int(data.number)>=5: group.append("zombie" if type=="ward" else "imp")
		if difficulty>=2 and type=="pursuit": group[2]="imp"
		if difficulty>=3 and type=="ambush": group[2]="ghost"
		if int(data.number)>=9: group.append("knight" if type=="crossfire" else "ghost")
		data.encounters.append({"room":i,"type":type,"triggered":false})
		var r: Array = data.rooms[i]
		# Compact, complementary packs engage together; a warden starts close
		# enough to protect its guards instead of standing in another corner.
		var center_cell: Vector2i = Dungeon.room_center(r)
		var offsets: Array[Vector2i] = [Vector2i(-2,-1),Vector2i(1,1),Vector2i(2,-1),Vector2i(-1,2),Vector2i(2,2),Vector2i(-2,2)]
		if type=="ward": offsets[0]=Vector2i.ZERO
		for j: int in range(group.size()):
			var role: String = "charger" if group[j]=="ghoul" else ("warden" if type=="ward" and j==0 else ("flanker" if group[j]=="skeleton" else ""))
			var p: Vector2 = TowerLayout.open_position(data.grid,r,center_cell+offsets[j])
			data.enemies.append({"id":"enemy_%d_%d"%[i,j],"kind":group[j],"pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"role":role,"encounter_room":i,"dormant":type=="ambush","awakened":false,"elite":difficulty>0 and j==0 and (i+offset)%maxi(1,5-difficulty)==0})
	# One deliberate detour: the reward is disclosed before the player awakens its guards.
	var optional: int = int(data.optional_room)
	var room: Array = data.rooms[optional]
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
	data.props.append({"id":"trial_%d"%optional,"kind":"reliquary","pos":Dungeon.pair(center),"opened":false,"phase":"idle","room":optional})
	for j: int in range(3):
		var point: Vector2 = TowerLayout.open_position(data.grid,room,Vector2i(room[0]+2+j*2,room[1]+room[3]-3))
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
			candidate+=point.distance_to(Dungeon.vec(enemy.pos))*0.12
			if candidate<score: score=candidate;best=point
	return best
