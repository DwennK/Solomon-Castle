extends Node

var failures: Array[String] = []
var checks: int = 0
var world: GameWorld
var main: Node
var totals: Dictionary = {"floors":0,"chests":0,"urns":0,"equipment":0,"health":0,"mana":0,"gold":0}

func _ready() -> void:
	if not State.qa: get_tree().quit(1); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	State.save_path = "user://qa_loot_balance.json"
	call_deferred("run_all")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run_all() -> void:
	print("LOOT_QA distribution")
	check_distribution()
	check_items()
	check_legacy()
	print("LOOT_QA live interactions")
	await check_live()
	if "--visual" in OS.get_cmdline_user_args():
		print("LOOT_QA native capture")
		await capture_live()
	var report: Dictionary = {"checks":checks,"failures":failures,"totals":totals,"mean_equipment_per_campaign":float(totals.equipment)/100.0,"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/loot-balance")
	var file: FileAccess = FileAccess.open("res://outputs/loot-balance/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("LOOT_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)

func check_distribution() -> void:
	for seed_value: int in range(100):
		for number: int in range(1,14):
			var data: Dictionary = Dungeon.generate(seed_value,number)
			var counts: Dictionary = {"chests":0,"urns":0,"equipment":0,"health":0,"mana":0,"gold":0}
			var key_found: bool = data.boss.is_empty()
			var ids: Dictionary = {}
			for prop: Dictionary in data.props:
				check(not ids.has(prop.id),"Unique prop ID")
				ids[prop.id] = true
				if prop.kind not in ["chest","urn"]: continue
				counts["chests" if prop.kind=="chest" else "urns"] += 1
				if prop.id==data.key_chest: key_found = true
				var reward: Dictionary = prop.reward
				counts.equipment += int(reward.equipment)
				for kind: String in ["health","mana","gold"]: counts[kind] += int(reward[kind])
				if prop.kind=="urn": check(not reward.equipment,"Urns never produce equipment")
				check(not prop.id.ends_with("_0"),"No free entry container")
			check(key_found,"Boss key chest retained")
			check(counts.chests>=2 and counts.chests<=3,"Two or three chests")
			check(counts.urns>=3 and counts.urns<=6,"Three to six urns")
			check(counts.equipment>=1 and counts.equipment<=2,"One guaranteed item, at most two chest items")
			check(counts.health+counts.mana<=3,"Container potions bounded")
			var enemy_potions: int = 0
			for enemy: Dictionary in data.enemies:
				var reward: Dictionary = enemy.get("reward",{})
				for kind: String in ["health","mana","gold"]: counts[kind] += int(reward.get(kind,0))
				enemy_potions += int(reward.get("health",0))+int(reward.get("mana",0))
			check(enemy_potions==2,"Exactly two seeded enemy potion carriers")
			if not data.boss.is_empty():
				check(counts.equipment==1,"Boss floors do not add bonus chest equipment")
				counts.equipment += 1
				counts.gold += 35+number*5
			if number==13: counts.gold += 35+number*5
			for key: String in counts: totals[key] += counts[key]
			totals.floors += 1
			var before: String = JSON.stringify(data)
			LootRules.prepare_floor(data,seed_value,0)
			check(before==JSON.stringify(data),"Preparation is idempotent")
			if seed_value==0: check(before==JSON.stringify(Dungeon.generate(seed_value,number)),"Generation and rewards deterministic")
	check(totals.equipment>=1800 and totals.equipment<=2050,"Campaign mean close to nineteen equipment drops")
	# Large independent samples ensure rarity progression, including NG+.
	for difficulty: int in [0,4]:
		for number: int in [1,5,9,13]:
			var epic_count: int = 0
			var boss_common: int = 0
			var rng: RandomNumberGenerator = LootRules.random_for(872,number,difficulty,0)
			for i: int in range(10000):
				if LootRules.rarity(rng,number,difficulty)==2: epic_count += 1
				if LootRules.rarity(rng,number,difficulty,true)==0: boss_common += 1
			check(boss_common==0,"Boss always rare or epic")
			if number==1 and difficulty==0: check(epic_count==0,"No epic jackpot in first three normal floors")
			if number==13: check(epic_count>800 and epic_count<(1200 if difficulty==0 else 2500),"Late epic frequency bounded")

