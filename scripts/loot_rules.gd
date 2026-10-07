class_name LootRules
extends RefCounted
## Seeded, finite rewards per floor. No global RNG or kill-order dependent rolls.
const VERSION: int = 1

static func random_for(seed_value: int, floor_number: int, difficulty: int, salt: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + floor_number*7919 + difficulty*982451653 + salt
	return rng

static func shuffled(values: Array, rng: RandomNumberGenerator) -> Array:
	var result: Array = values.duplicate()
	for i: int in range(result.size()-1,0,-1):
		var j: int = rng.randi_range(0,i)
		var value: Variant = result[i]
		result[i] = result[j]
		result[j] = value
	return result

static func prepare_floor(data: Dictionary, seed_value: int, difficulty: int) -> void:
	if int(data.get("loot_version",0))>=VERSION: return
	var number: int = int(data.number)
	var rng: RandomNumberGenerator = random_for(seed_value,number,difficulty,730201)
	var chests: Array = []
	var urns: Array = []
	var kept: Array = []
	for prop: Dictionary in data.props:
		if prop.kind=="chest": chests.append(prop)
		elif prop.kind=="urn": urns.append(prop)
		else: kept.append(prop)
	var candidates: Array = []
	for chest: Dictionary in chests:
		var index: int = int(String(chest.id).trim_prefix("chest_"))
		if index>0 and (data.boss.is_empty() or index<data.rooms.size()-1): candidates.append(chest)
	candidates = shuffled(candidates,rng)
	# The key chest is always retained, before the closed boss gate.
	for i: int in range(candidates.size()):
		if candidates[i].id==data.key_chest:
			var key: Dictionary = candidates.pop_at(i)
			candidates.push_front(key)
			break
	var chest_count: int = 2 + (rng.randi_range(0,1) if data.rooms.size()>6 else 0)
	var selected: Array = candidates.slice(0,chest_count)
	for i: int in range(selected.size()):
		var chest: Dictionary = selected[i]
		chest.reward = {"gold":rng.randi_range(12,20)+number*2,"equipment":i==0 or (i==1 and data.boss.is_empty() and rng.randf()<0.25),"health":1 if i==1 else 0,"mana":1 if i==1 else 0}
		kept.append(chest)
	# Previously opened containers remain opened; earned items and floor loot are untouched.
	for chest: Dictionary in chests:
		if chest not in selected and (chest.get("opened",false) or chest.id==data.key_chest):
			chest.reward = {"gold":0,"equipment":false,"health":0,"mana":0}
			kept.append(chest)
	candidates = []
	for urn: Dictionary in urns:
		var index: int = int(String(urn.id).trim_prefix("urn_"))
		if index>0 and (data.boss.is_empty() or index<data.rooms.size()-1): candidates.append(urn)
	selected = shuffled(candidates,rng).slice(0,rng.randi_range(3,4 if data.rooms.size()==6 else 6))
	var potion_assigned: bool = false
	for urn: Dictionary in selected:
		var roll: float = rng.randf()
		urn.reward = {"gold":0,"equipment":false,"health":0,"mana":0}
		if roll<0.30: urn.reward.gold = rng.randi_range(2,5)+int(number/3)
		elif roll<0.35 and not potion_assigned:
			urn.reward["health" if rng.randf()<0.5 else "mana"] = 1
			potion_assigned = true
		kept.append(urn)
	for urn: Dictionary in urns:
		if urn not in selected and urn.get("opened",false): kept.append(urn)
	data.props = kept
	var regular: Array = []
	for enemy: Dictionary in data.enemies:
		if enemy.id not in ["boss","guardian"] and not enemy.get("trial",false): regular.append(enemy)
	regular = shuffled(regular,rng)
	for i: int in range(regular.size()):
		regular[i].reward = {"gold":8+number*2 if rng.randf()<0.35 else 0,"health":1 if i==0 else 0,"mana":1 if i==1 else 0}
	data.loot_version = VERSION

static func rarity(rng: RandomNumberGenerator, floor_number: int, difficulty: int, boss: bool = false) -> int:
	var epic: float
	var rare: float
	if boss:
		epic = (0.20 if floor_number<8 else 0.35)+clampi(difficulty,0,4)*0.05
		rare = 1.0-epic
	else:
		var weights: Array = [0.10,0.0] if floor_number<4 else ([0.23,0.02] if floor_number<8 else ([0.34,0.06] if floor_number<11 else [0.40,0.10]))
		rare = weights[0]+clampi(difficulty,0,4)*0.05
		epic = weights[1]+clampi(difficulty,0,4)*0.03
	var roll: float = rng.randf()
	return 2 if roll<epic else (1 if roll<epic+rare else 0)

static func make_item(seed_value: int, floor_number: int, boss: bool = false, shop: bool = false) -> Dictionary:
	var rng: RandomNumberGenerator = random_for(seed_value,floor_number,int(State.run.difficulty),410117)
	var grade: int = rarity(rng,floor_number,int(State.run.difficulty),boss)
	# One staff and two rings per cycle match the three equipment slots.
	var sequence: int = int(State.run.get("loot_item_count",0))
	var slot: String = ["staff","ring","ring"][sequence%3] if not shop else ("staff" if rng.randf()<0.333333 else "ring")
	var history: Array = State.run.get("loot_recent_templates",[])
	var candidates: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	for template: Dictionary in Equipment.templates():
		if template.rarity!=grade or template.slot!=slot: continue
		candidates.append(template)
		if template.id not in history: fresh.append(template)
	if not fresh.is_empty(): candidates = fresh
	var template: Dictionary = candidates[rng.randi_range(0,candidates.size()-1)]
	if not shop:
		history = history.duplicate()
		history.append(template.id)
		if history.size()>4: history.pop_front()
		State.run.loot_recent_templates = history
		State.run.loot_item_count = sequence+1
	return State.make_equipment(template,rng,floor_number)
