class_name DiscoveryRules
extends RefCounted

const KINDS: Array[String] = ["reliquary","cursed_cache","archive","oath_altar","hidden_cache"]

static func populate(data: Dictionary,rng: RandomNumberGenerator) -> void:
	var index: int = int(data.optional_room)
	var room: Array = data.rooms[index]
	var kind: String = KINDS[rng.randi_range(0,KINDS.size()-1)]
	var point: Vector2 = TowerLayout.open_position(data.grid,room,Dungeon.room_center(room))
	if kind=="hidden_cache": point=TowerLayout.open_position(data.grid,room,Vector2i(room[0]+room[2]/2,room[1]+1))
	data.props.append({"id":"discovery_%d"%index,"kind":kind,"pos":Dungeon.pair(point),"opened":false,"phase":"idle","room":index})
	if kind in ["reliquary","cursed_cache"]:
		var occupied: Array[Vector2] = [point]
		for j: int in range(3 if kind=="reliquary" else 4):
			var p: Vector2 = EncounterRules.free_position(data,room,Dungeon.room_center(room)+Vector2i(j-1,2),occupied)
			occupied.append(p)
			data.enemies.append({"id":"trial_guard_%d"%j,"kind":"ghoul" if j==0 else "skeleton","pos":Dungeon.pair(p),"hp":-1.0,"dead":false,"role":"charger" if j==0 else "flanker","trial":true,"dormant":true,"awakened":false,"encounter_room":index})
	# The optional fountain is not a compulsory fixture on every floor.
	if rng.randf()<0.4:
		var font_room: int = 1 if index!=1 else 2
		room=data.rooms[font_room]
		data.props.append({"id":"blood_font","kind":"blood_font","pos":Dungeon.pair(TowerLayout.open_position(data.grid,room,Vector2i(room[0]+room[2]/2,room[1]+2))),"opened":false})

static func is_discovery(kind: String) -> bool:
	return kind in KINDS or kind=="blood_font"

static func caption(record: Dictionary) -> String:
	match record.kind:
		"blood_font": return "Blood font"
		"archive": return "Forgotten archive"
		"oath_altar": return "Altar of embers"
		"hidden_cache": return "Cracked masonry"
		_: return "Claim reward" if record.get("phase","")=="ready" else ("Trial active" if record.get("phase","")=="active" else ("Cursed cache" if record.kind=="cursed_cache" else "Optional trial"))

static func hint(record: Dictionary) -> String:
	match record.kind:
		"blood_font": return "Spend 20% max health to refill mana (once)"
		"archive": return "Choose a spell lesson or two Knowledge Shards (once)"
		"oath_altar": return "Offer 25% max health: +20% damage on this floor (once)"
		"hidden_cache": return "Cracked masonry: break it with a spell to uncover the cache"
		_:
			if record.get("phase","")=="active": return "Defeat the awakened sentries to unseal the rare item"
			if record.get("phase","")=="ready": return "Claim the rare equipment"
			return "Awaken %d sentries for rare equipment · retreat is possible"%(4 if record.kind=="cursed_cache" else 3)
