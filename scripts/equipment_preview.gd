class_name EquipmentPreview
extends RefCounted

# Use the real State / Combat / SkillDetails calculations on a detached Node.
# No live equipment changes, signals, vital clamps or save writes during preview.
static func capture(source: Node) -> Dictionary:
	var result: Dictionary = {"stats":source.stats(), "bonuses":source.equipment_bonuses(), "ranks":{}, "attacks":{}, "passives":{}, "secondary":source.secondary_skills(), "active":source.run.active, "features":active_features(source), "fusion":source.run.fusion.get("id", "")}
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

# Only the active spell's mechanics belong in the compact view. The combat profile
# supplies fusion snapshots, so equipment never invents a synergy for frozen ranks.
static func active_features(source: Node) -> Dictionary:
	var id: String = source.run.active
	if id.is_empty(): return {}
	var combat: CombatSystem = CombatSystem.new()
	combat.stats_source = source
	var p: Dictionary = combat.profile(id)
	var result: Dictionary = {}
	if "missile" in p.elements: result["Projectiles / salve"] = [float(p.multi), "rank"]
	if id in ["lightning", "flame_lash", "blizzard", "ball_lightning"]:
		result["Cibles des chaînes"] = [float(1+source.rank("chain",p.snapshot)+(1 if id=="flame_lash" else 0)), "rank"]
	if "fire" in p.elements:
		result["Rayon de l’explosion"] = [combat.splash_radius(p), "u"]
		result["Éclats par impact" if not p.channel else "Braises à la mort"] = [float(3*source.rank("embers",p.snapshot)), "rank"]
	if "lightning" in p.elements:
		var stun: int = source.rank("stun",p.snapshot)
		result["Interruption (hors boss)"] = [0.05+0.08*stun if stun>0 else 0.0, "s"]
	if "ice" in p.elements and p.channel:
		result["Ralentissement"] = [1.0-maxf(0.10,0.55-0.045*source.rank("chill",p.snapshot)), "%"]
	return result

static func compact_number(value: float, unit: String = "") -> String:
	if unit=="rank": return str(int(value))
	if unit=="%": return "%s %%" % String.num(value*100,1).trim_suffix(".0")
	return String.num(value,2).trim_suffix(".0")+( (" "+unit) if not unit.is_empty() else "")

static func compact_metric(output: Array, title: String, before: float, after: float, unit: String = "", lower_better: bool = false, relative: bool = false) -> void:
	if is_equal_approx(before,after): return
	var delta: float = after-before
	var value: String = compact_number(absf(delta),unit)
	if unit=="%": value=String.num(absf(delta)*100,1).trim_suffix(".0")+" pts"
	if relative and before>0: value=String.num(absf(delta/before)*100,1).trim_suffix(".0")+" %"
	# Avoid showing a rounded zero as a meaningful change.
	if absf(delta)<0.01 and unit!="%" and not relative: value="< 0,01"+(" "+unit if not unit.is_empty() else "")
	output.append({"title":title,"text":("+" if delta>0 else "−")+value,"gain":delta<0 if lower_better else delta>0,
		"tooltip":"%s : %s → %s" % [title,compact_number(before,unit),compact_number(after,unit)]})

