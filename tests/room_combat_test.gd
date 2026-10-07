extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_room_combat.json"
	call_deferred("run_all")

func freeze_world() -> void:
	world.set_physics_process(false)
	world.player.qa_controlled=true
	world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func fixture() -> Dictionary:
	var data: Dictionary = Dungeon.generate(97,1)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH):
			var room: bool = x>=14 and x<28 and y>=4 and y<18
			var entry: bool = x>=2 and x<7 and y>=7 and y<14
			var corridor: bool = x>=6 and x<14 and y>=9 and y<=11
			row+="." if room or entry or corridor else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[2,7,5,7],[14,4,14,14]]
	data.shapes=["hall","hall"];data.links=[[0,1]];data.optional_room=0
	data.props=[];data.entry=[416,672];data.exit=[1600,672]
	data.encounters=[{"room":1,"type":"crossfire","triggered":false}]
	data.enemies=[]
	for values: Array in [["archer","",[1040,650]],["sorcerer","warden",[1200,800]],["skeleton","flanker",[1000,700]],["ghoul","charger",[1100,680]]]:
		data.enemies.append({"id":values[0],"kind":values[0],"role":values[1],"pos":values[2],"hp":-1.0,"dead":false,"encounter_room":1,"dormant":false,"awakened":false})
	return data

func run_all() -> void:
	for seed_value: int in range(100):
		for number: int in range(1,14):
			var data: Dictionary = Dungeon.generate(seed_value,number)
			var spacious: int = 0
			for i: int in range(1,data.rooms.size()-1):
				var r: Array = data.rooms[i]
				if r[2]>=12 and r[3]>=12:
					spacious+=1
					check(data.shapes[i]=="octagon","Large combat rooms remain clear of interior pillars")
			check(spacious>=2,"Two large combat rooms on every generated floor")
			for record: Dictionary in data.enemies:
				if not record.has("encounter_room"): continue
				check(EncounterRules.inside_combat_area(data,int(record.encounter_room),EncounterRules.home_position(data,record)),"Every pack has an accessible interior anchor")
	State.fresh(97);State.learn("missile");State.run.floor=1
	State.run.floors["1"]=fixture()
	world=load("res://scenes/world.tscn").instantiate();add_child(world);freeze_world()
	world.player.position=Vector2(860,672)
	world._physics_process(0)
	for enemy: TowerEnemy in world.enemies: enemy._physics_process(0.1)
	check(not world.enemies.any(func(e: TowerEnemy)->bool:return e.active),"Visible pack does not aggro from the corridor")
	world.player.position=Vector2(928,672);world._physics_process(0)
	check(not world.floor_data.encounters[0].triggered,"Crossing the threshold alone does not start combat")
	world.player.position=Vector2(1024,672);world._physics_process(0)
	check(world.enemies.all(func(e: TowerEnemy)->bool:return e.active and e.record.awakened and e.wake_time>0),"Entering the room wakes the full pack with warning time")
	var warning: float = world.enemies[0].wake_time
	world.wake_encounter(1)
	check(world.enemies[0].wake_time==warning,"Re-entry never restarts the warning")
	# A real attack from outside must wake the whole pack, including ordinary guards.
	State.run.floors["1"]=fixture();world.load_floor(1,true);freeze_world()
	world.player.position=Vector2(860,672)
	world.enemies[0].take_damage(1)
	check(world.enemies.all(func(e: TowerEnemy)->bool:return e.active and e.record.awakened),"Attacking from the doorway alerts all defenders")
	var archer: TowerEnemy = world.enemies[0]
	var mage: TowerEnemy = world.enemies[1]
	var guard: TowerEnemy = world.enemies[2]
	var hunter: TowerEnemy = world.enemies[3]
	world.player.position=Vector2(650,672)
	check(not EncounterRules.may_pursue(world.floor_data,guard.record,world.player.position) and EncounterRules.may_pursue(world.floor_data,hunter.record,world.player.position),"Only hunters pursue deep into the corridor")
	# Move a melee guard out of its room and verify an actual return, not a teleport.
	guard.position=Vector2(820,710)
	var hp: float = archer.hp
	var hunter_start: float = hunter.position.x
	for enemy: TowerEnemy in world.enemies: enemy.wake_time=0
	for frame: int in range(240):
		world.player.invulnerable=2
		for enemy: TowerEnemy in world.enemies: enemy._physics_process(1.0/60.0)
		check(world.dungeon.room_at(archer.position)==1 and world.dungeon.room_at(mage.position)==1,"Ranged enemies retain their room during a retreat")
		await get_tree().physics_frame
	check(world.dungeon.room_at(guard.position)==1,"Ordinary guard walks back into its room")
	check(hunter.position.x<hunter_start-150,"Hunter really pursues beyond the doorway")
	check(archer.hp==hp,"Retreat never heals or resets a damaged defender")
	# Kill no enemies and reload: encounter activity, health and exact geometry persist.
	world.snapshot();State.mark_checkpoint()
	var grid: Array = world.floor_data.grid.duplicate()
	check(State.save_game() and State.load_game(),"Combat state saves and loads")
	world.load_floor(1,true);freeze_world()
	check(world.floor_data.grid==grid and world.enemies[0].hp==hp and world.enemies[0].active,"Reload preserves floor, damage and awakened defender")
	# A legacy enemy without room metadata retains proximity activation.
	var legacy: TowerEnemy = world.enemies[2]
	legacy.record.erase("encounter_room");legacy.active=false
	world.player.position=legacy.position+Vector2(70,0)
	legacy._physics_process(0)
	check(legacy.active,"Legacy enemies still activate without encounter metadata")
	if "--visual" in OS.get_cmdline_user_args(): await capture_rooms()
	print("ROOM_COMBAT_QA ",JSON.stringify({"checks":checks,"failures":failures,"floors":1300}))
	world.queue_free();Sound.stop_all()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func capture_rooms() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	State.fresh(20261008);State.learn("missile");State.run.floor=1
	world.load_floor(1);freeze_world()
	var layer: CanvasLayer = CanvasLayer.new();add_child(layer)
	var hud: GameHUD = GameHUD.new();hud.world=world;layer.add_child(hud)
	DirAccess.make_dir_recursive_absolute("res://outputs/room-combat")
	var captured: int = 0
	for i: int in range(1,world.floor_data.rooms.size()-1):
		var room: Array = world.floor_data.rooms[i]
		if room[2]<12 or room[3]<12: continue
		world.player.position=EncounterRules.home_position(world.floor_data,{"encounter_room":i})+Vector2(0,130)
		world._physics_process(0);world.camera.reset_smoothing();hud._process(0)
		await get_tree().create_timer(0.3).timeout
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://outputs/room-combat/room-%d-1440x900.png"%i)
		captured+=1
		if captured==2: break
	layer.queue_free()
	await get_tree().process_frame
