extends Node

signal changed
signal level_pending
signal message(text: String)

var run: Dictionary = {}
var checkpoint: Dictionary = {}
var options: Dictionary = {"volume":0.7,"music":0.45,"brightness":1.0,"reduced_effects":false,"fullscreen":false,"bindings":{},"pad_bindings":{}}
var qa: bool = false
var save_path: String = "user://campaign.json"
var unlocked: int = 0

func _ready() -> void:
	qa = "--qa" in OS.get_cmdline_user_args() or "--test" in OS.get_cmdline_user_args()
	if qa:
		save_path = "user://qa_campaign.json"
		if "--test" in OS.get_cmdline_user_args(): save_path = "user://qa_unit_campaign.json"
		if "--qa-playthrough" in OS.get_cmdline_user_args(): save_path = "user://qa_playthrough_campaign.json"
	var prefs: Dictionary = SaveStore.read_save("user://qa_options.json" if qa else "user://options.json")
	if not prefs.is_empty():
		options.merge(prefs.get("options", {}), true)
		unlocked = int(prefs.get("unlocked", 0))
	Controls.setup(options.bindings,options.pad_bindings)
	apply_options()

func fresh(seed_value: int = 0, difficulty: int = 0, hardcore: bool = false) -> void:
	run = {"seed":seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()),"difficulty":difficulty,"hardcore":hardcore,"level":1,"xp":0.0,"gold":140,"hp":110.0,"mp":100.0,"skills":{},"secondary":[],"active":"","fusion":{},"inventory":[],"equipped":{"staff":"","ring1":"","ring2":""},"hp_potions":3,"mp_potions":3,"floor":0,"deepest":1,"floors":{},"position":[720,580],"return_position":[],"return_floor":1,"dead":false,"victory":false,"deaths":0,"pending":[],"offers":[],"shop":[],"serial":0,"wisdom":0}
	checkpoint = {}
	changed.emit()

func rank(id: String, snapshot: Dictionary = {}) -> int:
	return effective_rank(id, learned_rank(id,snapshot), equipment_bonuses())

func stats() -> Dictionary:
	var bonuses: Dictionary = equipment_bonuses()
	var ranks: Dictionary = {}
	for id: String in ["life","mana","regen","power","haste","economy","rush","resist"]:
		ranks[id] = effective_rank(id,learned_rank(id),bonuses)
	var s: Dictionary = {"max_hp":110.0+ranks.life*24, "max_mana":100.0+ranks.mana*28, "mana_regen":7.5+ranks.regen*2.5, "hp_regen":0.12, "damage":1.0+ranks.power*0.14, "cast_speed":1.0+ranks.haste*0.12, "cost_reduction":ranks.economy*0.09, "speed":220.0*(1.0+ranks.rush*0.07), "resistance":ranks.resist*0.07,"flat_damage":0.0,"poison_resistance":0.0,"gold_bonus":0.0,"xp_bonus":0.0,"mana_recovery":0.0,"hp_recovery":0.0}
	for key: String in bonuses:
		if key in s: s[key] += float(bonuses[key])*(220.0 if key=="speed" else 1.0)
	s.mana_regen *= 1.0+s.mana_recovery
	s.hp_regen *= 1.0+s.hp_recovery
	s.telekinesis = float(bonuses.get("grant:reach",0))>0
	s.meditation = float(bonuses.get("grant:meditation",0))>0
	s.mental_focus = float(bonuses.get("grant:mental_focus",0))>0
	s.pickup_radius = 65.0+learned_rank("reach")*45.0+(180.0 if s.telekinesis else 0.0)
	s.poison_resistance = clampf(s.poison_resistance,0.0,1.0)
	s.cost_reduction = clampf(s.cost_reduction, 0.0, 0.8)
	s.resistance = clampf(s.resistance, 0.0, 0.75)
	s.cast_speed = maxf(s.cast_speed, 0.1)
	return s

func pay_mana(base: float) -> bool:
	var cost: float = maxf(0.0, base) * (1.0 - stats().cost_reduction)
	if float(run.mp) + 0.00001 < cost:
		return false
	run.mp = maxf(0.0, float(run.mp) - cost)
	return true

func xp_threshold(level: int) -> float:
	return 32.0 + level * 19.0 + pow(level, 1.5) * 2.0

func add_xp(amount: float) -> void:
	run.xp += amount*(1.0+stats().xp_bonus)
	while run.xp >= xp_threshold(run.level):
		run.xp -= xp_threshold(run.level)
		run.level += 1
		run.pending.append(run.level)
	if not run.pending.is_empty():
		level_pending.emit()

func eligible(level: int) -> Array[String]:
	var result: Array[String] = []
	for kind: String in ["primary","secondary","passive"]:
		for id: String in Catalog.ids(kind):
			var d: ContentDefinition = Catalog.definition(id)
			var cap: int = mini(d.max_rank, 12) if kind == "primary" and level < 25 else d.max_rank
			if level < d.min_level or learned_rank(id) >= cap:
				continue
			if not d.prerequisite.is_empty() and learned_rank(d.prerequisite) == 0:
				continue
			if kind == "secondary" and learned_rank(id) == 0 and run.secondary.size() >= (3 if level >= 20 else 2):
				continue
			result.append(id)
	if level % 5 == 0:
		for id: String in Catalog.ids("fusion"):
			var elements: Array = Catalog.definition(id).values.elements
			if learned_rank(elements[0]) > 0 and learned_rank(elements[1]) > 0:
				result.append(id)
	return result

