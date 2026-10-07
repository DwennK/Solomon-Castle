extends Node

var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless": return
	for id: String in ["missile","fire","impact","hurt","enemy","potion","loot","ui","ritual","channel","chest","death","victory"]:
		var path: String = "res://assets/audio/"+id+".wav"
		if ResourceLoader.exists(path): streams[id] = load(path)
	for i: int in range(12):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.volume_db = -12
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/ambience.wav")
	add_child(music)
	var track: AudioStreamWAV = music.stream as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = 24*22050
	music.play()

func _process(_delta: float) -> void:
	if music: music.volume_db = linear_to_db(maxf(0.0001,float(State.options.music)))-7.0

func play(id: String) -> void:
	if not streams.has(id): return
	var now: int = Time.get_ticks_msec()
	if now-int(last_played.get(id,0))<85: return
	last_played[id] = now
	for voice: AudioStreamPlayer in voices:
		if not voice.playing:
			voice.stream = streams[id]
			voice.pitch_scale = 0.97+float(now%7)*0.01
			voice.play()
			return

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	streams.clear()

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	streams.clear()
