class_name TowerEnemy
extends CharacterBody2D

var world: Node2D
var record: Dictionary
var definition: ContentDefinition
var visual: ActorVisual
var hp: float = 1.0
var max_hp: float = 1.0
var damage: float = 1.0
var speed: float = 1.0
var boss: bool = false
var dead: bool = false
var cooldown: float = 0.5
var path_timer: float = 0.0
var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 1
var slow_time: float = 0.0
var slow_factor: float = 1.0
var frozen: float = 0.0
var freeze_guard: float = 0.0
const FREEZE_RECOVERY: float = 0.75
const BOSS_FREEZE_RECOVERY: float = 1.8
var fear: float = 0.0
var burn: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var telegraph: float = 0.0
var attack_target: Vector2 = Vector2.ZERO
var phase: int = 0
var active: bool = false
var wake_time: float = 0.0
var charge_time: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var recovery_time: float = 0.0
var preparing_charge: bool = false
var warded: bool = false
var voice_timer: float = 0.0
var hurt_voice_timer: float = 0.0
var foot_distance: float = 0.0
var audio_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var counter_time: float = 0.0
var interrupt_damage: float = 0.0
var shield_facing: Vector2 = Vector2.DOWN
const COUNTER_MULTIPLIER: float = 1.5

func setup(owner_world: Node2D, value: Dictionary) -> void:
	world = owner_world
	record = value
	definition = Catalog.definition(record.kind)
	boss = definition.values.behavior.begins_with("boss")
	var floor_number: int = int(State.run.floor)
	var difficulty: int = int(State.run.difficulty)
	# Existing NG+ characters keep their original opposition until their next ascent.
	var fresh_ascent: bool = int(State.run.get("ascent_version",0))>=1
	var health_scale: float = ProgressionRules.health_multiplier(difficulty) if fresh_ascent else pow(1.8 if boss else 1.65,difficulty)
	var damage_scale: float = ProgressionRules.damage_multiplier(difficulty) if fresh_ascent else pow(1.35,difficulty)
	var floor_scale: float = ProgressionRules.floor_health_multiplier(floor_number,boss) if fresh_ascent else (1.0 if boss else 1.0+float(floor_number-1)*0.16)
	max_hp = float(definition.values.hp)*health_scale*floor_scale
	if record.get("elite",false): max_hp*=1.25;damage_scale*=1.15
	max_hp *= 1.0-clampf(float(record.get("ether_reduction",0.0)),0.0,0.8)
	max_hp *= float(record.get("health_factor",1.0))
	hp = max_hp if record.hp<0 else float(record.hp)
	damage = float(definition.values.damage)*(1.0+float(floor_number-1)*0.07)*damage_scale
	damage *= float(record.get("damage_factor",1.0))
	speed = float(definition.values.speed)
	position = Dungeon.vec(record.pos)
	# Restore activation from the saved encounter; do not require doorway sight again.
	active = bool(record.get("awakened",false))
	if record.get("trial",false) and not record.get("awakened",false): collision_layer=0;collision_mask=0
	path_timer = float(get_instance_id()%100)/100.0
	audio_rng.seed = String(record.id).hash()+int(State.run.seed)
	voice_timer = audio_rng.randf_range(1.5,7.0)

