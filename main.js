const canvas = document.querySelector("canvas");
resizeCanvas();

window.addEventListener("resize", resizeCanvas);
function resizeCanvas() {
    canvas.width = devicePixelRatio * window.innerWidth;
    canvas.height = devicePixelRatio * window.innerHeight;
}

const readCharStr = (ptr, len) => {
    const array = memoryU8.slice(ptr, ptr + len);
    const decoder = new TextDecoder();
    return decoder.decode(array);
};

const readSlicePtr = (slicePtr) => {
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

const wgpu_device_create_render_pipeline = (descriptor) => {
    const vertexModule = wgpu[memoryU32[descriptor / 4]];
    const fragmentModule = wgpu[memoryU32[descriptor / 4 + 1]];
    const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
    const pipeline = device.createRenderPipeline({
        label: 'our hardcoded red triangle pipeline',
        layout: 'auto',
        vertex: {
            module: vertexModule,
        },
        fragment: {
            module: fragmentModule,
            targets: [{ format: presentationFormat }],
        },
    });
    return wgpuStore(pipeline);
}

const wgpu_get_current_texture_view = () => {
    return wgpuStore(context.getCurrentTexture().createView());
}

const wgpu_device_create_command_encoder = () => {
    return wgpuStore(device.createCommandEncoder());
}

const wgpu_command_encoder_begin_render_pass = (commandEncoder, descriptor) => {
    let numColorAttachments = memoryU32[descriptor / 4 + 1];
    let colorAttachments = [];
    let i = memoryU32[descriptor / 4] / 4;
    while (numColorAttachments--) {
        colorAttachments.push({
            view: wgpu[memoryU32[i]],
            loadOp: loadOps[memoryU32[i + 1]],
            storeOp: storeOps[memoryU32[i + 2]],
            clearValue: [memoryF32[i + 3], memoryF32[i + 4], memoryF32[i + 5], memoryF32[i + 6]],
        });
        i += 7;
    }
    return wgpuStore(wgpu[commandEncoder].beginRenderPass({
        colorAttachments,
    }));
}

const wgpu_encoder_set_pipeline = (passEncoder, pipeline) => {
    wgpu[passEncoder].setPipeline(wgpu[pipeline]);
}

const wgpu_render_commands_mixin_draw = (passEncoder, vertexCount, instanceCount, firstVertex, firstInstance) => {
    wgpu[passEncoder].draw(vertexCount, instanceCount, firstVertex, firstInstance);
}

const wgpu_encoder_end = (encoder) => {
    wgpu[encoder].end();
}

const wgpu_encoder_finish = (encoder) => {
    return wgpuStore(wgpu[encoder].finish());
}

const wgpu_queue_submit = (commandBuffer) => {
    device.queue.submit([wgpu[commandBuffer]]);
}

const env = {
    performance_now,
    wasm_log_write,
    wasm_log_flush,

    wgpu_object_destroy,
    wgpu_device_create_shader_module,
    wgpu_device_create_render_pipeline,
    wgpu_get_current_texture_view,
    wgpu_device_create_command_encoder,
    wgpu_command_encoder_begin_render_pass,
    wgpu_encoder_set_pipeline,
    wgpu_render_commands_mixin_draw,
    wgpu_encoder_end,
    wgpu_encoder_finish,
    wgpu_queue_submit,
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
    window.memoryU8 = new Uint8Array(memory.buffer);
    window.memoryU32 = new Uint32Array(memory.buffer);
    window.memoryF32 = new Float32Array(memory.buffer);
    instance.exports.onInit();

    const draw = () => {
        instance.exports.onDraw();
        requestAnimationFrame(draw);
    }
    draw();
}
main();