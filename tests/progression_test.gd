extends Node

var checks: int = 0
var failures: Array[String] = []
var ranges: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func level_for(amount: float) -> int:
	var level: int=1
	while amount>=ProgressionRules.threshold(level):
		amount-=ProgressionRules.threshold(level);level+=1
	return level

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_progression.json"
	call_deferred("run_all")

func run_all() -> void:
	for difficulty: int in range(5):
		for seed_value: int in range(20):
			var xp: float=0
			var trial_xp: float=0
			for number: int in range(1,14):
				var data: Dictionary=Dungeon.generate(seed_value,number,difficulty)
				var regular: float=0
				var optional: float=0
				for enemy: Dictionary in data.enemies:
					if enemy.get("trial",false): optional+=enemy.xp_reward
					else: regular+=enemy.xp_reward
				check(is_equal_approx(regular,data.xp_budget),"Floor budget is conserved, including boss and guardian")
				check(is_equal_approx(optional,data.xp_budget*0.08),"Trials add a bounded bonus")
				var before: Array=data.enemies.duplicate(true)
				data.enemies[0].dead=true
				ProgressionRules.prepare_floor(data)
				check(data.enemies[0].xp_reward==before[0].xp_reward,"Kills never redistribute the floor budget")
				data.erase("xp_version")
				ProgressionRules.prepare_floor(data)
				check(data.enemies[0].dead and data.enemies[0].xp_reward==before[0].xp_reward,"Legacy migration includes dead enemies without reviving them")
				xp+=regular;trial_xp+=optional
				var level: int=level_for(xp)
				var bounds: Array=ranges.get(str(number),[99,0,99,0])
				bounds=[mini(bounds[0],level),maxi(bounds[1],level),mini(bounds[2],level_for(xp+trial_xp)),maxi(bounds[3],level_for(xp+trial_xp))]
				ranges[str(number)]=bounds
				if number in [1,4,8,11,13]:
					var target: int=int(ProgressionRules.FLOOR_LEVELS[number])
					check(level>=target and level<=target+1,"Milestone stays stable across seeds and difficulties")
			check(level_for(xp+trial_xp)<=38,"Optional content does not overflow the final progression target")
	State.fresh(829,2);State.learn("fire");State.run.level=32;State.run.xp=123
	State.run.gold=999;State.run.wisdom=7;State.run.pending=[32];State.run.offers=["life"]
	State.run.inventory=[State.make_item(9,7)];State.equip(State.run.inventory[0].uid)
	State.run.floors["1"]=Dungeon.generate(829,1,2);State.run.floors["1"].enemies[0].dead=true
	State.run.erase("ascent_version");State.mark_checkpoint();State.save_game()
	check(State.load_game() and State.run.level==32 and State.run.xp==123 and State.rank("fire")>=1,"Loading an existing character never resets progression")
	check(not State.run.has("ascent_version"),"Old NG+ retains its existing scaling until a new ascent")
	check(not State.next_difficulty() and State.run.level==32,"Restart requires a completed ascent")
	State.run.victory=true
	var original: Dictionary=State.run.duplicate(true)
	State.save_path="user://missing_progression_directory/save.json"
	check(not State.next_difficulty() and State.run==original,"Failed save restores the completed character")
	State.save_path="user://qa_progression.json"
	State.unlocked=4
	check(State.next_difficulty(),"Fresh ascent saves successfully")
	check(State.run.difficulty==3 and State.run.level==1 and State.run.xp==0,"Next difficulty resets level and XP")
	check(State.run.skills.is_empty() and State.run.fusion.is_empty() and State.run.secondary.is_empty() and State.run.active.is_empty(),"All learned and fused spells reset")
	check(State.run.inventory.is_empty() and State.run.equipped.values().all(func(uid:String)->bool:return uid.is_empty()),"Equipment resets without ghost equipped references")
	check(State.run.gold==140 and State.run.hp_potions==3 and State.run.mp_potions==3 and State.run.wisdom==0,"Currency, lessons and supplies reset")
	check(State.run.floors.is_empty() and State.run.pending.is_empty() and State.run.offers.is_empty() and State.unlocked==4,"Tower and pending choices reset; difficulty unlocks persist")
	check(State.load_game() and State.run.level==1 and State.checkpoint.level==1,"Save and checkpoint contain the fresh character")
	State.run.victory=true;State.next_difficulty()
	check(State.run.difficulty==4 and State.run.hardcore,"Final difficulty still enforces hardcore")
	State.fresh(829);State.learn("fire");State.run.gold=10000
	for floor_number: int in [1,5,9,13]:
		State.run.deepest=floor_number
		check(State.buy_lesson(),"One lesson becomes available at each milestone")
		var gold: int=State.run.gold
		check(not State.buy_lesson() and State.run.gold==gold,"Gold cannot bypass the lesson milestone limit")
	check(State.run.level==1 and State.run.pending.size()==4,"Lessons grant choices without changing XP or level")
	check(ProgressionRules.health_multiplier(4)<1.5 and ProgressionRules.damage_multiplier(4)<1.5,"Difficulty uses bounded statistics for fresh characters")
	await combat_rules()
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	DirAccess.make_dir_recursive_absolute("res://outputs/progression")
	var report: Dictionary={"checks":checks,"failures":failures,"floors_tested":1300,"level_ranges_regular_then_optional":ranges}
	var file: FileAccess=FileAccess.open("res://outputs/progression/tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PROGRESSION_TEST ",JSON.stringify(report));Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text==caption: return node
	for child: Node in node.get_children():
		var found: Button=find_button(child,caption)
		if found: return found
	return null

