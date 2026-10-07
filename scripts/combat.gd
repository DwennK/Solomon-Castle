class_name CombatSystem
extends RefCounted

var world: Node2D
# A detached State instance may supply read-only equipment previews.
var stats_source: Node = State
const COLORS: Dictionary = {"missile":Color("bba2f1"),"fire":Color("ffac62"),"lightning":Color("f7df94"),"ice":Color("8bdce9"),"fire_missile":Color("ffc486"),"flame_lash":Color("ffa568"),"steam":Color("d3e0df"),"ball_lightning":Color("ceb7ff"),"frost_missile":Color("a3e8fd"),"blizzard":Color("b9f5ff")}

func profile(id: String, preview_rank: int = -1, refresh_fusion: bool = false) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var snapshot: Dictionary = stats_source.run.fusion.get("snapshot",{}) if d.kind == "fusion" and stats_source.run.fusion.get("id","")==id and not refresh_fusion else {}
	var elements: Array = d.values.get("elements",[id])
	var level: float = 0.0
	for element: String in elements: level += maxf(1,stats_source.rank(element,snapshot))
	level /= elements.size()
	if preview_rank>=0 and d.kind=="primary": level=maxi(1,preview_rank)
	var channel: bool = id in ["lightning","ice","flame_lash","steam","blizzard"]
	var damage: float = {"missile":18.0,"fire":30.0,"lightning":44.0,"ice":32.0,"fire_missile":35.0,"flame_lash":65.0,"steam":52.0,"ball_lightning":28.0,"frost_missile":26.0,"blizzard":58.0}.get(id,18.0)
	if d.kind == "primary": damage = float(d.values.damage)
	damage += (level-1)*float({"missile":7,"fire":11,"lightning":15,"ice":11,"fire_missile":15,"flame_lash":22,"steam":18,"ball_lightning":12,"frost_missile":11,"blizzard":20}.get(id,7))
	var mana: float = {"missile":6.0,"fire":10.0,"lightning":17.0,"ice":14.0,"fire_missile":14.0,"flame_lash":26.0,"steam":25.0,"ball_lightning":16.0,"frost_missile":13.0,"blizzard":26.0}.get(id,6.0)
	if d.kind == "primary": mana = float(d.values.mana)
	mana *= 1.0+(level-1)*0.10
	var multi: int = 1+stats_source.rank("multishot",snapshot) if "missile" in elements else 1
	mana += (multi-1)*2.0
	for element: String in elements:
		for sub: String in {"missile":["potent"],"fire":["explode","embers"],"lightning":["chain","stun"],"ice":["cone","chill"]}[element]:
			mana += stats_source.rank(sub,snapshot)*(1.0 if sub=="potent" else 2.0)
	if d.kind=="primary":
		var major: String = {"missile":"ether_charge","fire":"immolation","lightning":"hurricane","ice":"harden"}[id]
		mana += stats_source.rank(major)*(0.0 if id=="missile" else (10.0 if id=="fire" else 6.0))
	return {"id":id,"damage":(damage+stats_source.stats().flat_damage)*stats_source.stats().damage,"mana":mana,"channel":channel,"cooldown":(0.55 if "fire" in elements else 0.38)/stats_source.stats().cast_speed,"multi":multi,"snapshot":snapshot,"elements":elements,"color":COLORS.get(id,Color.WHITE)}

const PROJECTILE_SPEED: float = 510.0
const PROJECTILE_LIFETIME: float = 2.1
const ORB_SPEED: float = 170.0
const ORB_LIFETIME: float = 3.0
const ORB_PULSE_INTERVAL: float = 0.25
const ORB_PULSE_RATIO: float = 0.35
const ORB_PULSE_RADIUS: float = 125.0
const BURN_DPS: float = 8.0

func channel_range(p: Dictionary) -> float:
	return 350.0+stats_source.rank("cone",p.snapshot)*18 if "ice" in p.elements else 470.0

func splash_ratio(p: Dictionary) -> float:
	if p.get("ember",false): return 0.0
	if "fire" in p.elements and stats_source.rank("explode",p.snapshot)>0:
		return 0.55+0.05*(stats_source.rank("explode",p.snapshot)-1)
	return 0.3 if p.id=="frost_missile" else 0.0