func check_items() -> void:
	State.fresh(197903)
	var recent: Array = []
	for i: int in range(60):
		var item: Dictionary = LootRules.make_item(i*971,1)
		check(item.slot==["staff","ring","ring"][i%3],"Equipment slot cycle matches worn slots")
		check(item.template not in recent,"No repeat of last four recipes when alternatives exist")
		recent.append(item.template)
		if recent.size()>4: recent.pop_front()
	var history: Array = State.run.loot_recent_templates.duplicate()
	var count: int = State.run.loot_item_count
	LootRules.make_item(128,1,false,true)
	check(history==State.run.loot_recent_templates and count==State.run.loot_item_count,"Merchant does not consume reward sequence")
	State.mark_checkpoint()
	check(State.save_game(),"Reward history saves")
	var first: Dictionary = LootRules.make_item(921,9,true)
	check(State.load_game(),"Reward history reloads")
	var replay: Dictionary = LootRules.make_item(921,9,true)
	check(first==replay,"Reload preserves item roll, history and UID")

func check_legacy() -> void:
	var data: Dictionary = Dungeon.generate(123,4)
	data.erase("loot_version")
	data.props = []
	for i: int in range(data.rooms.size()):
		var room: Array = data.rooms[i]
		for kind: String in ["chest","urn"]:
			data.props.append({"id":"%s_%d"%[kind,i],"kind":kind,"pos":[(room[0]+2)*64+32,(room[1]+2)*64+32],"opened":i==0})
	data.loot = [{"kind":"gold","amount":42,"pos":data.entry}]
	var key: String = data.key_chest
	LootRules.prepare_floor(data,123,0)
	check(data.loot.size()==1 and data.loot[0].amount==42,"Migration preserves earned ground loot")
	check(data.props.any(func(p: Dictionary) -> bool: return p.id==key and not p.opened),"Migration retains unopened key chest")
	check(data.props.any(func(p: Dictionary) -> bool: return p.id=="chest_0" and p.opened),"Migration preserves opened legacy chest")
	var before: String = JSON.stringify(data)
	LootRules.prepare_floor(data,123,0)
	check(before==JSON.stringify(data),"Migration cannot repopulate rewards")

func freeze_world() -> void:
	world.set_physics_process(false)
	world.player.qa_controlled = true
	world.player.set_physics_process(false)
	for enemy: TowerEnemy in world.enemies: enemy.set_physics_process(false)

func clear_shots() -> void:
	for shot: Node in world.shots.get_children():
		world.shots.remove_child(shot)
		shot.queue_free()

