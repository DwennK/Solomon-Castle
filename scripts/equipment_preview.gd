class_name EquipmentPreview
extends RefCounted

# Use the real State / Combat / SkillDetails calculations on a detached Node.
# No live equipment changes, signals, vital clamps or save writes during preview.
static func capture(source: Node) -> Dictionary:
	var result: Dictionary = {"stats":source.stats(), "bonuses":source.equipment_bonuses(), "ranks":{}, "attacks":{}, "passives":{}, "secondary":source.secondary_skills(), "active":source.run.active}
	for kind: String in ["primary", "secondary", "passive"]:
		for id: String in Catalog.ids(kind):
			result.ranks[id] = source.rank(id)
			if source.rank(id) == 0: continue
			if kind == "passive":
				result.passives[id] = SkillDetails.passive_effect(id,source.rank(id),source)
			elif kind == "primary" or id in result.secondary:
				result.attacks[id] = SkillDetails.attack(id,false,source)
	var fusion: String = source.run.fusion.get("id", "")
	if not fusion.is_empty(): result.attacks[fusion] = SkillDetails.attack(fusion,false,source)
	return result

static func compare(uid: String, slot: String, remove: bool = false) -> Dictionary:
	var source: Node = State.get_script().new()
	# Only equip/unequip's writable fields are copied. Inventory and skill data are read-only.
	source.run = State.run.duplicate()
	source.run.equipped = State.run.equipped.duplicate()
	var before: Dictionary = capture(source)
	var valid: bool = source.run.equipped.has(slot)
	if valid:
		if remove: source.unequip(slot)
		else: valid = source.equip(uid,slot)
	var after: Dictionary = capture(source)
	source.free()
	return {"before":before, "after":after, "valid":valid, "rows":rows(before,after)}

static func number(value: float, unit: String) -> String:
	match unit:
		"%": return "%.0f %%" % (value*100)
		"x": return "×%.2f" % value
		"/s": return "%.2f/s" % value
		"s": return "%.2f s" % value
		"rank": return str(int(value))
	return "%.1f" % value

static func add_numeric(result: Array, title: String, before: float, after: float, unit: String = "", lower_better: bool = false) -> void:
	if is_equal_approx(before,after): return
	var gain: bool = after < before if lower_better else after > before
	var delta: float = after-before
	var delta_text: String = number(absf(delta),unit)
	if unit == "x": delta_text = "%.2f" % absf(delta)
	if unit == "%": delta_text = "%.0f pts" % (absf(delta)*100)
	result.append({"title":title,"text":"%s → %s  (%s%s)" % [number(before,unit),number(after,unit),"+" if delta>0 else "−",delta_text],"gain":gain,"numeric":true})

