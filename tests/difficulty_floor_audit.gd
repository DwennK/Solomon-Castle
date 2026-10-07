extends "res://tests/difficulty_audit.gd"

func run_all() -> void:
	State.save_path="user://qa_difficulty_floor_20261007.json"
	for seed_value: int in [41,829,20261007]:
		for primary: String in ["missile","ice","lightning"]:
			load_case(Dungeon.generate(seed_value,1),{primary:1},1,seed_value,"kite")
			var initial: int=world.enemies.filter(func(e:TowerEnemy)->bool:return e.is_targetable() or not e.record.get("trial",false)).size()
			var points: PackedVector2Array=PackedVector2Array()
			var destination_index: int=1
			var repath: int=0
			var empty_mana_ticks: int=0
			for tick: int in range(60*600):
				if deaths: break
				var living: Array=world.enemies.filter(func(e:TowerEnemy)->bool:return not e.record.get("trial",false))
				if living.is_empty(): break
				while not State.run.pending.is_empty():
					var offers: Array=State.offers()
					var chosen: String=offers[0]
					var priorities: Array=[primary,"regen","power","economy","life","mana","haste","rush","resist"]
					if primary=="lightning": priorities.insert(1,"stun");priorities.insert(2,"chain")
					if primary=="ice": priorities.insert(1,"chill");priorities.insert(2,"cone")
					if primary=="missile": priorities.insert(1,"multishot");priorities.insert(2,"potent")
					for preferred: String in priorities:
						if preferred in offers: chosen=preferred;break
					State.choose(chosen)
				var player: MagePlayer=world.player
				var target: TowerEnemy=world.combat.nearest(player.position,550)
				if target and not world.dungeon.explored_position(target.position): target=null
				player.qa_fire=target!=null
				player.qa_direction=Vector2.ZERO
				if target:
					player.aim=player.position.direction_to(target.position)
					var distance: float=player.position.distance_to(target.position)
					var wish: Vector2=-player.aim if distance<preferred_range else player.aim if distance>preferred_range+50 else player.aim.orthogonal()
					for rotation: float in [0.0,0.65,-0.65,1.3,-1.3,2.0,-2.0,3.14]:
						var direction: Vector2=wish.rotated(rotation)
						if world.dungeon.walkable(player.position+direction*60,20): player.qa_direction=direction;break
				else:
					repath-=1
					if repath<=0 or points.is_empty():
						var room: Array=world.floor_data.rooms[destination_index%world.floor_data.rooms.size()]
						var destination: Vector2=TowerLayout.open_position(world.floor_data.grid,room,Dungeon.room_center(room))
						if player.position.distance_to(destination)<50: destination_index+=1
						points=world.dungeon.path(player.position,destination);repath=20
						if not points.is_empty(): points.remove_at(0)
					while not points.is_empty() and player.position.distance_to(points[0])<26: points.remove_at(0)
					if not points.is_empty(): player.qa_direction=player.position.direction_to(points[0])
				await get_tree().physics_frame
				ticks+=1
				if State.run.mp<1: empty_mana_ticks+=1
				if not deaths: case_damage+=maxf(0,last_hp-float(State.run.hp));last_hp=State.run.hp
			var remaining: int=world.enemies.filter(func(e:TowerEnemy)->bool:return not e.record.get("trial",false)).size()
			var result: Dictionary={"seed":seed_value,"primary":primary,"cleared":remaining==0,"died":deaths,"seconds":snappedf(ticks/60.0,0.01),"damage_taken":snappedf(case_damage,0.1),"fatal_hit_excluded_from_damage":deaths,"hp_end":snappedf(State.run.hp,0.1) if not deaths else 0,"hp_max":State.stats().max_hp,"mana_end":snappedf(State.run.mp,0.1),"level_end":State.run.level,"skills":State.run.skills.duplicate(),"kills":initial-remaining,"remaining":remaining,"hp_potions_remaining":State.run.hp_potions,"mp_potions_remaining":State.run.mp_potions,"near_zero_mana_seconds":snappedf(empty_mana_ticks/60.0,0.01)}
			results.append(result);print("FLOOR ",JSON.stringify(result))
			world.queue_free();await get_tree().process_frame;await get_tree().process_frame
	var out: Dictionary={"cases":results,"elapsed_wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"simulated_seconds":results.reduce(func(total:float,r:Dictionary)->float:return total+r.seconds,0.0),"method":"Complete first-floor combat sweep on actual generated geometry and all regular enemy groups, retaining health/mana between rooms and choosing only naturally earned offered upgrades. No gear, potion use, invulnerability or mana refill. No chests, urn farming or optional sentry trials; starting spell rank 1. Auto aim and simple wall-aware kiting; bot navigation can time out."}
	var file: FileAccess=FileAccess.open("res://outputs/balance/floor-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(out,"\t"));file.close()
	print("FLOOR_AUDIT_DONE ",out.elapsed_wall_seconds," wall sec, ",out.simulated_seconds," sim sec")
	Sound.stop_all();get_tree().quit()
