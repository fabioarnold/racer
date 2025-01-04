const std = @import("std");
const zgltf = @import("zgltf");
const wasm = @import("web/wasm.zig");
const gpu = @import("web/gpu.zig");
const la = @import("linear_algebra.zig");
const log = std.log.scoped(.main_wasm);
const assert = std.debug.assert;

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = wasm.log,
};

var depth_texture: gpu.Texture = undefined;

const texture_data = @embedFile("textures/brickwall.data");
const texture_width = 32;
const texture_height = 32;

var shader_module: gpu.ShaderModule = undefined;
var uniform_buffer: gpu.Buffer = undefined;
var bind_group_layout: gpu.BindGroupLayout = undefined;
var bind_group: gpu.BindGroup = undefined;
var pipeline_layout: gpu.PipelineLayout = undefined;

pub export fn onInit() void {
    const back_buffer = gpu.getCurrentTexture();
    depth_texture = gpu.createTexture(.{
        .size = .{ .width = back_buffer.getWidth(), .height = back_buffer.getHeight() },
        .format = .depth24plus,
        .usage = .{ .render_attachment = true },
    });

    shader_module = gpu.createShaderModule(.{ .code = @embedFile("shaders/default.wgsl") });

    uniform_buffer = gpu.createBuffer(.{
        .size = @sizeOf(la.mat4),
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

    bind_group_layout = gpu.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .visibility = .{ .vertex = true },
                .resource = .{ .buffer = .{} },
            },
            .{
                .binding = 1,
                .visibility = .{ .fragment = true },
                .resource = .{ .sampler = .{} },
            },
            .{
                .binding = 2,
                .visibility = .{ .fragment = true },
                .resource = .{ .texture = .{} },
            },
        },
    });
    pipeline_layout = gpu.createPipelineLayout(.{
        .bind_group_layouts = &.{bind_group_layout},
    });
    bind_group = gpu.createBindGroup(.{
        .layout = bind_group_layout,
        .entries = &.{
            .{ .binding = 0, .resource = uniform_buffer },
            .{ .binding = 1, .resource = sampler },
            .{ .binding = 2, .resource = texture.createView(.{}) },
        },
    });

    const allocator = std.heap.wasm_allocator;
    model.load(allocator, @alignCast(@embedFile("models/mazda_rx7.glb"))) catch unreachable;
}

var model: Model = undefined;

