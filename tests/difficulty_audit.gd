extends Node
var world: GameWorld
var results: Array = []
var started: int
var case_damage: float = 0
var last_hp: float
var ticks: int
var start_count: int
var frozen_ticks: int
var living_ticks: int
var deaths: bool
var move_mode: String
var preferred_range: float
var spell: String
var pos_start: Vector2

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_difficulty_audit_20261007.json"
	DirAccess.make_dir_recursive_absolute("res://outputs/balance")
	started=Time.get_ticks_msec()
	call_deferred("run_all")

func base_arena(number: int,kind: String) -> Dictionary:
	var data: Dictionary=Dungeon.generate(910,number)
	var grid: Array[String]=[]
	for y: int in range(Dungeon.HEIGHT):
		var row: String=""
		for x: int in range(Dungeon.WIDTH): row+="." if Rect2i(3,3,24,20).has_point(Vector2i(x,y)) else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[3,3,24,20]];data.props=[];data.encounters=[];data.loot=[]
	data.entry=[700,800];data.exit=[1500,1000];data.gate_open=true;data.gate_cells=[]
	data.enemies=[{"id":"boss","kind":kind,"pos":[1000,800],"hp":-1.0,"dead":false}]
	return data

func load_case(data: Dictionary,build: Dictionary,number: int,seed_value: int,mode: String) -> void:
	State.fresh(seed_value);State.run.floor=number;State.run.level=3 if build.has("stun") else 1
	for skill: String in build:
		for rank_value: int in range(build[skill]): State.learn(skill)
	State.run.floors[str(number)]=data;State.run.position=data.entry
	spell=State.run.active
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.player.qa_controlled=true
	world.died.connect(func()->void:deaths=true)
	case_damage=0;last_hp=State.run.hp;ticks=0;frozen_ticks=0;living_ticks=0;deaths=false
	move_mode=mode;pos_start=world.player.position
	start_count=world.enemies.size()
	preferred_range=255 if spell=="ice" else 340
	# Disable cosmetic updates only. Player, enemy, spell and world physics remain live.
	for actor: Node in world.actors.get_children():
		if actor is TowerEnemy: actor.visual.set_process(false)
	world.player.visual.set_process(false)
	for child: Node in world.get_children():
		if child is DungeonFog or child is WorldAtmosphere: child.set_process(false)
	world.effects.set_process(false)

func run_case(seconds: int) -> Dictionary:
	for tick: int in range(seconds*60):
		if deaths: break
		var target: TowerEnemy=world.combat.nearest(world.player.position,2000)
		if target==null:
			for e: TowerEnemy in world.enemies:
				if e.is_targetable(): target=e;break
		if target==null: break
		var origin: Vector2=world.player.position
		world.player.aim=origin.direction_to(target.position)
		world.player.qa_fire=true
		world.player.qa_direction=Vector2.ZERO
		if move_mode=="kite":
			var distance: float=origin.distance_to(target.position)
			var wish: Vector2=-world.player.aim if distance<preferred_range else world.player.aim if distance>preferred_range+80 else world.player.aim.orthogonal()
			for rotation: float in [0.0,0.65,-0.65,1.3,-1.3,2.0,-2.0,3.14]:
				var direction: Vector2=wish.rotated(rotation)
				if world.dungeon.walkable(origin+direction*60,20): world.player.qa_direction=direction;break
		if not target.dead:
			living_ticks+=1
			if target.frozen>0: frozen_ticks+=1
		await get_tree().physics_frame
		ticks+=1
		if not deaths:
			case_damage+=maxf(0,last_hp-float(State.run.hp));last_hp=State.run.hp
	var result: Dictionary={"spell":spell,"mode":move_mode,"cleared":world.enemies.filter(func(e:TowerEnemy)->bool:return e.is_targetable()).is_empty(),"died":deaths,"seconds":snappedf(ticks/60.0,0.01),"damage_taken":snappedf(case_damage,0.1),"hp_end":0.0 if deaths else snappedf(State.run.hp,0.1),"mana_end":snappedf(State.run.mp,0.1),"enemies":start_count,"frozen_fraction":snappedf(float(frozen_ticks)/maxi(1,living_ticks),0.001),"distance_moved":world.player.position.distance_to(pos_start),"level_end":State.run.level,"fatal_hit_excluded_from_damage":deaths,"remaining_hp":world.enemies.reduce(func(total:float,e:TowerEnemy)->float:return total+e.hp,0.0)}
	world.queue_free();await get_tree().process_frame;await get_tree().process_frame
	return result

func run_all() -> void:
	for kind: String in ["king","plague","demon","lich"]:
		var number: int={"king":4,"plague":8,"demon":11,"lich":13}[kind]
		for stun: int in [0,1]:
			var build: Dictionary={"lightning":1}
			if stun: build.stun=1
			load_case(base_arena(number,kind),build,number,910,"stand")
			var result: Dictionary=await run_case(180)
			result.test="boss";result.boss=kind;result.stun=stun;results.append(result)
			print("CASE ",JSON.stringify(result))
	for seed_value: int in [41,829,20261007]:
		for type: String in ["crossfire","pursuit","ward","ambush"]:
			for primary: String in ["missile","ice","lightning"]:
				for mode: String in ["stand","kite"]:
					var data: Dictionary=Dungeon.generate(seed_value,1)
					var encounter: Dictionary=data.encounters.filter(func(e:Dictionary)->bool:return e.type==type)[0]
					var index: int=int(encounter.room)
					data.enemies=data.enemies.filter(func(e:Dictionary)->bool:return int(e.get("encounter_room",-1))==index and not e.get("trial",false))
					# Start at the real room threshold reached from its entry path.
					var dungeon: Dungeon=Dungeon.new();dungeon.build(data)
					var center: Vector2=Dungeon.to_world(Dungeon.room_center(data.rooms[index]))
					var route: PackedVector2Array=dungeon.path(Dungeon.vec(data.entry),center)
					for point: Vector2 in route:
						if dungeon.room_at(point)==index: data.entry=Dungeon.pair(point);break
					dungeon.free()
					load_case(data,{primary:1},1,seed_value,mode)
					var result: Dictionary=await run_case(45)
					result.test="encounter";result.type=type;result.seed=seed_value;results.append(result)
					print("CASE ",JSON.stringify(result))
	var out: Dictionary={"cases":results,"elapsed_wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"simulated_seconds":results.reduce(func(total:float,r:Dictionary)->float:return total+r.seconds,0.0),"method":"Actual physics at 60 ticks/sec via fixed-fps, no invulnerability, no mana refill, no gear, no potions, no upgrades during an encounter. Isolated generated groups at actual room entrances; boss duels in a rectangular arena. Builds are explicit test presets, not natural campaign progression. Auto aim; kite uses simple wall-aware retreat without reading projectile paths."}
	var file: FileAccess=FileAccess.open("res://outputs/balance/combat-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(out,"\t"));file.close()
	print("AUDIT_DONE ",out.elapsed_wall_seconds," wall sec, ",out.simulated_seconds," sim sec")
	Sound.stop_all();get_tree().quit()
