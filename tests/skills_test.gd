extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var main: Node
var captures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual-expected)<0.001,message+" (%.4f / %.4f)" % [actual,expected])

func gear(bonuses: Dictionary) -> void:
	State.run.serial+=1
	var item: Dictionary={"uid":"skills_%d"%State.run.serial,"name":"Test","slot":"staff","rarity":2,"bonuses":bonuses,"price":1}
	State.run.inventory.append(item);State.equip(item.uid)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	process_mode=Node.PROCESS_MODE_ALWAYS
	State.save_path="user://qa_skills_audit.json"
	call_deferred("run_all")

func run_all() -> void:
	State.fresh(478)
	var combat: CombatSystem=CombatSystem.new()
	check(Catalog.ids("passive").size()==25,"24 wiki passives/subskills plus legacy resistance")
	for major: String in ["immolation","ether_charge","hurricane","harden"]:
		State.run.skills={}
		var d: ContentDefinition=Catalog.definition(major)
		check(major not in State.eligible(30),major+" requires its primary and both subskills")
		State.learn(d.prerequisite)
		State.learn(d.values.requires[0])
		check(major not in State.eligible(30),major+" requires second subskill")
		State.learn(d.values.requires[1])
		check(major not in State.eligible(29) and major in State.eligible(30),major+" unlocks at documented level 30")
	State.fresh(478);State.learn("fire")
	check("embers" not in State.eligible(10),"Embers require Explode")
	State.learn("explode")
	check("embers" in State.eligible(10),"Embers unlocked with Explode")
	check("haste" not in State.eligible(24) and "haste" in State.eligible(25),"Faster Caster level gate")
	check("power" not in State.eligible(24) and "power" in State.eligible(25),"Siege Mage level gate")
	check("focus" not in State.eligible(9),"Mental Focus needs a ritual")
	State.learn("shield");State.run.skills.shield=4
	check("shield" not in State.eligible(24) and "shield" in State.eligible(25),"Shield raised cap at level 25")
	check("focus" in State.eligible(9),"Mental Focus eligible after a ritual")
	check("resist" not in State.eligible(99),"Legacy physical resistance is not offered as wiki poison skill")
	for id: String in ["focus","meditation","reach","creativity"]:
		State.run.skills[id]=1
		gear({"all_skills":7,"skill:"+id:3})
		check(State.rank(id)==1 and id not in State.eligible(99),id+" is binary even with equipment")
	State.unequip("staff")
	State.run.level=30;State.run.pending=[30];State.run.offers=[]
	var offered: Array=State.offers().duplicate()
	check(offered.size()==4,"Creativity grants four choices")
	var unique: Dictionary={}
	for id: String in offered: unique[id]=true
	check(unique.size()==4,"Creativity choices are distinct")
	check(State.reroll() and State.run.offers.size()==4,"Reroll preserves fourth choice")
	check(State.save_game() and State.load_game() and State.run.offers.size()==4,"Four choices survive save/load")
	State.fresh(479);State.learn("fire");State.learn("embers");State.learn("explode");State.learn("immolation")
	gear({"skill:missile":2,"skill:multishot":1,"skill:potent":2,"skill:fire":2})
	check("fire_missile" in State.eligible(5),"Equipment-provided primary can be welded")
	State.learn("fire_missile")
	var fused: Dictionary=combat.profile("fire_missile")
	check(fused.multi==2 and State.run.fusion.snapshot.missile==2,"Welding captures equipped primary and subskill ranks")
	check(State.run.fusion.snapshot.immolation==0,"Major effects excluded from fusion snapshot")
	State.unequip("staff");State.learn("fire");State.learn("embers")
	near(combat.profile("fire_missile").damage,fused.damage,"Removing gear and learning leaves fused damage frozen")
	near(combat.profile("fire_missile").mana,fused.mana,"Fused subskill mana remains frozen")
	check(combat.profile("fire_missile").multi==2,"Fused salvo retained after item removal")
	gear({"flat_damage":10,"cast_speed":1})
	check(combat.profile("fire_missile").damage>fused.damage and combat.profile("fire_missile").cooldown<fused.cooldown,"Global damage and speed remain dynamic")
	State.unequip("staff");State.learn("power");State.learn("haste");State.learn("economy")
	check(combat.profile("fire_missile").damage>fused.damage,"General passive damage remains dynamic")
	check(State.save_game() and State.load_game() and combat.profile("fire_missile").multi==2,"Effective snapshot survives disk roundtrip")
	State.fresh(480)
	for entry: Array in [["missile","potent"],["missile","multishot"],["fire","explode"],["fire","embers"],["lightning","chain"],["lightning","stun"],["ice","cone"],["ice","chill"]]:
		State.run.skills={entry[0]:1}
		var before: float=combat.profile(entry[0]).mana
		State.learn(entry[1])
		check(combat.profile(entry[0]).mana>before,entry[1]+" increases actual mana cost")
	State.run.skills={"fire":1,"potent":5}
	near(SkillDetails.attack("fire").range,510*2.1,"Potent does not accelerate fireballs")
	for entry: Array in [[0,0.0],[1,0.1],[2,0.25],[5,1.0],[10,1.5]]:
		near(CombatSystem.missile_speed_bonus(entry[0]),entry[1],"Potent speed table")
	State.run.skills={"shield":1,"focus":1}
	near(combat.secondary_profile("shield").cooldown,11,"Learned Mental Focus halves cooldown")
	gear({"grant:mental_focus":1})
	near(combat.secondary_profile("shield").cooldown,11,"Granted and learned Mental Focus do not stack")
	for id: String in ["circle","freeze","ring_fire","acid","undead"]:
		check(combat.secondary_profile(id,2).mana>combat.secondary_profile(id,1).mana,id+" upgrades cost more mana")
		near(combat.secondary_profile(id,2).cooldown,combat.secondary_profile(id,1).cooldown,id+" rank does not change cooldown")
	State.run.skills.economy=4
	near(State.mana_cost(30,false),30,"Battle Mage does not discount utility spells")
	check(State.mana_cost(30,true)<30,"Battle Mage discounts offensive spells")
	await actual_combat()
	if DisplayServer.get_name()!="headless": await visual_checks()
	Sound.stop_all()
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures}
	var file: FileAccess=FileAccess.open("res://outputs/skills-audit/tests-native.json" if DisplayServer.get_name()!="headless" else "res://outputs/skills-audit/tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SKILLS_TEST ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func target(offset: Vector2, hp: float = 10000.0) -> TowerEnemy:
	var enemy: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	enemy.setup(world,{"id":"skill_target_%d"%world.enemies.size(),"kind":"skeleton","hp":hp,"pos":Dungeon.pair(world.player.position+offset),"dead":false})
	world.actors.add_child(enemy);world.enemies.append(enemy)
	enemy.set_physics_process(false)
	return enemy

func clear_shots() -> void:
	for shot: Node in world.shots.get_children(): shot.free()

func actual_combat() -> void:
	State.fresh(481)
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.set_process(false)
	world.village=false
	world.player.qa_controlled=true;world.player.set_physics_process(false)
	var enemy: TowerEnemy=target(Vector2(150,0))
	var side: TowerEnemy=target(Vector2(150,100))
	State.run.skills={"missile":1,"lightning":1,"chain":1,"stun":1}
	State.learn("ball_lightning")
	var p: Dictionary=world.combat.profile("ball_lightning")
	world.combat.orb_pulse(enemy.position,p)
	check(enemy.hp<10000 and side.hp<10000,"Ball Lightning pulse chains to real second enemy")
	near(10000-enemy.hp,10000-side.hp,"Chain hits each target exactly once with equal damage")
	check(side.frozen>0,"Orb chain inherits Stun")
	State.run.skills={"lightning":1,"ice":1,"chain":1}
	State.learn("blizzard");enemy.hp=10000;side.hp=10000
	world.combat.channel(world.player,world.combat.profile("blizzard"),0.1)
	check(side.hp<10000,"Blizzard chains outside the primary beam")
	State.run.skills={"missile":1,"ice":1,"cone":2,"chill":2}
	State.learn("frost_missile")
	near(world.combat.splash_radius(world.combat.profile("frost_missile")),111,"Frost Missile inherits Cone of Ice radius")
	# Fire channel subskills activate when their target dies.
	State.run.skills={"fire":1,"lightning":1,"explode":1,"embers":1}
	State.learn("flame_lash");enemy.hp=0.1;side.hp=10000
	world.combat.channel(world.player,world.combat.profile("flame_lash"),0.1)
	check(world.shots.get_child_count()==3,"Fire channel emits Embers on kill")
	clear_shots()
	# Isolate an ember from collisions to test expiry explosion and impact cancellation.
	State.run.skills={"fire":1,"embers":1,"immolation":1,"explode":1}
	gear({"skill:explode":3,"skill:embers":3})
	world.combat.emit_embers(side.position,world.combat.profile("fire"),40)
	var ember: MagicProjectile=world.shots.get_child(0)
	check(world.combat.splash_ratio(ember.profile)==0,"Equipment cannot make ordinary ember impacts explode")
	var count: int=world.shots.get_child_count()
	var before: float=side.hp
	ember._physics_process(1)
	check(side.hp<before,"Immolation explodes expired ember against real enemy")
	check(world.shots.get_child_count()==count,"Immolation does not recursively spawn embers")
	clear_shots()
	world.combat.emit_embers(side.position,world.combat.profile("fire"),40)
	ember=world.shots.get_child(0);before=side.hp
	ember.impact(side)
	near(before-side.hp,10,"Intercepted ember deals impact only")
	clear_shots();State.learn("fire_missile")
	world.combat.emit_embers(side.position,world.combat.profile("fire_missile"),40)
	ember=world.shots.get_child(0);before=side.hp;ember._physics_process(1)
	near(side.hp,before,"Fusion embers never inherit Immolation")
	clear_shots();State.unequip("staff")
	# Retarget only with Potent Missiles.
	State.run.skills={"missile":1}
	world.spawn_projectile(world.player.position,Vector2.RIGHT,world.combat.profile("missile"))
	var shot: MagicProjectile=world.shots.get_child(0)
	shot.target=null;shot._physics_process(0.001)
	check(shot.target==null,"Unupgraded missile does not retarget")
	State.learn("potent");shot._physics_process(0.001)
	check(shot.target==side,"Potent missile acquires a new living target")
	clear_shots()
	State.run.skills={"ice":1,"harden":1};State.run.active="ice";State.run.mp=100
	world.player.qa_fire=true;world.player.refresh_stats()
	world.player._physics_process(0.5)
	near(world.player.ice_armor,4,"Harden generates armor over actual paid channel time")
	State.run.hp=100;world.player.invulnerable=0;world.player.shield=0
	world.player.take_damage(3,"poison")
	near(State.run.hp,100,"Harden absorbs poison")
	near(world.player.ice_armor,1,"Poison consumes ice armor")
	world.player.qa_fire=false;world.player._physics_process(0.01)
	near(world.player.ice_armor,0,"Stopping Frost Jet removes Harden")
	State.run.skills.regen=0;gear({"mana_regen":-7.5})
	State.run.mp=0;world.player.qa_fire=true;world.player._physics_process(0.01)
	near(world.player.ice_armor,0,"No mana means no free Harden armor")
	State.unequip("staff")
	State.run.skills={"ice":1,"lightning":1,"harden":5,"hurricane":5};State.learn("blizzard")
	State.run.mp=100;world.player._physics_process(0.1)
	check(world.player.ice_armor==0 and not world.player.storm_active,"Fused channel excludes Harden and Hurricane")
	State.run.active="lightning";State.run.mp=100;side.hp=10000
	var behind: TowerEnemy=target(Vector2(-130,0))
	world.enemy_bolt(world.player.position+Vector2(-100,0),Vector2.RIGHT,10,100,Color.RED)
	shot=world.shots.get_child(0)
	world.player._physics_process(0.1)
	check(behind.hp<10000 and world.player.storm_active,"Hurricane damages enemies outside aiming beam")
	check(shot.direction==Vector2.RIGHT,"Hurricane leaves hostile projectile trajectories unchanged")
	clear_shots()
	# Ether maximum health reduction is bounded and persistent per enemy.
	State.run.skills={"missile":1,"ether_charge":2};State.run.active="missile"
	world.player.qa_fire=false;world.player.refresh_stats();world.player._physics_process(2)
	check(world.player.ether_charges==2,"Ether builds charges while not firing")
	before=behind.max_hp;world.player.qa_fire=true;world.player.fire_timer=0;State.run.mp=100
	world.player._physics_process(0.01)
	near(behind.max_hp,before*0.8,"Paid missile releases Ether pulse reducing maximum health")
	check(world.player.ether_charges==0,"Ether consumes charges on release")
	behind.apply_ether(2)
	near(behind.max_hp,before*0.8,"Repeated Ether does not multiply the same reduction")
	var reloaded: TowerEnemy=load("res://scenes/enemy.tscn").instantiate()
	reloaded.setup(world,behind.record.duplicate(true))
	near(reloaded.max_hp,behind.max_hp,"Ether reduction survives enemy reconstruction")
	reloaded.free();clear_shots()
	State.run.skills={"meditation":1,"poison_resist":3};world.player.qa_fire=false
	gear({"grant:meditation":1,"poison_resistance":0.8})
	State.run.mp=0;world.player.resting=2;world.player._physics_process(0.1)
	near(State.run.mp,3,"Learned plus granted Meditation multiplies regeneration once")
	world.player.shield=100;world.player.invulnerable=0;State.run.hp=100
	world.player.take_damage(100,"poison")
	near(State.run.hp,86,"Poison skill stacks multiplicatively with equipment and bypasses shield")
	near(world.player.resting,0,"Damage interrupts Meditation")
	# Continuous major effects have the same cost/output at different frame rates.
	State.run.equipped={"staff":"","ring1":"","ring2":""}
	for spell: String in ["ice","lightning"]:
		State.run.skills={"ice":1,"lightning":1,"harden":1,"hurricane":1}
		State.run.active=spell
		var outcomes: Array=[]
		for fps: int in [30,60,144]:
			world.player.ice_armor=0;State.run.mp=10000;behind.hp=10000;side.hp=10000
			for i: int in range(fps): world.combat.fire(world.player,1.0/fps)
			outcomes.append([world.player.ice_armor,State.run.mp,behind.hp])
		for index: int in range(3): near(outcomes[0][index],outcomes[2][index],spell+" major frame independence")
	world.free();world=null
	await get_tree().process_frame

func visual_checks() -> void:
	DisplayServer.window_set_size(Vector2i(1440,900))
	State.fresh(482);State.learn("missile");State.learn("creativity")
	State.run.skills.merge({"fire":1,"explode":1,"embers":1,"ice":1,"cone":1,"chill":1,"lightning":1,"chain":1,"stun":1,"multishot":1,"potent":1})
	State.run.level=30;State.run.pending=[30]
	State.run.offers=["immolation","ether_charge","hurricane","harden"]
	main=load("res://scenes/main.tscn").instantiate();add_child(main)
	main.start_game();main.world.player.qa_controlled=true
	main.show_level();await capture("four-choices-1440x900")
	var level_view: LevelUpView=main.modal
	level_view.cards.harden.grab_focus()
	await get_tree().create_timer(0.2,true).timeout
	var button: Button=level_view.confirm
	check(button!=null,"Fourth choice has an actual input button")
	if button:
		var parent: Node=button.get_parent()
		while parent:
			if parent is ScrollContainer: parent.ensure_control_visible(button);break
			parent=parent.get_parent()
		await capture("fourth-choice-1440x900")
		var point: Vector2=get_viewport().get_final_transform()*button.get_global_rect().get_center()
		var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.position=point
		Input.parse_input_event(motion)
		for pressed: bool in [true,false]:
			var event: InputEventMouseButton=InputEventMouseButton.new()
			event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			Input.parse_input_event(event);await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		check(State.learned_rank("harden")==1 and State.run.pending.is_empty(),"Native click on fourth choice learns Harden once")
	main.show_skills();await capture("grimoire-1440x900")
	main.close_modal();State.run.pending=[31];State.run.level=31
	State.run.offers=["immolation","ether_charge","hurricane","harden"]
	DisplayServer.window_set_size(Vector2i(960,600))
	main.show_level();await capture("four-choices-960x600")
	State.run.pending=[];State.run.offers=[];main.close_modal()
	DisplayServer.window_set_size(Vector2i(1440,900))
	main.world.load_floor(1)
	main.world.player.qa_controlled=true;main.world.player.set_physics_process(false)
	main.world.set_physics_process(false)
	for enemy: TowerEnemy in main.world.enemies: enemy.set_physics_process(false)
	State.run.skills.merge({"harden":3,"hurricane":3,"ether_charge":3})
	for spell: String in ["lightning","ice","missile"]:
		State.run.active=spell;State.run.mp=1000
		main.world.player.storm_active=false;main.world.player.ice_armor=0
		main.world.player.ether_charges=3 if spell=="missile" else 0
		if spell!="missile": main.world.combat.fire(main.world.player,0.5)
		main.world.player.queue_redraw()
		await capture("major-"+spell+"-1440x900")
	main.queue_free();await get_tree().create_timer(0.3,true).timeout

func find_choice(node: Node, title: String) -> Button:
	if node is Label and node.text==title: return find_button(node.get_parent(),"Choose")
	for child: Node in node.get_children():
		var found: Button=find_choice(child,title)
		if found: return found
	return null

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child: Node in node.get_children():
		var found: Button=find_button(child,prefix)
		if found: return found
	return null

func capture(name: String) -> void:
	await get_tree().create_timer(0.3,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://outputs/skills-audit/"+name+".png")
	captures.append(name)
