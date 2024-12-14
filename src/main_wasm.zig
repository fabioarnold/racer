const std = @import("std");
const wasm = @import("web/wasm.zig");
const gpu = @import("web/gpu.zig");
const log = std.log.scoped(.main_wasm);

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

const red_code = @embedFile("shaders/red.wgsl");

var mvp: [16]f32 = undefined;

var uniform_buffer: gpu.Buffer = undefined;
var bind_group: gpu.BindGroup = undefined;
var vertex_buffer: gpu.Buffer = undefined;
var index_buffer: gpu.Buffer = undefined;
var pipeline: gpu.RenderPipeline = undefined;

pub export fn onInit() void {
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

    uniform_buffer = gpu.createBuffer(.{
        .size = @sizeOf(@TypeOf(mvp)),
        .usage = .{ .uniform = true, .copy_dst = true },
    });

    const texture_data = [_]u8{
        0,   0, 255, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 255, 0, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 255, 0, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 255, 0, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
        255, 0, 0,   255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0,   0, 255, 255, 0, 0, 255,
    };
    const texture = gpu.createTexture(.{
        .size = .{ .width = 5, .height = 7 },
        .format = .rgba8unorm,
        .usage = .{ .texture_binding = true, .copy_dst = true },
    });
    gpu.queueWriteTexture(texture, .{
        .data = &texture_data,
        .bytes_per_row = 4 * 5,
        .width = 5,
        .height = 7,
    });
    const sampler = gpu.createSampler(.{});

    bind_group = gpu.createBindGroup(.{
        .layout = pipeline.getBindGroupLayout(0),
        .entries = &.{
            .{ .binding = 0, .resource = uniform_buffer },
            .{ .binding = 1, .resource = sampler },
            .{ .binding = 2, .resource = texture.createView() },
        },
    });

    const vertex_data = [_]f32{
        -0.5, -0.5, 1, 0, 0,
        0.5,  -0.5, 0, 1, 0,
        0.5,  0.5,  0, 0, 1,
        -0.5, 0.5,  1, 1, 0,
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
    const angle: f32 = @floatCast(wasm.performance.now() / 1000.0);
    const s = @sin(angle);
    const c = @cos(angle);
    mvp = .{
        c,  s, 0, 0,
        -s, c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1,
    };
    gpu.queueWriteBuffer(uniform_buffer, 0, std.mem.sliceAsBytes(&mvp));

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
    render_pass.setBindGroup(0, bind_group);
    render_pass.setVertexBuffer(0, vertex_buffer, .{});
    render_pass.setIndexBuffer(index_buffer, .uint16, .{});
    render_pass.drawIndexed(.{ .index_count = 6 });
    render_pass.end();

    const command_buffer = command_encoder.finish();
    defer command_buffer.release();
    gpu.queueSubmit(command_buffer);
}
