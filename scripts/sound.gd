extends Node
## Free, credited recordings; spatial creatures, room ambience and composed score.

const EFFECTS: Array[String] = ["missile","fire","fire_missile","frost_missile","ball_lightning","impact","impact_arcane","impact_fire","impact_ice","impact_lightning","hurt","enemy","enemy_melee","enemy_bow","enemy_magic","enemy_death","boss_attack","boss_death","potion","mana","loot","item","ui","spell_switch","ritual","chest","urn","teleport","portal","shield","shield_hit","circle","freeze","ring_fire","acid","undead","death","victory","level_up","step_stone","step_gravel"]
const CHANNELS: Array[String] = ["lightning","ice","flame_lash","steam","blizzard"]
const FAMILIES: Array[String] = ["skeleton","zombie","beast","armor","wraith","imp","demon"]
const CREATURE_EVENTS: Array[String] = ["idle","alert","attack","hurt","death","step"]
const ROOMS: Array[String] = ["crypt","library","prison","laboratory","chapel","ruins"]
const EXPLORATION: Array[String] = ["exploration","tower","caverns"]
const DETAILS: Array[String] = ["material_bone","material_flesh","material_metal","material_ethereal","material_stone","inventory_open","book_open","equip_staff","equip_ring","unequip","trade","key_found","seal_open","loot_rare","loot_epic","encounter","room_crypt","room_library","room_prison","room_laboratory","room_chapel","room_ruins","village_merchant","village_teacher","village_healer"]
const BOSSES: Array[String] = ["king","plague","demon","lich"]
const CREATURE_FAMILY: Dictionary = {"skeleton":"skeleton","archer":"skeleton","zombie":"zombie","plague":"zombie","ghoul":"beast","knight":"armor","king":"armor","sorcerer":"wraith","lich":"wraith","ghost":"wraith","imp":"imp","demon":"demon"}
const PRIORITY: Dictionary = {"death":10,"victory":10,"hurt":8,"shield_hit":8,"boss_attack":7,"boss_death":7,"level_up":7,"potion":6,"mana":6,"ui":5,"step_stone":0,"step_gravel":0}
var streams: Dictionary = {}
var tracks: Dictionary = {}
var channel_streams: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var last_played: Dictionary = {}
var variant_index: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var music_weights: Array[float] = [0.0,0.0]
var music_target: int = 0
var music_context: String = ""
var channel_voice: AudioStreamPlayer
var channel_id: String = ""
var channel_timeout: float = 0.0
var channel_gain: float = 0.0
var listener_position: Vector2 = Vector2.ZERO
var enabled: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambience_player: AudioStreamPlayer
var torch_player: AudioStreamPlayer2D
var ambience_streams: Dictionary = {}
var environment: String = ""
var ambience_gain: float = 0.0
var torch_gain: float = 0.0
var torch_target: float = 0.0
var room_reverb: AudioEffectReverb
var creature_cooldowns: Dictionary = {}
var room_players: Array[AudioStreamPlayer] = []
var room_weights: Array[float] = [0.0,0.0]
var room_target: int = 0
var room_style: String = ""
var music_track: String = ""
var music_remaining: float = 0.0
var music_gap: float = 0.0
var last_exploration: String = ""
var danger_time: float = 0.0
var danger_gain: float = 0.0
var tension: float = 0.0
var tension_target: float = 0.0
var encounter_cooldown: float = 0.0
var material_time: int = -10000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless" and "--audio-qa" not in OS.get_cmdline_user_args():
		enabled = false
		return
	rng.randomize()
	var effect_ids: Array[String] = EFFECTS.duplicate()
	effect_ids.append_array(["dungeon_creak","dungeon_stone"])
	effect_ids.append_array(DETAILS)
	for boss: String in BOSSES:
		for event: String in ["alert","warning","death"]: effect_ids.append("boss_"+boss+"_"+event)
	for family: String in FAMILIES:
		for event: String in CREATURE_EVENTS: effect_ids.append("creature_"+family+"_"+event)
	for id: String in effect_ids:
		var variants: Array[AudioStream] = []
		for suffix: String in ["","_2","_3"]:
			var path: String = "res://assets/audio/"+id+suffix+".wav"
			if ResourceLoader.exists(path): variants.append(load(path))
		if not variants.is_empty(): streams[id] = variants
	for id: String in CHANNELS:
		var stream: AudioStreamWAV = load("res://assets/audio/channel_"+id+".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		channel_streams[id] = stream
	for id: String in ["menu","village","exploration","boss","tower","caverns"]:
		var stream: AudioStreamOggVorbis = load("res://assets/audio/music_"+id+".ogg")
		stream.loop = id not in EXPLORATION
		tracks[id] = stream
	# A final limiter protects dense combat without flattening each sound asset.
	if AudioServer.get_bus_index("GameAudio")<0:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"GameAudio")
		AudioServer.set_bus_send(bus,"Master")
		var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -3.0
		AudioServer.add_bus_effect(bus,limiter)
	if AudioServer.get_bus_index("WorldEffects")<0:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"WorldEffects")
		AudioServer.set_bus_send(bus,"GameAudio")
		room_reverb = AudioEffectReverb.new()
		room_reverb.room_size = 0.65
		room_reverb.damping = 0.72
		room_reverb.wet = 0.0
		AudioServer.add_bus_effect(bus,room_reverb)
	if AudioServer.get_bus_index("OccludedEffects")<0:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"OccludedEffects")
		AudioServer.set_bus_send(bus,"WorldEffects")
		var filter: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 1300.0
		filter.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(bus,filter)
	for i: int in range(24):
		var voice: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		voice.bus = "GameAudio"
		voice.max_distance = 1150.0
		voice.panning_strength = 0.65
		add_child(voice)
		voices.append(voice)
	for i: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "GameAudio"
		player.volume_db = -80
		add_child(player)
		music_players.append(player)
	channel_voice = AudioStreamPlayer.new()
	channel_voice.bus = "GameAudio"
	channel_voice.volume_db = -80
	channel_voice.bus = "WorldEffects"
	add_child(channel_voice)
	var ambient_ids: Array[String] = ["cave","torch","village"]
	ambient_ids.append_array(ROOMS)
	for id: String in ambient_ids:
		var stream: AudioStreamOggVorbis = load("res://assets/audio/ambience_"+id+".ogg")
		stream.loop = true
		ambience_streams[id] = stream
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "GameAudio"
	ambience_player.stream = ambience_streams.cave
	ambience_player.volume_db = -80
	add_child(ambience_player)
	torch_player = AudioStreamPlayer2D.new()
	torch_player.bus = "GameAudio"
	torch_player.stream = ambience_streams.torch
	torch_player.max_distance = 340.0
	torch_player.attenuation = 1.4
	torch_player.panning_strength = 0.45
	torch_player.volume_db = -80
	add_child(torch_player)
	for i: int in range(2):
		var bed: AudioStreamPlayer = AudioStreamPlayer.new()
		bed.bus = "WorldEffects"
		bed.volume_db = -80
		add_child(bed)
		room_players.append(bed)
	set_music("menu")

