shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float distortion_strength : hint_range(0.0, 0.02) = 0.004;
uniform float motion_offset = 0.0;

void fragment() {
	float edge = smoothstep(0.0, 0.20, UV.x) * smoothstep(1.0, 0.80, UV.x);
	edge *= smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.72, UV.y);
	vec2 distortion = vec2(
		sin(UV.y * 38.0 + TIME * 3.2 + motion_offset),
		cos(UV.x * 29.0 - TIME * 2.1 + motion_offset)
	) * distortion_strength * edge;
	ALBEDO = texture(screen_texture, SCREEN_UV + distortion).rgb;
	ALPHA = edge * 0.58;
}
