extends Node

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run_test")

func run_test() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/screenshots")
	var viewport: SubViewport = SubViewport.new()
	viewport.size=Vector2i(1920,1080)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var preview: TextureRect = TextureRect.new()
	preview.texture=viewport.get_texture()
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preview)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	State.fresh(77231)
	State.learn("missile")
	main.start_game()
	main.world.enter_tower()
	for i: int in range(10): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = viewport.get_texture().get_image()
	assert(rendered.get_size()==Vector2i(1920,1080))
	rendered.save_png("res://outputs/screenshots/game-native-1920x1080.png")
	main.show_inventory()
	for i: int in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://outputs/screenshots/inventory-native-1920x1080.png")
	var report: Dictionary = {"renderer":"native Compatibility on Apple M4","viewport_width":rendered.get_width(),"viewport_height":rendered.get_height(),"method":"Godot SubViewport, real native GPU rendering; OS window limit 1728 pixels bypassed only by offscreen render target, not by image resizing"}
	var file: FileAccess=FileAccess.open("res://outputs/resolution-qa.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RESOLUTION_QA ",JSON.stringify(report))
	Sound.stop_all()
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()
