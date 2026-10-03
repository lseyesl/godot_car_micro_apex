shader_type spatial;
uniform vec4 tint : source_color = vec4(0.7, 0.65, 0.5, 1.0);
uniform float finish_kind = 0.0;
varying vec3 local_point;
varying vec3 local_normal;
void vertex() {
    // Box instances are scaled in MultiMesh; world coordinates retain physical detail size.
    local_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    local_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
    vec3 n = abs(local_normal);
    vec2 uv = n.y > 0.6 ? local_point.xz : (n.x > n.z ? local_point.zy : local_point.xy);
    float seam;
    if (finish_kind < 0.5) {
        float row = floor(uv.y / 0.55);
        vec2 brick = fract(vec2(uv.x / 1.1 + mod(row, 2.0) * 0.5, uv.y / 0.55));
        seam = max(1.0 - smoothstep(0.015, 0.055, brick.x), 1.0 - smoothstep(0.025, 0.065, brick.y));
    } else {
        seam = 1.0 - smoothstep(0.03, 0.085, fract(uv.y / 0.7));
    }
    float grain = fract(sin(dot(floor(uv * 10.0), vec2(12.9898, 78.233))) * 43758.5453);
    ALBEDO = tint.rgb * (0.98 - seam * 0.085 + grain * 0.035);
    ROUGHNESS = 0.95;
    SPECULAR = 0.15;
}
