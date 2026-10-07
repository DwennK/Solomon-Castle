class_name DungeonDecoration
extends Node2D
## Bottom-center is the physical foot, so the shared actor Y-sort handles overlap.
var environment: DungeonInterior
var tint: Color = Color.WHITE
var texture: Texture2D
var size: Vector2
var grounded: bool = false
var source_rect: Rect2

func setup(detail: Dictionary,source: Texture2D) -> void:
	texture = source
	position = detail.pos
	size = texture.get_size()*float(detail.height)/texture.get_height()
	grounded = detail.get("grounded",false)
	if environment: tint = environment.sample_light(position+Vector2(0,32)).color*Color(0.9,0.9,0.88,1.0)
	if texture is AtlasTexture: source_rect = (texture as AtlasTexture).region
	set_meta("decoration_kind",detail.kind)
	set_meta("wall_base_y",detail.get("wall_base_y",position.y))

func _draw() -> void:
	if grounded:
		draw_set_transform(Vector2(0,-1),0,Vector2(1,0.24))
		ArcaneArt.glow(self,Vector2.ZERO,size.x*0.48,Color(0,0,0,0.57))
		draw_set_transform(Vector2.ZERO)
	draw_texture_rect(texture,Rect2(Vector2(-size.x/2,-size.y),size),false,tint)
