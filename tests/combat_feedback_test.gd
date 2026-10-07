extends Node

var checks: int = 0
var failures: Array[String] = []
var world: GameWorld
var target: TowerEnemy

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_combat_feedback.json"
	call_deferred("run_all")

func run_all() -> void:
	State.fresh(821);State.learn("ice");State.run.floor=1
	var data: Dictionary = Dungeon.generate(821,1)
	var grid: Array[String] = []
	for y: int in range(Dungeon.HEIGHT):
		var row: String = ""
		for x: int in range(Dungeon.WIDTH): row+="." if Rect2i(3,3,22,18).has_point(Vector2i(x,y)) else "#"
		grid.append(row)
	data.grid=grid;data.rooms=[[3,3,22,18]];data.props=[];data.enemies=[];data.encounters=[]
	data.entry=[800,800];data.exit=[1200,1000]
	State.run.floors["1"]=data;State.run.position=[800,800]
	world=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.set_physics_process(false);world.player.qa_controlled=true
	world.player.aim=Vector2.RIGHT
	target=load("res://scenes/enemy.tscn").instantiate()
	target.setup(world,{"id":"feedback_target","kind":"skeleton","pos":[980,800],"hp":-1.0,"dead":false})
	world.actors.add_child(target);world.enemies.append(target);target.set_physics_process(false)
	target.visual.environment=world.dungeon.interior
	target.max_hp=1000;target.hp=1000;target.active=true
	for spell: String in ["ice","steam","blizzard"]:
		for rank_value: int in [1,5,10]:
			State.run.skills={"ice":1,"fire":1,"lightning":1,"cone":1,"chill":rank_value}
			if spell!="ice": State.learn(spell)
			world.enemy_bolt(world.player.position+Vector2(100,0),Vector2.LEFT,10,100,Color.RED)
			var shot: MagicProjectile = world.shots.get_child(0)
			shot.set_physics_process(false)
			var before: Vector2 = shot.position
			target.knockback=Vector2.ZERO
			world.combat.channel(world.player,world.combat.profile(spell),0.1)
			check(shot.direction==Vector2.LEFT and shot.position==before and shot.speed==100 and shot.hostile,"%s rank %d leaves hostile projectile unchanged"%[spell,rank_value])
			check(target.knockback.x>0,"%s keeps enemy knockback"%spell)
			shot.free()
	State.run.skills={"lightning":1,"hurricane":5}
	world.enemy_bolt(world.player.position+Vector2(100,0),Vector2.LEFT,10,100,Color.RED)
	var shot: MagicProjectile = world.shots.get_child(0);shot.set_physics_process(false)
	world.combat.hurricane(world.player,0.1)
	check(shot.direction==Vector2.LEFT,"Hurricane does not redirect hostile projectiles")
	world.player.shield=0;world.player.ice_armor=0;world.player.invulnerable=0
	var hp: float = State.run.hp
	shot._physics_process(0.9)
	check(State.run.hp<hp,"Incoming projectile can still hit the mage after knockback effects")
	shot.free()
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://outputs/combat-feedback")
	var file: FileAccess = FileAccess.open("res://outputs/combat-feedback/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT_FEEDBACK_QA ",JSON.stringify(report))
	world.queue_free();Sound.stop_all();get_tree().quit(0 if failures.is_empty() else 1)
