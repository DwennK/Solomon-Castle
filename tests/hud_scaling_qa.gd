extends Node
## Exercise the real root canvas stretch, which an unscaled SubViewport misses.
var main: Node
var failures: Array[String] = []
var samples: Dictionary = {}

func _ready() -> void:
	if not State.qa or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	call_deferred("run_qa")

func run_qa() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/hud-gothic")
	State.save_path = "user://qa_hud_scaling.json"
	State.fresh(197903)
	State.learn("lightning"); State.learn("fire"); State.learn("shield"); State.learn("teleport")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_game()
	main.world.load_floor(2)
	main.world.player.qa_controlled = true
	main.world.player.set_physics_process(false)
	main.world.set_physics_process(false)
	for enemy: Node in main.world.enemies: enemy.set_physics_process(false)
	State.run.hp = 66; State.run.mp = 65
	State.options.fullscreen = false
	State.apply_options()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	await capture("window-1440")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await capture("retina-maximized")
	check(samples["retina-maximized"].primary_pixels >= samples["window-1440"].primary_pixels,"Enlarging the window enlarges the spell controls")
	State.options.fullscreen = true
	State.apply_options()
	await capture("fullscreen")
	State.options.fullscreen = false
	State.apply_options()
	var report: Dictionary = {"failures":failures,"samples":samples}
	var file: FileAccess = FileAccess.open("res://outputs/hud-gothic/scaling-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("HUD_SCALING_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, description: String) -> void:
	if not ok: failures.append(description); push_error(description)

func capture(label: String) -> void:
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var hud: GameHUD = main.hud
	var canvas_scale: float = get_viewport().get_final_transform().get_scale().x
	var dock_rect: Rect2 = hud.dock.get_global_rect()
	var ratio: float = dock_rect.size.x/hud.size.x
	check(ratio>0.65 and ratio<0.99,label+": dock occupies a readable share of the canvas")
	check(absf(dock_rect.end.y-hud.size.y)<1.0,label+": dock meets the bottom edge")
	check(hud.primary.get_global_rect().size.x>=90.0,label+": Retina scaling is not cancelled")
	check(not hud.dock.is_ancestor_of(hud.navigation_panel),label+": navigation lives outside combat dock")
	check(not dock_rect.intersects(hud.navigation_panel.get_global_rect()),label+": navigation does not overlap combat controls")
	check(hud.primary.size.x>hud.rituals[0].size.x,label+": primary spell has larger distinct socket")
	var rendered: Image = get_viewport().get_texture().get_image()
	rendered.save_png("res://outputs/hud-gothic/"+label+".png")
	samples[label] = {"rendered_size":str(rendered.get_size()),"canvas_size":str(hud.size),"canvas_scale":canvas_scale,"dock_ratio":ratio,"primary_pixels":hud.primary.get_global_rect().size.x*canvas_scale}