func _ready() -> void:
	visual = ActorVisual.new()
	visual.texture = Catalog.texture(record.kind)
	visual.kind = record.kind
	visual.target_height = 176 if boss else (116 if record.kind == "zombie" or record.kind == "knight" else 103)
	if record.get("fragment",false): visual.target_height*=0.7
	add_child(visual)
	if boss:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 29
		$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world.player): return
	if record.id == "boss" and not world.floor_data.get("gate_open",true): return
	var player: MagePlayer = world.player
	if record.get("dormant",false) and not record.get("awakened",false):
		visual.tint=Color("737d94")
		visual.moving=false
		queue_redraw()
		return
	if wake_time>0:
		wake_time=maxf(0,wake_time-delta)
		visual.tint=Color("e4af69")
		queue_redraw()
		return
	var distance: float = position.distance_to(player.position)
	if distance>1200:
		visual.moving = false
		return
	var audible_line: bool = world.dungeon.visible_line(position,player.position)
	hurt_voice_timer = maxf(0.0,hurt_voice_timer-delta)
	voice_timer -= delta
	if not record.has("encounter_room") and distance<670 and audible_line and not active:
		active = true
		Sound.creature(String(record.kind),"alert",global_position,false,boss)
		if boss: set_meta("boss_announced",true)
		voice_timer = audio_rng.randf_range(4.0,8.0)
	if boss and active and distance<670 and audible_line and not get_meta("boss_announced",false):
		Sound.creature(String(record.kind),"alert",global_position,false,true)
		set_meta("boss_announced",true)
	if voice_timer<=0.0 and frozen<=0.0:
		Sound.creature(String(record.kind),"idle",global_position,not audible_line,boss)
		voice_timer = audio_rng.randf_range(5.0,11.0)
	if not active: return
	counter_time = maxf(0,counter_time-delta)
	slow_time = maxf(0,slow_time-delta)
	frozen = maxf(0,frozen-delta)
	freeze_guard = maxf(0,freeze_guard-delta)
	fear = maxf(0,fear-delta)
	if burn>0:
		burn -= delta
		take_damage(CombatSystem.BURN_DPS*delta,Vector2.ZERO,true,position)
		if dead: return
	visual.frozen = frozen>0
	visual.burning = burn>0
	visual.tint = Color("8ac9ed") if frozen>0 or slow_time>0 else Color.WHITE
	if frozen>0:
		visual.moving = false
		return
	warded = world.protection_for(self)>0
	# Chilling affects movement, not the cadence of attacks or their warnings.
	var local_delta: float = delta
	if fear>0:
		if telegraph>0 and interruptible_caster(): expose(1.1)
		preparing_charge=false;charge_time=0.0;telegraph=0.0
	if charge_time>0:
		charge_time=maxf(0,charge_time-local_delta)
		velocity=charge_direction*700.0*(slow_factor if slow_time>0 else 1.0)
		move_and_slide()
		visual.moving=true
		if position.distance_to(player.position)<55:
			player.take_damage(damage);charge_time=0;recovery_time=0.85
		elif is_on_wall() or charge_time<=0:
			charge_time=0;expose(1.2)
		queue_redraw()
		return
	if recovery_time>0:
		recovery_time=maxf(0,recovery_time-delta)
		visual.moving=false
		return
	cooldown -= local_delta
	var dir: Vector2 = (player.position-position).normalized()
	if record.get("elite_kind","")=="bulwark":
		shield_facing=shield_facing.rotated(clampf(shield_facing.angle_to(dir),-delta*1.8,delta*1.8))
		visual.facing=shield_facing
	else: visual.facing = dir
	if telegraph>0:
		telegraph -= local_delta
		velocity = Vector2.ZERO
		if telegraph<=0: release_attack()
		queue_redraw()
		return
	var behavior: String = definition.values.behavior
	var home_room: int = int(record.get("encounter_room",-1))
	var defend: bool = not boss and home_room>=0 and behavior in ["ranged","caster","imp"]
	var returning: bool = not boss and home_room>=0 and not EncounterRules.may_pursue(world.floor_data,record,player.position)
	var line: bool = world.dungeon.visible_line(position,player.position)
	var preferred: float = 270 if behavior in ["ranged","caster","imp"] else (175 if behavior == "ghost" else 35)
	if boss: preferred = 240
	if record.get("role","")=="warden": preferred=330
	if not returning and fear<=0 and cooldown<=0 and record.get("role","")=="charger" and distance>110 and distance<480 and line:
		attack_target=player.position+player.velocity*0.25
		if not world.dungeon.visible_line(position,attack_target): attack_target=player.position
		var aim: Vector2 = position.direction_to(attack_target)
		attack_target=position
		for step: int in range(1,40):
			var point: Vector2 = position+aim*step*16
			if not world.dungeon.walkable(point,18): break
			attack_target=point
		preparing_charge=true
		telegraph=0.75
		velocity=Vector2.ZERO
		queue_redraw()
		return
	if (not returning or defend) and fear<=0 and cooldown<=0 and distance<(600 if boss else (500 if preferred>100 else 62)) and line:
		attack_target = player.position
		if behavior in ["ranged","caster"]:
			var predicted: Vector2 = player.position+player.velocity*0.40
			if world.dungeon.visible_line(position,predicted): attack_target=predicted
		interrupt_damage=0.0
		telegraph = 1.1 if interruptible_caster() else (0.85 if boss else (0.45 if preferred>100 else 0.30))
		if boss: Sound.boss_warning(String(record.kind),global_position)
		visual.attack = 1.0
		queue_redraw()
		return
	path_timer -= delta
	var motion: Vector2 = Vector2.ZERO
	if not defend and not returning and (distance>preferred or not line):
		if line:
			motion = dir
			if record.get("role","")=="flanker" and distance>130 and distance<520:
				var side: float = -1.0 if posmod(String(record.id).hash(),2)==0 else 1.0
				var intercept: Vector2 = player.position+player.velocity*0.55+dir.orthogonal()*side*125
				if world.dungeon.visible_line(position,intercept): motion=position.direction_to(intercept)
		elif path_timer<=0:
			path_points = world.dungeon.path(position,player.position)
			path_index = 1
			path_timer = 0.55 + float(get_instance_id()%7)*0.06
		if not line and path_index<path_points.size():
			if position.distance_to(path_points[path_index])<18: path_index += 1
			if path_index<path_points.size(): motion = position.direction_to(path_points[path_index])
	elif not defend and not returning and preferred>100 and distance<preferred-65:
		motion = -dir
	if behavior == "dash" and record.get("role","")!="charger" and int(Time.get_ticks_msec()/1000.0)%3 == 0: motion *= 1.65
	if behavior == "imp": motion = motion.rotated(sin(Time.get_ticks_msec()*0.003+get_instance_id())*0.6)
	if behavior == "ghost": motion = motion.rotated(sin(Time.get_ticks_msec()*0.002)*0.3)
	if defend and fear<=0:
		# Find a firing position inside the room, including around pillars.
		if path_timer<=0 or path_points.is_empty():
			var goal: Vector2 = EncounterRules.defensive_position(world.dungeon,record,player.position,preferred)
			path_points = world.dungeon.path(position,goal)
			path_index = 1
			path_timer = 0.7
		motion = follow_home_path()
	elif returning and fear<=0:
		if path_timer<=0 or path_points.is_empty():
			path_points = world.dungeon.path(position,EncounterRules.home_position(world.floor_data,record))
			path_index = 1
			path_timer = 0.7
		motion = follow_home_path()
	if fear>0: motion = -dir
	if defend and world.dungeon.room_at(position)==home_room and world.dungeon.room_at(position+motion*48.0)!=home_room: motion=Vector2.ZERO
	velocity = motion*speed*(slow_factor if slow_time>0 else 1.0)+knockback
	knockback = knockback.move_toward(Vector2.ZERO,delta*600)
	var before_move: Vector2 = position
	move_and_slide()
	foot_distance += position.distance_to(before_move)
	if foot_distance>72.0:
		foot_distance = 0.0
		Sound.creature(String(record.kind),"step",global_position,not audible_line,boss)
	visual.moving = velocity.length()>4
	queue_redraw()

