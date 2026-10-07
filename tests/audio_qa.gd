extends Node

var failures: Array[String] = []
var checks: int = 0
var main: Node

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not State.qa:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://outputs/audio-qa")
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(Vector2i(1440,900))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	State.options.volume = 0.5
	State.options.music = 0.45
	State.options.effects = 0.8
	State.apply_options()
	await wait(0.1)
	check(Sound.streams.size()==Sound.EFFECTS.size(),"All effect assets loaded")
	check(Sound.channel_streams.size()==5,"Five distinct continuous spells loaded")
	check(Sound.tracks.size()==4,"Four music themes loaded")
	check(Sound.music_context=="menu","Menu selects its own score")
	for id: String in Sound.channel_streams:
		var stream: AudioStreamWAV = Sound.channel_streams[id]
		check(stream.loop_end==roundi(stream.get_length()*stream.mix_rate),"Loop length follows actual sample rate: "+id)
	for id: String in Sound.tracks:
		check(Sound.tracks[id].loop and Sound.tracks[id].get_length()>30,"Long looping theme: "+id)
	State.fresh(17432)
	State.learn("missile")
	main.start_game()
	check(Sound.music_context=="village","Village changes score")
	main.world.load_floor(1,true)
	check(Sound.music_context=="exploration","Tower changes score")
	main.world.player.qa_controlled = true
	main.world.player.set_physics_process(false)
	main.world.set_physics_process(false)
	for enemy: Node in main.world.enemies: enemy.set_physics_process(false)
	var enemy: TowerEnemy = main.world.enemies[0]
	var old_position: Vector2 = enemy.position
	var old_boss: bool = enemy.boss
	enemy.boss = true
	enemy.active = true
	enemy.position = main.world.player.position+Vector2(60,0)
	main.world.audio_check = 0.0
	main.world._physics_process(0.4)
	check(Sound.music_context=="boss","Nearby active boss triggers combat music")
	enemy.active = false
	main.world._physics_process(6.0)
	check(Sound.music_context=="exploration","Boss disengagement restores exploration after grace period")
	enemy.boss = old_boss
	enemy.position = old_position
	var recorder: AudioEffectRecord = AudioEffectRecord.new()
	var bus: int = AudioServer.get_bus_index("GameAudio")
	AudioServer.add_bus_effect(bus,recorder)
	recorder.set_recording_active(true)
	for id: String in ["missile","fire","fire_missile","frost_missile","ball_lightning"]:
		State.run.active = id
		State.run.mp = 100
		main.world.player.fire_timer = 0
		main.world.combat.fire(main.world.player,0.016)
		check(Sound.last_played.has(id),"Real projectile cast selects "+id)
		await wait(0.2)
	for id: String in Sound.CHANNELS:
		State.run.active = id
		State.run.mp = 100
		for i: int in range(6):
			main.world.combat.fire(main.world.player,0.016)
			await wait(0.025)
		check(Sound.channel_id==id and Sound.channel_voice.playing,"Sustained casting uses "+id)
		await wait(0.22)
		check(not Sound.channel_voice.playing,"Release stops "+id)
	State.run.active = "lightning"
	State.run.mp = 100
	main.world.combat.fire(main.world.player,0.016)
	State.run.mp = 0
	main.world.combat.fire(main.world.player,0.016)
	await wait(0.22)
	check(not Sound.channel_voice.playing,"Mana exhaustion stops channel audio")
	State.run.mp = 100
	main.world.combat.fire(main.world.player,0.016)
	main.show_pause()
	check(not Sound.channel_voice.playing,"Pause stops channel immediately")
	main.close_modal()
	for id: String in Catalog.ids("secondary"):
		State.run.secondary = [id]
		State.run.skills[id] = 1
		State.run.mp = 100
		main.world.player.cooldowns.clear()
		check(main.world.combat.secondary(main.world.player,0),"Ritual can execute: "+id)
		check(Sound.last_played.has(id),"Ritual has its own sound: "+id)
		await wait(0.2)
	Sound.stop_world()
	for i: int in range(Sound.voices.size()):
		var voice: AudioStreamPlayer2D = Sound.voices[i]
		voice.stream = Sound.streams.circle[0]
		voice.set_meta("priority",0)
		voice.set_meta("started",i)
		voice.play()
	Sound.last_played.erase("hurt")
	Sound.play("hurt")
	var hurt_found: bool = false
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.get_meta("sound_id","")=="hurt": hurt_found = true
	check(hurt_found,"Player damage remains audible when all 24 voices are occupied")
	Sound.set_music("boss")
	await wait(2.1)
	check(Sound.music_weights[Sound.music_target]==1.0,"Music transition reaches full gain")
	check(not Sound.music_players[1-Sound.music_target].playing,"Previous track stops after crossfade")
	Sound.set_music("exploration")
	await wait(0.3)
	Sound.set_music("boss")
	await wait(2.0)
	check(Sound.music_players[Sound.music_target].stream==Sound.tracks.boss,"Rapid context reversal preserves correct theme")
	State.options.effects = 0.0
	Sound.play("chest")
	await wait(.05)
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.playing: check(voice.volume_db<=-80,"Effects slider mutes active effects")
	State.options.effects = .8
	State.options.volume = 0.0
	State.apply_options()
	check(AudioServer.is_bus_mute(0),"Master zero truly mutes output")
	State.options.volume = .5
	State.apply_options()
	recorder.set_recording_active(false)
	var recording: AudioStreamWAV = recorder.get_recording()
	check(recording!=null and recording.get_length()>5,"Audio mixer produced a real recording")
	if recording: recording.save_to_wav("res://outputs/audio-qa/gameplay-mix.wav")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	main.show_options()
	await wait(0.3)
	var sliders: Array[Node] = main.content.find_children("*","HSlider",true,false)
	check(sliders.size()==4,"Options expose master, music, effects and brightness")
	sliders[2].value = 0.35
	check(is_equal_approx(float(State.options.effects),0.35),"Effects slider updates preferences through its signal")
	sliders[2].value = 0.8
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://outputs/audio-qa/options-1440x900.png")
	main.close_modal()
	main.show_victory()
	check(Sound.music_context.is_empty(),"Victory clears combat score")
	main.show_menu()
	check(Sound.music_context=="menu","Return to menu restores theme")
	var file: FileAccess = FileAccess.open("res://outputs/audio-qa/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("AUDIO_QA ",checks," checks; failures: ",failures)
	Sound.stop_all()
	get_tree().paused = false
	await wait(0.2)
	get_tree().quit(0 if failures.is_empty() else 1)