func splash_radius(p: Dictionary) -> float:
	if p.id=="frost_missile": return 75.0+stats_source.rank("cone",p.snapshot)*18.0
	return 60.0+stats_source.rank("explode",p.snapshot)*18 if splash_ratio(p)>0 else 0.0

func secondary_profile(id: String, preview_rank: int = -1) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var rank_value: int = maxi(1,stats_source.rank(id) if preview_rank<0 else preview_rank)
	var p: Dictionary = {"mana":float(d.values.mana),"cooldown":float(d.values.cooldown),"damage":0.0,"radius":0.0,"duration":0.0,"power":0.0,"rank":rank_value,"offensive":id in ["freeze","ring_fire","acid","undead"]}
	if stats_source.stats().mental_focus: p.cooldown *= 0.5
	# Utility and offensive rituals retain their local base costs; upgrades cost mana.
	if id not in ["teleport","shield"]: p.mana += (rank_value-1)*5.0
	match id:
		"teleport": p.duration=1.0
		"shield": p.power=45.0*rank_value
		"circle": p.radius=150.0+rank_value*25;p.duration=18.0
		"freeze": p.radius=260.0;p.damage=8.0*rank_value+stats_source.stats().flat_damage;p.duration=2.0+rank_value
		"ring_fire": p.radius=250.0;p.damage=(45.0*rank_value+stats_source.stats().flat_damage)*stats_source.stats().damage
		"acid": p.radius=180.0;p.duration=7.0;p.power=(14.0*rank_value+stats_source.stats().flat_damage)*stats_source.stats().damage;p.damage=p.power*p.duration
		"undead": p.radius=340.0;p.duration=4.0+rank_value
	return p

func spend_primary_mana(amount: float) -> bool:
	if State.pay_mana(amount): return true
	State.notify_limited("primary_mana","Not enough mana: wait for regeneration or use a potion (%s)." % Controls.caption("mp_potion"),3000)
	return false

func fire(player: MagePlayer, delta: float) -> void:
	var p: Dictionary = profile(State.run.active)
	if p.channel:
		if not spend_primary_mana(p.mana*delta): return
		channel(player,p,delta)
		if p.id=="ice" and State.rank("harden")>0:
			var armor: Dictionary = harden_profile(State.rank("harden"))
			player.ice_armor = minf(armor.cap,player.ice_armor+armor.regen*delta)
			player.harden_active = true
		if p.id=="lightning" and State.rank("hurricane")>0: hurricane(player,delta)
		Sound.sustain(p.id)
	else:
		if player.fire_timer>0: return
		if not spend_primary_mana(p.mana): return
		if p.id=="missile":
			if player.ether_charges>0: ether_pulse(player)
			player.ether_timer=0.0
		player.fire_timer = p.cooldown
		player.visual.attack = 1.0
		for i: int in range(p.multi):
			var angle: float = (float(i)-(p.multi-1)/2.0)*0.17
			world.spawn_projectile(player.position,player.aim.rotated(angle),p)
		Sound.play(p.id,player.global_position)