func _process(delta: float) -> void:
	if not enabled: return
	var paused: bool = get_tree().paused
	if not paused:
		danger_time = maxf(0.0,danger_time-delta)
		encounter_cooldown = maxf(0.0,encounter_cooldown-delta)
		if music_context=="exploration":
			if music_gap>0.0:
				music_gap = maxf(0.0,music_gap-delta)
				if music_gap==0.0: start_exploration()
			else:
				music_remaining -= delta
				if music_remaining<=0.0: music_gap = rng.randf_range(9.0,17.0)
	tension = move_toward(tension,tension_target,delta/2.0)
	danger_gain = move_toward(danger_gain,1.0 if danger_time>0.0 else 0.0,delta/(0.06 if danger_time>0.0 else 0.65))
	var music_volume: float = clampf(float(State.options.get("music",0.45)),0,1)
	var effects_volume: float = clampf(float(State.options.get("effects",0.8)),0,1)
	for i: int in range(music_players.size()):
		var target: float = 1.0 if i==music_target and not music_context.is_empty() and music_gap<=0.0 else 0.0
		music_weights[i] = move_toward(music_weights[i],target,delta/1.8)
		music_players[i].stream_paused = paused and music_context=="exploration"
		music_players[i].volume_db = linear_to_db(maxf(0.0001,music_weights[i]*music_volume))-7.0+2.0*tension-4.0*danger_gain-(7.0 if paused else 0.0)
		if music_weights[i]==0.0 and target==0.0: music_players[i].stop()
	channel_timeout = maxf(0.0,channel_timeout-delta)
	var active: bool = channel_timeout>0.0 and not paused
	channel_gain = move_toward(channel_gain,1.0 if active else 0.0,delta/0.065)
	channel_voice.volume_db = linear_to_db(maxf(0.0001,channel_gain*effects_volume))-9.0-5.0*danger_gain
	if channel_gain==0.0 and channel_voice.playing:
		channel_voice.stop()
		channel_id = ""
	for voice: AudioStreamPlayer2D in voices:
		if voice.playing:
			voice.volume_db = float(voice.get_meta("gain",-12.0))+linear_to_db(maxf(0.0001,effects_volume))
			if int(voice.get_meta("priority",0))<7: voice.volume_db -= 6.0*danger_gain
			if paused and not voice.get_meta("pause_safe",false): voice.stop()
	var ambient_active: bool = not environment.is_empty() and not paused
	ambience_gain = move_toward(ambience_gain,1.0 if ambient_active else 0.0,delta/1.4)
	torch_gain = move_toward(torch_gain,torch_target if ambient_active and environment=="tower" else 0.0,delta*2.0)
	ambience_player.volume_db = linear_to_db(maxf(0.0001,ambience_gain*effects_volume))-16.0-(4.0 if music_context=="boss" else 0.0)
	torch_player.volume_db = linear_to_db(maxf(0.0001,torch_gain*effects_volume))-9.0
	ambience_player.stream_paused = paused
	torch_player.stream_paused = paused
	ambience_player.volume_db -= 6.0*danger_gain
	for i: int in range(room_players.size()):
		var target: float = 1.0 if i==room_target and not room_style.is_empty() and environment=="tower" else 0.0
		room_weights[i] = move_toward(room_weights[i],target,delta/2.5)
		room_players[i].stream_paused = paused
		room_players[i].volume_db = linear_to_db(maxf(0.0001,room_weights[i]*effects_volume))-23.0-6.0*danger_gain
		if room_weights[i]==0.0 and target==0.0: room_players[i].stop()

