const canvas = document.querySelector("canvas");
resizeCanvas();

window.addEventListener("resize", resizeCanvas);
function resizeCanvas() {
    canvas.width = devicePixelRatio * window.innerWidth;
    canvas.height = devicePixelRatio * window.innerHeight;
}

const readCharStr = (ptr, len) => {
    const array = new Uint8Array(memory.buffer, ptr, len);
    const decoder = new TextDecoder();
    return decoder.decode(array);
};

const readSlicePtr = (slicePtr) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    const ptr = memoryU32[slicePtr / 4];
    const len = memoryU32[slicePtr / 4 + 1];
    return readCharStr(ptr, len);
}

const performance_now = () => performance.now();

let log_string = "";
const wasm_log_write = (ptr, len) => {
    log_string += readCharStr(ptr, len);
};
const wasm_log_flush = () => {
    console.log(log_string);
    log_string = "";
};

const loadOps = ["load", "clear"];
const storeOps = ["store", "discard"];
const vertexFormats = ["float32", "float32x2", "float32x3", "float32x4"];
const indexFormats = ["uint16", "uint32"];
const textureFormats = ["rgba8unorm", "depth24plus"];
const textureDimensions = ["2d", "2d-array"];
const depthCompareFunctions = ["less", "greater"];

let wgpu = {};
let wgpuIdCounter = 2;
const wgpuStore = (object) => {
    while (wgpu[wgpuIdCounter]) wgpuIdCounter = wgpuIdCounter < 2147483647 ? wgpuIdCounter + 1 : 2;
    wgpu[wgpuIdCounter] = object;
    object.wid = wgpuIdCounter;
    return wgpuIdCounter++;
}

const wgpu_object_destroy = (id) => {
    const object = wgpu[id];
    if (object) {
        object.wid = 0;
        // WebGPU objects of type GPUDevice, GPUBuffer, GPUTexture and GPUQuerySet have an explicit .destroy() function. Call that if applicable.
        if (object["destroy"]) object.destroy();
        delete wgpu[id];
    }
}

const wgpu_device_create_shader_module = (descriptor) => {
    const code = readSlicePtr(descriptor);
    const module = device.createShaderModule({ code });
    return wgpuStore(module);
};

const wgpu_device_create_buffer = (descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    return wgpuStore(device.createBuffer({
        size: memoryU32[descriptor / 4],
        usage: memoryU32[descriptor / 4 + 1],
    }));
}

const wgpu_device_create_render_pipeline = (descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    const vertexModule = wgpu[memoryU32[descriptor / 4]];
    let vertexBufferPtr = memoryU32[descriptor / 4 + 1];
    let vertexBufferLen = memoryU32[descriptor / 4 + 2];
    const fragmentModule = wgpu[memoryU32[descriptor / 4 + 3]];
    const depthStencilPtr = memoryU32[descriptor / 4 + 4];
    let vertexBuffers = [];
    while (vertexBufferLen--) {
        let attributes = [];
        let attributesPtr = memoryU32[vertexBufferPtr / 4 + 1];
        let attributesLen = memoryU32[vertexBufferPtr / 4 + 2];
        while (attributesLen--) {
            attributes.push({
                format: vertexFormats[memoryU32[attributesPtr / 4]],
                offset: memoryU32[attributesPtr / 4 + 1],
                shaderLocation: memoryU32[attributesPtr / 4 + 2],
            });
            attributesPtr += 12;
        }
        vertexBuffers.push({
            arrayStride: memoryU32[vertexBufferPtr / 4],
            attributes,
            stepMode: ["vertex", "instance"][memoryU32[vertexBufferPtr / 4 + 3]],
        });
        vertexBufferPtr += 16;
    }
    let depthStencil = undefined;
    if (depthStencilPtr > 0) {
        depthStencil = {
            depthCompare: depthCompareFunctions[memoryU32[depthStencilPtr / 4]],
            depthWriteEnabled: memoryU32[depthStencilPtr / 4 + 1] != 0,
            format: textureFormats[memoryU32[depthStencilPtr / 4 + 2]],
        };
    }
    const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
    const pipeline = device.createRenderPipeline({
        layout: 'auto',
        vertex: {
            module: vertexModule,
            buffers: vertexBuffers,
        },
        fragment: {
            module: fragmentModule,
            targets: [{ format: presentationFormat }],
        },
        depthStencil,
    });
    return wgpuStore(pipeline);
}