func follow_home_path() -> Vector2:
	while path_index<path_points.size() and position.distance_to(path_points[path_index])<18: path_index+=1
	if path_index<path_points.size(): return position.direction_to(path_points[path_index])
	return Vector2.ZERO

func release_attack() -> void:
	Sound.creature(String(record.kind),"attack",global_position,false,boss)
	if preparing_charge:
		preparing_charge=false
		charge_direction=position.direction_to(attack_target)
		charge_time=0.9
		cooldown=3.2
		Sound.play("enemy_melee",global_position)
		return
	var direction: Vector2 = position.direction_to(attack_target)
	var behavior: String = definition.values.behavior
	cooldown = 2.8 if boss else (1.65 if behavior in ["ranged","caster","imp"] else 1.0)
	if boss:
		phase += 1
		match behavior:
			"boss_king":
				if phase%2 == 0:
					world.hazard(attack_target,110,damage,0.9,Color("eec98a"))
				else:
					for i: int in range(9): world.enemy_bolt(position,Vector2.RIGHT.rotated(i*TAU/9.0),damage,210,Color("d8b080"))
			"boss_plague":
				for i: int in range(3): world.hazard(attack_target+Vector2(i*90-90,0),85,damage,1.1,Color("9caf49"),5.0,"poison")
			"boss_demon":
				for i: int in range(5): world.enemy_bolt(position,direction.rotated((i-2)*0.22),damage,260,Color("ff9757"))
				if phase%2 == 0: world.hazard(attack_target,150,damage,1.2,Color("ed8a48"))
			"boss_lich":
				if phase%3 == 0:
					for i: int in range(14): world.enemy_bolt(position,Vector2.RIGHT.rotated(i*TAU/14.0+phase),damage,220,Color("b48fe8"))
				elif phase%3 == 1:
					world.hazard(attack_target,165,damage*1.3,1.1,Color("b8a0ff"))
				else:
					for i: int in range(3): world.enemy_bolt(position,direction.rotated((i-1)*0.25),damage,340,Color("8ad9ff"))
		# Additional readable zones, without shortening the normal warning windows.
		var difficulty: int = int(State.run.difficulty)
		if difficulty>=1 and phase%2==0:
			world.hazard(attack_target+Vector2(120,0).rotated(phase),75,damage*0.65,1.25,Color("d7a9ff"))
		if difficulty>=3 and phase%3==0:
			world.hazard(attack_target-Vector2(150,0).rotated(phase),85,damage*0.65,1.35,Color("d7a9ff"))
	elif interruptible_caster():
		world.hazard(attack_target,110 if record.get("elite_kind","")=="ritualist" else 85,damage*1.2,0.25,Color("d3a0ef"))
		cooldown=3.3
	elif behavior == "ghost":
		world.beam(position+Vector2(0,-30),world.player.position+Vector2(0,-25),Color("9bd3e3"),3,0.4)
		if position.distance_to(world.player.position)<260 and world.dungeon.visible_line(position,world.player.position):
			State.run.mp = maxf(0,float(State.run.mp)-12)
			world.player.take_damage(damage*0.5)
	elif behavior in ["ranged","caster","imp"]:
		world.enemy_bolt(position,direction,damage,430 if behavior == "ranged" else 330,Color("d6b690") if behavior == "ranged" else Color("b384e5"))
		if behavior == "caster":
			world.enemy_bolt(position,direction.rotated(0.22),damage,330,Color("b384e5"))
			world.enemy_bolt(position,direction.rotated(-0.22),damage,330,Color("b384e5"))
	else:
		if position.distance_to(world.player.position)<78: world.player.take_damage(damage)
		if behavior == "poison": world.hazard(position,60,damage*0.4,0.3,Color("8aab61"),3.0,"poison")
	var weapon_sound: String = "enemy_bow" if behavior=="ranged" else ("enemy_magic" if behavior in ["caster","imp","ghost","boss_lich"] else "enemy_melee")
	if behavior=="boss_plague": weapon_sound = "acid"
	elif behavior=="boss_demon": weapon_sound = "fire"
	Sound.play(weapon_sound,global_position)
	queue_redraw()

