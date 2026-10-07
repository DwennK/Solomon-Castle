class_name SkillDetails
extends RefCounted

# Figures describe one enemy before its resistance, with uninterrupted hits and mana.
# Conditional damage is kept separate instead of assuming a crowd or perfect overlap.
static func attack(id: String, next_rank: bool = false, source: Node = null) -> Dictionary:
	if source == null: source = State
	var d: ContentDefinition = Catalog.definition(id)
	var combat: CombatSystem = CombatSystem.new()
	combat.stats_source = source
	var rank_value: int = maxi(1,source.effective_rank(id,source.learned_rank(id)+1,source.equipment_bonuses()) if next_rank else source.rank(id))
	var result: Dictionary = {"damage":0.0,"dps":0.0,"cost":0.0,"range":0.0,"cooldown":0.0,"unit":"/impact","extra":[],"effect":"","range_label":"Range","dps_label":"DPS / enemy"}
	if d.kind=="secondary":
		var p: Dictionary = combat.secondary_profile(id,rank_value)
		result.damage=p.damage;result.cost=source.mana_cost(p.mana,p.offensive)
		result.cooldown=p.cooldown;result.range=p.radius;result.range_label="Radius"
		result.dps=p.damage/p.cooldown
		result.dps_label="Average DPS / enemy"
		match id:
			"teleport": result.effect="Last safe position · 1 s invulnerability";result.range_label="Destination"
			"shield": result.effect="Absorbs %.0f damage" % p.power;result.range_label="Target"
			"circle": result.effect="18 s · +6 health/s and +18 mana/s · slows enemies and shots"
			"freeze": result.effect="Freeze %.1f s (bosses: max. 0.35 s)" % p.duration
			"ring_fire": result.effect="Instant wave with knockback"
			"acid":
				result.unit="/full zone duration"
				result.extra.append("Active DPS / enemy: %.1f for %.0f s" % [p.power,p.duration])
				result.effect="Centered 100 u ahead · deals damage while the target stays in the zone"
			"undead": result.effect="Undead: flee for %.1f s and take +35 %% damage" % p.duration
		return result
	var preview: int = rank_value if d.kind=="primary" else -1
	var p: Dictionary = combat.profile(id,preview,next_rank)
	result.cost=source.mana_cost(p.mana)
	result.cooldown=0.0 if p.channel else p.cooldown
	result.damage=p.damage
	result.dps=p.damage if p.channel else p.damage/p.cooldown
	if p.channel:
		result.unit="/s";result.range=combat.channel_range(p)
		if id in ["lightning","flame_lash"]:
			result.effect="Up to %d targets · 180 u bounces · same DPS per target" % (1+source.rank("chain",p.snapshot)+(1 if id=="flame_lash" else 0))
		else: result.effect="Pierces enemies in the stream · same DPS per target"
		if "ice" in p.elements:
			result.effect += " · slows"
		if id=="blizzard": result.effect += " and freezes"
		if id=="flame_lash":
			result.extra.append("Burn: +%.1f DPS / enemy, lasting 1 s after contact (does not stack)" % CombatSystem.BURN_DPS)
		if "lightning" in p.elements and source.rank("stun",p.snapshot)>0:
			result.extra.append("Interrupt: %.2f s (bosses: max. 0.35 s)" % (0.05+source.rank("stun",p.snapshot)*0.08))
	else:
		result.range=CombatSystem.PROJECTILE_SPEED*(1+CombatSystem.missile_speed_bonus(source.rank("potent",p.snapshot)) if "missile" in p.elements else 1.0)*CombatSystem.PROJECTILE_LIFETIME
		result.effect="One projectile hits one target per volley"
		var splash: float = combat.splash_ratio(p)
		if splash>0:
			result.damage *= 1+splash
			result.dps *= 1+splash
			result.extra.append("Area: %.1f DPS / other enemy (1 explosion / projectile) · radius %.0f u" % [p.damage*splash/p.cooldown,combat.splash_radius(p)])
			result.effect="Direct target: impact + explosion, one impact per volley"
		if p.multi>1:
			result.extra.append("%d projectiles: up to %.1f DPS on one target if the entire volley hits" % [p.multi,result.dps*p.multi])
		if id=="ball_lightning":
			result.range=CombatSystem.ORB_SPEED*CombatSystem.ORB_LIFETIME
			result.extra.append("Pulses: +%.1f DPS per orb on the nearest enemy within %.0f u" % [p.damage*CombatSystem.ORB_PULSE_RATIO/CombatSystem.ORB_PULSE_INTERVAL,CombatSystem.ORB_PULSE_RADIUS])
			result.effect="Homing orb · pulses every 0.25 s until impact (max. 3 s)"
		if id=="frost_missile": result.effect+=" · freeze 0.8 s direct / 0.5 s area (bosses: max. 0.35 s)"
		var embers: int = source.rank("embers",p.snapshot) if "fire" in p.elements else 0
		if embers>0:
			var shard: float = p.damage*0.25
			result.extra.append("%d embers / impact: %.1f damage each · +%.1f DPS if one ember hits per volley" % [embers*3,shard,shard/p.cooldown])
	if id in ["blizzard","ball_lightning"] and source.rank("chain",p.snapshot)>0:
		result.extra.append("Chains: up to %d additional targets, without repeated hits" % source.rank("chain",p.snapshot))
	if p.channel and "fire" in p.elements:
		if combat.splash_ratio(p)>0: result.extra.append("On kill: %.1f damage explosion, radius %.0f u" % [p.damage*combat.splash_ratio(p),combat.splash_radius(p)])
		if source.rank("embers",p.snapshot)>0: result.extra.append("On kill: %d embers dealing %.1f damage" % [source.rank("embers",p.snapshot)*3,p.damage*0.25])
	if d.kind=="primary":
		var major: String = {"missile":"ether_charge","fire":"immolation","lightning":"hurricane","ice":"harden"}[id]
		if source.rank(major)>0: result.extra.append(passive_effect(major,source.rank(major),source))
	return result

