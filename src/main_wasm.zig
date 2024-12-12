const std = @import("std");
const wasm = @import("web/wasm.zig");
const gpu = @import("web/gpu.zig");
const log = std.log.scoped(.main_wasm);

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

const red_code = @embedFile("shaders/red.wgsl");

var pipeline: gpu.RenderPipeline = undefined;

pub export fn onInit() void {
    log.info("Hello, world!", .{});

    const module = gpu.createShaderModule(.{ .code = red_code });
    pipeline = gpu.createRenderPipeline(.{
        .vertex = .{
            .module = module,
        },
        .fragment = .{
            .module = module,
        },
    });
}

pub export fn onDraw() void {
    const back_buffer = gpu.getCurrentTextureView();
    defer back_buffer.release();

    const command_encoder = gpu.createCommandEncoder();
    defer command_encoder.release();

    const render_pass = command_encoder.beginRenderPass(.{
        .color_attachments = &.{
            .{
                .view = back_buffer,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.2, .g = 0.2, .b = 0.3, .a = 1 },
            },
        },
    });
    defer render_pass.release();

    render_pass.setPipeline(pipeline);
    render_pass.draw(.{ .vertex_count = 3 });
    render_pass.end();

    const command_buffer = command_encoder.finish();
    defer command_buffer.release();
    gpu.queueSubmit(command_buffer);
}