func take_damage(amount: float, force: Vector2 = Vector2.ZERO, quiet: bool = false, source: Vector2 = Vector2.INF) -> void:
	if dead: return
	if record.get("trial",false) and not record.get("awakened",false): return
	if record.has("encounter_room") and not record.get("awakened",false): world.wake_encounter(int(record.get("encounter_room",-1)))
	active = true
	var origin: Vector2 = source
	if origin==Vector2.INF: origin=position-force if force.length_squared()>0.01 else world.player.position
	var multiplier: float = COUNTER_MULTIPLIER if counter_time>0 else 1.0
	if record.get("elite_kind","")=="bulwark" and counter_time<=0 and frozen<=0 and fear<=0:
		var facing_hit: bool = shield_facing.dot(position.direction_to(origin))>0.45
		if facing_hit:
			multiplier*=0.25
			world.effect(position,Color("e5bf74"),24)
	var received: float = maxf(0.0,amount)*(1.0-world.protection_for(self))*(1.0-float(definition.values.resistance))*(1.35 if fear>0 else 1.0)*multiplier
	hp -= received
	if telegraph>0 and interruptible_caster():
		interrupt_damage+=received
		if interrupt_damage>=max_hp*0.12: expose(1.1)
	# Health feedback must update even while frozen, recovering or offscreen.
	queue_redraw()
	knockback += force * (0.2 if boss else 1.0)
	if not quiet: visual.hit_flash = 0.6
	if not quiet and hp>0 and hurt_voice_timer<=0:
		Sound.creature(String(record.kind),"hurt",global_position,false,boss)
		hurt_voice_timer = 0.8
	if hp<=0:
		dead = true
		record.dead = true
		record.hp = 0.0
		world.enemy_killed(self)
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		visual.moving = false
		var death: Tween = create_tween()
		death.tween_property(visual,"dying",1.0,0.65)
		death.tween_callback(queue_free)

