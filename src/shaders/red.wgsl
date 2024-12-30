struct VertexIn {
    @location(0) position: vec2f,
    @location(1) color: vec3f,
}

struct VertexOut {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f,
    @location(1) texcoord: vec2f,
}

@group(0) @binding(0) var<uniform> mvp: mat4x4f;
@group(0) @binding(1) var ourSampler: sampler;
@group(0) @binding(2) var ourTexture: texture_2d<f32>;

@vertex fn vs(in: VertexIn) -> VertexOut {
    var out: VertexOut;
    out.position = mvp * vec4f(in.position, 0.0, 1.0);
    out.color = in.color;
    out.texcoord = in.position + vec2f(0.5);
    out.texcoord.y = 1.0 - out.texcoord.y;
    return out;
}

@fragment fn fs(in: VertexOut) -> @location(0) vec4f {
    return mix(textureSample(ourTexture, ourSampler, in.texcoord), vec4f(in.color, 1.0), 0.5);
}