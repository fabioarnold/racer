pub const ShaderModuleCompilationHint = struct {
    entry_point: []const u8,
};

pub const ShaderModuleDescriptor = struct {
    code: []const u8,
    hints: []const *ShaderModuleCompilationHint = &.{},
};

pub const VertexFormat = enum(u32) {
    float32,
    float32x2,
    float32x3,
    float32x4,
};

pub const IndexFormat = enum(u32) {
    uint16,
    uint32,
};

pub const TextureFormat = enum(u32) {
    rgba8unorm,
    depth24plus,
};

pub const TextureDimension = enum(u32) {
    @"2d",
    @"2d_array",
};

pub const RenderPipelineDescriptor = struct {
    vertex: struct {
        module: ShaderModule,
        buffers: []const struct {
            array_stride: u32,
            attributes: []const struct {
                format: VertexFormat,
                offset: u32,
                shader_location: u32,
            },
            step_mode: enum(u32) { vertex, instance } = .vertex,
        } = &.{},
    },
    fragment: struct {
        module: ShaderModule,
    },
    depth_stencil: ?*const struct {
        depth_compare: enum(u32) { less, greater },
        depth_write_enabled: bool,
        format: TextureFormat,
    } = null,
};

pub const TextureUsage = packed struct(u32) {
    copy_src: bool = false,
    copy_dst: bool = false,
    texture_binding: bool = false,
    storage_binding: bool = false,
    render_attachment: bool = false,
    _: u27 = 0,
};

pub const TextureDescriptor = struct {
    size: struct {
        width: u32,
        height: u32 = 1,
        depth: u32 = 1,
    },
    format: TextureFormat,
    usage: TextureUsage,
};

pub const TextureViewDescriptor = struct {
    dimension: TextureDimension = .@"2d",
    array_layer_count: u32 = 1,
};

pub const SamplerDescriptor = struct {};