func chill(duration: float, factor: float = 0.5) -> void:
	slow_time = maxf(slow_time,duration)
	slow_factor = maxf(0.65,factor) if boss else factor

func freeze(duration: float) -> void:
	# Shared by all freeze/stun sources: repeated hits cannot extend a lock or
	# chain different spells to skip the guaranteed period in which enemies act.
	if dead or duration<=0 or freeze_guard>0: return
	if telegraph>0 and interruptible_caster(): expose(1.1)
	frozen = minf(duration,0.35) if boss else duration
	freeze_guard = frozen+(BOSS_FREEZE_RECOVERY if boss else FREEZE_RECOVERY)
	active = true

func interruptible_caster() -> bool:
	return not boss and (record.get("role","")=="artillery" or record.get("elite_kind","")=="ritualist")

func expose(duration: float) -> void:
	counter_time=maxf(counter_time,duration)
	recovery_time=maxf(recovery_time,duration)
	telegraph=0.0
	preparing_charge=false
	charge_time=0.0
	cooldown=maxf(cooldown,duration+0.8)
	velocity=Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if dead: return
	draw_tactical_cues()
	if record.get("role","")=="warden":
		var aura: Color = Color("90dabb")
		draw_arc(Vector2.ZERO,260,0,TAU,64,Color(aura,0.25),2,true)
		ArcaneArt.rune(self,Vector2(0,-55),25,Color(aura,0.85),0.0,6)
	elif warded:
		draw_arc(Vector2(0,-45),35,0,TAU,32,Color("90dabb",0.7),2,true)
	if preparing_charge and telegraph>0:
		var target: Vector2 = attack_target-position
		draw_line(Vector2.ZERO,target,Color("edb66e",0.6),30,true)
		draw_line(Vector2.ZERO,target,Color("ffe0a6"),2,true)
		draw_arc(target,24,0,TAU,24,Color("ffe0a6"),2,true)
	if wake_time>0:
		draw_arc(Vector2.ZERO,30+(1.0-wake_time)*20,0,TAU,24,Color("edb66e"),2,true)
	if record.get("elite",false):
		ArcaneArt.rune(self,Vector2(0,-125),15,Color("f0be68"),0.0,4)
	if hp<max_hp or boss or record.get("elite",false):
		var width: float = 95 if boss else 48
		draw_rect(Rect2(-width/2,-(182 if boss else 117),width,4),Color("1a2026"))
		draw_rect(Rect2(-width/2,-(182 if boss else 117),width*maxf(0,hp/max_hp),4),Color("c8986c") if boss else Color("a56360"))
	if telegraph>0:
		var radius: float = 52 if boss else 29
		var windup: float = 1.1 if interruptible_caster() else (0.75 if preparing_charge else (0.85 if boss else (0.45 if definition.values.behavior in ["ranged","caster","imp","ghost"] else 0.30)))
		var time: float = 1.0-telegraph/windup
		var warning: Color = Color("ffb06d")
		ArcaneArt.glow(self,Vector2.ZERO,radius*1.4,Color(warning,0.17))
		draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*clampf(time,0,1),48,Color(warning,0.85),2.5,true)
		var direction: Vector2 = position.direction_to(attack_target)
		var tip: Vector2 = direction*(radius+10)
		draw_polyline(PackedVector2Array([tip-direction.rotated(-0.55)*9,tip,tip-direction.rotated(0.55)*9]),Color(warning,0.8),2,true)

