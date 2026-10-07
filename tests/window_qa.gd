extends Node

var errors: Array[String] = []
var samples: Dictionary = {}

func _ready() -> void:
	if not State.qa or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	call_deferred("run_qa")

func settle() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw

func check(condition: bool, label: String) -> void:
	if not condition: errors.append(label)

func sample(label: String) -> void:
	samples[label] = {"mode":DisplayServer.window_get_mode(), "size":str(DisplayServer.window_get_size()), "usable_screen":str(DisplayServer.screen_get_usable_rect()), "scale":DisplayServer.screen_get_scale()}

func run_qa() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs/window-fix")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await settle()
	# No resolution override: exercise the real project startup settings.
	sample("startup")
	if not State.options.fullscreen:
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Startup is maximized")
	State.options.fullscreen = false
	State.apply_options()
	await settle()
	var initial_size: Vector2i = DisplayServer.window_get_size()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Default windowed mode is maximized")
	get_viewport().get_texture().get_image().save_png("res://outputs/window-fix/startup.png")
	State.options.volume = 0.0
	State.apply_options()
	await settle()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED and DisplayServer.window_get_size() == initial_size, "Audio option preserves maximized window")
	State.options.fullscreen = true
	State.apply_options()
	await settle()
	sample("fullscreen")
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen enabled")
	State.options.fullscreen = false
	State.apply_options()
	await settle()
	sample("restored_maximized")
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "Fullscreen restores maximized mode")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await settle()
	DisplayServer.window_set_size(Vector2i(1100,720))
	await settle()
	var custom_size: Vector2i = DisplayServer.window_get_size()
	State.options.brightness = 0.9
	State.apply_options()
	await settle()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == custom_size, "Brightness preserves manually resized window")
	State.options.fullscreen = true
	State.apply_options()
	await settle()
	State.options.fullscreen = false
	State.apply_options()
	await settle()
	sample("restored_custom")
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == custom_size, "Fullscreen restores custom window size")
	var report: Dictionary = {"errors":errors, "samples":samples}
	var file: FileAccess = FileAccess.open("res://outputs/window-fix/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("WINDOW_QA ",JSON.stringify(report))
	Sound.stop_all()
	get_tree().quit(0 if errors.is_empty() else 1)
