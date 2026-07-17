shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_low : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_high : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_steep : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texture_scale : hint_range(0.001, 2.0, 0.001) = 0.08;
uniform float altitude_blend_start = 20.0;
uniform float altitude_blend_end = 60.0;
uniform float slope_blend_start : hint_range(0.0, 1.0) = 0.25;
uniform float slope_blend_end : hint_range(0.0, 1.0) = 0.65;
uniform float terrain_roughness : hint_range(0.0, 1.0) = 0.9;
uniform vec4 low_tint : source_color = vec4(0.10, 0.14, 0.13, 1.0);
uniform vec4 high_tint : source_color = vec4(0.42, 0.43, 0.40, 1.0);
uniform vec4 steep_tint : source_color = vec4(0.075, 0.085, 0.082, 1.0);
uniform vec4 ash_tint : source_color = vec4(0.58, 0.59, 0.55, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.34;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.18;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.34;
uniform float wetness : hint_range(0.0, 1.0) = 0.36;
uniform float wet_height = 10.0;

varying vec3 world_position;
varying vec3 world_normal;

vec3 triplanar_weights(vec3 normal_value) {
	vec3 weights = pow(abs(normal_value), vec3(6.0));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}

vec3 sample_triplanar(sampler2D texture_sampler, vec3 position, vec3 normal_value) {
	vec3 weights = triplanar_weights(normal_value);
	vec3 x_projection = texture(texture_sampler, position.zy * texture_scale).rgb;
	vec3 y_projection = texture(texture_sampler, position.xz * texture_scale).rgb;
	vec3 z_projection = texture(texture_sampler, position.xy * texture_scale).rgb;
	return x_projection * weights.x + y_projection * weights.y + z_projection * weights.z;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 normal_value = normalize(world_normal);
	float altitude_mix = smoothstep(altitude_blend_start, altitude_blend_end, world_position.y);
	float slope = 1.0 - abs(normal_value.y);
	float steep_mix = smoothstep(slope_blend_start, slope_blend_end, slope);
	vec3 low_sample = sample_triplanar(albedo_low, world_position, normal_value);
	vec3 high_sample = sample_triplanar(albedo_high, world_position, normal_value);
	vec3 steep_sample = sample_triplanar(albedo_steep, world_position, normal_value);
	float low_luma = dot(low_sample, vec3(0.299, 0.587, 0.114));
	float high_luma = dot(high_sample, vec3(0.299, 0.587, 0.114));
	float steep_luma = dot(steep_sample, vec3(0.299, 0.587, 0.114));
	vec3 low_color = low_tint.rgb * mix(1.0, mix(0.68, 1.25, low_luma), detail_strength);
	vec3 high_color = high_tint.rgb * mix(1.0, mix(0.70, 1.22, high_luma), detail_strength);
	vec3 steep_color = steep_tint.rgb * mix(1.0, mix(0.66, 1.20, steep_luma), detail_strength);
	vec3 terrain_color = mix(mix(low_color, high_color, altitude_mix), steep_color, steep_mix);
	float macro = sin(world_position.x * 0.018 + world_position.z * 0.014) * 0.5 + 0.5;
	terrain_color *= mix(1.0 - macro_variation, 1.0 + macro_variation, macro);
	float upward = smoothstep(0.45, 0.94, normal_value.y);
	float ash_mask = ash_amount * upward * altitude_mix * mix(0.75, 1.0, macro);
	terrain_color = mix(terrain_color, ash_tint.rgb, ash_mask);
	float wet_mask = wetness * (1.0 - smoothstep(wet_height - 5.0, wet_height + 8.0, world_position.y));
	terrain_color = mix(terrain_color, terrain_color * vec3(0.43, 0.55, 0.53), wet_mask);
	ALBEDO = max(terrain_color, vec3(0.003));
	ROUGHNESS = clamp(terrain_roughness - wet_mask * 0.34 + ash_mask * 0.08, 0.2, 1.0);
}
