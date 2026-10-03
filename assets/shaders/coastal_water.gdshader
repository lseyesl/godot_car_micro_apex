shader_type spatial;
render_mode diffuse_burley;
varying vec2 world_uv;
void vertex() {
    world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
    float wave = sin(world_uv.x * 0.22 + world_uv.y * 0.36 + TIME * 0.65);
    float cross_wave = sin(world_uv.x * 0.11 - world_uv.y * 0.19 - TIME * 0.4);
    float glint = smoothstep(0.92, 1.0, wave * 0.65 + cross_wave * 0.35);
    ALBEDO = mix(vec3(0.035, 0.34, 0.39), vec3(0.16, 0.50, 0.51), glint * 0.45 + wave * 0.035);
    ROUGHNESS = 0.8;
    SPECULAR = 0.2;
}
