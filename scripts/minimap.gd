class_name TowerMap
extends Control

var world: GameWorld
var expanded: bool = false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world) or world.village: return
	var scale_value: float = minf(size.x/Dungeon.WIDTH,size.y/Dungeon.HEIGHT)
	for key: String in world.dungeon.revealed:
		var bits: PackedStringArray = key.split(",")
		var p: Vector2 = Vector2(float(bits[0]),float(bits[1]))*scale_value
		draw_rect(Rect2(p,Vector2.ONE*(scale_value+0.3)),Color("526574"))
	var player_cell: Vector2 = world.player.position/Dungeon.CELL
	draw_circle(player_cell*scale_value,3.5,Color("eee3bd"))
	for prop: WorldProp in world.props:
		var cell: Vector2i = Vector2i((prop.position/Dungeon.CELL).floor())
		if not world.dungeon.revealed.has("%d,%d"%[cell.x,cell.y]): continue
		if prop.record.id=="exit": draw_rect(Rect2(Vector2(cell)*scale_value-Vector2.ONE*3,Vector2.ONE*6),Color("e4c78b"))
		if prop.record.kind=="chest" and not prop.record.opened: draw_circle(Vector2(cell)*scale_value,2,Color("9ce1d3"))
