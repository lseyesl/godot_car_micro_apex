shader_type spatial;
render_mode cull_disabled;
uniform sampler2D detail_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5,0.5,0.5,1.0);
uniform float tile_scale = 0.3;
uniform float detail_strength = 0.16;
uniform float surface_roughness = 0.83;
uniform bool vertex_tint = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 w = pow(abs(world_normal),vec3(4.0));
 w /= max(dot(w,vec3(1.0)),0.0001);
 vec3 p = world_position*tile_scale;
 vec3 d = texture(detail_texture,p.yz).rgb*w.x + texture(detail_texture,p.xz).rgb*w.y + texture(detail_texture,p.xy).rgb*w.z;
 float grain = dot(d,vec3(0.2126,0.7152,0.0722));
 ALBEDO = tint.rgb * mix(1.0,0.65+grain*0.7,detail_strength);
 if (vertex_tint) ALBEDO *= COLOR.rgb;
 ROUGHNESS = surface_roughness;
 SPECULAR = 0.25;
}
