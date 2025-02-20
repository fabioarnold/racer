const std = @import("std");
const zgltf = @import("zgltf");
const models = @import("models");
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

var shader_module: gpu.ShaderModule = undefined;
var global_uniform_buffer: gpu.Buffer = undefined;
var global_bind_group: gpu.BindGroup = undefined;
var local_bind_group_layout: gpu.BindGroupLayout = undefined;
var pipeline_layout: gpu.PipelineLayout = undefined;

pub export fn onInit() void {
    const back_buffer = gpu.getCurrentTexture();
    depth_texture = gpu.createTexture(.{
        .size = .{ .width = back_buffer.getWidth(), .height = back_buffer.getHeight() },
        .format = .depth24plus,
        .usage = .{ .render_attachment = true },
    });

    shader_module = gpu.createShaderModule(.{ .code = @embedFile("shaders/default.wgsl") });

    global_uniform_buffer = gpu.createBuffer(.{
        .size = @sizeOf(la.mat4),
        .usage = .{ .uniform = true, .copy_dst = true },
    });

    const sampler = gpu.createSampler(.{});

    const global_bind_group_layout = gpu.createBindGroupLayout(.{
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
        },
    });
    local_bind_group_layout = gpu.createBindGroupLayout(.{
        .entries = &.{
            .{
                .binding = 0,
                .visibility = .{ .vertex = true },
                .resource = .{ .buffer = .{} },
            },
            .{
                .binding = 1,
                .visibility = .{ .fragment = true },
                .resource = .{ .texture = .{} },
            },
        },
    });
    pipeline_layout = gpu.createPipelineLayout(.{
        .bind_group_layouts = &.{
            global_bind_group_layout,
            local_bind_group_layout,
        },
    });
    global_bind_group = gpu.createBindGroup(.{
        .layout = global_bind_group_layout,
        .entries = &.{
            .{ .binding = 0, .resource = global_uniform_buffer },
            .{ .binding = 1, .resource = sampler },
        },
    });

    const allocator = std.heap.wasm_allocator;
    model.load(allocator, @alignCast(models.acrux)) catch unreachable;
}

var model: Model = undefined;

const Model = struct {
    gltf: zgltf,
    textures: []gpu.Texture,
    buffers: []gpu.Buffer,
    meshes: []Mesh,

    const Mesh = struct {
        primitives: []Primitive,

        const Primitive = struct {
            pipeline: gpu.RenderPipeline,
            texture_index: u32,
            uniform_buffer: gpu.Buffer,
            bind_group: gpu.BindGroup,
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

        // load textures
        self.textures = try allocator.alloc(gpu.Texture, data.images.items.len);
        for (data.images.items, 0..) |image, i| {
            self.textures[i] = gpu.createTexture(.{
                .format = .rgba8unorm,
                .size = .{ .width = 512, .height = 512 }, // TODO: glTF does not have any info about tex dims
                .usage = .{ .texture_binding = true, .copy_dst = true, .render_attachment = true },
            });
            self.textures[i].fromImage(image.data.?, image.mime_type.?);
        }

        // upload buffers
        self.buffers = try allocator.alloc(gpu.Buffer, data.buffer_views.items.len);
        for (data.buffer_views.items, 0..) |*buffer_view, i| {
            const target = buffer_view.target orelse continue; // ignore textures
            const is_index = target == .element_array_buffer;
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
                const gltf_material = data.materials.items[gltf_primitive.material.?];
                primitive.texture_index = gltf_material.metallic_roughness.base_color_texture.?.index;

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

                primitive.uniform_buffer = gpu.createBuffer(.{
                    .size = @sizeOf(la.mat4),
                    .usage = .{ .uniform = true, .copy_dst = true },
                });
                primitive.bind_group = gpu.createBindGroup(.{
                    .layout = local_bind_group_layout,
                    .entries = &.{
                        .{ .binding = 0, .resource = primitive.uniform_buffer },
                        .{ .binding = 1, .resource = self.textures[primitive.texture_index].createView(.{}) },
                    },
                });
            }
        }
    }

    pub fn draw(self: *const Model, render_pass: gpu.RenderPass) void {
        const data = &self.gltf.data;
        for (data.nodes.items) |*node| {
            const transform = zgltf.getLocalTransform(node.*);
            const mesh = &self.meshes[node.mesh orelse continue];
            for (mesh.primitives) |*primitive| {
                gpu.queueWriteBuffer(primitive.uniform_buffer, 0, std.mem.sliceAsBytes(&transform));
                render_pass.setPipeline(primitive.pipeline);
                render_pass.setBindGroup(0, global_bind_group);
                render_pass.setBindGroup(1, primitive.bind_group);
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

    const angle: f32 = -1;
    const s = @sin(angle);
    const c = @cos(angle);
    const model_mat: la.mat4 = .{
        .{ c, s, 0, 0 },
        .{ -s, c, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    const view_mat = la.mul(la.translation(0, 0, -5), la.rotation(-60.0, .{ 1, 0, 0 }));
    const mvp = la.mul(projection, la.mul(view_mat, model_mat));
    gpu.queueWriteBuffer(global_uniform_buffer, 0, std.mem.sliceAsBytes(&mvp));

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
