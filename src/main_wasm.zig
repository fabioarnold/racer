const std = @import("std");
const zgltf = @import("zgltf");
const wasm = @import("web/wasm.zig");
const gpu = @import("web/gpu.zig");
const la = @import("linear_algebra.zig");
const log = std.log.scoped(.main_wasm);

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

var depth_texture: gpu.Texture = undefined;

const red_code = @embedFile("shaders/red.wgsl");

const texture_data = @embedFile("textures/brickwall.data");
const texture_width = 32;
const texture_height = 32;

var mvp: [16]f32 = undefined;

var uniform_buffer: gpu.Buffer = undefined;
var bind_group: gpu.BindGroup = undefined;
var vertex_buffer: gpu.Buffer = undefined;
var index_buffer: gpu.Buffer = undefined;
var pipeline: gpu.RenderPipeline = undefined;

pub export fn onInit() void {
    const back_buffer = gpu.getCurrentTexture();
    depth_texture = gpu.createTexture(.{
        .size = .{ .width = back_buffer.getWidth(), .height = back_buffer.getHeight() },
        .format = .depth24plus,
        .usage = .{ .render_attachment = true },
    });

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

    const texture = gpu.createTexture(.{
        .size = .{ .width = texture_width, .height = texture_height },
        .format = .rgba8unorm,
        .usage = .{ .texture_binding = true, .copy_dst = true },
    });
    gpu.queueWriteTexture(texture, .{
        .data = texture_data,
        .bytes_per_row = 4 * texture_width,
        .width = texture_width,
        .height = texture_height,
    });
    const sampler = gpu.createSampler(.{});

    bind_group = gpu.createBindGroup(.{
        .layout = pipeline.getBindGroupLayout(0),
        .entries = &.{
            .{ .binding = 0, .resource = uniform_buffer },
            .{ .binding = 1, .resource = sampler },
            .{ .binding = 2, .resource = texture.createView(.{}) },
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

    const allocator = std.heap.wasm_allocator;
    var gltf = zgltf.init(allocator);
    gltf.parse(@alignCast(@embedFile("models/mazda_rx7.glb"))) catch unreachable;
    const binary = gltf.glb_binary.?;
    _ = binary;
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

    const back_buffer = gpu.getCurrentTexture();
    defer back_buffer.release();

    const width = back_buffer.getWidth();
    const height = back_buffer.getHeight();

    if (depth_texture.getWidth() != width or depth_texture.getHeight() != height) {
        depth_texture.release();
        depth_texture = gpu.createTexture(.{
            .size = .{ .width = width, .height = height },
            .format = .depth24plus,
            .usage = .{ .render_attachment = true },
        });
    }

    const aspect_ratio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

    const projection = la.perspective(60, aspect_ratio, 0.01);
    _ = projection;

    const command_encoder = gpu.createCommandEncoder();
    defer command_encoder.release();

    const back_buffer_view = back_buffer.createView(.{});
    defer back_buffer_view.release();
    const depth_texture_view = depth_texture.createView(.{});
    defer depth_texture_view.release();
    const render_pass = command_encoder.beginRenderPass(.{
        .color_attachments = &.{
            .{
                .view = back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.2, .g = 0.2, .b = 0.3, .a = 1 },
            },
        },
        .depth_stencil_attachment = &.{
            .view = depth_texture_view,
            .depth_load_op = .clear,
            .depth_store_op = .store,
            .depth_clear_value = 0,
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
