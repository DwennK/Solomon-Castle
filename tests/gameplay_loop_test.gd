extends Node
var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var main: Node
var kinds: Dictionary = {}
var encounters: Dictionary = {}

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_gameplay_loop.json"
	call_deferred("run_all")

func freeze() -> void:
	world.set_physics_process(false);world.player.set_physics_process(false);world.player.qa_controlled=true
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func load_empty(number: int = 1) -> void:
	var data: Dictionary = Dungeon.generate(872,number)
	data.enemies=[];data.encounters=[];data.props=[];data.boss="";data.gate_open=true;data.gate_cells=[]
	State.run.floors[str(number)]=data
	world.load_floor(number);freeze()

func add_discovery(kind: String) -> WorldProp:
	var record: Dictionary = {"id":"qa_"+kind,"kind":kind,"pos":Dungeon.pair(world.player.position+Vector2(48,0)),"opened":false,"phase":"idle","room":0}
	world.floor_data.props.append(record);world.add_prop(record)
	return world.props[-1]

func run_all() -> void:
	for seed_value: int in range(25):
		for number: int in range(1,14):
			var data: Dictionary = Dungeon.generate(seed_value,number)
			var consecutive: int = 0
			for encounter: Dictionary in data.encounters:
				encounters[encounter.type]=true
				var pack: Array = data.enemies.filter(func(e: Dictionary)->bool:return int(e.get("encounter_room",-1))==int(encounter.room) and not e.get("trial",false))
				consecutive=0 if encounter.type=="quiet" else consecutive+1
				check(consecutive<=2,"Calm room interrupts long strings of combat")
				check(pack.is_empty() if encounter.type=="quiet" else not pack.is_empty(),"Encounter population matches its purpose")
				var positions: Dictionary={}
				for e: Dictionary in pack: positions[str(e.pos)]=true
				check(positions.size()==pack.size(),"Distinct spawn tiles for every pack")
			var discoveries: int = 0
			for prop: Dictionary in data.props:
				if prop.kind in DiscoveryRules.KINDS: kinds[prop.kind]=true;discoveries+=1
			check(discoveries==1,"One unpredictable optional destination per floor")
			check(JSON.stringify(data)==JSON.stringify(Dungeon.generate(seed_value,number)),"New generation remains deterministic")
	check(kinds.size()==5 and encounters.size()==8,"All discovery and encounter variants occur across seeds")
	State.fresh(872);State.learn("missile");State.run.floor=1
	world=load("res://scenes/world.tscn").instantiate();add_child(world);load_empty()
	world.use_portal();world.update_portal(1)
	check(not world.village and world.portal_remaining>0,"Portal cannot escape instantly")
	world.player.invulnerable=0;world.player.take_damage(1)
	check(world.portal_remaining==0 and not world.village,"Damage interrupts portal")
	world.use_portal();world.player.position.x+=8;world.update_portal(0.1)
	check(world.portal_remaining==0,"Movement interrupts portal")
	world.use_portal();world.player.qa_fire=true;world.player._physics_process(0.01);world.player.qa_fire=false
	check(world.portal_remaining==0,"Casting interrupts portal")
	world.player.velocity=Vector2.ZERO
	world.use_portal();var pos: Vector2=world.player.position
	world.update_portal(GameWorld.PORTAL_DURATION)
	check(world.village,"Completing the channel reaches village")
	world.enter_tower();freeze()
	check(world.player.position.distance_to(pos)<2,"Return restores position")
	State.run.level=3
	var archive: WorldProp=add_discovery("archive")
	world.pending_discovery=archive
	check(world.resolve_discovery("lesson") and State.rank("multishot")==1,"Archive grants its advertised signature lesson")
	world.pending_discovery=archive
	check(not world.resolve_discovery("insight"),"Archive cannot grant both choices")
	var altar: WorldProp=add_discovery("oath_altar")
	world.pending_discovery=altar;State.run.hp=1
	check(not world.resolve_discovery("accept") and not altar.record.opened,"Altar cannot kill player or consume refused offer")
	State.run.hp=State.stats().max_hp;var damage: float=State.stats().damage
	check(world.resolve_discovery("accept") and is_equal_approx(State.stats().damage,damage*1.2),"Altar pays health for a real floor damage bonus")
	world.snapshot();State.mark_checkpoint();State.save_game();State.load_game()
	world.load_floor(1,true);freeze()
	check(is_equal_approx(State.stats().damage,damage*1.2),"Floor oath survives save and reload")
	load_empty(2)
	check(is_equal_approx(State.stats().damage,damage),"Floor oath never leaks to another floor")
	var cache: WorldProp=add_discovery("hidden_cache")
	world.dungeon.reveal(world.player.position)
	var drops: int=world.loot.size()
	world.break_urn(cache);world.break_urn(cache)
	check(cache.record.opened and world.loot.size()==drops+1,"Breaking a hidden cache produces exactly one item")
	for element: String in ["missile","fire","ice","lightning"]:
		State.fresh(7);State.learn(element);State.run.level=2;State.run.pending=[2]
		var signature: String={"missile":"multishot","fire":"explode","ice":"cone","lightning":"chain"}[element]
		check(signature in State.offers(),"First level-up offers a visible transformation for "+element)
		check(State.choose(signature) and State.learned_rank(signature)==1,"Signature choice actually changes the learned build")
		check(not State.upgrade_message(signature).is_empty(),"Signature upgrade explains its tactical use")
	State.fresh(872);State.learn("missile");State.run.floor=4;load_empty(4)
	position_in_boss_room()
	for kind: String in ["king","plague","demon","lich"]:
		var record: Dictionary={"id":"qa_"+kind,"kind":kind,"pos":Dungeon.pair(world.player.position+Vector2(0,-128)),"hp":-1.0,"dead":false}
		world.floor_data.enemies.append(record)
		var boss: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
		boss.setup(world,record);world.actors.add_child(boss);world.enemies.append(boss);boss.active=true;boss.set_physics_process(false)
		boss.hp=boss.max_hp*0.49;BossPatterns.update(boss)
		check(BossPatterns.stage(boss)==1 and boss.recovery_time>0,"Half-health transition has a readable recovery: "+kind)
		if kind in ["king","lich"]: check(world.enemies.filter(func(e:TowerEnemy)->bool:return e.record.get("summoned_by","")==record.id).size()==(2 if kind=="king" else 3),"Phase creates the expected finite guards")
		var count: int=world.floor_data.enemies.size();BossPatterns.update(boss)
		check(count==world.floor_data.enemies.size(),"Phase guards cannot duplicate: "+kind)
		boss.attack_target=world.player.position
		boss.phase=1;State.run.difficulty=0
		BossPatterns.release(boss)
		var basic: int=world.shots.get_child_count()
		boss.phase=1;State.run.difficulty=1;BossPatterns.release(boss)
		check(world.shots.get_child_count()>basic*2,"Higher difficulty changes attack composition: "+kind)
		State.run.difficulty=0
		boss.phase=2;BossPatterns.release(boss)
		check(boss.recovery_time>1,"Boss leaves a punish window after a strong attack: "+kind)
		var hp: float=boss.hp;boss.take_damage(10,Vector2.ZERO,true)
		check(is_equal_approx(hp-boss.hp,13),"Exposed boss takes bonus damage: "+kind)
		if kind=="lich":
			boss.hp=boss.max_hp*0.21;BossPatterns.update(boss)
			check(BossPatterns.stage(boss)==2,"Final boss adds a third phase")
		world.snapshot();check(State.save_game() and State.load_game(),"Boss test save is valid")
		var saved: Array=State.run.floors["4"].enemies.filter(func(e:Dictionary)->bool:return e.id==record.id)
		check(not saved.is_empty() and saved[0].boss_stage==BossPatterns.stage(boss),"Boss phase survives actual save reload: "+kind)
		world.enemies.erase(boss);boss.queue_free()
		for shot: Node in world.shots.get_children(): shot.free()
		world.zones.clear()
	persistence_checks()
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	var report: Dictionary={"checks":checks,"failures":failures,"discovery_kinds":kinds.keys(),"encounter_types":encounters.keys(),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/gameplay-loop")
	var file: FileAccess=FileAccess.open("res://outputs/gameplay-loop/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("GAMEPLAY_LOOP_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)

func persistence_checks() -> void:
	State.fresh(872);State.learn("missile");State.run.floor=4;load_empty(4)
	position_in_boss_room()
	var record: Dictionary={"id":"boss","kind":"lich","pos":Dungeon.pair(world.player.position+Vector2(0,-128)),"hp":-1.0,"dead":false}
	world.floor_data.enemies.append(record)
	var boss: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	boss.setup(world,record);world.actors.add_child(boss);world.enemies.append(boss)
	boss.active=true;boss.hp=boss.max_hp*0.21;BossPatterns.update(boss)
	world.snapshot();check(State.save_game() and State.load_game(),"Final phase saves before recreating the world")
	world.load_floor(4,true);freeze()
	boss=world.enemies.filter(func(e:TowerEnemy)->bool:return e.boss)[0]
	boss.active=true;BossPatterns.update(boss)
	check(BossPatterns.stage(boss)==2 and world.enemies.size()==7,"Reload reconstructs final phase and exactly six finite guards")
	for guard: TowerEnemy in world.enemies:
		if not guard.boss: check(guard.record.get("xp_scale",1.0)==0 and guard.record.get("reward",{}).is_empty(),"Reloaded summons cannot farm XP or loot")
	var data: Dictionary
	for seed_value: int in range(100):
		data=Dungeon.generate(seed_value,1)
		if data.props.any(func(p:Dictionary)->bool:return p.kind=="cursed_cache"): break
	State.fresh(872);State.learn("missile");State.run.floor=1;State.run.floors["1"]=data
	world.load_floor(1);freeze()
	var cache: WorldProp=world.props.filter(func(p:WorldProp)->bool:return p.record.kind=="cursed_cache")[0]
	world.player.position=cache.position;world.dungeon.reveal(cache.position)
	world.use_discovery(cache)
	check(world.enemies.filter(func(e:TowerEnemy)->bool:return e.record.get("trial",false) and e.record.get("awakened",false)).size()==4,"Cursed cache awakens all four sentries")
	world.snapshot();check(State.save_game() and State.load_game(),"Active trial saves successfully")
	world.load_floor(1,true);freeze()
	cache=world.props.filter(func(p:WorldProp)->bool:return p.record.kind=="cursed_cache")[0]
	check(cache.record.phase=="active","Cursed trial remains active after reload")
	for guard: TowerEnemy in world.enemies.duplicate():
		if guard.record.get("trial",false): guard.take_damage(guard.hp+1,Vector2.ZERO,true)
	check(cache.record.phase=="ready","Defeating reloaded sentries releases the cursed cache")
	var drops: int=world.loot.size()
	world.use_discovery(cache);world.use_discovery(cache)
	check(cache.record.opened and world.loot.size()==drops+1,"Cursed cache releases one reward only")
	world.snapshot();check(State.save_game() and State.load_game(),"Claimed trial saves successfully")
	world.load_floor(1,true);freeze()
	cache=world.props.filter(func(p:WorldProp)->bool:return p.record.kind=="cursed_cache")[0]
	drops=world.loot.size();world.use_discovery(cache)
	check(cache.record.opened and world.loot.size()==drops,"Reload cannot reclaim a cursed cache")

func visual_checks() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	State.fresh(872);State.learn("missile");State.run.level=3;State.run.floor=1
	main=load("res://scenes/main.tscn").instantiate();add_child(main);main.start_game()
	world.queue_free();world=main.world;load_empty()
	var archive: WorldProp=add_discovery("archive")
	world.pending_discovery=archive;main.show_discovery()
	await capture("archive-choice-1440x900")
	DisplayServer.window_set_size(Vector2i(960,600));await capture("archive-choice-960x600")
	var shard_button: Button
	for candidate: Node in main.find_children("*","Button",true,false):
		if candidate.text.begins_with("Take two Knowledge"): shard_button=candidate
	check(is_instance_valid(shard_button),"Archive exposes a real choice button")
	if shard_button:
		shard_button.pressed.emit()
		check(archive.record.opened and State.run.insight==3,"Archive choice button grants shards and consumes the discovery")
	main.close_modal();DisplayServer.window_set_size(Vector2i(1440,900))
	world.use_portal();world.update_portal(1.0)
	await capture("portal-channel-1440x900")
	world.cancel_portal()
	for kind: String in DiscoveryRules.KINDS:
		load_empty();var prop: WorldProp=add_discovery(kind)
		world.dungeon.reveal(world.player.position);world.camera.reset_smoothing()
		await capture(kind+"-1440x900")

	load_empty(4)
	position_in_boss_room()
	var record: Dictionary={"id":"boss","kind":"king","pos":Dungeon.pair(world.player.position+Vector2(0,-128)),"hp":-1.0,"dead":false}
	world.floor_data.enemies.append(record)
	var boss: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	boss.setup(world,record);world.actors.add_child(boss);world.enemies.append(boss)
	boss.set_physics_process(false);boss.active=true;boss.hp=boss.max_hp*0.49;BossPatterns.update(boss)
	freeze();world.dungeon.reveal(boss.position)
	await capture("boss-second-phase-1440x900")
	DisplayServer.window_set_size(Vector2i(960,600));await capture("boss-second-phase-960x600")

func position_in_boss_room() -> void:
	var room: Array=world.floor_data.rooms[-1]
	world.player.position=TowerLayout.open_position(world.floor_data.grid,room,Dungeon.room_center(room)+Vector2i(0,1))
	world.dungeon.reveal(world.player.position)

func capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/gameplay-loop")
	world.camera.reset_smoothing()
	for i: int in range(12): await get_tree().process_frame
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/gameplay-loop/"+label+".png")
