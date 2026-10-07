class_name EncounterRules
extends RefCounted

const TYPES: Array[String] = ["crossfire","pursuit","ward","ambush"]

static func populate(data: Dictionary,rng: RandomNumberGenerator) -> void:
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
			data.enemies.append({"id":"enemy_%d_%d"%[i,j],"kind":group[j],"pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"role":role,"encounter_room":i,"dormant":type=="ambush","awakened":false})
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

static func kill_xp(floor_number: int,boss: bool = false) -> float:
	# Fewer early upgrades; later floors keep enough XP to reach major skills.
	var ramp: float = minf(1.0,0.45+maxi(0,floor_number-1)*0.055)
	return (19.0+floor_number*4.5)*ramp*(9 if boss else 1)