pub const BindGroupDescriptor = struct {
    layout: BindGroupLayout,
    entries: []const struct {
        binding: u32,
        resource: Object,
    },
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const LoadOp = enum(u32) {
    load,
    clear,
};

pub const StoreOp = enum(u32) {
    store,
    discard,
};

pub const ColorAttachment = struct {
    view: TextureView,
    load_op: LoadOp,
    store_op: StoreOp,
    clear_value: Color,
};

pub const DepthAttachment = struct {
    view: TextureView,
    depth_load_op: LoadOp,
    depth_store_op: StoreOp,
    depth_clear_value: f32,
};

pub const RenderPassDescriptor = struct {
    color_attachments: []const ColorAttachment,
    depth_stencil_attachment: ?*const DepthAttachment,
};

pub const BufferUsage = packed struct(u32) {
    map_read: bool = false,
    map_write: bool = false,
    copy_src: bool = false,
    copy_dst: bool = false,
    index: bool = false,
    vertex: bool = false,
    uniform: bool = false,
    storage: bool = false,
    indirect: bool = false,
    query_resolve: bool = false,
    _: u22 = 0,
};

pub const BufferDescriptor = struct {
    size: u32,
    usage: BufferUsage,
};

const Object = enum(u32) {
    pub fn release(self: Object) void {
        wgpu_object_destroy(self);
    }
};

pub const ShaderModule = Object;
pub const Sampler = Object;
pub const BindGroup = Object;
pub const BindGroupLayout = Object;
pub const TextureView = Object;
pub const CommandBuffer = Object;
pub const Buffer = Object;

pub const Texture = struct {
    object: Object,

    pub fn release(self: Texture) void {
        self.object.release();
    }

    pub fn createView(self: Texture, descriptor: TextureViewDescriptor) TextureView {
        return wgpu_texture_create_view(self.object, &descriptor);
    }

    pub fn getWidth(self: Texture) u32 {
        return wgpu_texture_width(self.object);
    }

    pub fn getHeight(self: Texture) u32 {
        return wgpu_texture_height(self.object);
    }
};

pub const RenderPipeline = struct {
    object: Object,

    pub fn getBindGroupLayout(self: RenderPipeline, index: u32) BindGroupLayout {
        return wgpu_pipeline_get_bind_group_layout(self.object, index);
    }
};

pub const CommandEncoder = struct {
    object: Object,

    pub fn release(self: CommandEncoder) void {
        self.object.release();
    }

    pub fn beginRenderPass(self: CommandEncoder, descriptor: RenderPassDescriptor) RenderPass {
        return .{ .object = wgpu_command_encoder_begin_render_pass(self.object, &descriptor) };
    }

    pub fn finish(self: CommandEncoder) CommandBuffer {
        return wgpu_encoder_finish(self.object);
    }
};

pub const RenderPass = struct {
    object: Object,

    pub fn release(self: RenderPass) void {
        self.object.release();
    }

    pub fn setPipeline(self: RenderPass, pipeline: RenderPipeline) void {
        wgpu_encoder_set_pipeline(self.object, pipeline.object);
    }

    pub fn setBindGroup(self: RenderPass, index: u32, bind_group: BindGroup) void {
        wgpu_encoder_set_bind_group(self.object, index, bind_group);
    }

    const BufferOptions = struct {
        const max_size = -1;
        offset: u32 = 0,
        size: i32 = max_size,
    };

    pub fn setVertexBuffer(self: RenderPass, slot: u32, buffer: Buffer, options: BufferOptions) void {
        wgpu_render_commands_mixin_set_vertex_buffer(self.object, slot, buffer, options.offset, options.size);
    }

    pub fn setIndexBuffer(self: RenderPass, buffer: Buffer, format: IndexFormat, options: BufferOptions) void {
        wgpu_render_commands_mixin_set_index_buffer(self.object, buffer, format, options.offset, options.size);
    }

    const DrawArgs = struct {
        vertex_count: u32,
        instance_count: u32 = 1,
        first_vertex: u32 = 0,
        first_instance: u32 = 0,
    };
    pub fn draw(self: RenderPass, args: DrawArgs) void {
        wgpu_render_commands_mixin_draw(self.object, args.vertex_count, args.instance_count, args.first_vertex, args.first_instance);
    }

    const DrawIndexedArgs = struct {
        index_count: u32,
        instance_count: u32 = 1,
        first_vertex: u32 = 0,
        base_vertex: u32 = 0,
        first_instance: u32 = 0,
    };
    pub fn drawIndexed(self: RenderPass, args: DrawIndexedArgs) void {
        wgpu_render_commands_mixin_draw_indexed(self.object, args.index_count, args.instance_count, args.first_vertex, args.base_vertex, args.first_instance);
    }

    pub fn end(self: RenderPass) void {
        wgpu_encoder_end(self.object);
    }
};

pub fn createShaderModule(descriptor: ShaderModuleDescriptor) ShaderModule {
    return wgpu_device_create_shader_module(&descriptor);
}

pub fn createBuffer(descriptor: BufferDescriptor) Buffer {
    return wgpu_device_create_buffer(&descriptor);
}

pub fn createRenderPipeline(descriptor: RenderPipelineDescriptor) RenderPipeline {
    return .{ .object = wgpu_device_create_render_pipeline(&descriptor) };
}

pub fn getCurrentTexture() Texture {
    return .{ .object = wgpu_canvas_context_get_current_texture() };
}

pub fn createCommandEncoder() CommandEncoder {
    return .{ .object = wgpu_device_create_command_encoder() };
}

pub fn createTexture(descriptor: TextureDescriptor) Texture {
    return .{ .object = wgpu_device_create_texture(&descriptor) };
}

pub fn createSampler(descriptor: SamplerDescriptor) Sampler {
    return wgpu_device_create_sampler(&descriptor);
}

pub fn createBindGroup(descriptor: BindGroupDescriptor) BindGroup {
    return wgpu_device_create_bind_group(&descriptor);
}

pub fn queueSubmit(command_buffer: CommandBuffer) void {
    wgpu_queue_submit(command_buffer);
}

pub fn queueWriteBuffer(buffer: Buffer, buffer_offset: u32, data: []const u8) void {
    wgpu_queue_write_buffer(buffer, buffer_offset, data.ptr, data.len);
}

pub const TextureWriteArgs = struct {
    data: []const u8,
    bytes_per_row: u32 = 0,
    rows_per_image: u32 = 0,
    width: u32,
    height: u32 = 1,
    depth: u32 = 1,
};
pub fn queueWriteTexture(texture: Texture, args: TextureWriteArgs) void {
    wgpu_queue_write_texture(texture.object, args.data.ptr, args.data.len, args.bytes_per_row, args.rows_per_image, args.width, args.height, args.depth);
}

extern fn wgpu_object_destroy(Object) void;
extern fn wgpu_canvas_context_get_current_texture() Object;
extern fn wgpu_device_create_shader_module(*const ShaderModuleDescriptor) ShaderModule;
extern fn wgpu_device_create_buffer(*const BufferDescriptor) Buffer;
extern fn wgpu_device_create_render_pipeline(*const RenderPipelineDescriptor) Object;
extern fn wgpu_device_create_command_encoder() Object;
extern fn wgpu_device_create_texture(*const TextureDescriptor) Object;
extern fn wgpu_device_create_sampler(*const SamplerDescriptor) Sampler;
extern fn wgpu_device_create_bind_group(*const BindGroupDescriptor) BindGroup;
extern fn wgpu_texture_create_view(texture: Object, *const TextureViewDescriptor) TextureView;
extern fn wgpu_texture_width(texture: Object) u32;
extern fn wgpu_texture_height(texture: Object) u32;
extern fn wgpu_pipeline_get_bind_group_layout(pipeline: Object, u32) BindGroupLayout;
extern fn wgpu_command_encoder_begin_render_pass(command_encoder: Object, *const RenderPassDescriptor) Object;
extern fn wgpu_encoder_set_pipeline(pass_encoder: Object, pipeline: Object) void;
extern fn wgpu_render_commands_mixin_set_vertex_buffer(pass_encoder: Object, u32, Buffer, u32, i32) void;
extern fn wgpu_render_commands_mixin_set_index_buffer(pass_encoder: Object, Buffer, IndexFormat, u32, i32) void;
extern fn wgpu_render_commands_mixin_draw(pass_encoder: Object, u32, u32, u32, u32) void;
extern fn wgpu_render_commands_mixin_draw_indexed(pass_encoder: Object, u32, u32, u32, u32, u32) void;
extern fn wgpu_encoder_end(pass_encoder: Object) void;
extern fn wgpu_encoder_finish(command_encoder: Object) CommandBuffer;
extern fn wgpu_encoder_set_bind_group(encoder: Object, u32, BindGroup) void;
extern fn wgpu_queue_submit(command_buffer: CommandBuffer) void;
extern fn wgpu_queue_write_buffer(buffer: Buffer, buffer_offset: u32, data_ptr: [*]const u8, data_len: u32) void;
extern fn wgpu_queue_write_texture(texture: Object, data_ptr: [*]const u8, data_len: u32, u32, u32, u32, u32, u32) void;