func set_music(context: String) -> void:
	if not enabled or context==music_context: return
	if not context.is_empty() and not tracks.has(context): return
	music_context = context
	music_gap = 0.0
	if context in ["menu",""]: set_environment("")
	if context.is_empty(): return
	if context=="exploration":
		start_exploration()
		return
	start_track(context)

func start_exploration() -> void:
	var candidates: Array[String] = EXPLORATION.duplicate()
	candidates.erase(last_exploration)
	last_exploration = candidates[rng.randi_range(0,candidates.size()-1)]
	start_track(last_exploration)
	music_remaining = tracks[last_exploration].get_length()-2.0

func start_track(context: String) -> void:
	music_track = context
	# Reuse the currently fading track if a rapid transition reverses direction.
	for i: int in range(music_players.size()):
		if music_players[i].stream==tracks[context] and music_players[i].playing:
			music_target = i
			return
	music_target = 1-music_target
	music_players[music_target].stream = tracks[context]
	music_weights[music_target] = 0.0
	music_players[music_target].volume_db = -80
	music_players[music_target].play()

func sustain(id: String) -> void:
	if not enabled or get_tree().paused or not channel_streams.has(id): return
	channel_timeout = 0.09
	if channel_id==id and channel_voice.playing: return
	channel_id = id
	channel_gain = 0.0
	channel_voice.volume_db = -80
	channel_voice.stream = channel_streams[id]
	channel_voice.play()

func stop_channel() -> void:
	channel_timeout = 0.0
	channel_gain = 0.0
	channel_id = ""
	if is_instance_valid(channel_voice): channel_voice.stop()

