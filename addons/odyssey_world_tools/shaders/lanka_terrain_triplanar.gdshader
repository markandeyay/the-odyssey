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
	vec3 low_color = sample_triplanar(albedo_low, world_position, normal_value);
	vec3 high_color = sample_triplanar(albedo_high, world_position, normal_value);
	vec3 steep_color = sample_triplanar(albedo_steep, world_position, normal_value);
	ALBEDO = mix(mix(low_color, high_color, altitude_mix), steep_color, steep_mix);
	ROUGHNESS = terrain_roughness;
}
