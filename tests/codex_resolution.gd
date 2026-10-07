extends Node

var failures: Array[String]=[]
var evidence: Array=[]

func _ready() -> void:
	if not State.qa or DisplayServer.get_name()=="headless": get_tree().quit(1);return
	process_mode=Node.PROCESS_MODE_ALWAYS
	State.save_path="user://qa_codex_resolution.json"
	DirAccess.make_dir_recursive_absolute("res://outputs/codex-ui")
	var viewport: SubViewport=SubViewport.new()
	viewport.size=Vector2i(1536,1024)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main: Node=load("res://scenes/main.tscn").instantiate();viewport.add_child(main)
	State.fresh(77231)
	for id: String in ["fire","missile","ice","lightning","shield","freeze","regen"]: State.learn(id)
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=6
	for index: int in range(20): State.run.inventory.append(State.make_equipment(Equipment.templates()[index*4],rng))
	State.equip(State.run.inventory[0].uid)
	State.run.active="lightning"
	var candidate: Dictionary={}
	for template: Dictionary in Equipment.templates():
		if template.slot=="staff" and template.bonuses.has("skill:chain"):
			candidate=State.make_equipment(template,rng)
			State.run.inventory.insert(1,candidate)
			break
	main.start_game();main.world.player.qa_controlled=true
	for resolution: Vector2i in [Vector2i(1536,1024),Vector2i(1440,900),Vector2i(960,600),Vector2i(1920,1080)]:
		viewport.size=resolution
		viewport.size_2d_override=Vector2i(1440,900) if resolution.x<1440 else Vector2i.ZERO
		viewport.size_2d_override_stretch=resolution.x<1440
		for state: String in ["inventory","skills","pause","options","initial","new","menu"]:
			match state:
				"inventory":
					main.show_inventory()
					main.modal.select_item(candidate.uid)
					main.modal.cells[candidate.uid].grab_focus()
				"skills": main.show_skills()
				"pause": main.show_pause()
				"options": main.show_options()
				"initial": main.show_initial()
				"new": main.show_new()
				"menu": main.show_menu()
			await get_tree().create_timer(0.35,true).timeout
			if state=="inventory":
				var inventory: InventoryView=main.modal
				if not viewport.get_visible_rect().encloses(inventory.action_body.get_global_rect()): failures.append("Inventory action overflow: "+str(resolution))
				if inventory.detail_scroll.get_v_scroll_bar().max_value>inventory.detail_scroll.size.y+1: failures.append("Compact card needs scrolling: "+str(resolution))
				if inventory.detail_scroll.get_h_scroll_bar().max_value>inventory.detail_scroll.size.x+1: failures.append("Compact card horizontal overflow: "+str(resolution))
			if state=="options":
				var focused: Control=viewport.gui_get_focus_owner()
				if not focused or not main.content.get_parent().get_global_rect().encloses(focused.get_global_rect()): failures.append("Focused option is outside scroll: "+str(resolution))
			await RenderingServer.frame_post_draw
			var rendered: Image=viewport.get_texture().get_image()
			if rendered.get_size()!=resolution: failures.append("Wrong render size "+str(resolution))
			var title: String="native-%s-%dx%d" % [state,resolution.x,resolution.y]
			rendered.save_png("res://outputs/codex-ui/"+title+".png")
			evidence.append({"file":title+".png","pixels":[rendered.get_width(),rendered.get_height()]})
			if state in ["pause","options","initial","new"]:
				var bounds: Rect2=main.content.get_parent().get_global_rect()
				if not viewport.get_visible_rect().encloses(bounds): failures.append("Content overflow: "+title+str(bounds))
			if state=="menu":
				main.start_game();main.world.player.qa_controlled=true
	var report: Dictionary={"errors":failures,"captures":evidence,"method":"Exact native GPU SubViewport; minimum desktop uses the game's 1440x900 canvas scaling; no image enlargement"}
	var file: FileAccess=FileAccess.open("res://outputs/codex-ui/resolution-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("CODEX_RESOLUTION ",JSON.stringify(report))
	Sound.stop_all();main.queue_free();await get_tree().create_timer(0.2,true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