func play(id: String, position: Vector2 = Vector2.INF, gain_adjust: float = 0.0, pitch: float = 1.0, occluded: bool = false) -> bool:
	if not enabled or not streams.has(id): return false
	if get_tree().paused and position!=Vector2.INF: return false
	var now: int = Time.get_ticks_msec()
	var interval: int = 65 if id.begins_with("impact") else (280 if id.begins_with("step") else 90)
	if id.begins_with("creature_"): interval = 240 if id.ends_with("_step") else 450
	if id=="loot": interval = 180
	if id.begins_with("loot_"): interval = 1400
	if id.begins_with("room_") or id.begins_with("village_"): interval = 5000
	if now-int(last_played.get(id,-10000))<interval: return false
	if position!=Vector2.INF and position.distance_to(listener_position)>1100: return false
	var priority: int = int(PRIORITY.get(id,3))
	if id.begins_with("creature_"):
		priority = 1 if id.ends_with("_idle") or id.ends_with("_step") else (6 if id.ends_with("_alert") else 4)
	if id.begins_with("dungeon_"): priority = 0
	if id.begins_with("room_") or id.begins_with("village_"): priority = 0
	if id.begins_with("boss_"): priority = 9
	if id in ["key_found","seal_open","loot_epic"]: priority = 7
	var chosen: AudioStreamPlayer2D
	for voice: AudioStreamPlayer2D in voices:
		if not voice.playing:
			chosen = voice
			break
		if int(voice.get_meta("priority",0))<priority:
			if chosen==null or int(voice.get_meta("started",0))<int(chosen.get_meta("started",0)): chosen = voice
	if chosen==null: return false
	var variants: Array = streams[id]
	var index: int = rng.randi_range(0,variants.size()-1)
	if variants.size()>1 and index==int(variant_index.get(id,-1)): index = (index+1)%variants.size()
	variant_index[id] = index
	last_played[id] = now
	chosen.stream = variants[index]
	chosen.bus = "GameAudio" if position==Vector2.INF else "WorldEffects"
	if occluded and position!=Vector2.INF: chosen.bus = "OccludedEffects"
	chosen.global_position = listener_position if position==Vector2.INF else position
	chosen.panning_strength = 0.0 if position==Vector2.INF else 0.65
	# Menus and feedback stay centered; only events in the world are spatialized.
	chosen.attenuation = 0.0 if position==Vector2.INF else 1.25
	chosen.max_distance = 1000000000.0 if position==Vector2.INF else 1150.0
	var gain: float = -17.0 if id.begins_with("step") else (-11.0 if id.begins_with("impact") or id=="loot" else -7.0)
	if id.begins_with("creature_"): gain = -14.0 if id.ends_with("_step") else (-9.0 if id.ends_with("_idle") else -4.0)
	if id.begins_with("dungeon_"): gain = -16.0
	if id.begins_with("room_") or id.begins_with("village_"): gain = -19.0
	if id.begins_with("material_"): gain = -13.0
	if id in ["inventory_open","book_open","equip_staff","equip_ring","unequip","trade"]: gain = -14.0
	if id in ["ui","spell_switch"]: gain = -16.0
	if id in ["death","victory","level_up"]: gain = -10.0
	gain += gain_adjust
	chosen.set_meta("gain",gain)
	chosen.set_meta("priority",priority)
	chosen.set_meta("started",now)
	chosen.set_meta("pause_safe",position==Vector2.INF)
	chosen.set_meta("sound_id",id)
	chosen.volume_db = gain+linear_to_db(maxf(0.0001,float(State.options.get("effects",0.8))))
	chosen.pitch_scale = pitch*(rng.randf_range(0.96,1.04) if variants.size()>1 else 1.0)
	chosen.play()
	if id.begins_with("boss_") or id in ["hurt","shield_hit"]: danger_time = 0.95
	return true

func creature(kind: String, event: String, position: Vector2, occluded: bool = false, is_boss: bool = false) -> bool:
	if not enabled or get_tree().paused or event not in CREATURE_EVENTS: return false
	var distance: float = position.distance_to(listener_position)
	if distance>(530.0 if event in ["idle","step"] else 950.0): return false
	if is_boss and kind in BOSSES and event in ["alert","death"]:
		return play("boss_"+kind+"_"+event,position,-8.0 if occluded else 0.0,1.0,occluded)
	var now: int = Time.get_ticks_msec()
	var interval: int = 1200 if event=="idle" else (180 if event=="step" else 170)
	if now-int(creature_cooldowns.get(event,-10000))<interval: return false
	var count: int = 0
	for voice: AudioStreamPlayer2D in voices:
		if voice.playing and String(voice.get_meta("sound_id","")).begins_with("creature_"): count += 1
	if count>=4 and event in ["idle","step","hurt","attack"]: return false
	var family: String = CREATURE_FAMILY.get(kind,"beast")
	var gain: float = (-10.0 if occluded else 0.0)+(2.0 if is_boss else 0.0)
	var played: bool = play("creature_"+family+"_"+event,position,gain,0.86 if is_boss else 1.0,occluded)
	if played: creature_cooldowns[event] = now
	return played

