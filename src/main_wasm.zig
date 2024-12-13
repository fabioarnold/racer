const std = @import("std");
const wasm = @import("web/wasm.zig");
const gpu = @import("web/gpu.zig");
const log = std.log.scoped(.main_wasm);

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

const red_code = @embedFile("shaders/red.wgsl");

var vertex_buffer: gpu.Buffer = undefined;
var index_buffer: gpu.Buffer = undefined;
var pipeline: gpu.RenderPipeline = undefined;

pub export fn onInit() void {
    log.info("Hello, world!", .{});

    const module = gpu.createShaderModule(.{ .code = red_code });
    pipeline = gpu.createRenderPipeline(.{
        .vertex = .{
            .module = module,
            .buffers = &.{
                .{
                    .array_stride = (2 + 3) * 4,
                    .attributes = &.{
                        .{
                            .format = .float32x2,
                            .offset = 0,
                            .shader_location = 0,
                        },
                        .{
                            .format = .float32x3,
                            .offset = 2 * 4,
                            .shader_location = 1,
                        },
                    },
                },
            },
        },
        .fragment = .{
            .module = module,
        },
    });

    const vertex_data = [_]f32{
        // x, y          // r, g, b
        -0.5, -0.5, 1.0, 0.0, 0.0, // bottom-left
        0.5, -0.5, 0.0, 1.0, 0.0, // bottom-right
        0.5, 0.5, 0.0, 0.0, 1.0, // top-right
        -0.5, 0.5, 1.0, 1.0, 0.0, // top-left
    };
    const index_data = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };

    vertex_buffer = gpu.createBuffer(.{
        .size = @sizeOf(@TypeOf(vertex_data)),
        .usage = .{ .vertex = true, .copy_dst = true },
    });
    index_buffer = gpu.createBuffer(.{
        .size = @sizeOf(@TypeOf(index_data)),
        .usage = .{ .index = true, .copy_dst = true },
    });

    gpu.queueWriteBuffer(vertex_buffer, 0, std.mem.sliceAsBytes(&vertex_data));
    gpu.queueWriteBuffer(index_buffer, 0, std.mem.sliceAsBytes(&index_data));
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
    render_pass.setVertexBuffer(0, vertex_buffer, .{});
    render_pass.setIndexBuffer(index_buffer, .uint16, .{});
    render_pass.drawIndexed(.{ .index_count = 6 });
    render_pass.end();

    const command_buffer = command_encoder.finish();
    defer command_buffer.release();
    gpu.queueSubmit(command_buffer);
}
