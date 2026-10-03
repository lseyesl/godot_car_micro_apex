shader_type spatial;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 plaster_tint : source_color = vec4(0.8, 0.77, 0.68, 1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = world_position * 0.55;
	vec3 detail = texture(surface_texture, p.yz).rgb * weights.x
		+ texture(surface_texture, p.xz).rgb * weights.y
		+ texture(surface_texture, p.xy).rgb * weights.z;
	// Broad, quiet plaster colour with restrained weathering at gameplay distance.
	ALBEDO = plaster_tint.rgb * mix(vec3(1.0), detail, 0.23);
	ROUGHNESS = 0.93;
	SPECULAR = 0.15;
}
