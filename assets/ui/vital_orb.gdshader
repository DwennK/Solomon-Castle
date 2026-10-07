shader_type canvas_item;
uniform sampler2D liquid_atlas : source_color, filter_linear;
uniform vec4 liquid_region = vec4(0.0,0.0,0.5,1.0);
uniform vec4 liquid_color : source_color = vec4(0.7,0.04,0.08,1.0);
uniform float fill_level : hint_range(0.0,1.0) = 1.0;
uniform float motion = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float mask = 1.0 - smoothstep(0.975, 1.0, r);
	float t = TIME * motion;
	float wave = sin(p.x * 8.0 + t * 1.6) * 0.014 * motion;
	float surface = 1.0 - fill_level * 2.0 + wave * sin(fill_level * 3.14159);
	float filled = smoothstep(surface - 0.008, surface + 0.008, p.y);
	if (fill_level <= 0.001) { filled = 0.0; }
	if (fill_level >= 0.999) { filled = 1.0; }
	// Slow refraction keeps ImageGen's painted cloudy liquid detail intact.
	float interior = max(0.0,1.0-r*r);
	vec2 drift = vec2(sin(p.y*5.0+t*0.55),cos(p.x*5.0-t*0.4))*0.009*motion*interior;
	vec2 liquid_uv = clamp(UV+drift,vec2(0.0),vec2(1.0));
	vec3 painted = texture(liquid_atlas, liquid_region.xy + liquid_uv * liquid_region.zw).rgb;
	vec3 empty_glass = vec3(0.012,0.017,0.026) + painted*0.045;
	vec3 col = mix(empty_glass,painted*0.88,filled);
	float meniscus = exp(-abs(p.y-surface)*100.0)*sin(fill_level*3.14159);
	col += liquid_color.rgb*meniscus*0.36;
	COLOR = vec4(col,mask);
}
