extends Node

var failures: Array[String] = []
var checks: int = 0
var generations: int = 0
var state: Node
var catalog: Node

func _ready() -> void:
	call_deferred("run_all")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		push_error("FAIL: "+text)

func run_all() -> void:
	state = get_tree().root.get_node("State")
	catalog = get_tree().root.get_node("Catalog")
	state.fresh(91231)
	check(state.qa,"Test save namespace isolated")
	check(catalog.ids("primary").size()==4,"Four primary spells")
	check(catalog.ids("fusion").size()==6,"Six fusion spells")
	check(catalog.ids("passive").size()+catalog.ids("secondary").size()+4>=21,"At least 21 usable skills")
	for seed_value: int in range(100):
		for floor_number: int in range(1,14):
			var data: Dictionary = Dungeon.generate(seed_value,floor_number)
			var grid: AStarGrid2D = AStarGrid2D.new()
			grid.region = Rect2i(0,0,Dungeon.WIDTH,Dungeon.HEIGHT)
			grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			grid.update()
			for y: int in range(Dungeon.HEIGHT):
				for x: int in range(Dungeon.WIDTH): grid.set_point_solid(Vector2i(x,y),data.grid[y][x]!=".")
			var entry: Vector2i = Vector2i(Dungeon.vec(data.entry)/Dungeon.CELL)
			var exit_cell: Vector2i = Vector2i(Dungeon.vec(data.exit)/Dungeon.CELL)
			check(not grid.get_id_path(entry,exit_cell).is_empty(),"Connected exit %d/%d"%[seed_value,floor_number])
			for record: Dictionary in data.enemies+data.props:
				var target: Vector2i = Vector2i(Dungeon.vec(record.pos)/Dungeon.CELL)
				check(not grid.get_id_path(entry,target).is_empty(),"Reachable entity %d/%d/%s"%[seed_value,floor_number,record.id])
			check(data.rooms.size()>=6,"Multiple rooms")
			generations += 1
		if seed_value%20==0: print("Generation seeds checked: ",seed_value+1)
	check(JSON.stringify(Dungeon.generate(72,8))==JSON.stringify(Dungeon.generate(72,8)),"Deterministic seeds")
	check(JSON.stringify(Dungeon.generate(72,8))!=JSON.stringify(Dungeon.generate(73,8)),"Varied seeds")
	state.fresh(721)
	state.learn("fire");state.learn("missile")
	check("fire_missile" in state.eligible(5),"Fusion at multiple of five")
	check(not "fire_missile" in state.eligible(6),"Fusion unavailable at other levels")
	state.learn("fire_missile")
	var captured: Dictionary = state.run.fusion.snapshot.duplicate(true)
	state.learn("fire")
	check(state.run.fusion.snapshot==captured,"Fusion snapshot stable after learning")
	state.learn("shield");state.learn("teleport")
	check(not "acid" in state.eligible(19),"Two secondary slots before level 20")
	check("acid" in state.eligible(20),"Third secondary slot at level 20")
	state.run.skills.fire=12
	check(not "fire" in state.eligible(24),"Primary cap before 25")
	check("fire" in state.eligible(25),"Primary cap raised after 25")
	state.run.skills.fire=20
	check(not "fire" in state.eligible(30),"No maxed skill offer")
	state.fresh(721)
	state.learn("missile")
	state.add_xp(500)
	check(state.run.pending.size()>1,"Multiple simultaneous level-ups queued")
	var offered: Array = state.offers().duplicate()
	var first: String = offered[0]
	check(state.choose(first),"Offer applied")
	check(not state.choose(first),"Offer cannot be applied twice")
	check(not state.run.pending.is_empty(),"Remaining level preserved")
	state.fresh(731)
	var varieties: Dictionary = {}
	for i: int in range(300):
		var item: Dictionary = state.make_item(i,5)
		varieties[item.name]=true
	check(varieties.size()>=50,"At least fifty differentiated item combinations")
	var item: Dictionary = state.make_item(81,3)
	state.run.inventory.append(item)
	var baseline: Dictionary = state.stats()
	check(state.equip(item.uid),"Equipment accepted")
	check(state.stats()!=baseline,"Equipment changes statistics")
	state.unequip("staff" if item.slot=="staff" else "ring1")
	check(state.stats()==baseline,"Unequip removes bonuses exactly")
	check(state.equip(item.uid,"ring1" if item.slot=="staff" else "staff")==false,"Slot mismatch rejected")
	state.run.gold=10000
	var shop_item: Dictionary = state.make_item(22,4)
	state.run.shop=[shop_item]
	var gold: int = state.run.gold
	check(state.buy(shop_item.uid),"Purchase works")
	check(state.run.gold==gold-shop_item.price,"Purchase charges once")
	check(not state.buy(shop_item.uid),"Purchase cannot duplicate item")
	check(state.sell(shop_item.uid),"Sale works")
	check(not state.sell(shop_item.uid),"Sale cannot duplicate money")
	state.run.skills.economy=1000
	check(state.stats().cost_reduction<=0.8,"Cost reduction capped")
	state.run.mp=10.0
	check(state.pay_mana(10),"Mana spend succeeds")
	check(state.run.mp>=0 and state.run.mp<10,"No negative or refunded costs")
	state.run.hp=1.0
	check(state.potion("hp"),"Health potion heals")
	check(state.run.hp>1,"Potion effect applied")
	state.run.hp=state.stats().max_hp
	var pots: int = state.run.hp_potions
	check(not state.potion("hp") and state.run.hp_potions==pots,"No wasted potion at full health")
	state.fresh(345)
	state.learn("ice")
	state.run.floors["1"]=Dungeon.generate(345,1)
	state.run.floors["1"].props[0].opened=true
	state.mark_checkpoint()
	check(state.save_game(),"Save succeeds")
	var saved_seed: int = state.run.seed
	state.run.seed=0
	check(state.load_game() and state.run.seed==saved_seed,"Save round-trip")
	check(state.run.floors["1"].props[0].opened,"Claimed chest persists")
	check(state.save_game(),"Backup generated")
	var broken: FileAccess = FileAccess.open(state.save_path,FileAccess.WRITE)
	broken.store_string("{broken");broken.close()
	check(state.load_game() and not SaveStore.last_error.is_empty(),"Corrupt primary recovers backup")
	var bad: String = "user://qa_invalid.json"
	SaveStore.write_save(bad,{"foo":123})
	check(not state.valid_payload(SaveStore.read_save(bad)),"Malformed payload rejected")
	state.fresh(811)
	state.mark_checkpoint()
	state.run.gold=999
	state.die()
	check(state.run.gold==140 and state.run.deaths==1 and not state.run.dead,"Normal death rolls back checkpoint")
	state.fresh(822,0,true)
	state.mark_checkpoint();state.die()
	check(state.run.dead,"Hardcore death persists")
	state.fresh(833)
	state.learn("fire");state.win()
	check(state.run.victory and state.unlocked>=1,"Victory unlocks next difficulty")
	state.next_difficulty()
	check(state.run.difficulty==1 and not state.run.victory and state.rank("fire")==1 and state.run.floors.is_empty(),"NG+ preserves build and resets tower")
	await test_combat()
	var report: Dictionary = {"checks":checks,"generated_floors":generations,"failures":failures,"engine":Engine.get_version_info().string,"item_combinations_observed":varieties.size()}
	var file: FileAccess = FileAccess.open("res://outputs/tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func test_combat() -> void:
	state.fresh(721)
	for id: String in catalog.ids("primary"): state.learn(id)
	state.run.skills.mana=1000
	state.run.skills.regen=20
	var data: Dictionary = Dungeon.generate(721,1)
	data.enemies=[]
	state.run.floors["1"]=data
	state.run.floor=1
	state.run.position=data.entry
	var world: GameWorld = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	world.player.qa_controlled=true
	world.player.qa_direction=Vector2.ZERO
	var target_pos: Vector2 = world.player.position+Vector2(160,0)
	var record: Dictionary = {"id":"test_target","kind":"skeleton","hp":100000.0,"pos":Dungeon.pair(target_pos),"dead":false}
	var enemy: TowerEnemy = load("res://scenes/enemy.tscn").instantiate()
	enemy.setup(world,record)
	world.actors.add_child(enemy)
	world.enemies.append(enemy)
	enemy.set_physics_process(false)
	world.player.set_physics_process(false)
	for id: String in catalog.ids("primary")+catalog.ids("fusion"):
		if catalog.definition(id).kind=="fusion": state.learn(id)
		state.run.active=id
		state.run.mp=10000.0
		world.player.aim=world.player.position.direction_to(enemy.position)
		world.player.fire_timer=0
		var before: float = enemy.hp
		var p: Dictionary = world.combat.profile(id)
		if p.channel:
			for i: int in range(60): world.combat.fire(world.player,1.0/60)
		else:
			world.combat.fire(world.player,1.0/60)
			for i: int in range(75): await get_tree().physics_frame
		check(enemy.hp<before,"Actual spell hits target: "+id)
		check(state.run.mp<10000,"Spell consumes mana: "+id)
		for child: Node in world.shots.get_children(): child.queue_free()
		await get_tree().process_frame
	for id: String in ["lightning","ice","flame_lash","steam","blizzard"]:
		if catalog.definition(id).kind=="fusion": state.learn(id)
		state.run.active=id
		var results: Array = []
		for fps: int in [30,60,144]:
			state.run.mp=10000.0
			enemy.hp=100000.0
			for i: int in range(fps): world.combat.fire(world.player,1.0/fps)
			results.append([100000-enemy.hp,10000-state.run.mp])
		check(absf(results[0][0]-results[2][0])<0.01 and absf(results[0][1]-results[2][1])<0.01,"FPS independent damage/mana: "+id)
	for id: String in catalog.ids("secondary"):
		state.run.secondary=[]
		state.learn(id)
		state.run.mp=10000
		world.player.cooldowns={}
		check(world.combat.secondary(world.player,0),"Secondary cast: "+id)
		check(not world.combat.secondary(world.player,0),"Cooldown enforced: "+id)
	world.free()
