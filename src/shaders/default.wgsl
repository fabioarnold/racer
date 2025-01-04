struct VertexIn {
    @location(0) position: vec3f,
    @location(1) normal: vec3f,
    @location(2) texcoord: vec2f,
}

struct VertexOut {
    @builtin(position) position: vec4f,
    @location(0) normal: vec3f,
    @location(1) texcoord: vec2f,
}

@group(0) @binding(0) var<uniform> mvp: mat4x4f;
@group(0) @binding(1) var ourSampler: sampler;
@group(0) @binding(2) var ourTexture: texture_2d<f32>;

@vertex fn vs(in: VertexIn) -> VertexOut {
    var out: VertexOut;
    out.position = mvp * vec4f(in.position, 1.0);
    out.normal = in.normal;
    out.texcoord = in.texcoord;
    return out;
}

@fragment fn fs(in: VertexOut) -> @location(0) vec4f {
    return mix(textureSample(ourTexture, ourSampler, in.texcoord), vec4f(0.5 + 0.5 * in.normal, 1.0), 0.5);
}