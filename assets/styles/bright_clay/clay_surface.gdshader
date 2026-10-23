shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.7,0.8,0.65,1.0);
uniform bool vertex_tint = false;
void fragment() {
 ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
 ROUGHNESS = 0.95;
 METALLIC = 0.0;
 SPECULAR = 0.1;
}
