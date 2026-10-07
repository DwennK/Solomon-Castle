extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var captures: Array[String] = []

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_tactical_combat.json"
	call_deferred("run_all")

func freeze_world() -> void:
	world.set_physics_process(false)
	world.player.qa_controlled=true;world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)
	for shot: Node in world.shots.get_children(): shot.set_physics_process(false)

func fixture() -> Dictionary:
	var data: Dictionary = Dungeon.generate(382,5)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row+="." if x>=3 and x<26 and y>=3 and y<19 and Vector2i(x,y)!=Vector2i(11,10) else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[3,3,23,16]];data.shapes=["hall"];data.links=[];data.optional_room=0
	data.entry=[400,700];data.exit=[1500,700];data.enemies=[];data.encounters=[]
	data.props=[{"id":"brazier","kind":"brazier","pos":[900,800],"opened":false,"room":0},{"id":"rest","kind":"rest_font","pos":[500,1000],"opened":false,"room":0}]
	for values: Array in [["hunter","ghoul","charger",""],["caster","sorcerer","artillery","ritualist"],["shield","knight","","bulwark"],["brood","zombie","","brood"]]:
		data.enemies.append({"id":values[0],"kind":values[1],"role":values[2],"elite_kind":values[3],"elite":values[3]!="","pos":[1300,300+data.enemies.size()*150],"hp":-1.0,"dead":false,"encounter_room":0,"awakened":true,"xp_reward":0.0,"reward":{}})
	return data

func reset_fixture() -> void:
	State.fresh(382);State.learn("fire");State.run.floor=5
	State.run.floors["5"]=fixture()
	if not world:
		world=load("res://scenes/world.tscn").instantiate();add_child(world)
	else: world.load_floor(5)
	freeze_world()

func named(id: String) -> TowerEnemy:
	for enemy: TowerEnemy in world.enemies:
		if enemy.record.id==id: return enemy
	return null

