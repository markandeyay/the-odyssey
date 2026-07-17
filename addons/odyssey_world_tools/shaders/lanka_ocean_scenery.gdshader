shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.018, 0.075, 0.072, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.10, 0.27, 0.24, 1.0);
uniform vec4 foam_color : source_color = vec4(0.64, 0.66, 0.60, 1.0);
uniform float wave_height : hint_range(0.0, 8.0) = 2.4;
uniform float wave_scale : hint_range(0.001, 0.2) = 0.022;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.17;
uniform bool mask_island = true;

varying float crest;
varying vec3 world_position;

void vertex() {
	vec3 source_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float first_wave = sin(source_position.x * wave_scale + TIME * wave_speed * 5.1);
	float second_wave = sin(source_position.z * wave_scale * 0.71 - TIME * wave_speed * 3.7);
	float long_wave = sin((source_position.x + source_position.z) * wave_scale * 0.24 + TIME * wave_speed);
	float displacement = (first_wave * 0.44 + second_wave * 0.31 + long_wave * 0.25) * wave_height;
	VERTEX.y += displacement;
	crest = displacement / max(wave_height, 0.001) * 0.5 + 0.5;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 island_space = world_position.xz / vec2(525.0, 555.0);
	float offshore = smoothstep(0.86, 0.94, length(island_space));
	float southern_channel = (1.0 - smoothstep(155.0, 230.0, abs(world_position.x)))
		* (1.0 - smoothstep(-385.0, -330.0, world_position.z));
	if (mask_island && max(offshore, southern_channel) < 0.02) {
		discard;
	}
	float patient_motion = sin(world_position.x * 0.009 + world_position.z * 0.007 + TIME * 0.08) * 0.5 + 0.5;
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, crest * 0.42 + patient_motion * 0.10);
	float foam = smoothstep(0.80, 0.96, crest + patient_motion * 0.08);
	ALBEDO = mix(water, foam_color.rgb, foam * 0.44 + fresnel * 0.12);
	ROUGHNESS = mix(0.56, 0.80, foam);
	METALLIC = 0.0;
	SPECULAR = 0.18;
	EMISSION = foam_color.rgb * foam * 0.035;
}
