extends Node

var checks: int = 0
var failures: Array[String] = []
var notices: Array[String] = []
var main: Node

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description);push_error(description)

func near(actual: float, expected: float, description: String) -> void:
	check(absf(actual-expected)<0.01,description+" (%.3f / %.3f)" % [actual,expected])

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_ux_campaign.json"
	State.message.connect(func(value: String)->void:notices.append(value))
	call_deferred("run_all")

func run_all() -> void:
	State.fresh(419)
	var combat: CombatSystem = CombatSystem.new()
	State.learn("fire");State.learn("missile");State.learn("lightning");State.learn("ice")
	near(SkillDetails.attack("fire").dps,30.0/0.55,"Fire DPS per projectile / enemy")
	State.learn("explode")
	near(SkillDetails.attack("fire").dps,46.5/0.55,"Direct target includes explosion")
	check("30.0 DPS / other enemy" in SkillDetails.text("fire",false),"Splash DPS independent of enemy count")
	State.run.skills.multishot=3
	near(SkillDetails.attack("missile").dps,18.0/0.38,"Multishot baseline never assumes all projectiles connect")
	check("189.5 DPS" in SkillDetails.text("missile",false),"Conditional full salvo stated separately")
	State.learn("fire_missile")
	var old_damage: float = SkillDetails.attack("fire_missile").damage
	State.run.skills.fire=10
	near(SkillDetails.attack("fire_missile").damage,old_damage,"Learned fusion keeps snapshot")
	check(SkillDetails.attack("fire_missile",true).damage>old_damage,"Fusion refresh uses current elements")
	check(combat.profile("steam").damage>52,"New fusion does not use another fusion's old snapshot")
	var before: String = JSON.stringify(State.run)
	for kind: String in ["primary","secondary","fusion","passive"]:
		for id: String in Catalog.ids(kind):
			check(not SkillDetails.text(id).is_empty(),"Sheet exists: "+id)
	check(JSON.stringify(State.run)==before,"Previews never mutate campaign")
	State.run.skills.acid=2;State.run.skills.focus=2;State.run.skills.economy=2
	near(SkillDetails.attack("acid").dps,196.0/12.5,"Acid average includes duration and cooldown")
	near(SkillDetails.attack("acid").cost,40*0.82,"Actual reduced mana cost shown")
	near(SkillDetails.attack("shield").dps,0,"Utility spell never invents damage")
	check("Active DPS / enemy: 28.0" in SkillDetails.text("acid"),"Active zone DPS shown")
	State.run.skills.shield=1
	check("Absorbs 45 → 90" in SkillDetails.text("shield"),"Next ritual effect shown")
	State.fresh(221);State.learn("fire");State.learn("shield")
	var equipment: Dictionary=test_item(1234)
	equipment.bonuses={"skill:fire":3,"flat_damage":5.0,"cost_reduction":0.1,"grant:mental_focus":1}
	State.run.inventory=[equipment];State.equip(equipment.uid)
	near(SkillDetails.attack("fire").damage,68,"Equipment rank and flat damage included")
	near(SkillDetails.attack("fire",true).damage,79,"Next learned rank includes equipment exactly once")
	near(SkillDetails.attack("shield").cooldown,11,"Equipment cooldown power shown")
	# Persistence and resource limits, including old saves.
	State.fresh(713);State.learn("fire");State.run.pending=[3];State.run.level=3
	var original: Array = State.offers().duplicate()
	check(State.reroll(),"Reroll accepted")
	check(State.run.insight==0 and State.run.pending==[3],"One shard charged without consuming level")
	for id: String in State.run.offers: check(id not in original,"Previous choices excluded when enough alternatives")
	var rerolled: Array = State.run.offers.duplicate()
	check(not State.reroll(),"Zero shards blocks repeat")
	check(State.load_game() and State.run.insight==0 and State.run.offers==rerolled,"Reload preserves cost and offers")
	State.run.insight=1
	var save_path: String = State.save_path
	State.save_path="user://missing-ux-directory/save.json"
	original=State.run.offers.duplicate()
	check(not State.reroll() and State.run.insight==1 and State.run.offers==original,"Failed save rolls back reroll")
	State.save_path=save_path
	State.fresh(331);State.run.level=39;State.run.pending=[39]
	for id: String in Catalog.ids("primary")+Catalog.ids("secondary")+Catalog.ids("passive"): State.run.skills[id]=Catalog.definition(id).max_rank
	State.offers()
	check(not State.can_reroll() and not State.reroll() and State.run.insight==1,"No alternatives never charges a shard")
	State.fresh(551);State.learn("fire");State.learn("missile");State.run.level=5;State.run.pending=[5]
	State.offers();check(State.reroll() and "fire_missile" in State.run.offers,"Unique fusion opportunity survives a reroll")
	check(State.run.offers.size()==3 and State.run.offers[0]!=State.run.offers[1] and State.run.offers[1]!=State.run.offers[2],"Rerolled choices remain distinct")
	State.run.erase("insight");State.run.erase("reroll_serial");State.mark_checkpoint()
	check(State.save_game() and State.load_game(),"Legacy campaign loads")
	check(State.run.insight==1 and State.checkpoint.insight==1,"Legacy run and checkpoint migrate")
	State.run.floor=4;State.run.floors["4"]=Dungeon.generate(713,4);State.run.position=State.run.floors["4"].entry
	State.mark_checkpoint("Floor entry")
	State.run.gold=999;State.die()
	check("Floor 4 · room 1" in State.checkpoint_description() and "140 gold" in State.checkpoint_description(),"Death reports restored state, room and reason")
	# Real input events and rendered UI.
	State.fresh(197903);State.run.shop=[test_item(0)];State.learn("fire");State.learn("missile");State.learn("shield");State.learn("acid")
	main=load("res://scenes/main.tscn").instantiate();add_child(main)
	main.start_game();main.world.enter_tower()
	main.world.player.qa_controlled=true;main.world.player.set_physics_process(false)
	for enemy: TowerEnemy in main.world.enemies: enemy.set_physics_process(false)
	main.world.set_physics_process(false)
	Controls.setup({"mp_potion":KEY_H},{"secondary_0":JOY_BUTTON_Y})
	var pad: InputEventJoypadMotion=InputEventJoypadMotion.new();pad.axis=JOY_AXIS_RIGHT_X;pad.axis_value=0.8
	Input.parse_input_event(pad);await settle()
	# Reassert after window-generated mouse motion; inspect the same frame as the event.
	main._input(pad);main.hud._process(0)
	check(main.hud.rituals[0].key_label.text=="Y" and main.hud.mp_potion.text.begins_with("→"),"HUD switches to remapped gamepad buttons")
	await capture("01-gamepad-hud")
	pad.axis_value=0.1;Controls.using_pad=false;Controls.observe(pad)
	check(not Controls.using_pad,"Stick drift does not switch device")
	pad.axis_value=0.8;Controls.observe(pad);Controls.pad_name="DualSense"
	check(Controls.caption("secondary_0")=="△","PlayStation face symbols respect remap")
	var key: InputEventKey=InputEventKey.new();key.physical_keycode=KEY_LEFT;key.pressed=true
	Input.parse_input_event(key);await settle()
	check(main.hud.mp_potion.text.begins_with("H"),"Keyboard switches captions back and respects remap")
	key.pressed=false;Input.parse_input_event(key)
	Controls.observe(pad);Controls.disconnected(0,false)
	check(not Controls.using_pad,"Disconnect returns captions to keyboard")
	notices.clear();State.notice_times.clear();State.run.mp=0;State.run.active="fire"
	main.world.combat.fire(main.world.player,1.0/60)
	main.world.combat.fire(main.world.player,1.0/60)
	check(notices.size()==1 and "Not enough mana" in notices[0],"Primary mana warning throttled")
	State.run.inventory=[]
	for i: int in range(48): State.run.inventory.append(test_item(i))
	var drop: Dictionary={"kind":"item","item":test_item(999),"pos":Dungeon.pair(main.world.player.position)}
	main.world.loot=[drop];notices.clear()
	main.world.collect_loot();main.world.collect_loot()
	check(main.world.loot.size()==1 and notices.size()==1 and "Bag full" in notices[0],"Full bag leaves item and throttles notice")
	State.run.inventory.pop_back();main.world.collect_loot()
	check(main.world.loot.is_empty() and State.run.inventory.size()==48,"Item collected when space becomes available")
	await verify_damage()
	var boss: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	boss.setup(main.world,{"id":"boss","kind":"king","hp":1.0,"pos":Dungeon.pair(main.world.player.position),"dead":false})
	main.world.actors.add_child(boss);main.world.enemies.append(boss);boss.set_physics_process(false)
	var shards_before: int=State.run.insight
	boss.take_damage(100000);boss.take_damage(100000)
	check(State.run.insight==shards_before+1,"Main guardian grants exactly one shard")
	State.run.level=5;State.run.pending=[5];State.run.offers=["fire_missile","acid","shield"];State.run.insight=2
	main.show_level();await settle();await capture("02-level-details")
	var reroll_button: Button=find_button(main.modal,"Reroll choices")
	check(reroll_button!=null and not reroll_button.disabled,"Reroll is actionable in level modal")
	await click(reroll_button)
	check(State.run.insight==1 and main.modal_kind=="level","Real reroll click stays in pending level")
	await capture("03-rerolled")
	var choose: Button=find_button(main.modal,"Choose")
	await click(choose)
	check(State.run.pending.is_empty() and main.modal_kind.is_empty(),"Choice after reroll consumes level and resumes")
	main.show_skills();await capture("04-grimoire")
	main.close_modal();State.mark_checkpoint("Return through portal");State.die();main.show_death();await capture("05-checkpoint")
	main.close_modal();main.show_initial();await capture("06-initial")
	main.close_modal()
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(960,600));await settle()
		State.run.pending=[5];State.run.offers=["fire_missile","acid","shield"]
		main.show_level();await capture("07-level-960x600")
		check(main.modal.get_global_rect().size.x<=get_viewport().get_visible_rect().size.x,"Small desktop modal fits")
	main.close_modal();State.run.pending=[]
	DirAccess.make_dir_recursive_absolute("res://outputs/ux-features")
	var file: FileAccess=FileAccess.open("res://outputs/ux-features/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));file.close()
	print("UX_FEATURES ",JSON.stringify({"checks":checks,"failures":failures}))
	Sound.stop_all();main.queue_free();await settle()
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_damage() -> void:
	State.run.skills={"fire":1,"explode":1,"ice":1,"ring_fire":1,"acid":1,"focus":2}
	State.run.fusion={};State.run.mp=10000
	var world: GameWorld=main.world
	for enemy: TowerEnemy in world.enemies: enemy.queue_free()
	world.enemies=[]
	var enemies: Array[TowerEnemy]=[]
	for offset: Vector2 in [Vector2(80,0),Vector2(90,15)]:
		var e: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
		e.setup(world,{"id":"ux_target","kind":"skeleton","hp":10000.0,"pos":Dungeon.pair(world.player.position+offset),"dead":false})
		world.actors.add_child(e);world.enemies.append(e);e.set_physics_process(false);enemies.append(e)
	var resistance: float=1.0-float(enemies[0].definition.values.resistance)
	var projectile: MagicProjectile=MagicProjectile.new()
	projectile.world=world;projectile.profile=world.combat.profile("fire");projectile.position=enemies[0].position
	world.shots.add_child(projectile);projectile.set_physics_process(false);projectile.impact(enemies[0])
	near((10000-enemies[0].hp)/resistance,SkillDetails.attack("fire").damage,"Displayed direct+splash equals actual impact")
	near((10000-enemies[1].hp)/resistance,16.5,"Adjacent enemy takes splash only")
	for e: TowerEnemy in enemies: e.hp=10000
	State.run.active="ice";world.player.aim=Vector2.RIGHT
	for i: int in range(60): world.combat.channel(world.player,world.combat.profile("ice"),1.0/60)
	for e: TowerEnemy in enemies: near((10000-e.hp)/resistance,SkillDetails.attack("ice").dps,"Channel DPS matches each enemy independently")
	State.run.secondary=["ring_fire"];world.player.cooldowns={};State.run.mp=10000
	for e: TowerEnemy in enemies: e.hp=10000
	world.combat.secondary(world.player,0)
	near((10000-enemies[0].hp)/resistance/world.player.cooldowns.ring_fire,SkillDetails.attack("ring_fire").dps,"Ritual average DPS matches damage and actual recharge")
	State.run.secondary=["acid"];world.player.cooldowns={};State.run.mp=10000
	for e: TowerEnemy in enemies: e.hp=10000
	world.combat.secondary(world.player,0)
	for i: int in range(60): world.update_zones(1.0/60)
	for e: TowerEnemy in enemies: near((10000-e.hp)/resistance,14,"Acid active DPS applied to each enemy")
	world.zones=[]
	State.run.skills.shield=1;State.run.secondary=["shield","acid"]
	world.player.refresh_stats()

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child: Node in node.get_children():
		var found: Button=find_button(child,prefix)
		if found: return found
	return null

func click(button: Button) -> void:
	if button==null: return
	button.grab_focus();await settle()
	# Focus also scrolls long cards into view before accepting with the keyboard.
	for pressed: bool in [true,false]:
		var event: InputEventKey=InputEventKey.new();event.keycode=KEY_ENTER;event.physical_keycode=KEY_ENTER;event.pressed=pressed
		Input.parse_input_event(event);await get_tree().process_frame
	await settle()

func settle() -> void:
	await get_tree().create_timer(0.2,true).timeout

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await settle();await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://outputs/ux-features")
	get_viewport().get_texture().get_image().save_png("res://outputs/ux-features/"+name+".png")

func test_item(index: int) -> Dictionary:
	return {"uid":"ux_item_%d"%index,"name":"Test Staff","slot":"staff","rarity":0,"bonuses":{"damage":0.1},"price":30,"base":"bone_staff"}
