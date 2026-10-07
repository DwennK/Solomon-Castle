class_name ActorVisual
extends Node2D

var texture: Texture2D
var target_height: float = 90.0
var moving: bool = false
var facing: Vector2 = Vector2.DOWN
var phase: float = 0.0
var attack: float = 0.0
var hit_flash: float = 0.0
var tint: Color = Color.WHITE

func _process(delta: float) -> void:
	phase += delta * (11.0 if moving else 2.0)
	attack = maxf(0.0,attack-delta*4.0)
	hit_flash = maxf(0.0,hit_flash-delta*5.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.38))
	draw_circle(Vector2.ZERO,target_height*0.27,Color(0,0,0,0.45))
	draw_set_transform(Vector2.ZERO)
	if texture:
		var ratio: float = target_height / texture.get_height()
		var size: Vector2 = texture.get_size()*ratio
		var hop: float = absf(sin(phase))*5.0 if moving else sin(phase)*1.3
		var lean: float = sin(phase)*0.05 if moving else 0.0
		lean += attack * 0.16 * signf(facing.x)
		draw_set_transform(Vector2(facing.x*attack*10,-hop),lean,Vector2(-1 if facing.x < -0.1 else 1,1))
		var color: Color = tint.lerp(Color(1.9,1.5,1.2),hit_flash if not State.options.reduced_effects else hit_flash*0.2)
		draw_texture_rect(texture,Rect2(Vector2(-size.x/2,-size.y+8),size),false,color)
		draw_set_transform(Vector2.ZERO)