func channel(player: MagePlayer, p: Dictionary, delta: float) -> void:
	var id: String = p.id
	player.visual.attack = 0.6
	var origin: Vector2 = player.position
	var distance: float = channel_range(p)
	var end: Vector2 = origin+player.aim*distance
	for i: int in range(int(distance/16)):
		var point: Vector2 = origin+player.aim*i*16
		if not world.dungeon.walkable(point):
			end = point
			break
	var targets: Array[TowerEnemy] = []
	for enemy: TowerEnemy in world.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var offset: Vector2 = enemy.position-origin
		if offset.length()>distance or not world.dungeon.visible_line(origin,enemy.position): continue
		var dot: float = player.aim.dot(offset.normalized())
		var width: float = 0.30+State.rank("cone",p.snapshot)*0.12 if id in ["ice","steam"] else 0.13
		if id == "steam": width += 0.18
		if dot>cos(width): targets.append(enemy)
	targets.sort_custom(func(a: TowerEnemy,b: TowerEnemy)->bool:return origin.distance_squared_to(a.position)<origin.distance_squared_to(b.position))
	if id in ["lightning","flame_lash"] and not targets.is_empty():
		var primary: TowerEnemy = targets[0]
		targets = [primary]
		end = primary.position
		var previous: TowerEnemy = primary
		for i: int in range(State.rank("chain",p.snapshot)+(1 if id == "flame_lash" else 0)):
			var candidate: TowerEnemy = nearest(previous.position,180,targets)
			if candidate == null: break
			world.beam(previous.position,candidate.position,p.color,3,0.1,false,id)
			targets.append(candidate)
			previous = candidate
	if id in ["lightning","flame_lash"]:
		var urn: WorldProp = world.urn_on_segment(origin,end)
		if urn: world.break_urn(urn)
	else:
		var urn_width: float = 0.30+State.rank("cone",p.snapshot)*0.12 if id in ["ice","steam"] else 0.13
		if id=="steam": urn_width += 0.18
		world.break_urns_in_cone(origin,player.aim,distance,urn_width)
	world.beam(origin,end,p.color,13 if id in ["ice","steam"] else 4,0.07,id in ["ice","steam"],id)
	if id=="blizzard":
		# One chain budget for the beam; a target cannot be hit twice in one tick.
		var beam_targets: Array[TowerEnemy] = targets.duplicate()
		for source: TowerEnemy in beam_targets:
			var previous: TowerEnemy = source
			for i: int in range(State.rank("chain",p.snapshot)):
				var candidate: TowerEnemy = nearest(previous.position,180,targets)
				if candidate==null: break
				world.beam(previous.position,candidate.position,p.color,3,0.1,false,id)
				targets.append(candidate);previous=candidate
			break
	for enemy: TowerEnemy in targets:
		if not is_instance_valid(enemy) or enemy.dead: continue
		enemy.take_damage(p.damage*delta,player.aim*delta*(70+State.rank("chill",p.snapshot)*35) if "ice" in p.elements else Vector2.ZERO,true)
		if "ice" in p.elements: enemy.chill(0.5,maxf(0.10,0.55-State.rank("chill",p.snapshot)*0.045))
		if id == "blizzard": enemy.freeze(0.09)
		if "lightning" in p.elements and State.rank("stun",p.snapshot)>0: enemy.freeze(0.05+State.rank("stun",p.snapshot)*0.08)
		if id == "flame_lash": enemy.burn = 1.0
		if enemy.dead and "fire" in p.elements:
			if splash_ratio(p)>0: explosion(enemy.position,splash_radius(p),p.damage*splash_ratio(p),p.color)
			emit_embers(enemy.position,p,p.damage)
	if "ice" in p.elements and State.rank("chill",p.snapshot)>0:
		for shot: MagicProjectile in world.shots.get_children():
			if not shot.hostile: continue
			var offset: Vector2 = shot.position-origin
			if offset.length()<distance and player.aim.dot(offset.normalized())>cos(0.30+State.rank("cone",p.snapshot)*0.12) and world.dungeon.visible_line(origin,shot.position):
				shot.direction = shot.direction.lerp(offset.normalized(),minf(1,delta*State.rank("chill",p.snapshot)*5)).normalized()

func nearest(origin: Vector2, radius: float, excluded: Array = []) -> TowerEnemy:
	var found: TowerEnemy
	var best: float = radius*radius
	for enemy: TowerEnemy in world.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy in excluded: continue
		var distance: float = origin.distance_squared_to(enemy.position)
		if distance<best and world.dungeon.visible_line(origin,enemy.position):
			best = distance
			found = enemy
	return found

func explosion(position: Vector2, radius: float, damage: float, color: Color, freeze_time: float = 0.0) -> void:
	world.effect(position,color,radius)
	if damage>0: world.break_urns_in_radius(position,radius)
	for enemy: TowerEnemy in world.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead: continue
		if position.distance_to(enemy.position)<radius and world.dungeon.visible_line(position,enemy.position):
			if freeze_time>0: enemy.freeze(freeze_time)
			enemy.take_damage(damage,position.direction_to(enemy.position)*90)