const wgpu_canvas_context_get_current_texture = () => {
    return wgpuStore(context.getCurrentTexture());
}

const wgpu_device_create_command_encoder = () => {
    return wgpuStore(device.createCommandEncoder());
}

const wgpu_device_create_texture = (descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    return wgpuStore(device.createTexture({
        size: [memoryU32[descriptor / 4], memoryU32[descriptor / 4 + 1], memoryU32[descriptor / 4 + 2],],
        format: textureFormats[memoryU32[descriptor / 4 + 3]],
        usage: memoryU32[descriptor / 4 + 4],
    }));
}

const wgpu_device_create_sampler = (descriptor) => {
    return wgpuStore(device.createSampler());
}

const wgpu_command_encoder_begin_render_pass = (commandEncoder, descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    const memoryF32 = new Float32Array(memory.buffer);
    let colorAttachmentsLen = memoryU32[descriptor / 4 + 1];
    let colorAttachments = [];
    let i = memoryU32[descriptor / 4] / 4;
    while (colorAttachmentsLen--) {
        colorAttachments.push({
            view: wgpu[memoryU32[i]],
            loadOp: loadOps[memoryU32[i + 1]],
            storeOp: storeOps[memoryU32[i + 2]],
            clearValue: [memoryF32[i + 3], memoryF32[i + 4], memoryF32[i + 5], memoryF32[i + 6]],
        });
        i += 7;
    }
    let depthStencilAttachment = undefined;
    const depthStencilAttachmentPtr = memoryU32[descriptor / 4 + 2];
    if (depthStencilAttachmentPtr > 0) {
        depthStencilAttachment = {
            view: wgpu[memoryU32[depthStencilAttachmentPtr / 4]],
            depthLoadOp: loadOps[memoryU32[depthStencilAttachmentPtr / 4 + 1]],
            depthStoreOp: storeOps[memoryU32[depthStencilAttachmentPtr / 4 + 2]],
            depthClearValue: memoryF32[depthStencilAttachmentPtr / 4 + 3],
        };
    }
    return wgpuStore(wgpu[commandEncoder].beginRenderPass({
        colorAttachments,
        depthStencilAttachment,
    }));
}

const wgpu_device_create_bind_group = (descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    let entriesPtr = memoryU32[descriptor / 4 + 1];
    let entriesLen = memoryU32[descriptor / 4 + 2];
    let entries = [];
    while (entriesLen--) {
        let resource = wgpu[memoryU32[entriesPtr / 4 + 1]];
        if (resource instanceof GPUBuffer) resource = { buffer: resource };
        entries.push({
            binding: memoryU32[entriesPtr / 4],
            resource,
        });
        entriesPtr += 8;
    }
    return wgpuStore(device.createBindGroup({
        layout: wgpu[memoryU32[descriptor / 4]],
        entries,
    }));
}

const wgpu_texture_create_view = (texture, descriptor) => {
    const memoryU32 = new Uint32Array(memory.buffer);
    const dimension = textureDimensions[memoryU32[descriptor / 4]];
    const arrayLayerCount = memoryU32[descriptor / 4 + 1];
    return wgpuStore(wgpu[texture].createView({
        dimension,
        arrayLayerCount,
    }));
}

const wgpu_texture_width = (texture) => {
    return wgpu[texture].width;
}

const wgpu_texture_height = (texture) => {
    return wgpu[texture].height;
}

const wgpu_pipeline_get_bind_group_layout = (pipeline, index) => {
    return wgpuStore(wgpu[pipeline].getBindGroupLayout(index));
}

const wgpu_encoder_set_pipeline = (passEncoder, pipeline) => {
    wgpu[passEncoder].setPipeline(wgpu[pipeline]);
}

const wgpu_render_commands_mixin_set_vertex_buffer = (passEncoder, slot, buffer, offset, size) => {
    wgpu[passEncoder].setVertexBuffer(slot, wgpu[buffer], offset, size < 0 ? void 0 : size);
}