func apply_ether(charges: int) -> void:
	var before: float = float(record.get("ether_reduction",0.0))
	var after: float = maxf(before,clampf(charges*0.1,0.0,0.8))
	if after<=before: return
	max_hp = max_hp/(1.0-before)*(1.0-after)
	hp = minf(hp,max_hp)
	record.ether_reduction=after
	record.hp=hp
	queue_redraw()
	active=true

func is_targetable() -> bool:
	return not dead and (not record.get("trial",false) or record.get("awakened",false))

func awaken(delay: float) -> void:
	record.awakened=true
	active=true
	wake_time=delay
	collision_layer=4
	collision_mask=5

func draw_tactical_cues() -> void:
	var font: Font = ThemeDB.fallback_font
	var affix: String = record.get("elite_kind","")
	var tint: Color = Color("e5bf74") if affix=="bulwark" else (Color("d3a0ef") if affix=="ritualist" else Color("a3d884"))
	if not affix.is_empty():
		var caption: String = {"bulwark":"BULWARK · FLANK","ritualist":"RITUALIST · INTERRUPT","brood":"BROOD · SPLITS"}.get(affix,"")
		var width: float = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string_outline(font,Vector2(-width/2,-146),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color("12151c"))
		draw_string(font,Vector2(-width/2,-146),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,tint)
		if affix=="bulwark" and counter_time<=0:
			var angle: float = shield_facing.angle()
			draw_arc(Vector2.ZERO,43,angle-1.05,angle+1.05,24,tint,6,true)
			draw_line(shield_facing*35,shield_facing*51,tint,3,true)
		elif affix=="ritualist": ArcaneArt.rune(self,Vector2(0,-60),31,tint,0,3)
		elif affix=="brood":
			for side: int in [-1,1]:
				draw_arc(Vector2(side*18,-48),11,0,TAU,16,tint,2,true)
	if telegraph>0 and interruptible_caster():
		var target: Vector2 = attack_target-position
		var radius: float = 110 if affix=="ritualist" else 85
		draw_circle(target,radius,Color("d3a0ef",0.12))
		draw_arc(target,radius,0,TAU,48,Color("d3a0ef"),2,true)
		draw_line(target-Vector2(12,0),target+Vector2(12,0),Color("f0d7ff"),2,true)
		draw_line(target-Vector2(0,12),target+Vector2(0,12),Color("f0d7ff"),2,true)
	if counter_time>0:
		draw_arc(Vector2.ZERO,37,0,TAU,32,Color("fff0ab"),3,true)
		draw_string_outline(font,Vector2(-20,-98),"OPEN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("12151c"))
		draw_string(font,Vector2(-20,-98),"OPEN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff0ab"))
