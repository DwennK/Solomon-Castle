shader_type canvas_item;
uniform vec4 liquid_color : source_color = vec4(0.75,0.03,0.08,1.0);
uniform float fill_level : hint_range(0.0,1.0) = 1.0;
uniform float motion = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float mask = 1.0 - smoothstep(0.965, 0.995, r);
	float wave = sin(p.x * 8.0 + TIME * 1.9) * 0.015 * motion;
	float surface = 1.0 - fill_level * 2.0 + wave * sin(fill_level * 3.14159);
	float filled = smoothstep(surface - 0.015, surface + 0.015, p.y);
	float depth = sqrt(max(0.0, 1.0 - dot(p,p)));
	float swirl = sin(p.x * 6.0 + sin(p.y * 7.0 + TIME * 0.7 * motion) + TIME * 0.5 * motion) * 0.07;
	vec3 liquid = liquid_color.rgb * (0.35 + depth * 0.8 + swirl);
	liquid += liquid_color.rgb * exp(-abs(p.y - surface) * 65.0) * 0.65;
	vec3 col = mix(vec3(0.025,0.025,0.032), liquid, filled);
	float highlight = exp(-length((p - vec2(-0.3,-0.43)) * vec2(3.2,5.5)) * 2.0);
	col += vec3(0.72,0.76,0.8) * highlight * 0.65;
	col += liquid_color.rgb * pow(max(0.0, 1.0 - abs(r - 0.88) * 13.0), 3.0) * 0.15;
	COLOR = vec4(col, mask);
}
