extends "res://tests/difficulty_audit.gd"

var primary: String
var hp_used: int=0
var mp_used: int=0
var equipped: Dictionary={}
var navigation: PackedVector2Array=PackedVector2Array()
var destination: Vector2=Vector2.INF

func choose_upgrades() -> void:
	while not State.run.pending.is_empty():
		var offers: Array=State.offers()
		var priorities: Array=[primary,"regen","power","economy","life","mana","haste","rush","resist","shield","circle","freeze"]
		match primary:
			"lightning": priorities.insert(1,"chain");priorities.insert(2,"stun")
			"ice": priorities.insert(1,"cone");priorities.insert(2,"chill")
			"missile": priorities.insert(1,"multishot");priorities.insert(2,"potent")
			"fire": priorities.insert(1,"explode");priorities.insert(2,"burn")
		var chosen: String=offers[0]
		for preferred: String in priorities:
			if preferred in offers: chosen=preferred;break
		State.choose(chosen)
	# Learning another offered element does not change the intended test build.
	State.run.active=primary

func provision() -> void:
	if State.run.hp<State.stats().max_hp*0.38 and State.potion("hp"): hp_used+=1
	if State.run.mp<State.stats().max_mana*0.12 and State.potion("mp"): mp_used+=1
	for item: Dictionary in State.run.inventory:
		if equipped.has(item.uid): continue
		# First item in each slot; deliberately no perfect build optimizer.
		var slot: String="staff" if item.slot=="staff" else "ring1" if State.run.equipped.ring1.is_empty() else "ring2"
		if State.run.equipped[slot].is_empty(): State.equip(item.uid)
		equipped[item.uid]=true

func steer(tick: int) -> void:
	var player: MagePlayer=world.player
	var target: TowerEnemy=world.combat.nearest(player.position,550)
	if target and not world.dungeon.explored_position(target.position): target=null
	player.qa_fire=target!=null;player.qa_direction=Vector2.ZERO
	if target:
		player.aim=player.position.direction_to(target.position)
		if tick%30==0:
			for index: int in range(State.run.secondary.size()): world.combat.secondary(player,index)
		var distance: float=player.position.distance_to(target.position)
		var wish: Vector2=-player.aim if distance<preferred_range else player.aim if distance>preferred_range+60 else player.aim.orthogonal()
		var best: float=-INF
		for rotation: float in [0.0,0.65,-0.65,1.3,-1.3,2.0,-2.0,3.14]:
			var direction: Vector2=wish.rotated(rotation)
			var point: Vector2=player.position+direction*65
			if not world.dungeon.walkable(point,20): continue
			var score: float=direction.dot(wish)
			for zone: Dictionary in world.zones:
				if zone.kind=="hostile" and point.distance_to(zone.pos)<zone.radius+20: score-=10
			if score>best: best=score;player.qa_direction=direction
		return
	# Real movement to reachable objectives. Floor geometry is known to this QA
	# navigator, but combat targets still require the game's actual sight checks.
	if tick%30==0 or navigation.is_empty():
		var objectives: Array[Vector2]=[]
		for drop: Dictionary in world.loot:
			if player.position.distance_to(Dungeon.vec(drop.pos))>25: objectives.append(Dungeon.vec(drop.pos))
		for prop: WorldProp in world.props:
			if prop.record.kind=="chest" and not prop.record.get("opened",false): objectives.append(prop.position)
		for enemy: TowerEnemy in world.enemies:
			if not enemy.record.get("trial",false): objectives.append(enemy.position)
		if world.floor_data.has_key and world.floor_data.guardian_dead and not world.floor_data.gate_open:
			objectives.append(Dungeon.vec(world.floor_data.gate_position))
		var regular: Array=world.enemies.filter(func(e:TowerEnemy)->bool:return not e.record.get("trial",false))
		if regular.is_empty(): objectives.append(Dungeon.vec(world.floor_data.exit))
		var best_distance: float=INF
		for point: Vector2 in objectives:
			var route: PackedVector2Array=world.dungeon.path(player.position,point)
			if route.is_empty() or route[-1].distance_to(point)>80: continue
			var distance: float=route.size()*Dungeon.CELL
			if distance<best_distance:
				best_distance=distance;navigation=route;destination=point
		if not navigation.is_empty(): navigation.remove_at(0)
	while not navigation.is_empty() and player.position.distance_to(navigation[0])<24: navigation.remove_at(0)
	if not navigation.is_empty(): player.qa_direction=player.position.direction_to(navigation[0])
	elif destination!=Vector2.INF: player.qa_direction=player.position.direction_to(destination)
	for prop: WorldProp in world.props:
		if prop.position.distance_to(player.position)>85 or not world.dungeon.visible_line(player.position,prop.position): continue
		if prop.record.kind=="chest": world.open_prop(prop)
		elif prop.record.id=="gate": world.unlock_gate()