func run_all() -> void:
	var affixes: Dictionary = {}
	for seed_value: int in range(50):
		for number: int in range(1,14):
			var data: Dictionary = Dungeon.generate(seed_value,number)
			var tempos: Dictionary = {}
			for encounter: Dictionary in data.encounters:
				tempos[encounter.tempo]=true
				var pack: Array = data.enemies.filter(func(e: Dictionary)->bool:return int(e.get("encounter_room",-1))==int(encounter.room) and not e.get("trial",false))
				if encounter.tempo=="rest": check(pack.is_empty(),"Sanctuary rooms have no initial hostile pack")
				elif encounter.tempo=="skirmish": check(pack.size()==2,"Skirmishes remain short")
				elif encounter.tempo=="setpiece":
					check(pack.size()>=5,"Set pieces have larger complementary groups")
					var room: Array = data.rooms[encounter.room]
					check(room[2]>=12 and room[3]>=12,"Large encounters use spacious rooms")
				if encounter.type=="crossfire":
					check(Dungeon.vec(pack[0].pos).distance_to(Dungeon.vec(pack[1].pos))>=160,"Crossfire archers start on distinct firing lanes")
			check(tempos.has("rest") and tempos.has("skirmish") and tempos.has("pressure") and tempos.has("setpiece"),"Every floor mixes pressure and recovery")
			check(data.props.filter(func(p: Dictionary)->bool:return p.kind=="rest_font").size()==1,"One finite sanctuary per floor")
			var gold: int = 0
			for record: Dictionary in data.enemies: gold+=int(record.get("reward",{}).get("gold",0))
			check(gold==int(data.enemy_gold_budget),"Room pacing preserves the floor enemy gold budget")
			var positions: Dictionary = {}
			for enemy: Dictionary in data.enemies:
				if not enemy.get("elite_kind","").is_empty(): affixes[enemy.elite_kind]=true
				if not enemy.has("encounter_room"): continue
				var pos: String = JSON.stringify(enemy.pos)
				check(not positions.has(pos),"Tactical enemies have separate spawn positions")
				positions[pos]=true
				check(not data.props.any(func(p: Dictionary)->bool:return p.kind=="brazier" and p.pos==enemy.pos),"Braziers do not overlap enemy spawn positions")
			for cover: Array in data.tactical_cover: check(data.grid[cover[1]][cover[0]]=="#","Cover is a real collision and sight obstacle")
	check(affixes.size()==3,"All three elite behaviors appear across normal campaigns")
	reset_fixture()
	var hunter: TowerEnemy = named("hunter")
	hunter.position=Vector2(500,500);world.player.position=Vector2(900,900)
	hunter.charge_time=0.005;hunter.charge_direction=Vector2.LEFT
	hunter._physics_process(1.0/60.0)
	check(hunter.counter_time>1 and hunter.recovery_time>1,"A missed charge opens a counterattack window")
	var hp: float = hunter.hp
	hunter.take_damage(4)
	check(is_equal_approx(hp-hunter.hp,6),"Counterattack window grants 50 percent extra damage")
	hunter._physics_process(1.3)
	check(hunter.counter_time==0,"Counterattack window expires")
	hp=hunter.hp;hunter.take_damage(4)
	check(is_equal_approx(hp-hunter.hp,4),"Ordinary damage returns after the window")
	reset_fixture();hunter=named("hunter")
	hunter.position=Vector2(500,500);world.player.position=Vector2(530,500)
	hunter.charge_time=0.3;hunter.charge_direction=Vector2.RIGHT
	hunter._physics_process(1.0/60)
	check(hunter.counter_time==0,"A charge that hits does not reward a failed dodge")
	reset_fixture()
	var caster: TowerEnemy = named("caster")
	caster.position=Vector2(650,500);world.player.position=Vector2(850,500);caster.cooldown=0
	caster._physics_process(1.0/60)
	check(caster.telegraph>1,"Ritualist marks a long interruptible cast")
	var locked: Vector2 = caster.attack_target
	world.player.position+=Vector2(0,100)
	caster._physics_process(0.1)
	check(caster.attack_target==locked,"Area attack stays committed to its marked position")
	caster.take_damage(caster.max_hp*0.04,Vector2.ZERO,true)
	check(caster.telegraph>0,"Tiny hits alone do not permanently interrupt a caster")
	caster.take_damage(caster.max_hp*0.10)
	check(caster.telegraph==0 and caster.counter_time>1 and world.zones.is_empty(),"Enough damage cancels the cast and exposes its caster")
	caster.recovery_time=0;caster.counter_time=0;caster.cooldown=0;caster._physics_process(0.01);caster._physics_process(1.2)
	check(world.zones.size()==1 and world.zones[0].kind=="hostile","Uninterrupted ritual creates the announced hostile zone")
	reset_fixture()
	var shield: TowerEnemy = named("shield")
	shield.shield_facing=Vector2.RIGHT
	hp=shield.hp;shield.take_damage(8,Vector2.LEFT*10)
	var front: float = hp-shield.hp
	hp=shield.hp;shield.take_damage(8,Vector2.RIGHT*10)
	check(is_equal_approx(hp-shield.hp,front*4),"Flanking bypasses the frontal shield")
	shield.freeze(1);hp=shield.hp;shield.take_damage(8,Vector2.LEFT*10)
	check(is_equal_approx(hp-shield.hp,front*4),"Freezing also disables the frontal shield")
	reset_fixture()
	var brood: TowerEnemy = named("brood")
	brood.take_damage(100000)
	var children: Array = world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("fragment",false))
	check(children.size()==2 and children.all(func(e: TowerEnemy)->bool:return e.wake_time>0.6 and not e.record.elite),"Brood splits into exactly two warned, weaker non-elite children")
	world.split_brood(brood)
	check(world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("fragment",false)).size()==2,"Split cannot be repeated")
	world.snapshot();State.mark_checkpoint();check(State.save_game() and State.load_game(),"Split state saves and loads")
	world.load_floor(5,true);freeze_world()
	check(not named("brood") and world.enemies.filter(func(e: TowerEnemy)->bool:return e.record.get("fragment",false)).size()==2,"Reload restores children without resurrecting or duplicating their parent")
	var xp: float = State.run.xp
	var loot: int = world.loot.size()
	for enemy: TowerEnemy in world.enemies.duplicate():
		if enemy.record.get("fragment",false): enemy.take_damage(100000)
	check(State.run.xp==xp and world.loot.size()==loot,"Fragments never farm extra XP or supplies")
	reset_fixture()
	var brazier: WorldProp = world.props.filter(func(p: WorldProp)->bool:return p.record.kind=="brazier")[0]
	world.spawn_projectile(Vector2(780,800),Vector2.RIGHT,world.combat.profile("fire"))
	var shot: MagicProjectile = world.shots.get_child(0);shot.set_physics_process(false)
	for i: int in range(30):
		if shot.is_queued_for_deletion(): break
		shot._physics_process(1.0/60)
	check(brazier.record.opened and world.zones.size()==1 and world.zones[0].delay>0.6,"A real spell hit ignites a brazier with a readable warning")
	world.break_urn(brazier)
	check(world.zones.size()==1,"A spent brazier never detonates twice")
	hunter=named("hunter");hunter.position=brazier.position+Vector2(50,0);hunter.hp=500
	world.player.position=brazier.position+Vector2(-50,0);world.player.invulnerable=0
	hp=State.run.hp;world.update_zones(0.4)
	check(State.run.hp==hp and hunter.hp==500,"Brazier warning does no immediate damage")
	world.update_zones(0.4);world.update_zones(0.01)
	check(hunter.hp<500 and State.run.hp<hp,"Brazier explosion damages monsters and player")
	var after: float = hunter.hp;world.update_zones(0.01)
	check(hunter.hp==after,"Blast applies once, not once per frame")
	world.snapshot();State.mark_checkpoint();State.save_game();State.load_game();world.load_floor(5,true);freeze_world()
	check(world.props.any(func(p: WorldProp)->bool:return p.record.kind=="brazier" and p.record.opened),"Spent brazier survives save and reload")
	check(not world.dungeon.visible_line(Vector2(650,672),Vector2(820,672)),"Masonry pillar blocks real line of sight")
	world.spawn_projectile(Vector2(650,672),Vector2.RIGHT,world.combat.profile("fire"))
	shot=world.shots.get_child(world.shots.get_child_count()-1);shot.set_physics_process(false)
	for i: int in range(20):
		if shot.is_queued_for_deletion(): break
		shot._physics_process(1.0/60)
	check(shot.is_queued_for_deletion() and shot.position.x<736,"Masonry pillar stops actual projectiles")
	reset_fixture()
	brazier=world.props.filter(func(p: WorldProp)->bool:return p.record.kind=="brazier")[0]
	brazier.position=Vector2(685,672);hunter=named("hunter");hunter.position=Vector2(785,672);hunter.hp=500
	world.break_urn(brazier);world.update_zones(0.8);world.update_zones(0.01)
	check(hunter.hp==500,"Pillar also shields monsters from brazier damage")
	reset_fixture()
	var rest: WorldProp = world.props.filter(func(p: WorldProp)->bool:return p.record.kind=="rest_font")[0]
	world.player.position=rest.position
	world.use_discovery(rest)
	check(not rest.record.opened,"Full resources do not waste the sanctuary")
	State.run.hp=20;State.run.mp=0
	named("hunter").position=rest.position+Vector2(100,0)
	world.use_discovery(rest)
	check(not rest.record.opened and State.run.hp==20,"Nearby active enemies block recovery")
	for enemy: TowerEnemy in world.enemies: enemy.active=false
	world.dungeon.reveal(world.player.position)
	check(world.closest_prop()==rest,"Sanctuary is reachable through normal interaction")
	world.interact()
	check(rest.record.opened and is_equal_approx(State.run.hp,20+State.stats().max_hp*0.2) and is_equal_approx(State.run.mp,State.stats().max_mana*0.4),"Sanctuary restores its bounded health and mana amounts")
	hp=State.run.hp;world.use_discovery(rest)
	check(State.run.hp==hp,"Sanctuary can only be consumed once")
	world.snapshot();State.mark_checkpoint();State.save_game();State.load_game();world.load_floor(5,true);freeze_world()
	check(world.props.any(func(p: WorldProp)->bool:return p.record.kind=="rest_font" and p.record.opened),"Consumed sanctuary persists across reload")
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	var report: Dictionary = {"checks":checks,"failures":failures,"floors":650,"captures":captures}
	DirAccess.make_dir_recursive_absolute("res://outputs/tactical-combat")
	FileAccess.open("res://outputs/tactical-combat/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TACTICAL_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	world.dungeon.reveal(world.player.position);world.camera.reset_smoothing()
	await get_tree().create_timer(0.25).timeout
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://outputs/tactical-combat/"+label+".png")
	captures.append(label)

func visual_checks() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/tactical-combat")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1440,900))
	reset_fixture()
	var layer: CanvasLayer = CanvasLayer.new();add_child(layer)
	var hud: GameHUD = GameHUD.new();hud.world=world;layer.add_child(hud)
	world.player.position=Vector2(930,650)
	named("shield").position=Vector2(700,500);named("shield").shield_facing=Vector2.RIGHT
	named("caster").position=Vector2(1100,470);named("caster").telegraph=0.8;named("caster").attack_target=Vector2(980,650)
	named("brood").position=Vector2(1130,780)
	named("hunter").position=Vector2(680,850);named("hunter").expose(1.2)
	await capture("elite-counterplay-1440x900")
	world.break_urn(world.props.filter(func(p: WorldProp)->bool:return p.record.kind=="brazier")[0])
	await capture("brazier-warning-1440x900")
	world.player.position=Vector2(540,950)
	await capture("sanctuary-1440x900")
	State.fresh(20261008);State.learn("fire");State.run.floor=5
	world.load_floor(5);freeze_world()
	var encounter: Dictionary = world.floor_data.encounters.filter(func(e: Dictionary)->bool:return e.tempo=="setpiece")[0]
	world.player.position=EncounterRules.home_position(world.floor_data,{"encounter_room":encounter.room})+Vector2(0,100)
	world._physics_process(0)
	for frame: int in range(48):
		world.player.invulnerable=2.0
		for enemy: TowerEnemy in world.enemies: enemy._physics_process(1.0/60)
		await get_tree().physics_frame
	await capture("generated-setpiece-1440x900")
	var sanctuary: WorldProp = world.props.filter(func(p: WorldProp)->bool:return p.record.kind=="rest_font")[0]
	world.player.position=sanctuary.position+Vector2(0,60)
	world._physics_process(0)
	await capture("generated-sanctuary-1440x900")
	layer.queue_free();await get_tree().process_frame
