extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var layouts: Dictionary = {}

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_encounters.json"
	call_deferred("run_all")

func run_all() -> void:
	for seed_value: int in range(30):
		for number: int in [1,4,13]:
			var data: Dictionary = Dungeon.generate(seed_value,number)
			check(data.rooms.size()>=7 and data.rooms.size()<=12,"Variable room count in supported range")
			check(data.links.size()>=data.rooms.size()+1,"Every new floor contains multiple graph loops")
			var degrees: Array = [];degrees.resize(data.rooms.size());degrees.fill(0)
			for edge: Array in data.links: degrees[edge[0]]+=1;degrees[edge[1]]+=1
			check(degrees.max()>=3,"Every floor has branching routes")
			check(degrees[data.optional_room]==1,"Optional encounter occupies a leaf of the room graph")
			var roles: Dictionary = {}
			for enemy: Dictionary in data.enemies: roles[enemy.get("role","")]=true
			check(roles.has("charger") and roles.has("warden") and roles.has("flanker"),"Authored encounters include different tactical roles")
			check(data.props.any(func(p: Dictionary)->bool:return p.kind=="reliquary"),"Optional reward retained by loot preparation")
			check(data.props.any(func(p: Dictionary)->bool:return p.kind=="blood_font"),"Health/mana trade retained by loot preparation")
			var nav: AStarGrid2D = AStarGrid2D.new()
			nav.region=Rect2i(0,0,Dungeon.WIDTH,Dungeon.HEIGHT)
			nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;nav.update()
			var side: Array = data.rooms[data.optional_room]
			var avoid: Rect2i = Rect2i(side[0],side[1],side[2],side[3])
			for y: int in range(Dungeon.HEIGHT):
				for x: int in range(Dungeon.WIDTH): nav.set_point_solid(Vector2i(x,y),data.grid[y][x]!="." or avoid.has_point(Vector2i(x,y)))
			check(not nav.get_id_path(Vector2i(Dungeon.vec(data.entry)/Dungeon.CELL),Vector2i(Dungeon.vec(data.exit)/Dungeon.CELL)).is_empty(),"Exit remains reachable without entering the optional trial room")
			if not data.boss.is_empty():
				for cell: Array in data.gate_cells: nav.set_point_solid(Vector2i(cell[0],cell[1]),true)
				var chest: Dictionary = data.props.filter(func(p: Dictionary)->bool:return p.id==data.key_chest)[0]
				check(not nav.get_id_path(Vector2i(Dungeon.vec(data.entry)/Dungeon.CELL),Vector2i(Dungeon.vec(chest.pos)/Dungeon.CELL)).is_empty(),"Key is accessible without visiting the trial or crossing the boss seal")
				if number==13:
					var guardian: Dictionary = data.enemies.filter(func(e: Dictionary)->bool:return e.id=="guardian")[0]
					check(not nav.get_id_path(Vector2i(Dungeon.vec(data.entry)/Dungeon.CELL),Vector2i(Dungeon.vec(guardian.pos)/Dungeon.CELL)).is_empty(),"Required guardian never occupies the optional detour")
			layouts[JSON.stringify(data.grid).sha256_text()]=true
	check(layouts.size()==90,"Ninety distinct floor plans across seeds and depths")
	State.fresh(20261007);State.learn("missile")
	State.run.floor=1
	world=load("res://scenes/world.tscn").instantiate()
	add_child(world)
	freeze()
	var ambushers: Array = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("dormant",false) and not e.record.get("trial",false))
	var ambush_room: int = int(ambushers[0].record.encounter_room)
	check(not ambushers[0].record.awakened,"Ambushers begin dormant")
	world.player.position=Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[ambush_room]))
	world._physics_process(0)
	check(ambushers[0].record.awakened and ambushers[0].wake_time>0.8,"Entering an ambush room wakes sentries with a grace period")
	ambushers[0]._physics_process(0.2)
	var warning_left: float = ambushers[0].wake_time
	world.wake_encounter(ambush_room)
	check(ambushers[0].wake_time==warning_left,"Room re-entry does not restart an ambush")
	var trial: WorldProp = discovery("reliquary")
	var font: WorldProp = discovery("blood_font")
	var sentries: Array = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("trial",false))
	check(sentries.size()==3,"Three finite optional sentries")
	for enemy: TowerEnemy in sentries:
		var hp: float = enemy.hp
		enemy.take_damage(10000)
		check(enemy.hp==hp and not enemy.is_targetable() and enemy.collision_layer==0,"Sleeping trial statues neither fight nor block projectiles or movement")
	var count: int = world.loot.size()
	world.player.position=trial.position+Vector2(0,50)
	world._physics_process(0) # Reveal the room after the simulated player movement.
	check(world.closest_prop()==trial,"Optional trial is reachable by normal interaction")
	world.interact()
	check(trial.record.phase=="active" and world.loot.size()==count,"Accepting trial gives no immediate reward")
	for enemy: TowerEnemy in sentries: check(enemy.is_targetable() and enemy.wake_time>0,"Trial wakes its sentries with a warning")
	world.use_discovery(trial)
	check(world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("trial",false)).size()==3,"Repeated interaction never duplicates sentries")
	world.snapshot();State.mark_checkpoint()
	check(State.save_game() and State.load_game(),"Active trial saves and loads")
	var saved_grid: Array = State.run.floors["1"].grid.duplicate()
	world.load_floor(0);freeze();world.load_floor(1);freeze()
	trial=discovery("reliquary");font=discovery("blood_font")
	check(world.floor_data.encounters.any(func(e: Dictionary)->bool:return int(e.room)==ambush_room and e.triggered),"Triggered ambush remains triggered after save and return")
	check(trial.record.phase=="active" and world.floor_data.grid==saved_grid,"Returning preserves trial state and exact floor geometry")
	for enemy: TowerEnemy in world.enemies.duplicate():
		if enemy.record.get("trial",false): enemy.take_damage(100000)
	check(trial.record.phase=="ready","Last sentry death unlocks reward")
	count=world.loot.size()
	world.use_discovery(trial)
	check(trial.record.opened and world.loot.size()==count+1,"Claim releases exactly one equipment item")
	check(world.loot[-1].item.rarity>=1,"Optional trial reward is at least rare")
	world.use_discovery(trial)
	check(world.loot.size()==count+1,"Claim cannot be repeated")
	State.run.hp=1;State.run.mp=0
	world.use_discovery(font)
	check(State.run.hp==1 and not font.record.opened,"Blood font cannot kill the player or consume itself on refusal")
	State.run.hp=State.stats().max_hp;State.run.mp=0
	world.use_discovery(font)
	check(is_equal_approx(State.run.hp,State.stats().max_hp*0.8) and State.run.mp==State.stats().max_mana,"Font trades exactly 20 percent max health for mana")
	State.run.mp=0;var remaining_hp: float = State.run.hp
	world.use_discovery(font)
	check(State.run.mp==0 and State.run.hp==remaining_hp,"Font cannot be reused")
	world.snapshot();State.mark_checkpoint();State.save_game();State.load_game()
	State.die();world.load_floor(1,true);freeze()
	check(discovery("reliquary").record.opened and discovery("blood_font").record.opened,"Claimed discoveries survive checkpoint restore")
	check(not world.enemies.any(func(e: TowerEnemy)->bool:return e.record.get("trial",false)),"Dead sentries never resurrect after claiming")
	# Legacy floors remain intact; only newly generated floors use the new layout.
	State.run.floors["1"].erase("layout_version")
	world.snapshot();State.save_game();State.load_game();world.load_floor(1,true);freeze()
	check(world.floor_data.grid==saved_grid and not world.floor_data.has("layout_version"),"Existing floor geometry is not regenerated on load")
	await combat_checks()
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	var report: Dictionary = {"checks":checks,"failures":failures,"distinct_layouts":layouts.size(),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/encounters")
	var file: FileAccess = FileAccess.open("res://outputs/encounters/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ENCOUNTER_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)

func discovery(kind: String) -> WorldProp:
	for prop: WorldProp in world.props:
		if prop.record.kind==kind: return prop
	return null

func freeze() -> void:
	world.set_physics_process(false)
	world.player.qa_controlled=true
	world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func combat_checks() -> void:
	State.fresh(99);State.learn("missile");State.run.floor=1
	# Real collision arena, kept separate from procedural reachability tests.
	var data: Dictionary = Dungeon.generate(99,1)
	var tiles: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row += "." if x>=3 and x<=22 and y>=3 and y<=18 else "#"
		tiles.append(row)
	data.grid=tiles;data.rooms=[[3,3,20,16]];data.props=[];data.encounters=[]
	data.entry=[700,700];data.exit=[800,700];data.enemies=[]
	for values: Array in [["charger","ghoul",[500,700]],["warden","sorcerer",[650,650]],["flanker","skeleton",[760,650]]]:
		data.enemies.append({"id":values[0],"kind":values[1],"role":values[0],"pos":values[2],"hp":-1.0,"dead":false})
	State.run.floors["1"]=data
	world.load_floor(1);freeze()
	var charger: TowerEnemy = world.enemies[0]
	var warden: TowerEnemy = world.enemies[1]
	var guard: TowerEnemy = world.enemies[2]
	check(world.protection_for(guard)==0.45 and world.protection_for(warden)==0,"Warden protects nearby allies but never itself")
	var hp: float = guard.hp
	guard.take_damage(10)
	check(is_equal_approx(hp-guard.hp,5.5),"Aura actually reduces incoming damage")
	warden.take_damage(10000)
	check(world.protection_for(guard)==0,"Killing the priority target immediately removes protection")
	guard.take_damage(10000)
	world.player.position=Vector2(730,700);world.player.velocity=Vector2(220,0)
	charger.cooldown=0;charger._physics_process(1.0/60)
	check(charger.preparing_charge and charger.telegraph>0.7,"Charge starts with a readable warning")
	var locked: Vector2 = charger.attack_target
	world.player.position.y+=150
	for i: int in range(48): charger._physics_process(1.0/60);await get_tree().physics_frame
	check(charger.attack_target==locked and charger.charge_time>0,"Charge direction does not home after the warning")
	hp=State.run.hp
	for i: int in range(65): charger._physics_process(1.0/60);await get_tree().physics_frame
	check(State.run.hp==hp,"A lateral dodge avoids the charge")
	charger.position=Vector2(500,700);charger.charge_time=0;charger.recovery_time=0;charger.cooldown=0
	world.player.position=Vector2(730,700);world.player.velocity=Vector2(220,0);world.player.invulnerable=0
	hp=State.run.hp
	for i: int in range(105):
		world.player.position.x+=220.0/60.0
		charger._physics_process(1.0/60)
		await get_tree().physics_frame
	check(State.run.hp<hp,"Straight backward kiting can be caught by a committed charge")
	charger.position=Vector2(500,700);charger.charge_time=0.5;charger.fear=2
	charger._physics_process(1.0/60)
	check(charger.charge_time==0,"Crowd control interrupts charging")

func visual_checks() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	State.fresh(20261007);State.learn("missile");State.run.floor=1
	world.load_floor(1);freeze()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var hud: GameHUD = GameHUD.new()
	hud.world=world;layer.add_child(hud)
	world.player.position=discovery("reliquary").position+Vector2(0,80)
	world._physics_process(0)
	world.camera.reset_smoothing()
	await capture("reliquary-1440x900")
	world.use_discovery(discovery("reliquary"))
	await capture("trial-awakening-1440x900")
	var charger: TowerEnemy = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("trial",false))[0]
	charger.position=world.player.position+Vector2(-210,0);charger.wake_time=0;charger.cooldown=0
	charger._physics_process(1.0/60)
	await capture("charge-warning-1440x900")
	DisplayServer.window_set_size(Vector2i(960,600))
	await capture("charge-warning-960x600")
	DisplayServer.window_set_size(Vector2i(1440,900))
	var warden: TowerEnemy = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("role","")=="warden")[0]
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(world.floor_data.rooms[int(warden.record.encounter_room)]))
	world.player.position=center+Vector2(0,120);warden.position=center-Vector2(100,80)
	var guard: TowerEnemy = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("role","")=="flanker" and not e.record.get("trial",false))[0]
	guard.position=center+Vector2(110,-20);guard.warded=true;guard.queue_redraw()
	world.camera.reset_smoothing()
	await capture("warden-1440x900")
	hud.hide()
	DisplayServer.window_set_size(Vector2i(1440,900))
	var atlas: Control = Control.new()
	layer.add_child(atlas)
	atlas.draw.connect(func()->void:
		atlas.draw_rect(Rect2(0,0,1440,900),Color("10151c"))
		var font: Font = ThemeDB.fallback_font
		atlas.draw_string(font,Vector2(32,40),"THE TOWER OF ASH — SIX GENERATED FLOORS",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e3d4af"))
		atlas.draw_string(font,Vector2(32,70),"Green: entry   Gold: stairs   Violet: optional trial   Red: blood font",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b7bcc5"))
		for i: int in range(6):
			var data: Dictionary = Dungeon.generate(18+i*971,1+i*2)
			var origin: Vector2 = Vector2(35+(i%3)*472,130+(i/3)*382)
			atlas.draw_string(font,origin-Vector2(0,12),"Seed %d · floor %d · %d rooms"%[18+i*971,1+i*2,data.rooms.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e3d4af"))
			for y: int in range(Dungeon.HEIGHT):
				for x: int in range(Dungeon.WIDTH):
					if data.grid[y][x]==".": atlas.draw_rect(Rect2(origin+Vector2(x,y)*6,Vector2(5.5,5.5)),Color("637786"))
			atlas.draw_circle(origin+Dungeon.vec(data.entry)/Dungeon.CELL*6,5,Color("83e7b3"))
			atlas.draw_circle(origin+Dungeon.vec(data.exit)/Dungeon.CELL*6,5,Color("ffcf71"))
			for prop: Dictionary in data.props:
				if prop.kind in ["reliquary","blood_font"]: atlas.draw_circle(origin+Dungeon.vec(prop.pos)/Dungeon.CELL*6,5,Color("c6a4eb") if prop.kind=="reliquary" else Color("ed7b81"))
	)
	atlas.queue_redraw()
	await capture("layout-atlas-1440x900")
	layer.queue_free()

func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/encounters")
	world._physics_process(0)
	for i: int in range(12): await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/encounters/"+label+".png")
