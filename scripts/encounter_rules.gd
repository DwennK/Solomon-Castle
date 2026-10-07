class_name EncounterRules
extends RefCounted

const TYPES: Array[String] = ["crossfire","pursuit","ward","ambush","swarm","duel","artillery"]

static func populate(data: Dictionary,rng: RandomNumberGenerator) -> void:
	data.encounter_version = 2
	data.encounters = []
	var bag: Array = LootRules.shuffled(TYPES,rng)
	var battles: int = 0
	for i: int in range(1,data.rooms.size()):
		if i==data.rooms.size()-1 and not data.boss.is_empty(): continue
		var quiet: bool = i==int(data.optional_room) or battles==2
		var type: String = "quiet" if quiet else String(bag.pop_front())
		if bag.is_empty(): bag=LootRules.shuffled(TYPES,rng)
		battles = 0 if quiet else battles+1
		data.encounters.append({"room":i,"type":type,"triggered":false})
		var group: Array = []
		match type:
			"crossfire": group=["archer","archer","skeleton","ghoul"]
			"pursuit": group=["ghoul","ghoul","skeleton","archer"]
			"ward": group=["sorcerer","skeleton","skeleton","archer"]
			"ambush": group=["ghoul","skeleton","archer","skeleton"]
			"swarm": group=["skeleton","skeleton","skeleton","skeleton","skeleton","skeleton","skeleton","skeleton"]
			"duel": group=["ghoul","knight" if int(data.number)>=5 else "sorcerer"]
			"artillery": group=["archer","sorcerer","archer"]
		if not quiet and type not in ["swarm","duel"]:
			if int(data.number)>=5: group.append("zombie" if type=="ward" else "imp")
			if int(data.number)>=9: group.append("knight" if type=="crossfire" else "ghost")
		var r: Array = data.rooms[i]
		var center: Vector2i = Dungeon.room_center(r)
		var offsets: Array[Vector2i] = [Vector2i.ZERO,Vector2i(1,1),Vector2i(2,-1),Vector2i(-1,2),Vector2i(2,2),Vector2i(-2,2),Vector2i(-2,-1),Vector2i(0,-2)]
		var occupied: Array[Vector2] = []
		for j: int in range(group.size()):
			var desired: Vector2i = center+offsets[j]
			if type in ["crossfire","artillery"]:
				desired=Vector2i(r[0]+2 if j%2==0 else r[0]+r[2]-3,r[1]+2+j/2*2)
			var p: Vector2 = free_position(data,r,desired,occupied)
			occupied.append(p)
			var role: String = "charger" if group[j]=="ghoul" else ("warden" if type=="ward" and j==0 else ("flanker" if group[j]=="skeleton" else ""))
			data.enemies.append({"id":"enemy_%d_%d"%[i,j],"kind":group[j],"pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"role":role,"encounter_room":i,"dormant":type=="ambush","awakened":false,"vital_scale":0.45 if type=="swarm" else (1.65 if type=="duel" else 1.0),"damage_scale":0.6 if type=="swarm" else (1.15 if type=="duel" else 1.0),"xp_scale":0.65 if type=="swarm" else (2.0 if type=="duel" else 1.35)})
	DiscoveryRules.populate(data,rng)

static func free_position(data: Dictionary,room: Array,desired: Vector2i,occupied: Array[Vector2]) -> Vector2:
	var best: Vector2 = TowerLayout.open_position(data.grid,room,desired)
	var distance: float = INF
	for y: int in range(room[1]+1,room[1]+room[3]-1):
		for x: int in range(room[0]+1,room[0]+room[2]-1):
			var cell: Vector2i = Vector2i(x,y)
			var point: Vector2 = Dungeon.to_world(cell)
			if data.grid[y][x]!="." or point in occupied: continue
			var score: float = Vector2(cell-desired).length_squared()
			if score<distance: distance=score;best=point
	return best

static func kill_xp(floor_number: int,boss: bool = false) -> float:
	# Fewer early upgrades; later floors keep enough XP to reach major skills.
	var ramp: float = minf(1.0,0.45+maxi(0,floor_number-1)*0.055)
	return (19.0+floor_number*4.5)*ramp*(9 if boss else 1)