func check_live() -> void:
	State.fresh(197903)
	State.learn("missile")
	var data: Dictionary = Dungeon.generate(197903,1)
	data.enemies = []
	State.run.floors["1"] = data
	State.run.floor = 1
	State.run.position = data.entry
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	freeze_world()
	var center: Vector2 = Dungeon.to_world(Dungeon.room_center(data.rooms[1]))
	world.player.position = center
	world.player.aim = Vector2.RIGHT
	world.add_prop({"id":"test_urn","kind":"urn","pos":Dungeon.pair(center+Vector2(130,0)),"opened":false,"reward":{"gold":3}})
	var urn: WorldProp = world.props[-1]
	data.props.append(urn.record)
	world.player.position = urn.position
	check(world.closest_prop()!=urn,"Urn never offers interaction")
	world.open_prop(urn)
	check(not urn.record.opened,"Open chest action cannot break urn")
	world.player.position = center
	for id: String in Catalog.ids("primary")+Catalog.ids("fusion"):
		State.run.skills = {"missile":1,"fire":1,"lightning":1,"ice":1}
		State.run.fusion = {}
		if Catalog.definition(id).kind=="fusion": State.learn(id)
		State.run.active = id
		State.run.mp = 1000
		urn.record.opened = false
		world.player.fire_timer = 0
		world.combat.fire(world.player,1.0/60)
		var frames: int = 0
		while not urn.record.opened and frames<100:
			await get_tree().physics_frame
			frames += 1
		check(urn.record.opened,"Real spell breaks urn: "+id)
		print("LOOT_QA spell ",id)
		clear_shots()
		await get_tree().process_frame
	# Area spells, hostile protection, walls, and single payout.
	urn.record.opened = false
	world.combat.explosion(center,200,10,Color.ORANGE)
	check(urn.record.opened,"Explosion breaks urn")
	urn.record.opened = false
	world.friendly_zone(center,"acid",200,2,5)
	world.update_zones(0.1)
	check(urn.record.opened,"Acid breaks urn")
	world.zones.clear()
	urn.record.opened = false
	world.hazard(urn.position,200,10,0,Color.RED,1)
	world.update_zones(0.1)
	check(not urn.record.opened,"Hostile zone cannot harvest urn")
	world.zones.clear()
	world.enemy_bolt(center,Vector2.RIGHT,1,510,Color.RED)
	for i: int in range(30): await get_tree().physics_frame
	check(not urn.record.opened,"Hostile projectile cannot harvest urn")
	clear_shots()
	var hidden: Vector2 = Vector2.ZERO
	for room: Array in data.rooms:
		var candidate: Vector2 = Dungeon.to_world(Dungeon.room_center(room))
		if not world.dungeon.visible_line(center,candidate): hidden = candidate; break
	check(hidden!=Vector2.ZERO,"Occluded room exists for wall test")
	urn.position = hidden
	world.break_urns_in_radius(center,10000)
	check(not urn.record.opened,"Area attack cannot break urn through walls")
	urn.position = center+Vector2(130,0)
	world.loot.clear()
	world.break_urn(urn)
	world.break_urn(urn)
	check(world.loot.size()==1 and world.loot[0].amount==3,"Urn pays once despite repeated hits")
	var chest: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.kind=="chest" and prop.record.reward.equipment: chest = prop; break
	world.open_prop(chest)
	var drop_count: int = world.loot.size()
	world.open_prop(chest)
	world.combat.explosion(chest.position,100,100,Color.ORANGE)
	check(world.loot.size()==drop_count,"Chest pays once and is unaffected by spells")
	var ground: Array = world.loot.duplicate(true)
	var chest_id: String = chest.record.id
	world.snapshot()
	State.mark_checkpoint()
	check(State.save_game() and State.load_game(),"Opened props and uncollected loot save/load")
	world.load_floor(0); freeze_world()
	world.load_floor(1); freeze_world()
	check(JSON.parse_string(JSON.stringify(world.loot))==JSON.parse_string(JSON.stringify(ground)),"Village round trip preserves uncollected loot")
	check(world.props.any(func(p: WorldProp) -> bool: return p.record.id==chest_id and p.record.opened),"Opened chest survives return")
	check(world.props.any(func(p: WorldProp) -> bool: return p.record.id=="test_urn" and p.record.opened),"Broken urn survives return")
	world.loot.clear()
	var hp: int = State.run.hp_potions
	var mp: int = State.run.mp_potions
	world.add_supplies({"health":1,"mana":1},world.player.position)
	world.collect_loot()
	check(State.run.hp_potions==hp+1 and State.run.mp_potions==mp+1,"Both ground potion types collect correctly")
	world.free()

func capture_live() -> void:
	State.fresh(197903)
	State.learn("fire")
	State.options.fullscreen = false
	State.apply_options()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_game()
	world = main.world
	world.load_floor(1)
	freeze_world()
	var urn: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.kind=="urn": urn = prop; break
	world.player.position = urn.position+Vector2(-120,120)
	world.player.aim = world.player.position.direction_to(urn.position)
	world.camera.reset_smoothing()
	world.dungeon.reveal(world.player.position)
	await capture("urn-intact")
	world.combat.fire(world.player,1.0/60)
	for i: int in range(35): await get_tree().physics_frame
	check(urn.record.opened,"Rendered fireball breaks actual dressed urn")
	await capture("urn-shattered")
	var chest: WorldProp
	for prop: WorldProp in world.props:
		if prop.record.kind=="chest" and prop.record.reward.equipment: chest = prop; break
	world.player.position = chest.position+Vector2(0,64)
	world.camera.reset_smoothing()
	world.dungeon.reveal(world.player.position)
	check(world.closest_prop()==chest,"Rendered chest retains interaction at visual position")
	world.interact()
	check(chest.record.opened,"Rendered chest opens through interaction")
	await capture("chest-reward")
	main.queue_free()
	main = null
	world = null
	await get_tree().process_frame
	await get_tree().process_frame

func capture(label: String) -> void:
	print("LOOT_QA capture ",label)
	DirAccess.make_dir_recursive_absolute("res://outputs/loot-balance")
	for i: int in range(12): await get_tree().process_frame
	world._physics_process(0)
	main.hud._process(0)
	RenderingServer.force_draw()
	print("LOOT_QA rendered ",label)
	get_viewport().get_texture().get_image().save_png("res://outputs/loot-balance/"+label+".png")
	await get_tree().process_frame
