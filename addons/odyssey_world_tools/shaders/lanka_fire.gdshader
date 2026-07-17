shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 ember_color : source_color = vec4(1.0, 0.10, 0.006, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.42, 0.045, 1.0);
uniform float motion_offset = 0.0;

void vertex() {
	float taper = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 5.2 + UV.y * 8.0 + motion_offset) * 0.14 * taper;
}

void fragment() {
	vec2 centered = UV - vec2(0.5, 0.10);
	float width = mix(0.46, 0.07, clamp(UV.y, 0.0, 1.0));
	float flame_shape = 1.0 - smoothstep(width * 0.35, width, abs(centered.x));
	float vertical = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.76, 1.0, UV.y));
	float lick = sin(UV.y * 21.0 - TIME * 7.0 + motion_offset) * 0.10 + 0.90;
	float alpha = flame_shape * vertical * lick;
	ALBEDO = mix(ember_color.rgb, flame_color.rgb, clamp(UV.y * 1.2, 0.0, 1.0));
	EMISSION = ALBEDO * 3.4;
	ALPHA = alpha;
}
