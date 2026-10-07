extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_balance.json"
	call_deferred("run_all")

func make_enemy(kind: String) -> TowerEnemy:
	var enemy: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	enemy.setup(world,{"id":"balance_target","kind":kind,"pos":Dungeon.pair(world.player.position+Vector2(300,0)),"hp":-1.0,"dead":false})
	world.actors.add_child(enemy);world.enemies.append(enemy)
	enemy.set_physics_process(false);enemy.active=true
	return enemy

func remove_enemy(enemy: TowerEnemy) -> void:
	world.enemies.erase(enemy);enemy.free()
	for shot: Node in world.shots.get_children(): shot.free()
	world.zones.clear()

func run_all() -> void:
	State.fresh(829);State.learn("lightning");State.run.floor=1
	var data: Dictionary=Dungeon.generate(829,1)
	data.enemies=[];data.props=[];data.encounters=[]
	State.run.floors["1"]=data
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.set_physics_process(false)
	var regular: TowerEnemy=make_enemy("skeleton")
	regular.freeze(3)
	var guard: float=regular.freeze_guard
	regular.freeze(10)
	check(regular.frozen==3 and regular.freeze_guard==guard,"A second freeze source cannot extend an existing freeze")
	regular._physics_process(3)
	check(regular.frozen==0 and is_equal_approx(regular.freeze_guard,TowerEnemy.FREEZE_RECOVERY),"Thawing leaves a full recovery window")
	regular.freeze(10)
	check(regular.frozen==0,"Ritual freeze cannot bypass recovery from another source")
	regular._physics_process(TowerEnemy.FREEZE_RECOVERY+0.01)
	regular.freeze(3)
	check(regular.frozen==3,"Long ritual freeze works again after recovery")
	remove_enemy(regular)
	for fps: int in [30,60,144]:
		var boss: TowerEnemy=make_enemy("king")
		boss.freeze(20)
		check(boss.frozen==0.35,"Boss keeps its duration cap at %d FPS"%fps)
		boss.frozen=0;boss.freeze_guard=0
		var frozen_frames: int=0
		for tick: int in range(fps*12):
			# Simulate continuous Blizzard plus high-rank Stun and ritual attempts.
			boss.freeze(0.09);boss.freeze(0.85)
			if boss.frozen>0: frozen_frames+=1
			boss._physics_process(1.0/fps)
		check(float(frozen_frames)/(fps*12)<0.12,"Repeated freeze leaves bosses free to act at %d FPS"%fps)
		check(boss.phase>=2,"Boss actually releases multiple attacks under repeated freeze at %d FPS"%fps)
		boss.chill(10,0.1)
		check(boss.slow_factor==0.65,"Boss slow is capped independently of freeze")
		boss.frozen=0;boss.freeze_guard=0;boss.telegraph=0;boss.cooldown=1
		boss._physics_process(0.2)
		check(is_equal_approx(boss.cooldown,0.8),"Chill cannot slow down the boss attack cooldown")
		remove_enemy(boss)
	regular=make_enemy("skeleton")
	State.run.skills={"ice":1,"lightning":1,"stun":4};State.learn("blizzard")
	world.player.aim=Vector2.RIGHT
	world.combat.channel(world.player,world.combat.profile("blizzard"),0.001)
	check(is_equal_approx(regular.frozen,0.37),"Blizzard and Stun combine into one strongest freeze instead of discarding the upgrade")
	remove_enemy(regular)
	State.run.skills={"lightning":1}
	var charger: TowerEnemy=make_enemy("ghoul")
	check(charger.hp/world.combat.profile("lightning").damage>0.75,"Full-health charger survives its warning against starting Lightning")
	remove_enemy(charger)
	var levels: Array=[]
	for seed_value: int in range(20):
		var total_xp: float=0
		var first_xp: float=0
		for number: int in range(1,14):
			var floor_value: Dictionary=Dungeon.generate(seed_value,number)
			for encounter: Dictionary in floor_value.encounters:
				var pack: Array=floor_value.enemies.filter(func(e:Dictionary)->bool:return int(e.get("encounter_room",-1))==int(encounter.room) and not e.get("trial",false))
				var expected: int={"quiet":0,"swarm":8,"duel":2,"artillery":3+(1 if number>=5 else 0)+(1 if number>=9 else 0)}.get(encounter.type,4+(1 if number>=5 else 0)+(1 if number>=9 else 0))
				check(pack.size()==expected,"New encounters match their tactical composition")
				var cells: Dictionary={}
				for enemy: Dictionary in pack: cells[str(enemy.pos)]=true
				check(cells.size()==pack.size(),"Pack members never spawn on the same tile")
				if encounter.type=="ward":
					var warden: Dictionary=pack[0]
					check(pack.all(func(e:Dictionary)->bool:return Dungeon.vec(e.pos).distance_to(Dungeon.vec(warden.pos))<260),"Warden begins within protection range of every guard")
			for enemy: Dictionary in floor_value.enemies:
				if enemy.get("trial",false): continue
				var is_boss: bool=Catalog.definition(enemy.kind).values.behavior.begins_with("boss")
				total_xp+=EncounterRules.kill_xp(number,is_boss)*float(enemy.get("xp_scale",1.0))
			if number==1: first_xp=total_xp
		var level: int=level_for_xp(first_xp)
		check(level>=3 and level<=5,"First floor grants fewer early upgrades even in large layouts")
		level=level_for_xp(total_xp);levels.append(level)
		check(level>=30,"Regular campaign rewards still reach major-skill unlocks without optional trials")
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	var report: Dictionary={"checks":checks,"failures":failures,"campaign_levels":levels,"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/balance")
	var file: FileAccess=FileAccess.open("res://outputs/balance/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BALANCE_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)

func level_for_xp(amount: float) -> int:
	var level: int=1
	while amount>=State.xp_threshold(level):
		amount-=State.xp_threshold(level);level+=1
	return level

func visual_checks() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	State.run.skills={"lightning":1,"stun":1,"ice":1,"chill":1,"freeze":1}
	State.run.active="lightning"
	var layer: CanvasLayer=CanvasLayer.new();add_child(layer)
	var grimoire: GrimoireView=GrimoireView.new();layer.add_child(grimoire)
	grimoire.chapter="passive";grimoire.selected_id="stun";grimoire.refresh_list()
	for viewport: Vector2i in [Vector2i(1440,900),Vector2i(960,600)]:
		DisplayServer.window_set_size(viewport)
		for i: int in range(12): await get_tree().process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://outputs/balance")
		get_viewport().get_texture().get_image().save_png("res://outputs/balance/stun-rules-%dx%d.png"%[viewport.x,viewport.y])
	layer.queue_free()
