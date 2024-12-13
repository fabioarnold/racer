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

pub const RenderPipelineDescriptor = struct {
    vertex: struct { module: ShaderModule, buffers: []const struct {
        array_stride: u32,
        attributes: []const struct {
            format: VertexFormat,
            offset: u32,
            shader_location: u32,
        },
        step_mode: enum(u32) { vertex, instance } = .vertex,
    } },
    fragment: struct {
        module: ShaderModule,
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

pub const RenderPassDescriptor = struct {
    color_attachments: []const ColorAttachment,
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
pub const RenderPipeline = Object;
pub const TextureView = Object;
pub const CommandBuffer = Object;
pub const Buffer = Object;

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
        wgpu_encoder_set_pipeline(self.object, pipeline);
    }

    const VertexBufferOptions = struct {
        const max_size = -1;
        offset: u32 = 0,
        size: i32 = max_size,
    };
    pub fn setVertexBuffer(self: RenderPass, slot: u32, buffer: Buffer, options: VertexBufferOptions) void {
        wgpu_render_commands_mixin_set_vertex_buffer(self.object, slot, buffer, options.offset, options.size);
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
    return wgpu_device_create_render_pipeline(&descriptor);
}

pub fn getCurrentTextureView() TextureView {
    return wgpu_get_current_texture_view();
}

pub fn createCommandEncoder() CommandEncoder {
    return .{ .object = wgpu_device_create_command_encoder() };
}

pub fn queueSubmit(command_buffer: CommandBuffer) void {
    wgpu_queue_submit(command_buffer);
}

pub fn queueWriteBuffer(buffer: Buffer, buffer_offset: u32, data: []const u8) void {
    wgpu_queue_write_buffer(buffer, buffer_offset, data.ptr, data.len);
}

extern fn wgpu_object_destroy(Object) void;
extern fn wgpu_device_create_shader_module(*const ShaderModuleDescriptor) ShaderModule;
extern fn wgpu_device_create_buffer(*const BufferDescriptor) Buffer;
extern fn wgpu_device_create_render_pipeline(*const RenderPipelineDescriptor) RenderPipeline;
extern fn wgpu_get_current_texture_view() TextureView;
extern fn wgpu_device_create_command_encoder() Object;
extern fn wgpu_command_encoder_begin_render_pass(command_encoder: Object, *const RenderPassDescriptor) Object;
extern fn wgpu_encoder_set_pipeline(pass_encoder: Object, RenderPipeline) void;
extern fn wgpu_render_commands_mixin_set_vertex_buffer(pass_encoder: Object, u32, Buffer, u32, i32) void;
extern fn wgpu_render_commands_mixin_draw(pass_encoder: Object, u32, u32, u32, u32) void;
extern fn wgpu_encoder_end(pass_encoder: Object) void;
extern fn wgpu_encoder_finish(command_encoder: Object) CommandBuffer;
extern fn wgpu_queue_submit(command_buffer: CommandBuffer) void;
extern fn wgpu_queue_write_buffer(buffer: Buffer, buffer_offset: u32, data_ptr: [*]const u8, data_len: u32) void;