func secondary(player: MagePlayer, index: int) -> bool:
	var available: Array = State.secondary_skills()
	if index<0 or index>=available.size() or world.village: return false
	var id: String = available[index]
	var p: Dictionary = secondary_profile(id)
	if float(player.cooldowns.get(id,0.0))>0.0: return false
	if not State.pay_mana(p.mana,p.offensive):
		State.message.emit("Not enough mana for this ritual.")
		return false
	player.cooldowns[id] = p.cooldown
	player.resting = 0.0
	var rank_value: int = State.rank(id)
	match id:
		"teleport":
			world.effect(player.position,Color("bda8ed"),90)
			player.position = world.safe_position
			player.invulnerable = p.duration
		"shield": player.shield = p.power
		"circle": world.friendly_zone(player.position,"circle",p.radius,p.duration,rank_value)
		"freeze": explosion(player.position,p.radius,p.damage,Color("b8eafa"),p.duration)
		"ring_fire": explosion(player.position,p.radius,p.damage,Color("ff985b"))
		"acid": world.friendly_zone(player.position+player.aim*100,"acid",p.radius,p.duration,p.power)
		"undead":
			world.effect(player.position,Color("e8e0b2"),300)
			for enemy: TowerEnemy in world.enemies:
				if enemy.definition.values.undead and player.position.distance_to(enemy.position)<p.radius:
					enemy.fear = p.duration
	player.visual.attack = 1.0
	world.effect(player.position,Color("9cdde5") if id in ["shield","freeze","circle"] else Color("d6a6f5"),60,id)
	Sound.play(id,player.global_position)
	return true

static func missile_speed_bonus(rank_value: int) -> float:
	return [0.0,0.10,0.25,0.40,0.55,1.0,1.1,1.2,1.3,1.4,1.5][clampi(rank_value,0,10)]

static func harden_profile(rank_value: int) -> Dictionary:
	var r: int = clampi(rank_value,0,10)
	return {"regen":[0,8,12,18,25,30,35,40,45,50,60][r],"cap":[0,25,50,75,100,125,150,175,200,250,300][r]}

func emit_embers(origin: Vector2, p: Dictionary, damage: float) -> void:
	var count: int = State.rank("embers",p.snapshot)*3
	if "fire" not in p.elements or p.get("ember",false): return
	for i: int in range(count):
		# Embers have no primary/sub effects, even with equipment. Major only on Fireball.
		var child: Dictionary = {"id":"fire","damage":damage*0.25,"color":p.color,"elements":["fire"],"snapshot":{"embers":0},"ember":true,"detonate":State.rank("immolation") if p.id=="fire" else 0}
		world.spawn_projectile(origin,Vector2.RIGHT.rotated(i*TAU/count),child,0.6)

func orb_pulse(origin: Vector2, p: Dictionary) -> void:
	world.break_urns_in_radius(origin,ORB_PULSE_RADIUS)
	var targets: Array = []
	var previous: Vector2 = origin
	for i: int in range(1+State.rank("chain",p.snapshot)):
		var victim: TowerEnemy = nearest(previous,ORB_PULSE_RADIUS if i==0 else 180.0,targets)
		if victim==null: break
		world.beam(previous,victim.position,p.color,3)
		victim.take_damage(p.damage*ORB_PULSE_RATIO)
		if State.rank("stun",p.snapshot)>0: victim.freeze(0.05+State.rank("stun",p.snapshot)*0.08)
		targets.append(victim);previous=victim.position

func hurricane(player: MagePlayer, delta: float) -> void:
	var rank_value: int = clampi(State.rank("hurricane"),0,8)
	var dps: float = [0,10,15,18,21,24,25,26,27][rank_value]*State.stats().damage
	player.storm_active = true
	world.break_urns_in_radius(player.position,520)
	for enemy: TowerEnemy in world.enemies.duplicate():
		var offset: Vector2 = enemy.position-player.position
		if enemy.dead or offset.length()>520: continue
		enemy.take_damage(dps*delta,offset.normalized().orthogonal()*150*delta,true)
		enemy.chill(0.2,0.7)
	for shot: MagicProjectile in world.shots.get_children():
		if shot.hostile and shot.position.distance_to(player.position)<520:
			var outward: Vector2 = player.position.direction_to(shot.position)
			shot.direction=shot.direction.lerp(outward.orthogonal(),minf(1,delta*4)).normalized()

func ether_pulse(player: MagePlayer) -> void:
	var charges: int = mini(player.ether_charges,State.rank("ether_charge"))
	player.ether_charges=0;player.ether_timer=0.0
	if charges<=0: return
	world.effect(player.position,COLORS.missile,320)
	world.break_urns_in_radius(player.position,320)
	for enemy: TowerEnemy in world.enemies.duplicate():
		if enemy.dead or enemy.position.distance_to(player.position)>320 or not world.dungeon.visible_line(player.position,enemy.position): continue
		enemy.apply_ether(charges)
