struct VertexIn {
    @location(0) position: vec2f,
    @location(1) color: vec3f,
}

struct VertexOut {
    @location(0) color: vec3f,
    @builtin(position) position: vec4f,
}

@group(0) @binding(0) var<uniform> mvp: mat4x4f;

@vertex fn vs(in: VertexIn) -> VertexOut {
    var out: VertexOut;
    out.position = mvp * vec4f(in.position, 0.0, 1.0);
    out.color = in.color;
    return out;
}

@fragment fn fs(@location(0) color: vec3f) -> @location(0) vec4f {
    return vec4f(color, 1.0);
}