extends Node
## Original score, spatial Foley, continuous magic and bounded voice mixing.

const EFFECTS: Array[String] = ["missile","fire","fire_missile","frost_missile","ball_lightning","impact","impact_arcane","impact_fire","impact_ice","impact_lightning","hurt","enemy","enemy_melee","enemy_bow","enemy_magic","enemy_death","boss_attack","boss_death","potion","mana","loot","item","ui","spell_switch","ritual","chest","urn","teleport","portal","shield","shield_hit","circle","freeze","ring_fire","acid","undead","death","victory","level_up","step_stone","step_gravel"]
const CHANNELS: Array[String] = ["lightning","ice","flame_lash","steam","blizzard"]
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless" and "--audio-qa" not in OS.get_cmdline_user_args():
		enabled = false
		return
	rng.randomize()
	for id: String in EFFECTS:
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
	for id: String in ["menu","village","exploration","boss"]:
		var stream: AudioStreamOggVorbis = load("res://assets/audio/music_"+id+".ogg")
		stream.loop = true
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
	add_child(channel_voice)
	set_music("menu")

func _process(delta: float) -> void:
	if not enabled: return
	var paused: bool = get_tree().paused
	var music_volume: float = clampf(float(State.options.get("music",0.45)),0,1)
	var effects_volume: float = clampf(float(State.options.get("effects",0.8)),0,1)
	for i: int in range(music_players.size()):
		var target: float = 1.0 if i==music_target and not music_context.is_empty() else 0.0
		music_weights[i] = move_toward(music_weights[i],target,delta/1.8)
		music_players[i].volume_db = linear_to_db(maxf(0.0001,music_weights[i]*music_volume))-9.0-(5.0 if paused else 0.0)
		if music_weights[i]==0.0 and target==0.0: music_players[i].stop()
	channel_timeout = maxf(0.0,channel_timeout-delta)
	var active: bool = channel_timeout>0.0 and not paused
	channel_gain = move_toward(channel_gain,1.0 if active else 0.0,delta/0.065)
	channel_voice.volume_db = linear_to_db(maxf(0.0001,channel_gain*effects_volume))-15.0
	if channel_gain==0.0 and channel_voice.playing:
		channel_voice.stop()
		channel_id = ""
	for voice: AudioStreamPlayer2D in voices:
		if voice.playing:
			voice.volume_db = float(voice.get_meta("gain",-12.0))+linear_to_db(maxf(0.0001,effects_volume))
			if paused and not voice.get_meta("pause_safe",false): voice.stop()

func set_music(context: String) -> void:
	if not enabled or context==music_context: return
	if not context.is_empty() and not tracks.has(context): return
	music_context = context
	if context.is_empty(): return
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

func play(id: String, position: Vector2 = Vector2.INF) -> void:
	if not enabled or not streams.has(id): return
	var now: int = Time.get_ticks_msec()
	var interval: int = 65 if id.begins_with("impact") else (280 if id.begins_with("step") else 90)
	if now-int(last_played.get(id,-10000))<interval: return
	if position!=Vector2.INF and position.distance_to(listener_position)>1100: return
	last_played[id] = now
	var priority: int = int(PRIORITY.get(id,3))
	var chosen: AudioStreamPlayer2D
	for voice: AudioStreamPlayer2D in voices:
		if not voice.playing:
			chosen = voice
			break
		if int(voice.get_meta("priority",0))<priority:
			if chosen==null or int(voice.get_meta("started",0))<int(chosen.get_meta("started",0)): chosen = voice
	if chosen==null: return
	var variants: Array = streams[id]
	var index: int = int(variant_index.get(id,0))%variants.size()
	variant_index[id] = index+1
	chosen.stream = variants[index]
	chosen.global_position = listener_position if position==Vector2.INF else position
	chosen.panning_strength = 0.0 if position==Vector2.INF else 0.65
	# Menus and feedback stay centered; only events in the world are spatialized.
	chosen.attenuation = 0.0 if position==Vector2.INF else 1.25
	chosen.max_distance = 1000000000.0 if position==Vector2.INF else 1150.0
	var gain: float = -21.0 if id.begins_with("step") else (-17.0 if id.begins_with("impact") or id=="loot" else -12.0)
	if id in ["death","victory","level_up"]: gain = -9.0
	chosen.set_meta("gain",gain)
	chosen.set_meta("priority",priority)
	chosen.set_meta("started",now)
	chosen.set_meta("pause_safe",position==Vector2.INF)
	chosen.set_meta("sound_id",id)
	chosen.volume_db = gain+linear_to_db(maxf(0.0001,float(State.options.get("effects",0.8))))
	chosen.pitch_scale = rng.randf_range(0.96,1.04) if variants.size()>1 else 1.0
	chosen.play()

func impact(id: String, position: Vector2) -> void:
	var kind: String = "arcane"
	if id in ["fire","fire_missile"]: kind = "fire"
	elif id=="frost_missile": kind = "ice"
	elif id=="ball_lightning": kind = "lightning"
	play("impact_"+kind,position)

func stop_world() -> void:
	stop_channel()
	for voice: AudioStreamPlayer2D in voices:
		if not voice.get_meta("pause_safe",false): voice.stop()

func stop_all() -> void:
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
