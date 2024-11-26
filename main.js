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

const performanceNow = () => performance.now();

let log_string = "";
const wasm_log_write = (ptr, len) => {
    log_string += readCharStr(ptr, len);
};
const wasm_log_flush = () => {
    console.log(log_string);
    log_string = "";
};

let modules = [];
let moduleHandles = 0;
const gpuCreateShaderModule = (codePtr, codeLen) => {
    const code = readCharStr(codePtr, codeLen);
    const module = device.createShaderModule({ code });
    moduleHandles++;
    modules[moduleHandles] = module;
    return moduleHandles;
};

let pipelines = [];
let pipelineHandles = 0;
const gpuCreateRenderPipeline = (moduleHandle) => {
    const module = modules[moduleHandle];
    const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
    const pipeline = device.createRenderPipeline({
        label: 'our hardcoded red triangle pipeline',
        layout: 'auto',
        vertex: {
            module,
        },
        fragment: {
            module,
            targets: [{ format: presentationFormat }],
        },
    });
    pipelineHandles++;
    pipelines[pipelineHandles] = pipeline;
    return pipelineHandles;
}

let renderPassDescriptors = [];
let renderPassDescriptorHandles = 0;
const gpuCreateRenderPassDescriptor = () => {
    const renderPassDescriptor = {
        label: 'our basic canvas renderPass',
        colorAttachments: [
            {
                // view: <- to be filled out when we render
                clearValue: [0.3, 0.3, 0.3, 1],
                loadOp: 'clear',
                storeOp: 'store',
            },
        ],
    };
    renderPassDescriptorHandles++;
    renderPassDescriptors[renderPassDescriptorHandles] = renderPassDescriptor;
    return renderPassDescriptorHandles;
}

const gpuRenderPassDescriptorSetCurrentTexture = (renderPassDescriptorHandle) => {
    const renderPassDescriptor = renderPassDescriptors[renderPassDescriptorHandle];
    renderPassDescriptor.colorAttachments[0].view = context.getCurrentTexture().createView();
}

let encoders = [];
let encoderHandles = 0;
const gpuCreateCommandEncoder = () => {
    const encoder = device.createCommandEncoder({ label: 'our encoder' });
    encoderHandles++;
    encoders[encoderHandles] = encoder;
    return encoderHandles;
}

let passes = [];
let passHandles = 0;
const gpuEncoderBeginRenderPass = (encoderHandle, renderPassDescriptorHandle) => {
    const encoder = encoders[encoderHandle];
    const renderPassDescriptor = renderPassDescriptors[renderPassDescriptorHandle];
    const pass = encoder.beginRenderPass(renderPassDescriptor);
    passHandles++;
    passes[passHandles] = pass;
    return passHandles;
}

const gpuPassSetPipeline = (passHandle, pipelineHandle) => {
    const pass = passes[passHandle];
    const pipeline = pipelines[pipelineHandle];
    pass.setPipeline(pipeline);
}

const gpuPassDraw = (passHandle, count) => {
    const pass = passes[passHandle];
    pass.draw(count);
}

const gpuPassEnd = (passHandle) => {
    const pass = passes[passHandle];
    pass.end();
}

let commandBuffers = [];
let commandBufferHandles = 0;
const gpuEncoderFinish = (encoderHandle) => {
    const encoder = encoders[encoderHandle];
    const commandBuffer = encoder.finish();
    commandBufferHandles++;
    commandBuffers[commandBufferHandles] = commandBuffer;
    return commandBufferHandles;
}

const gpuQueueSubmit = (commandBufferHandle) => {
    const commandBuffer = commandBuffers[commandBufferHandle];
    device.queue.submit([commandBuffer]);
}

const env = {
    performanceNow,
    wasm_log_write,
    wasm_log_flush,

    gpuCreateShaderModule,
    gpuCreateRenderPipeline,
    gpuCreateRenderPassDescriptor,
    gpuRenderPassDescriptorSetCurrentTexture,
    gpuCreateCommandEncoder,
    gpuEncoderBeginRenderPass,
    gpuPassSetPipeline,
    gpuPassDraw,
    gpuPassEnd,
    gpuEncoderFinish,
    gpuQueueSubmit,
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
}
main();