func run_all() -> void:
	var suffix: String="-final" if "--final" in OS.get_cmdline_user_args() else ""
	State.save_path="user://qa_progression_campaign%s.json"%suffix
	for difficulty: int in [0,2,4]:
		for starting_spell: String in ["fire","missile","ice","lightning"]:
			primary=starting_spell
			State.fresh(829,difficulty,difficulty==4);State.learn(primary);State.run.floor=1
			world=load("res://scenes/world.tscn").instantiate();add_child(world)
			world.died.connect(func()->void:deaths=true)
			deaths=false;hp_used=0;mp_used=0;equipped={};ticks=0
			preferred_range=255 if primary=="ice" else 340
			var floors: Array=[]
			for number: int in range(1,14):
				world.player.qa_controlled=true;navigation=PackedVector2Array();destination=Vector2.INF
				for child: Node in world.get_children():
					if child is DungeonFog or child is WorldAtmosphere: child.set_process(false)
				world.effects.set_process(false)
				var start_tick: int=ticks
				var floor_done: bool=false
				var level_before_death: int=State.run.level
				for tick: int in range(60*480):
					if deaths: break
					choose_upgrades();provision();steer(tick)
					level_before_death=State.run.level
					if world.enemies.all(func(e:TowerEnemy)->bool:return e.record.get("trial",false)) and world.player.position.distance_to(Dungeon.vec(world.floor_data.exit))<85:
						floor_done=true;break
					await get_tree().physics_frame
					ticks+=1
				floors.append({"floor":number,"cleared":floor_done,"died":deaths,"level":level_before_death,"seconds":snappedf((ticks-start_tick)/60.0,0.01),"hp":0 if deaths else State.run.hp,"hp_potions":State.run.hp_potions,"mp_potions":State.run.mp_potions,"remaining":world.enemies.size(),"skills":State.run.skills.duplicate(),"stats":State.stats(),"shield":world.player.shield})
				print("CAMPAIGN_FLOOR ",difficulty," ",primary," ",JSON.stringify(floors[-1]))
				if not floor_done or deaths: break
				world.advance();await get_tree().physics_frame
			results.append({"difficulty":difficulty,"primary":primary,"seed":829,"victory":State.run.victory,"died":deaths,"hp_potions_used":hp_used,"mp_potions_used":mp_used,"floors":floors,"seconds":ticks/60.0})
			world.queue_free();await get_tree().process_frame;await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://outputs/progression")
	var report: Dictionary={"cases":results,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"simulated_seconds":results.reduce(func(total:float,r:Dictionary)->float:return total+r.seconds,0.0),"method":"12 continuous campaign attempts, all four starting spells at difficulties 0/2/4, seed 829. Real physics 60Hz, actual upgrades, mana, damage, finite earned potions, first found equipment and secondary casts. No revival, no stat injection, no position injection, no healing/mana cheats. Navigator knows layout; aim respects sight. No village shopping/healer/lessons, no optional trials. Stops on first death or 480s navigation timeout per floor; deaths roll back the normal save but the audit never retries."}
	var file: FileAccess=FileAccess.open("res://outputs/progression/campaign-audit%s.json"%suffix,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CAMPAIGN_AUDIT_DONE ",report.wall_seconds," wall sec, ",report.simulated_seconds," simulated sec")
	Sound.stop_all();get_tree().quit()
