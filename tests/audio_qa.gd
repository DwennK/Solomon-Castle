extends Node

var failures: Array[String] = []
var checks: int = 0
var main: Node
var deadline: int = 0

func _process(_delta: float) -> void:
	if deadline>0 and Time.get_ticks_msec()>deadline:
		push_error("Audio QA exceeded its 60-second deadline")
		get_tree().quit(1)

func check(ok: bool, description: String) -> void:
	checks += 1
	print("AUDIO_CHECK ",checks," ",ok," ",description)
	if not ok:
		failures.append(description)
		push_error(description)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec()+60000
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
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1440,900))
	await wait(0.1)
	check(Sound.streams.size()==Sound.EFFECTS.size()+Sound.FAMILIES.size()*Sound.CREATURE_EVENTS.size()+2+Sound.DETAILS.size()+Sound.BOSSES.size()*3+Sound.SPELL_DETAILS.size()+Sound.CHANNELS.size()*2,"All effects and creature families loaded")
	check(Sound.channel_streams.size()==5,"Five distinct continuous spells loaded")
	check(Sound.tracks.size()==6,"Six music themes loaded")
	check(Sound.music_context=="menu","Menu selects its own score")
	check(not Sound.ambience_player.playing,"Menu has no lingering dungeon ambience")
	for kind: String in Catalog.ids("enemy"):
		check(Sound.CREATURE_FAMILY.has(kind),"Creature has an explicit voice identity: "+kind)
	for id: String in Sound.channel_streams:
		var stream: AudioStreamWAV = Sound.channel_streams[id]
		check(stream.loop_end==roundi(stream.get_length()*stream.mix_rate),"Loop length follows actual sample rate: "+id)
	for id: String in Sound.tracks:
		check(Sound.tracks[id].loop==(id not in Sound.EXPLORATION) and Sound.tracks[id].get_length()>70,"Composed theme and correct loop policy: "+id)
	State.fresh(17432)
	State.learn("missile")
	main.start_game()
	check(Sound.music_context=="village","Village changes score")
	main.world.load_floor(1,true)
	check(Sound.music_context=="exploration","Tower changes score")
	check(Sound.environment=="tower" and Sound.ambience_player.playing,"Tower starts the environmental bed")
	main.world.player.qa_controlled = true
	main.world.player.set_physics_process(false)
	main.world.set_physics_process(false)
	for enemy: Node in main.world.enemies: enemy.set_physics_process(false)
	var recorder: AudioEffectRecord = AudioEffectRecord.new()
	var bus: int = AudioServer.get_bus_index("GameAudio")
	AudioServer.add_bus_effect(bus,recorder)
	recorder.set_recording_active(true)
	await spell_checks()
	await living_checks()
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
	# Exercise the actual creature hooks without depending on a generated encounter's state.
	Sound.stop_world()
	Sound.set_environment("tower")
	enemy.record.dormant = false
	enemy.record.trial = false
	# Exercise proximity detection independently of the room encounter wake rules.
	enemy.record.erase("encounter_room")
	enemy.active = false
	enemy.position = main.world.player.position+Vector2(20,0)
	enemy.frozen = 0.0
	enemy.wake_time = 0.0
	enemy.voice_timer = 0.0
	var family: String = Sound.CREATURE_FAMILY[enemy.record.kind]
	Sound.last_played.erase("creature_"+family+"_alert")
	enemy._physics_process(.016)
	check(Sound.last_played.has("creature_"+family+"_alert"),"Enemy detection triggers its own alert voice")
	Sound.stop_world()
	Sound.last_played.erase("creature_"+family+"_idle")
	enemy.voice_timer = 0.0
	enemy._physics_process(.016)
	check(Sound.last_played.has("creature_"+family+"_idle"),"Active enemy emits spaced presence sounds")
	Sound.stop_world()
	Sound.last_played.erase("creature_"+family+"_hurt")
	enemy.hurt_voice_timer = 0.0
	enemy.take_damage(.01)
	check(Sound.last_played.has("creature_"+family+"_hurt"),"Nonlethal hits trigger creature pain")
	Sound.stop_world()
	Sound.last_played.erase("creature_"+family+"_attack")
	enemy.release_attack()
	check(Sound.last_played.has("creature_"+family+"_attack"),"Real attack triggers creature effort")
	Sound.stop_world()
	Sound.last_played.clear()
	enemy.frozen = 1.0
	enemy.voice_timer = 0.0
	enemy._physics_process(.016)
	check(not Sound.last_played.has("creature_"+family+"_idle"),"Frozen enemies do not emit idle voices")
	enemy.frozen = 0.0
	enemy.record.dormant = true
	enemy.record.awakened = false
	enemy._physics_process(.016)
	check(not Sound.last_played.has("creature_"+family+"_idle"),"Dormant encounters remain silent")
	enemy.record.dormant = false
	enemy.take_damage(999999.0)
	check(Sound.last_played.has("creature_"+family+"_death"),"Lethal damage uses that creature's death sound")
	Sound.stop_world()
	Sound.last_played.clear()
	check(not Sound.creature("zombie","idle",Sound.listener_position+Vector2(1600,0)),"Far creatures are silent")
	check(Sound.creature("zombie","idle",Sound.listener_position),"Nearby creature can be heard")
	check(not Sound.creature("imp","idle",Sound.listener_position),"Global idle budget prevents a chorus")
	Sound.stop_world()
	Sound.last_played.clear()
	check(Sound.creature("ghost","alert",Sound.listener_position,true),"Occluded presence can still be heard")
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.playing and voice.get_meta("sound_id","")=="creature_wraith_alert": check(float(voice.get_meta("gain"))<=-14.0,"Walls attenuate the creature voice")
	Sound.stop_world()
	Sound.last_played.clear()
	for i: int in range(3):
		Sound.play("missile")
		var previous_variant: int = Sound.variant_index.missile
		Sound.last_played.erase("missile")
		Sound.play("missile")
		check(Sound.variant_index.missile!=previous_variant,"Variants never immediately repeat")
		Sound.last_played.erase("missile")
	Sound.stop_world()
	Sound.set_environment("tower")
	Sound.set_torch(Sound.listener_position+Vector2(30,0))
	await wait(.1)
	check(Sound.torch_player.playing and Sound.torch_gain>0,"Nearby torch starts a localized fire loop")
	Sound.set_torch(Vector2.INF)
	await wait(.7)
	check(Sound.torch_gain==0,"Leaving a torch removes its sound")
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
	await wait(.06)
	check(Sound.ambience_player.stream_paused and Sound.torch_player.stream_paused,"Pause suspends environmental loops")
	check(not Sound.creature("demon","alert",Sound.listener_position),"Paused creatures cannot start voices")
	main.close_modal()
	await wait(.06)
	check(Sound.environment=="tower" and Sound.ambience_player.playing and not Sound.ambience_player.stream_paused,"Resuming restores the same environmental loop")
	for id: String in Catalog.ids("secondary"):
		State.run.secondary = [id]
		State.run.skills[id] = 1
		State.run.mp = 100
		main.world.player.cooldowns.clear()
		check(main.world.combat.secondary(main.world.player,0),"Ritual can execute: "+id)
		check(Sound.last_played.has(id),"Ritual has its own sound: "+id)
		await wait(0.2)
	Sound.stop_world()
	check(not Sound.ambience_player.playing and not Sound.torch_player.playing,"World teardown stops both ambient layers")
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
		# macOS can suppress frame_post_draw for an occluded test window.
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://outputs/audio-qa/options-1440x900.png")
	main.close_modal()
	main.show_victory()
	check(Sound.music_context.is_empty(),"Victory clears combat score")
	main.show_menu()
	check(Sound.music_context=="menu","Return to menu restores theme")
	check(not Sound.ambience_player.playing and not Sound.torch_player.playing,"Menu remains free of dungeon audio")
	main.show_credits()
	var credits_button: Button
	for node: Node in main.content.get_children():
		if node is Button and node.text=="Audio credits": credits_button = node
	check(credits_button!=null,"Audio attribution is reachable from the credits screen")
	if credits_button: credits_button.pressed.emit()
	await wait(.3)
	check(main.modal_kind=="credits","Audio credits opens through the actual button")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://outputs/audio-qa/credits-1440x900.png")
	var file: FileAccess = FileAccess.open("res://outputs/audio-qa/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("AUDIO_QA ",checks," checks; failures: ",failures)
	Sound.stop_all()
	get_tree().paused = false
	await wait(0.2)
	get_tree().quit(0 if failures.is_empty() else 1)

func spell_checks() -> void:
	Sound.stop_world()
	Sound.last_played.clear()
	for id: String in Sound.SPELL_CASTS:
		check(Sound.streams[id].size()==3,"Spell has three authored variations: "+id)
	for id: String in Sound.SPELL_IMPACTS:
		Sound.stop_world()
		Sound.last_played.clear()
		Sound.impact(id,Sound.listener_position,"stone")
		check(Sound.last_played.has("impact_"+String(Sound.SPELL_IMPACTS[id])),"Impact retains spell identity: "+id)
	for id: String in Sound.CHANNELS:
		Sound.stop_world()
		Sound.last_played.clear()
		Sound.sustain(id)
		check(Sound.last_played.has("cast_"+id),"Channel starts with its own transient: "+id)
		var started: int = Sound.last_played["cast_"+id]
		Sound._process(.25)
		check(not Sound.channel_released,"A long render delta cannot release a freshly refreshed channel: "+id)
		for i: int in range(8):
			await wait(.025)
			Sound.sustain(id)
		check(Sound.last_played["cast_"+id]==started,"Holding cast does not repeat the attack: "+id)
		await wait(.24)
		check(not Sound.channel_voice.playing and Sound.last_played.has("release_"+id),"Release finishes the channel with its own tail: "+id)
		await wait(.1)
	Sound.last_played.clear()
	Sound.sustain("ice")
	await wait(.02)
	Sound.sustain("lightning")
	check(Sound.channel_id=="lightning" and not Sound.last_played.has("release_ice"),"Switching channels cancels the old tail")
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.playing: check(voice.get_meta("sound_id","")!="cast_ice","Old channel attack cannot linger after switching")
	Sound.last_played.clear()
	main.show_pause()
	await wait(.2)
	check(not Sound.last_played.has("release_lightning") and not Sound.channel_voice.playing,"Pause cancels all spell phases without a spurious release")
	main.close_modal()
	Sound.sustain("steam")
	Sound.stop_world()
	await wait(.2)
	check(not Sound.last_played.has("release_steam"),"World teardown never emits a spell release")
	Sound.last_played.clear()
	main.world.combat.orb_pulse(Vector2(100000,100000),main.world.combat.profile("ball_lightning"))
	check(not Sound.last_played.has("orb_pulse"),"An orb in empty space does not emit false contact feedback")
	for i: int in range(12):
		Sound.last_played.erase("impact_fire")
		Sound.play("impact_fire",Sound.listener_position)
	var impact_count: int = 0
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.playing and String(voice.get_meta("sound_id","")).begins_with("impact_"): impact_count += 1
	check(impact_count==6,"Dense multishot impacts have a six-voice ceiling")
	Sound.last_played.erase("missile")
	check(Sound.play("missile",Sound.listener_position),"A new cast remains audible during impact saturation")
	Sound.stop_world()
	Sound.set_environment("tower")

func living_checks() -> void:
	Sound.last_played.clear()
	for style: String in Sound.ROOMS:
		Sound.set_room(style)
		check(Sound.room_style==style and Sound.room_players[Sound.room_target].playing,"Room selects its own texture: "+style)
		check(Sound.room_players[Sound.room_target].stream==Sound.ambience_streams[style],"Room bed matches the selected style: "+style)
		Sound.play("room_"+style,Sound.listener_position)
		await wait(.04)
	await wait(2.7)
	check(not Sound.room_players[1-Sound.room_target].playing,"Previous room bed stops after its crossfade")
	Sound.set_room("crypt")
	await wait(.1)
	Sound.set_room("ruins")
	check(Sound.room_players[Sound.room_target].stream==Sound.ambience_streams.ruins,"Rapid room reversal reuses the correct bed")
	Sound.set_room("corridor")
	await wait(2.7)
	check(not Sound.room_players[0].playing and not Sound.room_players[1].playing,"Corridors release both room textures")
	Sound.set_room("library")
	main.show_pause()
	await wait(.05)
	check(Sound.room_players[Sound.room_target].stream_paused,"Room textures suspend in pause")
	main.close_modal()
	Sound.set_environment("village")
	check(Sound.ambience_player.stream==Sound.ambience_streams.village and Sound.ambience_player.playing,"Village has its own natural ambience")
	check(not Sound.room_players[0].playing and not Sound.room_players[1].playing and not Sound.torch_player.playing,"Village clears dungeon room beds and fire")
	Sound.set_environment("tower")
	var previous: String = Sound.music_track
	Sound.music_remaining = .01
	await wait(.08)
	check(Sound.music_gap>0.0,"End of exploration score schedules a quiet interval")
	var gap: float = Sound.music_gap
	main.show_pause()
	await wait(.1)
	check(is_equal_approx(Sound.music_gap,gap),"Music silence timer suspends in pause")
	main.close_modal()
	Sound.music_gap = .01
	await wait(.08)
	check(Sound.music_track!=previous and Sound.music_track in Sound.EXPLORATION,"Exploration resumes with a different composition")
	var remaining: float = Sound.music_remaining
	Sound.set_music("exploration")
	check(is_equal_approx(Sound.music_remaining,remaining),"Repeated world checks do not restart a score")
	Sound.set_threat(4)
	check(Sound.last_played.has("encounter"),"Entering a dense encounter triggers a restrained tension cue")
	var encounter_time: int = Sound.last_played.encounter
	Sound.set_threat(0)
	Sound.set_threat(4)
	check(Sound.last_played.encounter==encounter_time,"Encounter cooldown prevents repeated stingers")
	Sound.stop_world()
	Sound.last_played.clear()
	Sound.set_environment("tower")
	check(Sound.creature("ghost","alert",Sound.listener_position,true),"Occluded creature can start")
	for voice: AudioStreamPlayer2D in Sound.voices:
		if voice.playing and voice.get_meta("sound_id","")=="creature_wraith_alert": check(voice.bus=="OccludedEffects","Walls route creature through a real low-pass filter")
	var bus: int = AudioServer.get_bus_index("OccludedEffects")
	check(AudioServer.get_bus_effect(bus,0) is AudioEffectLowPassFilter,"Occlusion bus contains the low-pass effect")
	for pair: Array in [["skeleton","bone"],["knight","metal"],["zombie","flesh"],["ghost","ethereal"],["stone","stone"]]:
		Sound.material_time = -10000
		Sound.impact("missile",Sound.listener_position,pair[0])
		check(Sound.last_played.has("material_"+pair[1]),"Impact uses the target material: "+pair[1])
		await wait(.08)
	Sound.material_time = Time.get_ticks_msec()
	Sound.last_played.erase("material_bone")
	Sound.hit_material("skeleton",Sound.listener_position)
	check(not Sound.last_played.has("material_bone"),"Continuous and area hits share a bounded material budget")
	for kind: String in Sound.BOSSES:
		Sound.stop_world()
		Sound.last_played.clear()
		check(Sound.creature(kind,"alert",Sound.listener_position,false,true),"Boss reveal signature: "+kind)
		Sound.boss_warning(kind,Sound.listener_position)
		check(Sound.last_played.has("boss_"+kind+"_warning"),"Boss has a distinct warning: "+kind)
		check(Sound.creature(kind,"death",Sound.listener_position,false,true),"Boss death signature: "+kind)
		await wait(.08)
	check(Sound.danger_gain>0.0,"Danger cues duck secondary effects and music")
	var specimen: TowerEnemy = main.world.enemies[0]
	var saved_record: Dictionary = specimen.record.duplicate(true)
	var saved_position: Vector2 = specimen.position
	var saved_active: bool = specimen.active
	specimen.record.kind = "king"
	specimen.record.dormant = false
	specimen.boss = true
	specimen.active = true
	specimen.position = main.world.player.position+Vector2(15,0)
	specimen.cooldown = 0.0
	specimen.telegraph = 0.0
	Sound.last_played.erase("boss_king_warning")
	var phase: int = specimen.phase
	specimen._physics_process(.016)
	check(specimen.telegraph>0.0 and specimen.phase==phase and Sound.last_played.has("boss_king_warning"),"Real boss warning occurs during telegraph, before damage release")
	specimen.record = saved_record
	specimen.position = saved_position
	specimen.active = saved_active
	specimen.boss = false
	specimen.telegraph = 0.0
	specimen.cooldown = 1.0
	specimen.remove_meta("boss_announced")
	Sound.stop_world()
	Sound.last_played.clear()
	main.show_inventory()
	check(Sound.last_played.has("inventory_open"),"Opening actual inventory plays its own cue")
	var saved_inventory: Array = State.run.inventory.duplicate(true)
	var saved_equipped: Dictionary = State.run.equipped.duplicate(true)
	var saved_gold: int = State.run.gold
	var inventory: InventoryView = main.modal
	for slot: String in ["staff","ring"]:
		var item: Dictionary = {}
		for seed: int in range(100,140):
			item = State.make_item(seed,3)
			if item.slot==slot: break
		State.run.inventory = [item]
		State.run.equipped = {"staff":"","ring1":"","ring2":""}
		Sound.last_played.erase("equip_"+slot)
		inventory.selected_uid = item.uid
		inventory.choose_target()
		inventory.refresh()
		check(not Sound.last_played.has("equip_"+slot),"Equipment comparison is silent: "+slot)
		var action: Button = inventory.action_body.get_node("InventoryAction")
		action.pressed.emit()
		check(Sound.last_played.has("equip_"+slot) and item.uid in State.run.equipped.values(),"Real equipment action plays its cue: "+slot)
		Sound.last_played.erase("unequip")
		action = inventory.action_body.get_node("InventoryAction")
		action.pressed.emit()
		check(Sound.last_played.has("unequip") and item.uid not in State.run.equipped.values(),"Real removal plays its cue: "+slot)
		await wait(.1)
	inventory.selling = true
	inventory.refresh()
	Sound.last_played.erase("trade")
	var sell: Button = inventory.action_body.get_node("InventoryAction")
	sell.pressed.emit()
	check(Sound.last_played.has("trade") and State.run.inventory.is_empty(),"Successful sale plays transaction cue")
	main.close_modal()
	var saved_loot: Array = main.world.loot.duplicate(true)
	for rarity: int in [1,2]:
		var item: Dictionary = State.make_item(148+rarity,3)
		item.rarity = rarity
		var cue: String = "loot_rare" if rarity==1 else "loot_epic"
		Sound.last_played.erase(cue)
		main.world.loot = [{"kind":"item","item":item,"pos":Dungeon.pair(main.world.player.position)}]
		State.run.inventory.clear()
		for i: int in range(48): State.run.inventory.append(item.duplicate(true))
		main.world.collect_loot()
		check(not Sound.last_played.has(cue) and main.world.loot.size()==1,"Full bag keeps rare loot silent and on ground")
		State.run.inventory.clear()
		main.world.collect_loot()
		check(Sound.last_played.has(cue) and main.world.loot.is_empty(),"Actual pickup plays the correct rarity: "+cue)
	main.world.loot = saved_loot
	State.run.inventory = saved_inventory
	State.run.equipped = saved_equipped
	State.run.gold = saved_gold
	State.refresh_equipment()
	main.show_skills()
	check(Sound.last_played.has("book_open"),"Opening actual grimoire plays its own cue")
	main.close_modal()
	Sound.set_environment("tower")
