class_name CombatSystem
extends RefCounted

var world: Node2D
const COLORS: Dictionary = {"missile":Color("bba2f1"),"fire":Color("ffac62"),"lightning":Color("f7df94"),"ice":Color("8bdce9"),"fire_missile":Color("ffc486"),"flame_lash":Color("ffa568"),"steam":Color("d3e0df"),"ball_lightning":Color("ceb7ff"),"frost_missile":Color("a3e8fd"),"blizzard":Color("b9f5ff")}

func profile(id: String, preview_rank: int = -1, refresh_fusion: bool = false) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var snapshot: Dictionary = State.run.fusion.get("snapshot",{}) if d.kind == "fusion" and State.run.fusion.get("id","")==id and not refresh_fusion else {}
	var elements: Array = d.values.get("elements",[id])
	var level: float = 0.0
	for element: String in elements: level += maxf(1,State.rank(element,snapshot))
	level /= elements.size()
	if preview_rank>=0 and d.kind=="primary": level=maxi(1,preview_rank)
	var channel: bool = id in ["lightning","ice","flame_lash","steam","blizzard"]
	var damage: float = {"missile":18.0,"fire":30.0,"lightning":44.0,"ice":32.0,"fire_missile":35.0,"flame_lash":65.0,"steam":52.0,"ball_lightning":28.0,"frost_missile":26.0,"blizzard":58.0}.get(id,18.0)
	if d.kind == "primary": damage = float(d.values.damage)
	damage += (level-1)*float({"missile":7,"fire":11,"lightning":15,"ice":11,"fire_missile":15,"flame_lash":22,"steam":18,"ball_lightning":12,"frost_missile":11,"blizzard":20}.get(id,7))
	var mana: float = {"missile":6.0,"fire":10.0,"lightning":17.0,"ice":14.0,"fire_missile":14.0,"flame_lash":26.0,"steam":25.0,"ball_lightning":16.0,"frost_missile":13.0,"blizzard":26.0}.get(id,6.0)
	if d.kind == "primary": mana = float(d.values.mana)
	mana *= 1.0+(level-1)*0.10
	var multi: int = 1+State.rank("multishot",snapshot) if "missile" in elements else 1
	mana += (multi-1)*2.0
	return {"id":id,"damage":(damage+State.stats().flat_damage)*State.stats().damage,"mana":mana,"channel":channel,"cooldown":(0.55 if "fire" in elements else 0.38)/State.stats().cast_speed,"multi":multi,"snapshot":snapshot,"elements":elements,"color":COLORS.get(id,Color.WHITE)}

const PROJECTILE_SPEED: float = 510.0
const PROJECTILE_LIFETIME: float = 2.1
const ORB_SPEED: float = 170.0
const ORB_LIFETIME: float = 3.0
const ORB_PULSE_INTERVAL: float = 0.25
const ORB_PULSE_RATIO: float = 0.35
const ORB_PULSE_RADIUS: float = 125.0
const BURN_DPS: float = 8.0

func channel_range(p: Dictionary) -> float:
	return 350.0+State.rank("cone",p.snapshot)*18 if "ice" in p.elements else 470.0

func splash_ratio(p: Dictionary) -> float:
	if p.id=="fire_missile" or (p.id=="fire" and State.rank("explode",p.snapshot)>0): return 0.55
	return 0.3 if p.id=="frost_missile" else 0.0

func splash_radius(p: Dictionary) -> float:
	if p.id=="frost_missile": return 75.0
	return 60.0+State.rank("explode",p.snapshot)*18 if splash_ratio(p)>0 else 0.0

func secondary_profile(id: String, preview_rank: int = -1) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var rank_value: int = maxi(1,State.rank(id) if preview_rank<0 else preview_rank)
	var p: Dictionary = {"mana":float(d.values.mana),"cooldown":float(d.values.cooldown)*maxf(0.4,1.0-State.rank("focus")*0.1),"damage":0.0,"radius":0.0,"duration":0.0,"power":0.0,"rank":rank_value}
	if State.stats().mental_focus: p.cooldown *= 0.5
	match id:
		"teleport": p.duration=1.0
		"shield": p.power=45.0*rank_value
		"circle": p.radius=150.0+rank_value*25;p.duration=18.0
		"freeze": p.radius=260.0;p.damage=8.0*rank_value+State.stats().flat_damage;p.duration=2.0+rank_value
		"ring_fire": p.radius=250.0;p.damage=(45.0*rank_value+State.stats().flat_damage)*State.stats().damage
		"acid": p.radius=180.0;p.duration=7.0;p.power=(14.0*rank_value+State.stats().flat_damage)*State.stats().damage;p.damage=p.power*p.duration
		"undead": p.radius=340.0;p.duration=4.0+rank_value
	return p

func spend_primary_mana(amount: float) -> bool:
	if State.pay_mana(amount): return true
	State.notify_limited("primary_mana","Mana insuffisant : attendez la régénération ou utilisez une potion (%s)." % Controls.caption("mp_potion"),3000)
	return false

func fire(player: MagePlayer, delta: float) -> void:
	var p: Dictionary = profile(State.run.active)
	if p.channel:
		if not spend_primary_mana(p.mana*delta): return
		channel(player,p,delta)
		Sound.sustain(p.id)
	else:
		if player.fire_timer>0: return
		if not spend_primary_mana(p.mana): return
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
	world.beam(origin,end,p.color,13 if id in ["ice","steam"] else 4,0.07,id in ["ice","steam"],id)
	for enemy: TowerEnemy in targets:
		enemy.take_damage(p.damage*delta,player.aim*delta*(70+State.rank("chill",p.snapshot)*35) if "ice" in p.elements else Vector2.ZERO,true)
		if "ice" in p.elements: enemy.chill(0.5,0.55-State.rank("chill",p.snapshot)*0.045)
		if id == "blizzard": enemy.freeze(0.09)
		if "lightning" in p.elements and State.rank("stun",p.snapshot)>0: enemy.freeze(0.05+State.rank("stun",p.snapshot)*0.08)
		if id == "flame_lash": enemy.burn = 1.0

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
	if not State.pay_mana(p.mana):
		State.message.emit("Mana insuffisant pour ce rituel.")
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
