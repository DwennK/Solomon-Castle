class_name CombatSystem
extends RefCounted

var world: Node2D
const COLORS: Dictionary = {"missile":Color("bba2f1"),"fire":Color("ffac62"),"lightning":Color("f7df94"),"ice":Color("8bdce9"),"fire_missile":Color("ffc486"),"flame_lash":Color("ffa568"),"steam":Color("d3e0df"),"ball_lightning":Color("ceb7ff"),"frost_missile":Color("a3e8fd"),"blizzard":Color("b9f5ff")}

func profile(id: String, preview_rank: int = -1) -> Dictionary:
	var d: ContentDefinition = Catalog.definition(id)
	var snapshot: Dictionary = State.run.fusion.get("snapshot",{}) if d.kind == "fusion" else {}
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
	return {"id":id,"damage":damage*State.stats().damage,"mana":mana,"channel":channel,"cooldown":(0.55 if "fire" in elements else 0.38)/State.stats().cast_speed,"multi":multi,"snapshot":snapshot,"elements":elements,"color":COLORS.get(id,Color.WHITE)}

func fire(player: MagePlayer, delta: float) -> void:
	var p: Dictionary = profile(State.run.active)
	if p.channel:
		if not State.pay_mana(p.mana*delta): return
		channel(player,p,delta)
		if player.fire_timer<=0:
			Sound.play("channel")
			player.fire_timer = 0.2
	else:
		if player.fire_timer>0: return
		if not State.pay_mana(p.mana): return
		player.fire_timer = p.cooldown
		player.visual.attack = 1.0
		for i: int in range(p.multi):
			var angle: float = (float(i)-(p.multi-1)/2.0)*0.17
			world.spawn_projectile(player.position,player.aim.rotated(angle),p)
		Sound.play("fire" if "fire" in p.elements else "missile")

func channel(player: MagePlayer, p: Dictionary, delta: float) -> void:
	var id: String = p.id
	var origin: Vector2 = player.position
	var distance: float = 350.0+State.rank("cone",p.snapshot)*18 if "ice" in p.elements else 470.0
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
			world.beam(previous.position,candidate.position,p.color,3)
			targets.append(candidate)
			previous = candidate
	world.beam(origin,end,p.color,13 if id in ["ice","steam"] else 4,0.07,id in ["ice","steam"])
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
	if index>=State.run.secondary.size() or world.village: return false
	var id: String = State.run.secondary[index]
	var d: ContentDefinition = Catalog.definition(id)
	if float(player.cooldowns.get(id,0.0))>0.0: return false
	if not State.pay_mana(d.values.mana):
		State.message.emit("Mana insuffisant pour ce rituel.")
		return false
	player.cooldowns[id] = float(d.values.cooldown)*maxf(0.4,1.0-State.rank("focus")*0.1)
	var rank_value: int = State.rank(id)
	match id:
		"teleport":
			world.effect(player.position,Color("bda8ed"),90)
			player.position = world.safe_position
			player.invulnerable = 1.0
		"shield": player.shield = 45.0*rank_value
		"circle": world.friendly_zone(player.position,"circle",150+rank_value*25,18,rank_value)
		"freeze": explosion(player.position,260,8.0*rank_value,Color("b8eafa"),2+rank_value)
		"ring_fire": explosion(player.position,250,45.0*rank_value*State.stats().damage,Color("ff985b"))
		"acid": world.friendly_zone(player.position+player.aim*100,"acid",180,7,14*rank_value*State.stats().damage)
		"undead":
			world.effect(player.position,Color("e8e0b2"),300)
			for enemy: TowerEnemy in world.enemies:
				if enemy.definition.values.undead and player.position.distance_to(enemy.position)<340:
					enemy.fear = 4+rank_value
	Sound.play("ritual")
	return true