func set_environment(context: String) -> void:
	if not enabled: return
	environment = context
	if room_reverb: room_reverb.wet = 0.12 if context=="tower" else 0.0
	if context in ["tower","village"]:
		var bed: AudioStream = ambience_streams["cave" if context=="tower" else "village"]
		if ambience_player.stream!=bed: ambience_player.stop();ambience_player.stream=bed
		if not ambience_player.playing: ambience_player.play(rng.randf_range(0.0,20.0))
	else:
		ambience_player.stop()
		torch_player.stop()
		ambience_gain = 0.0
		torch_gain = 0.0
		torch_target = 0.0
	if context!="tower":
		room_style = ""
		torch_player.stop()
		torch_target = 0.0
		for bed: AudioStreamPlayer in room_players: bed.stop()
		room_weights = [0.0,0.0]
		tension_target = 0.0

func set_torch(position: Vector2) -> void:
	if not enabled or environment!="tower": return
	torch_target = 0.0 if position==Vector2.INF else 1.0
	if position!=Vector2.INF:
		torch_player.global_position = position
		if not torch_player.playing: torch_player.play(rng.randf_range(0.0,5.0))

func set_room(style: String) -> void:
	if not enabled or not room_reverb or environment!="tower": return
	room_reverb.wet = 0.19 if style in ["chapel","crypt"] else 0.10
	var next: String = style if style in ROOMS else ""
	if room_style==next: return
	room_style = next
	if next.is_empty(): return
	for i: int in range(room_players.size()):
		if room_players[i].stream==ambience_streams[next] and room_players[i].playing:
			room_target = i
			return
	room_target = 1-room_target
	room_players[room_target].stream = ambience_streams[next]
	room_weights[room_target] = 0.0
	room_players[room_target].volume_db = -80
	room_players[room_target].play(rng.randf_range(0.0,5.0))

func impact(id: String, position: Vector2, target_kind: String = "stone") -> void:
	var kind: String = "arcane"
	if id in ["fire","fire_missile"]: kind = "fire"
	elif id=="frost_missile": kind = "ice"
	elif id=="ball_lightning": kind = "lightning"
	play("impact_"+kind,position)
	hit_material(target_kind,position)

func hit_material(kind: String, position: Vector2) -> void:
	if not enabled or get_tree().paused: return
	var now: int = Time.get_ticks_msec()
	if now-material_time<180: return
	var material: String = "flesh"
	if kind in ["skeleton","archer"]: material = "bone"
	elif kind in ["knight","king"]: material = "metal"
	elif kind in ["ghost","lich"]: material = "ethereal"
	elif kind=="stone": material = "stone"
	if play("material_"+material,position): material_time = now

func boss_warning(kind: String, position: Vector2) -> void:
	if kind in BOSSES: play("boss_"+kind+"_warning",position)

func set_threat(enemies_nearby: int) -> void:
	var next: float = clampf(enemies_nearby/4.0,0.0,1.0)
	if next>=0.75 and tension_target<0.75 and encounter_cooldown<=0.0:
		if play("encounter",listener_position,-5.0): encounter_cooldown = 35.0
	tension_target = next

func pause_world() -> void:
	stop_channel()
	for voice: AudioStreamPlayer2D in voices:
		if not voice.get_meta("pause_safe",false): voice.stop()
	if is_instance_valid(ambience_player): ambience_player.stream_paused = true
	if is_instance_valid(torch_player): torch_player.stream_paused = true
	for bed: AudioStreamPlayer in room_players: bed.stream_paused = true

func stop_world() -> void:
	pause_world()
	set_environment("")
	creature_cooldowns.clear()
	danger_time = 0.0
	danger_gain = 0.0
	tension = 0.0
	tension_target = 0.0

func stop_all() -> void:
	if is_instance_valid(ambience_player): ambience_player.stop()
	if is_instance_valid(torch_player): torch_player.stop()
	for bed: AudioStreamPlayer in room_players: bed.stop()
	enabled = false
	stop_channel()
	for player: AudioStreamPlayer in music_players:
		player.stop()
		player.stream = null
	for voice: AudioStreamPlayer2D in voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(channel_voice): channel_voice.stream = null
	streams.clear()
	tracks.clear()
	channel_streams.clear()

func _exit_tree() -> void:
	stop_all()