static func compact(comparison: Dictionary) -> Dictionary:
	var before: Dictionary = comparison.before
	var after: Dictionary = comparison.after
	var metrics: Array = []
	var effects: Array = []
	var active: String = before.active
	if not active.is_empty() and active==after.active and before.attacks.has(active) and after.attacks.has(active):
		var a: Dictionary = before.attacks[active]
		var b: Dictionary = after.attacks[active]
		compact_metric(metrics,"Dégâts / seconde",a.dps,b.dps,"/s",false,true)
		compact_metric(metrics,"Coût du sort",a.cost,b.cost,"mana/s" if b.unit=="/s" else "mana/tir",true)
		compact_metric(metrics,b.range_label,a.range,b.range,"u")
		for title: String in after.features:
			var old: Array = before.features.get(title,[0.0,after.features[title][1]])
			var next: Array = after.features[title]
			compact_metric(effects,title,old[0],next[0],next[1])
		# Major specializations have conditional effects, not unconditional DPS.
		if Catalog.definition(active).kind=="primary":
			var major: String = {"missile":"ether_charge","fire":"immolation","lightning":"hurricane","ice":"harden"}[active]
			if before.passives.get(major,"")!=after.passives.get(major,""):
				var explanation: String = SkillDetails.compare_values(before.passives.get(major,"Inactif"),after.passives.get(major,"Inactif"))
				effects.append({"title":Catalog.title(major),"text":explanation.split(" ; ")[0] if after.ranks[major]>0 else "Pouvoir perdu",
					"gain":after.ranks[major]>before.ranks[major],"neutral":after.ranks[major]==before.ranks[major],"tooltip":SkillDetails.compare_values(before.passives.get(major,"Inactif"),after.passives.get(major,"Inactif"))})
	for field: Array in [
		["mana_regen","Régénération de mana","mana/s"], ["max_hp","Vie maximale",""],
		["resistance","Protection","%"], ["max_mana","Réserve de mana",""],
		["hp_regen","Régénération de vie","vie/s"], ["poison_resistance","Protection poison","%"],
		["speed","Déplacement","u/s"], ["gold_bonus","Or trouvé","%"], ["xp_bonus","Expérience","%"],
	]: compact_metric(metrics,field[1],before.stats[field[0]],after.stats[field[0]],field[2])
	# Four priority gains at most; negative changes are never silently omitted.
	var visible: Array = []
	for metric: Dictionary in metrics:
		if visible.size()<4 or not metric.gain: visible.append(metric)
	for id: String in ["meditation","focus","reach","creativity"]:
		var old: int = before.ranks[id]
		var next: int = after.ranks[id]
		if old!=next:
			var explanations: Dictionary = {"meditation":"Mana au repos ×4","focus":"Recharge des rituels ÷2","reach":"Ramassage à distance","creativity":"4 choix aux prochains niveaux"}
			effects.append({"title":Catalog.title(id),"text":explanations[id] if next>0 else "Pouvoir perdu","gain":next>old,
				"tooltip":after.passives.get(id,before.passives.get(id,""))})
		else:
			var key: String = "grant:"+("mental_focus" if id=="focus" else id)
			if before.bonuses.get(key,0)!=after.bonuses.get(key,0) and next>0:
				effects.append({"title":Catalog.title(id),"text":"Déjà actif · aucun cumul","neutral":true})
	var ids: Array = before.attacks.keys()
	for id: String in after.attacks:
		if id not in ids: ids.append(id)
	for id: String in ids:
		if not before.attacks.has(id) or not after.attacks.has(id):
			var gained: bool = after.attacks.has(id)
			effects.append({"title":Catalog.title(id),"text":"Sort disponible" if gained else "Sort perdu","gain":gained})
		elif id in after.secondary:
			var a: Dictionary = before.attacks[id]
			var b: Dictionary = after.attacks[id]
			if a.effect!=b.effect:
				effects.append({"title":Catalog.title(id),"text":SkillDetails.compare_values(a.effect,b.effect),"gain":after.ranks[id]>before.ranks[id]})
			if before.ranks.focus==after.ranks.focus:
				compact_metric(effects,Catalog.title(id)+" · recharge",a.cooldown,b.cooldown,"s",true)
			compact_metric(effects,Catalog.title(id)+" · dégâts",a.damage,b.damage,"",false,true)
			if b.cost>a.cost: compact_metric(effects,Catalog.title(id)+" · coût",a.cost,b.cost,"mana",true)
	if before.active!=after.active:
		effects.push_front({"title":"Magie active","text":Catalog.title(after.active) if not after.active.is_empty() else "Aucune magie disponible","gain":before.active.is_empty() and not after.active.is_empty()})
	var caps: Array[String] = []
	for row: Dictionary in comparison.rows:
		if row.text.contains("plafond atteint"): caps.append(row.title)
		if row.text.contains("Rituel indisponible"):
			effects.append({"title":row.title,"text":"Emplacements de rituels occupés","neutral":true})
	if not caps.is_empty(): effects.append({"title":"Bonus plafonnés","text":"%d sans gain supplémentaire" % caps.size(),"neutral":true,"tooltip":"\n".join(caps)})
	# Explain a frozen fusion only when relevant elemental equipment ranks change.
	if not after.fusion.is_empty() and after.active==after.fusion:
		var elements: Array = Catalog.definition(after.fusion).values.elements
		var relevant: Array = elements.duplicate()
		for element: String in elements:
			relevant.append_array({"fire":["explode","embers"],"missile":["multishot","potent"],"lightning":["chain","stun"],"ice":["cone","chill"]}[element])
		for id: String in relevant:
			if before.ranks[id]!=after.ranks[id]:
				effects.append({"title":"Fusion actuelle","text":"Rangs figés · ces bonus de rang ne la modifient pas","neutral":true})
				break
	return {"metrics":visible,"effects":effects,"active":after.active,"extra_metrics":metrics.size()-visible.size()}
