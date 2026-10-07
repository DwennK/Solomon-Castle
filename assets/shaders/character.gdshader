shader_type canvas_item;
uniform float motion = 0.0;
uniform float clock = 0.0;
uniform float flash = 0.0;
uniform float dissolve = 0.0;
uniform vec4 rim_color : source_color = vec4(0.25, 0.65, 0.72, 1.0);
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
	float cloth = pow(1.0 - UV.y, 1.5);
	VERTEX.x += sin(clock * 1.7 + UV.y * 7.0) * cloth * motion * 3.5;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.5;
	float edge = max(0.0, tex.a - texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	vec3 lit = tex.rgb + edge * rim_color.rgb * 0.65;
	lit = mix(lit, vec3(1.0, 0.88, 0.66), flash * 0.7);
	float noise = fract(sin(dot(floor(UV * 130.0), vec2(12.9898,78.233))) * 43758.5453);
	float threshold = dissolve * 1.4 - (1.0 - UV.y) * 0.35;
	float fade = dissolve <= 0.0 ? 1.0 : smoothstep(threshold, threshold + 0.09, noise);
	float ember = (1.0-smoothstep(threshold+0.05, threshold+0.15, noise)) * step(0.01,dissolve);
	COLOR = vertex_tint * vec4(mix(lit, rim_color.rgb*1.6,ember), tex.a * fade * (1.0-dissolve));
}
