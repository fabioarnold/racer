const std = @import("std");
const wasm = @import("web/wasm.zig");
const log = std.log.scoped(.main_wasm);

extern fn gpuCreateShaderModule(code_ptr: [*]const u8, code_len: usize) u32;
extern fn gpuCreateRenderPipeline(module: u32) u32;
extern fn gpuCreateRenderPassDescriptor() u32;
extern fn gpuRenderPassDescriptorSetCurrentTexture(render_pass_descriptor: u32) void;
extern fn gpuCreateCommandEncoder() u32;
extern fn gpuEncoderBeginRenderPass(encoder: u32, render_pass_descriptor: u32) u32;
extern fn gpuPassSetPipeline(pass: u32, pipeline: u32) void;
extern fn gpuPassDraw(pass: u32, count: u32) void;
extern fn gpuPassEnd(pass: u32) void;
extern fn gpuEncoderFinish(encoder: u32) u32;
extern fn gpuQueueSubmit(command_buffer: u32) void;

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

const red_code = @embedFile("shaders/red.wgsl");

var pipeline: u32 = undefined;
var render_pass_descriptor: u32 = undefined;

pub export fn onInit() void {
    log.info("Hello, world!", .{});
    const module = gpuCreateShaderModule(red_code.ptr, red_code.len);
    pipeline = gpuCreateRenderPipeline(module);
    render_pass_descriptor = gpuCreateRenderPassDescriptor();

    render();
}

fn render() void {
    gpuRenderPassDescriptorSetCurrentTexture(render_pass_descriptor);
    const encoder = gpuCreateCommandEncoder();
    const pass = gpuEncoderBeginRenderPass(encoder, render_pass_descriptor);
    gpuPassSetPipeline(pass, pipeline);
    gpuPassDraw(pass, 3);
    gpuPassEnd(pass);
    const command_buffer = gpuEncoderFinish(encoder);
    gpuQueueSubmit(command_buffer);
}
