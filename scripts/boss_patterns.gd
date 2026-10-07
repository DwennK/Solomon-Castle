class_name BossPatterns
extends RefCounted

static func stage(enemy: TowerEnemy) -> int:
	return int(enemy.record.get("boss_stage",0))

static func update(enemy: TowerEnemy) -> void:
	if not enemy.boss or not enemy.active or enemy.dead: return
	var next: int = 2 if enemy.record.kind=="lich" and enemy.hp<=enemy.max_hp*0.22 else (1 if enemy.hp<=enemy.max_hp*0.5 else 0)
	if next<=stage(enemy): return
	# Saved before summons are created: crossing a threshold or reloading cannot
	# duplicate a phase's finite guards. Large hits still trigger each wave once.
	var previous: int = stage(enemy)
	enemy.record.boss_stage=next
	enemy.telegraph=0;enemy.recovery_time=1.25;enemy.cooldown=1.3
	enemy.world.effect(enemy.position,Color("edb269"),110)
	State.message.emit("%s · %s"%[enemy.definition.title,"Final stand" if next==2 else "Second phase"])
	for wave: int in range(previous+1,next+1):
		if enemy.record.kind in ["king","lich"]:
			enemy.world.summon_boss_guards(enemy,wave,2 if enemy.record.kind=="king" else 3)

static func release(enemy: TowerEnemy) -> void:
	var world: GameWorld = enemy.world
	var target: Vector2 = enemy.attack_target
	var direction: Vector2 = enemy.position.direction_to(target)
	var empowered: bool = stage(enemy)>0
	var advanced: bool = int(State.run.difficulty)>0
	enemy.phase+=1
	enemy.record.boss_attack=enemy.phase
	enemy.cooldown=2.8
	match enemy.record.kind:
		"king":
			if enemy.phase%2==0:
				world.hazard(target,110,enemy.damage,0.9,Color("eec98a"))
				if empowered: world.hazard(target+direction.orthogonal()*145,85,enemy.damage,1.3,Color("eec98a"))
			else:
				fan(enemy,Vector2.RIGHT.rotated(enemy.phase*0.24),9 if not empowered else 12,TAU,210,Color("d8b080"))
		"plague":
			var axis: Vector2 = direction.orthogonal() if empowered else Vector2.RIGHT
			for i: int in range(3): world.hazard(target+axis*(i-1)*110,75,enemy.damage,1.1+i*0.15,Color("9caf49"),3.5,"poison")
			if empowered and enemy.phase%2==0: fan(enemy,direction,3,0.5,230,Color("b5cb64"))
		"demon":
			fan(enemy,direction,7 if empowered else 5,1.2 if empowered else 0.88,260,Color("ff9757"))
			if enemy.phase%2==0:
				world.hazard(target,130,enemy.damage,1.2,Color("ed8a48"))
				if empowered: world.hazard(enemy.position.lerp(target,0.5),90,enemy.damage,1.5,Color("ed8a48"))
		"lich":
			match enemy.phase%3:
				0: fan(enemy,Vector2.RIGHT.rotated(enemy.phase),14 if not empowered else 18,TAU,220,Color("b48fe8"))
				1:
					world.hazard(target,145,enemy.damage*1.3,1.1,Color("b8a0ff"))
					if empowered: world.hazard(target+direction.orthogonal()*180,95,enemy.damage,1.6,Color("b8a0ff"))
				2: fan(enemy,direction,3 if not empowered else 5,0.5 if not empowered else 0.9,340,Color("8ad9ff"))
			if stage(enemy)==2: enemy.cooldown=2.3
	# Higher difficulties introduce an extra aimed volley on alternate attacks.
	# The same warning/locked target applies; no untelegraphed instant damage.
	if advanced and enemy.phase%2==0: fan(enemy,direction,2,0.3,240,Color("e4c4ff"))
	# A strong attack leaves an explicit punish window, even during later phases.
	if enemy.phase%3==0:
		enemy.recovery_time=1.35
		enemy.cooldown=1.5
		enemy.world.effect(enemy.position,Color("9fe0dd"),50)

static func fan(enemy: TowerEnemy,direction: Vector2,count: int,spread: float,speed: float,color: Color) -> void:
	for i: int in range(count):
		var angle: float = i*TAU/count if spread>=TAU else (float(i)/maxi(1,count-1)-0.5)*spread
		enemy.world.enemy_bolt(enemy.position,direction.rotated(angle),enemy.damage,speed,color)