func offers() -> Array:
	if run.pending.is_empty():
		return []
	if not run.offers.is_empty():
		return run.offers
	var choices: Array[String] = eligible(int(run.pending[0]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(run.seed) + int(run.pending[0])*92821 + int(run.wisdom)
	# Fusion opportunities must remain discoverable at each fifth level.
	var fusion_choices: Array = choices.filter(func(id: String) -> bool: return Catalog.definition(id).kind == "fusion")
	if not fusion_choices.is_empty():
		var fusion: String = fusion_choices[rng.randi_range(0, fusion_choices.size()-1)]
		run.offers.append(fusion)
		choices.erase(fusion)
	while run.offers.size() < 3 and not choices.is_empty():
		var index: int = rng.randi_range(0, choices.size()-1)
		run.offers.append(choices[index])
		choices.remove_at(index)
	return run.offers

func learn(id: String) -> bool:
	if not Catalog.defs.has(id):
		return false
	var d: ContentDefinition = Catalog.definition(id)
	if d.kind == "fusion":
		run.fusion = {"id":id,"snapshot":run.skills.duplicate(true),"level":run.level}
		run.active = id
	else:
		run.skills[id] = learned_rank(id) + 1
		if d.kind == "secondary" and not id in run.secondary:
			run.secondary.append(id)
		if d.kind == "primary" and run.active.is_empty():
			run.active = id
	changed.emit()
	return true

func choose(id: String) -> bool:
	if run.pending.is_empty() or not id in run.offers:
		return false
	if not id in eligible(int(run.pending[0])):
		return false
	learn(id)
	run.pending.pop_front()
	run.offers = []
	return true

func find_item(uid: String) -> Dictionary:
	for item: Dictionary in run.get("inventory", []):
		if item.uid == uid:
			return item
	return {}

func make_item(seed_value: int, tier: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rarity: int = clampi(rng.randi_range(0,2) + int(tier / 8),0,2)
	var candidates: Array[Dictionary] = []
	for template: Dictionary in Equipment.templates():
		if template.rarity==rarity: candidates.append(template)
	return make_equipment(candidates[rng.randi_range(0,candidates.size()-1)],rng,tier)

func equip(uid: String, slot: String = "") -> bool:
	var item: Dictionary = find_item(uid)
	if item.is_empty(): return false
	if slot.is_empty():
		slot = "staff" if item.slot == "staff" else ("ring1" if run.equipped.ring1.is_empty() else "ring2")
	if not run.equipped.has(slot) or (item.slot == "staff") != (slot == "staff"): return false
	for key: String in run.equipped:
		if run.equipped[key] == uid: run.equipped[key] = ""
	run.equipped[slot] = uid
	refresh_equipment()
	return true

func unequip(slot: String) -> void:
	if run.equipped.has(slot): run.equipped[slot] = ""
	refresh_equipment()

func clamp_vitals() -> void:
	var s: Dictionary = stats()
	run.hp = clampf(run.hp,0.0,s.max_hp)
	run.mp = clampf(run.mp,0.0,s.max_mana)

func sell(uid: String) -> bool:
	var item: Dictionary = find_item(uid)
	if item.is_empty() or uid in run.equipped.values(): return false
	run.gold += maxi(1,int(item.price / 3))
	run.inventory.erase(item)
	changed.emit()
	return true

func buy(uid: String) -> bool:
	for item: Dictionary in run.shop:
		if item.uid == uid and run.gold >= item.price and run.inventory.size() < 48:
			run.gold -= item.price
			run.inventory.append(item.duplicate(true))
			run.shop.erase(item)
			changed.emit()
			return true
	return false

func potion(kind: String) -> bool:
	var key: String = kind + "_potions"
	var stat_key: String = "hp" if kind == "hp" else "mp"
	var max_value: float = stats().max_hp if kind == "hp" else stats().max_mana
	if run[key] <= 0 or run[stat_key] >= max_value: return false
	run[key] -= 1
	run[stat_key] = minf(max_value, run[stat_key]+max_value*0.65)
	changed.emit()
	return true

func mark_checkpoint() -> void:
	checkpoint = run.duplicate(true)

func die() -> void:
	var deaths: int = int(run.deaths)+1
	if run.hardcore:
		run.dead = true
	elif not checkpoint.is_empty():
		run = checkpoint.duplicate(true)
		run.deaths = deaths
		run.hp = stats().max_hp
		run.mp = stats().max_mana
	else:
		run.floor = 0
		run.hp = stats().max_hp
	save_game()

func win() -> void:
	run.victory = true
	unlocked = maxi(unlocked, mini(4, int(run.difficulty)+1))
	save_options()
	save_game()

func next_difficulty() -> void:
	run.difficulty = mini(4,int(run.difficulty)+1)
	run.hardcore = run.hardcore or int(run.difficulty) == 4
	run.floors = {}
	run.floor = 0
	run.deepest = 1
	run.return_floor = 1
	run.return_position = []
	run.victory = false
	run.seed += 104729
	run.shop = []
	run.hp = stats().max_hp
	run.mp = stats().max_mana
	mark_checkpoint()
	save_game()

func save_game() -> bool:
	return SaveStore.write_save(save_path, {"run":run,"checkpoint":checkpoint})

func load_game() -> bool:
	var payload: Dictionary = SaveStore.read_save(save_path)
	if not valid_payload(payload):
		payload = SaveStore.read_save(save_path+".bak")
	if not valid_payload(payload):
		message.emit("Sauvegarde invalide ou incompatible. Nouvelle partie disponible.")
		return false
	run = payload.run
	checkpoint = payload.get("checkpoint",{} )
	if not SaveStore.last_error.is_empty(): message.emit(SaveStore.last_error)
	return true

func valid_payload(payload: Dictionary) -> bool:
	if not payload.get("run") is Dictionary: return false
	var r: Dictionary = payload.run
	for key: String in ["seed","skills","floor","floors","inventory","equipped","hp","mp","pending","offers","secondary","shop","difficulty","level","gold","fusion","serial","dead","victory"]:
		if not r.has(key): return false
	for key: String in ["skills","floors","equipped","fusion"]:
		if not r[key] is Dictionary: return false
	for key: String in ["inventory","pending","offers","secondary","shop"]:
		if not r[key] is Array: return false
	for key: String in ["seed","floor","hp","mp","difficulty","level","gold","serial"]:
		if not (r[key] is float or r[key] is int) or not is_finite(float(r[key])): return false
	if int(r.floor) not in range(14) or int(r.difficulty) not in range(5) or int(r.level)<1: return false
	for id: String in r.skills:
		if not Catalog.defs.has(id) or not (r.skills[id] is float or r.skills[id] is int): return false
	for item: Variant in r.inventory+r.shop:
		if not item is Dictionary: return false
		for key: String in ["uid","name","slot","bonuses","price","rarity"]:
			if not item.has(key): return false
		if not item.bonuses is Dictionary: return false
		for bonus: Variant in item.bonuses.values():
			if not (bonus is float or bonus is int) or not is_finite(float(bonus)): return false
	for floor_value: Variant in r.floors.values():
		if not floor_value is Dictionary or not floor_value.get("grid") is Array: return false
		if floor_value.grid.size()!=Dungeon.HEIGHT: return false
		for row: Variant in floor_value.grid:
			if not row is String or row.length()!=Dungeon.WIDTH: return false
	return true

func save_options() -> void:
	SaveStore.write_save("user://qa_options.json" if qa else "user://options.json", {"options":options,"unlocked":unlocked})
	apply_options()

func apply_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, options.volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func learned_rank(id: String, snapshot: Dictionary = {}) -> int:
	return int((snapshot if not snapshot.is_empty() else run.get("skills", {})).get(id, 0))

func equipment_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for uid: String in run.get("equipped", {}).values():
		var item: Dictionary = find_item(uid)
		for key: String in item.get("bonuses", {}):
			result[key] = float(result.get(key,0.0))+float(item.bonuses[key])
	return result

func effective_rank(id: String, learned: int, bonuses: Dictionary) -> int:
	var specific: int = int(bonuses.get("skill:"+id,0))
	# All-skills improves acquired skills, without learning the entire grimoire.
	var extra: int = specific+(int(bonuses.get("all_skills",0)) if learned+specific>0 else 0)
	if extra<=0: return learned
	var definition: ContentDefinition = Catalog.definition(id)
	if not definition: return learned
	var cap: int = 11 if id=="shield" else definition.max_rank+7
	if id in ["meditation","reach"]: return learned
	return maxi(learned,mini(cap,learned+extra))

func secondary_skills() -> Array:
	var result: Array = run.get("secondary",[]).duplicate()
	for id: String in Catalog.ids("secondary"):
		if result.size()>=(3 if run.get("level",1)>=20 else 2): break
		if id not in result and rank(id)>0: result.append(id)
	return result

func refresh_equipment() -> void:
	var active: String = run.get("active","")
	if active.is_empty() or (active in Catalog.ids("primary") and rank(active)==0):
		run.active = ""
		for id: String in Catalog.ids("primary"):
			if rank(id)>0:
				run.active=id
				break
	clamp_vitals()
	changed.emit()

func add_gold(amount: int) -> void:
	run.gold += int(round(amount*(1.0+stats().gold_bonus)))

func make_equipment(template: Dictionary, rng: RandomNumberGenerator, tier: int = 1) -> Dictionary:
	var bonus: Dictionary = Equipment.roll(template,rng)
	run.serial += 1
	return {"uid":"item_%d_%d"%[run.seed,run.serial],"template":template.id,"name":Equipment.item_name(template.slot,bonus),"slot":template.slot,"rarity":template.rarity,"bonuses":bonus,"price":35+maxi(0,tier)*12+int(template.rarity)*42}
