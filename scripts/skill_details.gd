class_name SkillDetails
extends RefCounted

# Figures describe one enemy before its resistance, with uninterrupted hits and mana.
# Conditional damage is kept separate instead of assuming a crowd or perfect overlap.
static func attack(id: String, next_rank: bool = false) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var combat: CombatSystem = CombatSystem.new()
	var rank_value: int = maxi(1,State.effective_rank(id,State.learned_rank(id)+1,State.equipment_bonuses()) if next_rank else State.rank(id))
	var result: Dictionary = {"damage":0.0,"dps":0.0,"cost":0.0,"range":0.0,"cooldown":0.0,"unit":"/impact","extra":[],"effect":"","range_label":"Portée","dps_label":"DPS / ennemi"}
	if d.kind=="secondary":
		var p: Dictionary = combat.secondary_profile(id,rank_value)
		result.damage=p.damage;result.cost=p.mana*(1-State.stats().cost_reduction)
		result.cooldown=p.cooldown;result.range=p.radius;result.range_label="Rayon"
		result.dps=p.damage/p.cooldown
		result.dps_label="DPS moyen / ennemi"
		match id:
			"teleport": result.effect="Dernière position sûre · invulnérabilité 1 s";result.range_label="Destination"
			"shield": result.effect="Absorbe %.0f dégâts" % p.power;result.range_label="Cible"
			"circle": result.effect="18 s · +6 vie/s et +18 mana/s · ralentit ennemis et tirs"
			"freeze": result.effect="Gel %.1f s (boss : 0,35 s max.)" % p.duration
			"ring_fire": result.effect="Onde instantanée avec recul"
			"acid":
				result.unit="/zone complète"
				result.extra.append("DPS actif / ennemi : %.1f pendant %.0f s" % [p.power,p.duration])
				result.effect="Centre à 100 u devant vous · dégâts tant que la cible reste dans la zone"
			"undead": result.effect="Morts-vivants : fuite %.1f s et +35 %% dégâts reçus" % p.duration
		return result
	var preview: int = rank_value if d.kind=="primary" else -1
	var p: Dictionary = combat.profile(id,preview,next_rank)
	result.cost=p.mana*(1-State.stats().cost_reduction)
	result.cooldown=0.0 if p.channel else p.cooldown
	result.damage=p.damage
	result.dps=p.damage if p.channel else p.damage/p.cooldown
	if p.channel:
		result.unit="/s";result.range=combat.channel_range(p)
		if id in ["lightning","flame_lash"]:
			result.effect="Jusqu’à %d cibles · rebonds de 180 u · DPS identique par cible" % (1+State.rank("chain",p.snapshot)+(1 if id=="flame_lash" else 0))
		else: result.effect="Traverse les ennemis du jet · DPS identique par cible"
		if "ice" in p.elements:
			result.effect += " · ralentit"
		if id=="blizzard": result.effect += " et fige"
		if id=="flame_lash":
			result.extra.append("Brûlure : +%.1f DPS / ennemi, puis 1 s après contact (non cumulable)" % CombatSystem.BURN_DPS)
		if "lightning" in p.elements and State.rank("stun",p.snapshot)>0:
			result.extra.append("Interruption : %.2f s (boss : 0,35 s max.)" % (0.05+State.rank("stun",p.snapshot)*0.08))
	else:
		result.range=CombatSystem.PROJECTILE_SPEED*(1+State.rank("potent",p.snapshot)*0.2)*CombatSystem.PROJECTILE_LIFETIME
		result.effect="Un projectile touche une cible par salve"
		var splash: float = combat.splash_ratio(p)
		if splash>0:
			result.damage *= 1+splash
			result.dps *= 1+splash
			result.extra.append("Zone : %.1f DPS / autre ennemi (1 explosion / salve) · rayon %.0f u" % [p.damage*splash/p.cooldown,combat.splash_radius(p)])
			result.effect="Cible directe : impact + explosion, un impact par salve"
		if p.multi>1:
			result.extra.append("%d projectiles : jusqu’à %.1f DPS sur une cible si toute la salve la touche" % [p.multi,result.dps*p.multi])
		if id=="ball_lightning":
			result.range=CombatSystem.ORB_SPEED*CombatSystem.ORB_LIFETIME
			result.extra.append("Pulsations : +%.1f DPS par orbe sur l’ennemi le plus proche à %.0f u" % [p.damage*CombatSystem.ORB_PULSE_RATIO/CombatSystem.ORB_PULSE_INTERVAL,CombatSystem.ORB_PULSE_RADIUS])
			result.effect="Orbe guidée · pulsations toutes les 0,25 s, jusqu’à l’impact (3 s max.)"
		if id=="frost_missile": result.effect+=" · gel 0,8 s direct / 0,5 s zone (boss : 0,35 s max.)"
		var embers: int = State.rank("embers",p.snapshot) if "fire" in p.elements else 0
		if embers>0:
			var shard: float = p.damage*0.25*(1.55 if id=="fire_missile" else 1.0)
			result.extra.append("%d éclats / impact : %.1f dégâts chacun · +%.1f DPS si un éclat touche à chaque salve" % [embers*3,shard,shard/p.cooldown])
	return result

