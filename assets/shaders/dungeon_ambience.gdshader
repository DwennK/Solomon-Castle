shader_type canvas_item;
render_mode unshaded;

uniform vec2 hero_position = vec2(0.0);
varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

void fragment() {
	float distance_from_hero = length(world_position - hero_position);
	float penumbra = smoothstep(100.0, 660.0, distance_from_hero);
	COLOR = vec4(0.012, 0.020, 0.032, mix(0.10, 0.36, penumbra));
}
