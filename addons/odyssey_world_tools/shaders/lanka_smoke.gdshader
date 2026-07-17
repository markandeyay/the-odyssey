shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 smoke_color : source_color = vec4(0.075, 0.085, 0.082, 1.0);
uniform float motion_offset = 0.0;

void vertex() {
	float rise = fract(TIME * 0.055 + motion_offset);
	VERTEX.y += rise * 2.2;
	VERTEX.x += sin(TIME * 0.45 + UV.y * 5.0 + motion_offset * 9.0) * 0.38 * UV.y;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radial = length(centered * vec2(1.25, 0.86));
	float billow = sin(UV.y * 13.0 + UV.x * 7.0 - TIME * 0.7 + motion_offset * 11.0) * 0.08;
	float alpha = (1.0 - smoothstep(0.22 + billow, 0.58 + billow, radial));
	alpha *= smoothstep(0.02, 0.18, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
	ALBEDO = smoke_color.rgb;
	ALPHA = alpha * 0.34;
}