const Model = struct {
    gltf: zgltf,
    buffers: []gpu.Buffer,
    meshes: []Mesh,

    const Mesh = struct {
        primitives: []Primitive,

        const Primitive = struct {
            pipeline: gpu.RenderPipeline,
            position_buffer: gpu.Buffer,
            normal_buffer: gpu.Buffer,
            texcoord_buffer: gpu.Buffer,
            index_buffer: gpu.Buffer,
            index_format: gpu.IndexFormat,
            index_count: u32,
        };
    };

    pub fn load(self: *Model, allocator: std.mem.Allocator, file_data: []align(4) const u8) !void {
        self.gltf = zgltf.init(allocator);
        self.gltf.parse(file_data) catch return error.ParseFailed;
        const binary = self.gltf.glb_binary.?;
        const data = &self.gltf.data;

        // upload buffers
        self.buffers = try allocator.alloc(gpu.Buffer, data.buffer_views.items.len);
        for (data.buffer_views.items, 0..) |*buffer_view, i| {
            const is_index = buffer_view.target == .element_array_buffer;
            self.buffers[i] = gpu.createBuffer(.{
                .size = buffer_view.byte_length,
                .usage = .{ .vertex = !is_index, .index = is_index, .copy_dst = true },
            });
            const buffer_data = binary[buffer_view.byte_offset..][0..buffer_view.byte_length];
            gpu.queueWriteBuffer(self.buffers[i], 0, buffer_data);
        }

        // create render pipelines
        self.meshes = try allocator.alloc(Mesh, data.meshes.items.len);
        for (data.meshes.items, self.meshes) |*gltf_mesh, *mesh| {
            mesh.primitives = try allocator.alloc(Mesh.Primitive, gltf_mesh.primitives.items.len);
            for (gltf_mesh.primitives.items, mesh.primitives) |*gltf_primitive, *primitive| {
                for (gltf_primitive.attributes.items) |attribute| {
                    switch (attribute) {
                        .position => |accessor_index| {
                            const accessor = data.accessors.items[accessor_index];
                            primitive.position_buffer = self.buffers[accessor.buffer_view.?];
                            assert(accessor.byte_offset == 0);
                            assert(accessor.stride == 12);
                        },
                        .normal => |accessor_index| {
                            const accessor = data.accessors.items[accessor_index];
                            primitive.normal_buffer = self.buffers[accessor.buffer_view.?];
                            assert(accessor.byte_offset == 0);
                            assert(accessor.stride == 12);
                        },
                        .texcoord => |accessor_index| {
                            const accessor = data.accessors.items[accessor_index];
                            primitive.texcoord_buffer = self.buffers[accessor.buffer_view.?];
                            assert(accessor.byte_offset == 0);
                            assert(accessor.stride == 8);
                        },
                        .joints => {},
                        .weights => {},
                        else => return error.InvalidAttribute,
                    }
                }
                const index_accessor = data.accessors.items[gltf_primitive.indices.?];
                primitive.index_buffer = self.buffers[index_accessor.buffer_view.?];
                primitive.index_format = switch (index_accessor.component_type) {
                    .unsigned_short => .uint16,
                    .unsigned_integer => .uint32,
                    else => return error.InvalidIndexFormat,
                };
                primitive.index_count = @intCast(index_accessor.count);
                const topology: gpu.Topology = switch (gltf_primitive.mode) {
                    .points => .point_list,
                    .lines => .line_list,
                    .line_strip => .line_strip,
                    .triangles => .triangle_list,
                    .triangle_strip => .triangle_strip,
                    else => return error.InvalidTopology,
                };
                primitive.pipeline = gpu.createRenderPipeline(.{
                    .layout = &pipeline_layout,
                    .vertex = .{
                        .module = shader_module,
                        .buffers = &.{
                            .{
                                .array_stride = 12,
                                .attributes = &.{
                                    .{
                                        .format = .float32x3,
                                        .offset = 0,
                                        .shader_location = 0,
                                    },
                                },
                            },
                            .{
                                .array_stride = 12,
                                .attributes = &.{
                                    .{
                                        .format = .float32x3,
                                        .offset = 0,
                                        .shader_location = 1,
                                    },
                                },
                            },
                            .{
                                .array_stride = 8,
                                .attributes = &.{
                                    .{
                                        .format = .float32x2,
                                        .offset = 0,
                                        .shader_location = 2,
                                    },
                                },
                            },
                        },
                    },
                    .fragment = .{
                        .module = shader_module,
                    },
                    .primitive = &.{
                        .topology = topology,
                    },
                    .depth_stencil = &.{
                        .depth_compare = .greater,
                        .format = .depth24plus,
                        .depth_write_enabled = true,
                    },
                });
            }
        }
    }

    pub fn draw(self: *const Model, render_pass: gpu.RenderPass) void {
        const data = &self.gltf.data;
        for (data.nodes.items) |*node| {
            const mesh = &self.meshes[node.mesh orelse continue];
            for (mesh.primitives) |*primitive| {
                render_pass.setPipeline(primitive.pipeline);
                render_pass.setBindGroup(0, bind_group);
                render_pass.setVertexBuffer(0, primitive.position_buffer, .{});
                render_pass.setVertexBuffer(1, primitive.normal_buffer, .{});
                render_pass.setVertexBuffer(2, primitive.texcoord_buffer, .{});
                render_pass.setIndexBuffer(primitive.index_buffer, primitive.index_format, .{});
                render_pass.drawIndexed(.{
                    .index_count = primitive.index_count,
                });
            }
        }
    }
};

pub export fn onDraw() void {
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

    const angle: f32 = @floatCast(wasm.performance.now() / 1000.0);
    const s = @sin(angle);
    const c = @cos(angle);
    const model_mat: la.mat4 = .{
        .{ c, s, 0, 0 },
        .{ -s, c, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    const view_mat = la.mul(la.translation(0, 0, -6), la.rotation(-60.0, .{ 1, 0, 0 }));
    const mvp = la.mul(projection, la.mul(view_mat, model_mat));
    gpu.queueWriteBuffer(uniform_buffer, 0, std.mem.sliceAsBytes(&mvp));

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

    model.draw(render_pass);
    render_pass.end();

    const command_buffer = command_encoder.finish();
    defer command_buffer.release();
    gpu.queueSubmit(command_buffer);
}
