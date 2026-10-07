extends Node
func _ready() -> void:
	if not State.qa: get_tree().quit(1);return
	State.save_path="user://qa_portal_channel.json"
	call_deferred("run_test")
func run_test() -> void:
	State.fresh(872);State.learn("missile");State.run.floor=1
	var data: Dictionary=Dungeon.generate(872,1)
	data.enemies=[];State.run.floors["1"]=data
	var world: GameWorld=load("res://scenes/world.tscn").instantiate();add_child(world)
	world.set_physics_process(false);world.player.set_physics_process(false);world.player.qa_controlled=true
	world.use_portal();world.update_portal(1)
	assert(not world.village and world.portal_remaining>0)
	world.player.invulnerable=0;world.player.take_damage(1)
	assert(world.portal_remaining==0)
	world.use_portal();world.player.position.x+=8;world.update_portal(0.1)
	assert(world.portal_remaining==0)
	world.use_portal();world.player.qa_fire=true;world.player._physics_process(0.01);world.player.qa_fire=false
	assert(world.portal_remaining==0)
	world.player.velocity=Vector2.ZERO
	world.use_portal();var pos: Vector2=world.player.position
	world.update_portal(GameWorld.PORTAL_DURATION)
	assert(world.village)
	world.enter_tower()
	assert(world.player.position.distance_to(pos)<2)
	print("PORTAL_QA 6 checks passed")
	world.queue_free();Sound.stop_all();get_tree().quit()