static func rows(id: String, next_rank: bool = false) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	if d.kind=="passive":
		var rank_value: int = State.effective_rank(id,State.learned_rank(id)+1,State.equipment_bonuses()) if next_rank else State.rank(id)
		return {"Effect":passive_effect(id,rank_value)}
	var a: Dictionary = attack(id,next_rank)
	var channel: bool = a.unit=="/s"
	var r: Dictionary = {}
	r["Damage / enemy"] = "%.1f %s" % [a.damage,a.unit] if a.damage>0 else "None (utility)"
	r[a.dps_label] = "%.1f" % a.dps if a.damage>0 else "— (no damage)"
	r["Mana"] = "%.1f %s" % [a.cost,"/s" if channel else "/cast"]
	r[a.range_label] = "%.0f u" % a.range if a.range>0 else ("Last safe position" if id=="teleport" else "Yourself")
	r["Cooldown"] = "None (continuous)" if channel else "%.2f s" % a.cooldown
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
		lines.append("Current → New fusion" if d.kind=="fusion" else "Rank %d → %d" % [State.learned_rank(id),State.learned_rank(id)+1])
	elif not known: lines.append("When learned")
	elif not can_advance: lines.append("Maximum rank")
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
		if d.kind=="fusion": lines.append("Snapshot ranks; learning again updates the fusion.")
	return "\n".join(lines)

static func passive_effect(id: String, rank_value: int, source: Node = null) -> String:
	if source == null: source = State
	match id:
		"life": return "+%d max. health" % (24*rank_value)
		"mana": return "+%d max. mana" % (28*rank_value)
		"regen": return "+%.1f mana/s" % (2.5*rank_value)
		"power": return "+%d %% damage" % (14*rank_value)
		"haste": return "+%d %% projectile cast speed" % (10*rank_value)
		"economy": return "−%d %% offensive spell cost (total capped at 80 %%)" % (9*rank_value)
		"rush": return "+%d %% speed" % (7*rank_value)
		"resist": return "−%d %% damage taken (total capped at 75 %%)" % (7*rank_value)
		"meditation": return "After 1 s idle: mana regeneration ×4 (does not stack)"
		"focus": return "Ritual cooldown ÷2 (does not stack with equipment)"
		"reach": return "260 u pickup radius (distance ×4; does not stack)"
		"creativity": return "Four distinct choices on future level-ups"
		"poison_resist": return "−%d %% poison damage; combines multiplicatively with items" % int([0,10,20,30,35,40,45,50,55,60][clampi(rank_value,0,9)])
		"immolation": return "Embers: explode after 0.6 s, radius 65 u, ember damage ×%.1f; +%d mana/shot. No explosion if intercepted." % [1+0.2*rank_value,10*rank_value]
		"ether_charge": return "While not firing: 1 charge/s, up to %d; next shot: 320 u wave, −10 %% max. health/charge (does not stack)" % rank_value
		"hurricane": return "While casting Lightning: %.1f storm DPS, radius 520 u, pushes enemies; +%d mana/s" % [float([0,10,15,18,21,24,25,26,27][clampi(rank_value,0,8)])*source.stats().damage,6*rank_value]
		"harden":
			var armor: Dictionary = CombatSystem.harden_profile(rank_value)
			return "While casting Ice Stream: +%d armor/s, up to %d; includes poison; +%d mana/s. Lost when casting stops." % [armor.regen,armor.cap,6*rank_value]
		"multishot": return "%d projectiles / volley; +%d mana before reduction" % [1+rank_value,2*rank_value]
		"chain": return "+%d targets for Lightning and its fusions; +%d mana" % [rank_value,2*rank_value]
		"explode": return "Explosion: radius %d u, %.0f %% of direct damage; +%d mana" % [60+18*rank_value,55+5*(rank_value-1),2*rank_value] if rank_value>0 else "No Fireball explosion"
		"embers": return "%d embers / impact, each dealing 25 %% of projectile damage" % (3*rank_value)
		"cone": return "+%d u range; +%.2f rad half-angle for Ice and Steam" % [18*rank_value,0.12*rank_value]
		"potent": return "+%.0f %% missile speed (except Orb); may retarget; +%d mana" % [100*CombatSystem.missile_speed_bonus(rank_value),rank_value]
		"chill": return "Ice: enemy speed ×%.3f; stronger knockback" % maxf(0.10,0.55-0.045*rank_value)
		"stun": return "Interrupt %.2f s (bosses: max. 0.35 s)" % (0.05+0.08*rank_value) if rank_value>0 else "No lightning interrupt"
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