func visual_checks() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var main: Node=load("res://scenes/main.tscn").instantiate();add_child(main)
	State.fresh(829);State.learn("fire");main.start_game();State.run.victory=true
	DirAccess.make_dir_recursive_absolute("res://outputs/progression")
	for viewport: Vector2i in [Vector2i(1440,900),Vector2i(960,600)]:
		DisplayServer.window_set_size(viewport);main.show_victory()
		for i: int in range(12): await get_tree().process_frame
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://outputs/progression/victory-%dx%d.png"%[viewport.x,viewport.y])
	var begin: Button=find_button(main.modal,"Start a fresh ascent")
	check(begin!=null,"Victory exposes the fresh ascent action")
	if begin: begin.pressed.emit()
	check(State.run.level==1 and main.modal_kind=="initial" and main.world.village,"Actual victory button reaches a fresh spell choice in the village")
	for i: int in range(12): await get_tree().process_frame
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://outputs/progression/initial-960x600.png")
	main.close_modal();State.learn("fire");main.show_teacher()
	var lesson: Button=find_button(main.modal,"Buy a lesson · 80 gold")
	if lesson: lesson.pressed.emit()
	State.run.gold=10000;main.show_teacher()
	check(find_button(main.modal,"Buy a lesson · 145 gold").disabled,"Teacher disables unavailable lessons")
	for i: int in range(12): await get_tree().process_frame
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://outputs/progression/teacher-960x600.png")
	main.close_modal();main.queue_free();get_tree().paused=false

func combat_rules() -> void:
	State.fresh(829,4);State.learn("fire");State.run.floor=13
	var data: Dictionary=Dungeon.generate(829,13,4);data.enemies=[]
	State.run.floors["13"]=data
	var world: GameWorld=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.set_physics_process(false)
	var value: Dictionary={"id":"boss","kind":"lich","pos":Dungeon.pair(world.player.position+Vector2(150,0)),"hp":-1.0,"dead":false}
	var boss: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	boss.setup(world,value);world.actors.add_child(boss);boss.set_physics_process(false)
	var fresh_hp: float=boss.max_hp
	State.run.erase("ascent_version");boss.setup(world,value)
	check(boss.max_hp>fresh_hp*3,"Legacy NG+ keeps its stronger enemies; fresh builds get the new curve")
	State.run.ascent_version=1
	var hazard_counts: Array=[]
	for difficulty: int in [0,1,3]:
		State.run.difficulty=difficulty;boss.setup(world,value);boss.phase=5;boss.attack_target=world.player.position
		world.zones.clear();boss.release_attack();hazard_counts.append(world.zones.size())
		check(world.zones.all(func(z:Dictionary)->bool:return z.delay>=1.0),"Additional boss hazards retain readable warnings")
	check(hazard_counts[0]<hazard_counts[1] and hazard_counts[1]<hazard_counts[2],"Difficulty adds real boss attacks beyond stat scaling")
	State.run.difficulty=0
	var regular: Dictionary={"id":"regular","kind":"ghoul","pos":[600,600],"hp":-1.0,"dead":false}
	State.run.floor=4;boss.setup(world,regular);var early: float=boss.max_hp
	State.run.floor=13;boss.setup(world,regular)
	check(boss.max_hp>early*3,"Late-floor chargers survive long enough to threaten developed builds")
	regular.elite=true;boss.setup(world,regular)
	check(boss.record.elite and boss.damage>float(Catalog.definition("ghoul").values.damage)*1.84,"Elite record actually increases combat strength")
	world.queue_free();await get_tree().process_frame
