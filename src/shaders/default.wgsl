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

@group(0) @binding(0) var<uniform> view_projection: mat4x4f;
@group(0) @binding(1) var ourSampler: sampler;
@group(0) @binding(2) var ourTexture: texture_2d<f32>;
@group(1) @binding(0) var<uniform> model: mat4x4f;

@vertex fn vs(in: VertexIn) -> VertexOut {
    var out: VertexOut;
    out.position = view_projection * model * vec4f(in.position, 1);
    out.normal = in.normal;
    out.texcoord = in.texcoord;
    return out;
}

@fragment fn fs(in: VertexOut) -> @location(0) vec4f {
    var light = max(0, dot(in.normal, vec3f(0, 0, 1)));
    light = 0.5 * light + 0.5;
    return light * textureSample(ourTexture, ourSampler, in.texcoord) + 0.1 * light;
    // return vec4f(0.5 + 0.5 * in.normal, 1.0);
    // return mix(textureSample(ourTexture, ourSampler, in.texcoord), vec4f(0.5 + 0.5 * in.normal, 1.0), 0.5);
}