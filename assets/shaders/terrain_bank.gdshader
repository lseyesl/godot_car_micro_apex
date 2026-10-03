shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 n = abs(normalize(world_normal));
    vec3 stone = texture(rock_tex, (n.x > n.z ? world_point.zy : world_point.xy) * 0.16).rgb;
    vec3 turf = texture(grass_tex, world_point.xz * 0.16).rgb;
    float top = smoothstep(0.6, 0.90, normalize(world_normal).y);
    ALBEDO = mix(stone, turf, top) * tint.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.15;
}