static func rows(id: String, next_rank: bool = false) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	if d.kind=="passive":
		var rank_value: int = State.effective_rank(id,State.learned_rank(id)+1,State.equipment_bonuses()) if next_rank else State.rank(id)
		return {"Effet":passive_effect(id,rank_value)}
	var a: Dictionary = attack(id,next_rank)
	var channel: bool = a.unit=="/s"
	var r: Dictionary = {}
	r["Dégâts / ennemi"] = "%.1f %s" % [a.damage,a.unit] if a.damage>0 else "Aucun (utilitaire)"
	r[a.dps_label] = "%.1f" % a.dps if a.damage>0 else "— (aucun dégât)"
	r["Mana"] = "%.1f %s" % [a.cost,"/s" if channel else "/lancement"]
	r[a.range_label] = "%.0f u" % a.range if a.range>0 else ("Dernière position sûre" if id=="teleport" else "Vous-même")
	r["Recharge"] = "Aucune (continu)" if channel else "%.2f s" % a.cooldown
	return r

static func text(id: String, compare: bool = true, acquiring: bool = false) -> String:
	var d: ContentDefinition = Catalog.definition(id)
	if d==null: return ""
	var known: bool = State.rank(id)>0 if d.kind!="fusion" else State.run.fusion.get("id","")==id
	var can_advance: bool = d.kind=="fusion" or State.learned_rank(id)<d.max_rank
	var show_next: bool = compare and can_advance and known
	var current: Dictionary = rows(id,acquiring or not known)
	var next: Dictionary = rows(id,true) if show_next else {}
	var lines: Array[String] = []
	if show_next:
		lines.append("Actuel → Nouvelle fusion" if d.kind=="fusion" else "Rang %d → %d" % [State.learned_rank(id),State.learned_rank(id)+1])
	elif not known: lines.append("À l’apprentissage")
	elif not can_advance: lines.append("Rang maximal")
	for key: String in current:
		var value: String = str(current[key])
		if show_next and value!=str(next.get(key,value)): value = compare_values(value,str(next[key]))
		lines.append(key+" : "+value)
	if d.kind!="passive":
		var a: Dictionary = attack(id,acquiring or not known)
		var future: Dictionary = attack(id,true) if show_next else a
		for i: int in range(a.extra.size()):
			var extra: String = a.extra[i]
			lines.append(compare_values(extra,str(future.extra[i])) if show_next and i<future.extra.size() else extra)
		lines.append(compare_values(a.effect,future.effect) if show_next else a.effect)
		if d.kind=="fusion": lines.append("Rangs figés ; réapprendre actualise la fusion.")
	return "\n".join(lines)

static func passive_effect(id: String, rank_value: int) -> String:
	match id:
		"life": return "+%d vie max." % (24*rank_value)
		"mana": return "+%d mana max." % (28*rank_value)
		"regen": return "+%.1f mana/s" % (2.5*rank_value)
		"power": return "+%d %% dégâts" % (14*rank_value)
		"haste": return "+%d %% cadence des projectiles" % (12*rank_value)
		"economy": return "−%d %% coût (réduction totale plafonnée à 80 %%)" % (9*rank_value)
		"rush": return "+%d %% vitesse" % (7*rank_value)
		"resist": return "−%d %% dégâts subis (total plafonné à 75 %%)" % (7*rank_value)
		"meditation": return "Après 1 s immobile sans tirer : +%.1f mana/s, +%.1f vie/s" % [3.0*rank_value,0.8*rank_value]
		"focus": return "−%d %% recharge des rituels" % (10*rank_value)
		"reach": return "%d u de ramassage" % (65+45*rank_value)
		"multishot": return "%d projectiles / salve ; +%d mana avant réduction" % [1+rank_value,2*rank_value]
		"chain": return "+%d cibles pour Éclair et Fouet de flammes" % rank_value
		"explode": return "Explosion : rayon %d u, 55 %% des dégâts directs" % (60+18*rank_value) if rank_value>0 else "Pas d’explosion de Boule de feu"
		"embers": return "%d éclats / impact, chacun à 25 %% des dégâts du projectile" % (3*rank_value)
		"cone": return "+%d u de portée ; +%.2f rad de demi-angle pour Glace et Vapeur" % [18*rank_value,0.12*rank_value]
		"potent": return "+%d %% vitesse des projectiles (hors Orbe électrique)" % (20*rank_value)
		"chill": return "Glace : vitesse ennemie ×%.3f ; recul renforcé" % (0.55-0.045*rank_value)
		"stun": return "Interruption %.2f s (boss : 0,35 s max.)" % (0.05+0.08*rank_value) if rank_value>0 else "Pas d’interruption électrique"
	return Catalog.definition(id).description

static func compare_values(current: String, future: String) -> String:
	if current==future: return current
	# Compact numeric comparisons keep their units/context once, without losing effects.
	var pattern: RegEx = RegEx.new()
	pattern.compile("[0-9]+(?:\\.[0-9]+)?")
	var old_numbers: Array[RegExMatch] = pattern.search_all(current)
	var new_numbers: Array[RegExMatch] = pattern.search_all(future)
	if old_numbers.size()==new_numbers.size() and pattern.sub(current,"#",true)==pattern.sub(future,"#",true):
		var result: String = current
		for i: int in range(old_numbers.size()-1,-1,-1):
			var old: RegExMatch=old_numbers[i]
			var next: RegExMatch=new_numbers[i]
			if old.get_string()!=next.get_string(): result=result.substr(0,old.get_start())+old.get_string()+" → "+next.get_string()+result.substr(old.get_end())
		return result
	return current+" → "+future