const wgpu_render_commands_mixin_set_index_buffer = (passEncoder, buffer, indexFormat, offset, size) => {
    wgpu[passEncoder].setIndexBuffer(wgpu[buffer], indexFormats[indexFormat], offset, size < 0 ? void 0 : size);
}

const wgpu_render_commands_mixin_draw = (passEncoder, vertexCount, instanceCount, firstVertex, firstInstance) => {
    wgpu[passEncoder].draw(vertexCount, instanceCount, firstVertex, firstInstance);
}

const wgpu_render_commands_mixin_draw_indexed = (passEncoder, indexCount, instanceCount, firstVertex, baseVertex, firstInstance) => {
    wgpu[passEncoder].drawIndexed(indexCount, instanceCount, firstVertex, baseVertex, firstInstance);
}

const wgpu_encoder_end = (encoder) => {
    wgpu[encoder].end();
}

const wgpu_encoder_finish = (encoder) => {
    return wgpuStore(wgpu[encoder].finish());
}

const wgpu_encoder_set_bind_group = (encoder, index, bindGroup) => {
    wgpu[encoder].setBindGroup(index, wgpu[bindGroup]);
}

const wgpu_queue_submit = (commandBuffer) => {
    device.queue.submit([wgpu[commandBuffer]]);
}

const wgpu_queue_write_buffer = (buffer, bufferOffset, dataPtr, dataLen) => {
    device.queue.writeBuffer(wgpu[buffer], bufferOffset, memory.buffer, dataPtr, dataLen);
}

const wgpu_queue_write_texture = (texture, dataPtr, dataLen, bytesPerRow, rowsPerImage, writeWidth, writeHeight, writeDepth) => {
    const data = new Uint8Array(memory.buffer, dataPtr, dataLen);
    const dataLayout = {};
    if (bytesPerRow > 0) dataLayout.bytesPerRow = bytesPerRow;
    if (rowsPerImage > 0) dataLayout.rowsPerImage = rowsPerImage;
    const size = [writeWidth, writeHeight, writeDepth];
    device.queue.writeTexture({ texture: wgpu[texture] }, data, dataLayout, size);
}

const env = {
    performance_now,
    wasm_log_write,
    wasm_log_flush,

    wgpu_object_destroy,
    wgpu_canvas_context_get_current_texture,
    wgpu_device_create_shader_module,
    wgpu_device_create_buffer,
    wgpu_device_create_render_pipeline,
    wgpu_device_create_command_encoder,
    wgpu_device_create_texture,
    wgpu_device_create_sampler,
    wgpu_device_create_bind_group,
    wgpu_texture_create_view,
    wgpu_texture_width,
    wgpu_texture_height,
    wgpu_pipeline_get_bind_group_layout,
    wgpu_command_encoder_begin_render_pass,
    wgpu_encoder_set_pipeline,
    wgpu_render_commands_mixin_set_vertex_buffer,
    wgpu_render_commands_mixin_set_index_buffer,
    wgpu_render_commands_mixin_draw,
    wgpu_render_commands_mixin_draw_indexed,
    wgpu_encoder_end,
    wgpu_encoder_finish,
    wgpu_encoder_set_bind_group,
    wgpu_queue_submit,
    wgpu_queue_write_buffer,
    wgpu_queue_write_texture,
};

async function main() {
    const adapter = await navigator.gpu?.requestAdapter();
    const device = await adapter?.requestDevice();
    if (!device) {
        fail('need a browser that supports WebGPU');
        return;
    }
    // Get a WebGPU context from the canvas and configure it
    const canvas = document.querySelector('canvas');
    const context = canvas.getContext('webgpu');
    const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
        device,
        format: presentationFormat,
    });
    window.context = context;
    window.device = device;

    const response = await fetch("zig-out/bin/racer.wasm");
    const bytes = await response.arrayBuffer();
    const results = await WebAssembly.instantiate(bytes, { env });
    const instance = results.instance;
    window.memory = instance.exports.memory;
    instance.exports.onInit();

    const draw = () => {
        instance.exports.onDraw();
        requestAnimationFrame(draw);
    }
    draw();
}
main();