static func rows(before: Dictionary, after: Dictionary) -> Array:
	var result: Array = []
	for field: Array in [
		["max_hp","Vie maximale",""], ["max_mana","Mana maximal",""],
		["mana_regen","Régénération de mana","/s"], ["hp_regen","Régénération de vie","/s"],
		["flat_damage","Dégâts fixes",""], ["damage","Multiplicateur de dégâts","x"],
		["cast_speed","Cadence des projectiles","x"], ["cost_reduction","Réduction du coût offensif (max. 80 %)","%"],
		["resistance","Résistance aux dégâts (max. 75 %)","%"], ["poison_resistance","Résistance au poison (max. 100 %)","%"],
		["speed","Vitesse de déplacement",""], ["gold_bonus","Bonus d’or trouvé","%"], ["xp_bonus","Bonus d’expérience","%"],
		["pickup_radius","Rayon de ramassage",""],
	]: add_numeric(result,field[1],before.stats[field[0]],after.stats[field[0]],field[2])
	for field: Array in [["cost_reduction","economy",0.8,"Réduction du coût offensif"],["resistance","resist",0.75,"Résistance aux dégâts"],["poison_resistance","poison_resist",1.0,"Résistance au poison"]]:
		var affected: bool = before.ranks[field[1]]!=after.ranks[field[1]] or before.bonuses.get(field[0],0)!=after.bonuses.get(field[0],0)
		if affected and is_equal_approx(before.stats[field[0]],field[2]) and is_equal_approx(after.stats[field[0]],field[2]):
			result.append({"title":field[3],"text":"%s → %s · plafond atteint, aucun gain supplémentaire" % [number(field[2],"%"),number(field[2],"%")],"neutral":true})
	if before.stats.meditation or after.stats.meditation: add_numeric(result,"Mana au repos (Méditation)",before.stats.mana_regen*(4 if before.stats.meditation else 1),after.stats.mana_regen*(4 if after.stats.meditation else 1),"/s")
	for id: String in before.ranks:
		add_numeric(result,Catalog.title(id)+" · rang effectif",before.ranks[id],after.ranks[id],"rank")
		var d: ContentDefinition = Catalog.definition(id)
		var raw_changed: bool = before.bonuses.get("skill:"+id,0)!=after.bonuses.get("skill:"+id,0) or before.bonuses.get("all_skills",0)!=after.bonuses.get("all_skills",0)
		var cap: int = int(d.values.get("equipment_cap",25 if d.kind=="primary" else d.max_rank+5))
		if raw_changed and before.ranks[id]==after.ranks[id] and after.ranks[id]>=cap:
			result.append({"title":Catalog.title(id)+" · rang effectif","text":"%d → %d · plafond atteint" % [before.ranks[id],after.ranks[id]],"neutral":true})
		if d.kind=="secondary" and after.ranks[id]>0 and id not in after.secondary and before.ranks[id]!=after.ranks[id]:
			result.append({"title":Catalog.title(id),"text":"Rituel indisponible : tous les emplacements sont occupés.","neutral":true})
	var ids: Array = before.attacks.keys()
	for id: String in after.attacks:
		if id not in ids: ids.append(id)
	for id: String in ids:
		var title: String = Catalog.title(id)
		if not before.attacks.has(id) or not after.attacks.has(id):
			var gained: bool = after.attacks.has(id)
			result.append({"title":title,"text":"Indisponible → Disponible" if gained else "Disponible → Indisponible","gain":gained})
			continue
		var a: Dictionary = before.attacks[id]
		var b: Dictionary = after.attacks[id]
		for field: Array in [["damage","Dégâts "+b.unit,"",false],["dps",b.dps_label,"",false],["cost","Mana"+(" /s" if b.unit=="/s" else " /lancement"),"",true],["cooldown","Recharge","s",true],["range",b.range_label,"",false]]:
			add_numeric(result,title+" · "+field[1],a[field[0]],b[field[0]],field[2],field[3])
		if a.effect != b.effect:
			result.append({"title":title+" · effet","text":SkillDetails.compare_values(a.effect,b.effect),"neutral":true})
		if a.extra != b.extra:
			result.append({"title":title+" · effets complémentaires","text":"Avant : "+(" ; ".join(a.extra) if not a.extra.is_empty() else "aucun")+"\nAprès : "+(" ; ".join(b.extra) if not b.extra.is_empty() else "aucun"),"neutral":true})
	for id: String in after.passives:
		# Derived stat rows already express these effects after real gameplay caps.
		if id in ["life","mana","regen","power","haste","economy","rush","resist","poison_resist"]: continue
		if after.passives[id] != before.passives.get(id,""):
			result.append({"title":Catalog.title(id)+" · effet","text":SkillDetails.compare_values(before.passives.get(id,"Inactif"),after.passives[id]),"neutral":true})
	for id: String in before.passives:
		if not after.passives.has(id): result.append({"title":Catalog.title(id)+" · effet","text":before.passives[id]+" → Inactif","gain":false})
	if before.active != after.active:
		result.append({"title":"Sort actif","text":Catalog.title(before.active)+" → "+(Catalog.title(after.active) if not after.active.is_empty() else "aucun"),"neutral":true})
	return result
