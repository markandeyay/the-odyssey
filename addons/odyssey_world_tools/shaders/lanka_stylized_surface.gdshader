shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 base_tint : source_color = vec4(0.28, 0.30, 0.29, 1.0);
uniform vec4 accent_tint : source_color = vec4(0.11, 0.13, 0.12, 1.0);
uniform vec4 ash_tint : source_color = vec4(0.62, 0.63, 0.59, 1.0);
uniform vec4 emission_tint : source_color = vec4(1.0, 0.22, 0.025, 1.0);
uniform float texture_scale : hint_range(0.005, 1.0, 0.005) = 0.09;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;
uniform float macro_variation : hint_range(0.0, 1.0) = 0.16;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float soot_amount : hint_range(0.0, 1.0) = 0.0;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy : hint_range(0.0, 12.0) = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 vertex_paint;

vec2 dominant_projection_uv(vec3 position, vec3 normal_value) {
	vec3 axis_weight = abs(normal_value);
	if (axis_weight.x > axis_weight.y && axis_weight.x > axis_weight.z) {
		return position.zy * texture_scale;
	}
	if (axis_weight.z > axis_weight.y) {
		return position.xy * texture_scale;
	}
	return position.xz * texture_scale;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vertex_paint = COLOR.rgb;
}

void fragment() {
	vec3 normal_value = normalize(world_normal);
	vec3 sampled = texture(detail_albedo, dominant_projection_uv(world_position, normal_value)).rgb;
	float luminance = dot(sampled, vec3(0.299, 0.587, 0.114));
	float broad_detail = mix(1.0, mix(0.64, 1.28, luminance), detail_strength);
	float macro = sin(world_position.x * 0.035 + world_position.z * 0.027) * 0.5 + 0.5;
	vec3 painted_tint = mix(accent_tint.rgb, base_tint.rgb, clamp(vertex_paint.r, 0.0, 1.0));
	vec3 surface_color = painted_tint * broad_detail * mix(1.0 - macro_variation, 1.0 + macro_variation, macro);
	float upward = smoothstep(0.38, 0.94, normal_value.y);
	float ash_mask = ash_amount * upward * mix(0.72, 1.0, macro);
	surface_color = mix(surface_color, ash_tint.rgb, ash_mask);
	surface_color = mix(surface_color, surface_color * vec3(0.19, 0.20, 0.19), soot_amount);
	surface_color = mix(surface_color, surface_color * vec3(0.48, 0.58, 0.56), wetness);
	ALBEDO = max(surface_color, vec3(0.003));
	ROUGHNESS = clamp(surface_roughness - wetness * 0.34 + ash_mask * 0.08, 0.18, 1.0);
	METALLIC = surface_metallic;
	EMISSION = emission_tint.rgb * emission_energy;
}
