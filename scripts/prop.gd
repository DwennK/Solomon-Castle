class_name WorldProp
extends Node2D

var environment: DungeonInterior
var environment_tint: Color = Color.WHITE
var record: Dictionary
var texture: Texture2D
var time: float = 0.0
var label: String = ""
var font: Font = ThemeDB.fallback_font
var actor: ActorVisual
var opened_time: float = 0.0

func _ready() -> void:
	refresh_texture()
	position = environment.dressing.prop_positions.get(record.id,Dungeon.vec(record.pos)) if environment else Dungeon.vec(record.pos)
	if environment: environment_tint = environment.sample_light(position).color
	if record.kind in ["merchant","teacher","healer"]:
		actor = ActorVisual.new()
		actor.texture = texture
		actor.kind = record.kind
		actor.target_height = 135
		add_child(actor)

func refresh_texture() -> void:
	texture = EnvironmentArt.prop(record.kind,record.get("opened",false)) if environment else null
	if not texture: texture = Catalog.texture("chest_open" if record.get("opened",false) and record.kind=="chest" else record.kind)

func _process(delta: float) -> void:
	time += delta
	if record.get("opened",false): opened_time += delta
	queue_redraw()

func _draw() -> void:
	var kind: String = record.kind
	if kind=="urn" and record.get("opened",false): return
	var height: float = {"torch":100,"chest":65,"chest_open":65,"portal":125,"stairs":150,"merchant":115,"teacher":120,"healer":112,"urn":58}.get(kind,65)
	if kind in ["chest","urn","stairs","torch"]:
		draw_set_transform(Vector2(0,1),0,Vector2(1,0.22))
		ArcaneArt.glow(self,Vector2.ZERO,40 if kind=="stairs" else (36 if kind=="chest" else 22),Color(0,0,0,0.84))
		draw_set_transform(Vector2.ZERO)
	if kind in ["torch","portal"]:
		var color: Color = Color("e3a051") if kind=="torch" else Color("69ccd9")
		var origin: Vector2 = Vector2(0,-46 if kind=="torch" and environment else (-65 if kind=="torch" else -40))
		ArcaneArt.glow(self,origin,28 if kind=="torch" and environment else (180 if kind=="torch" else 130),Color(color,0.22+sin(time*3.3)*0.025))
		if kind=="portal":
			draw_set_transform(Vector2(0,4),0,Vector2(1,0.4))
			ArcaneArt.rune(self,Vector2.ZERO,67,Color(color,0.6),time*0.2)
			draw_set_transform(Vector2.ZERO)
			for i: int in range(22 if not State.options.reduced_effects else 7):
				var a: float = i*2.399+time*0.7
				var p: Vector2 = Vector2(cos(a)*37,sin(a)*45-50)
				ArcaneArt.glow(self,p,7,Color(color,0.5))
				draw_circle(p,1.4,Color(0.8,1,1,0.8))
		else:
			for i: int in range(8 if not State.options.reduced_effects else 3):
				var f: float = fposmod(time*0.65+i*0.13,1)
				var p: Vector2 = origin+Vector2(sin(time*2+i*3)*f*15,-f*65)
				draw_circle(p,1.6*(1-f),Color(1,0.68,0.22,1-f))
	if kind=="chest" and not record.get("opened",false):
		# A small lock glint identifies loot without a disconnected halo.
		ArcaneArt.glow(self,Vector2(0,-17),9,Color("c5ad75",0.08))
	if kind=="chest" and record.get("opened",false) and opened_time<1:
		ArcaneArt.glow(self,Vector2(0,-30),80,Color("ffdc83",(1-opened_time)*0.6))
	if texture and not actor:
		var size: Vector2 = texture.get_size()*height/texture.get_height()
		if environment and kind in ["chest","urn","torch","stairs"]:
			var width: float = {"chest":72.0,"urn":33.0,"torch":48.0,"stairs":90.0}[kind]
			size = texture.get_size()*width/texture.get_width()
			draw_texture_rect(texture,Rect2(Vector2(-size.x/2,-size.y),size),false,environment_tint)
		else: draw_texture_rect(texture,Rect2(Vector2(-size.x/2,-size.y+12),size),false)
	if not label.is_empty():
		draw_string(font,Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x/2,36),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e4d3ac"))
