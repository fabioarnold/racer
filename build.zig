const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const native = false;
    if (native) {
        const target = b.standardTargetOptions(.{});

        const raylib_dep = b.dependency("raylib-zig", .{
            .target = target,
            .optimize = optimize,
        });

        const raylib = raylib_dep.module("raylib");
        const raygui = raylib_dep.module("raygui");
        const raylib_artifact = raylib_dep.artifact("raylib");

        const exe = b.addExecutable(.{
            .name = "racer",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);

        b.installArtifact(exe);
        return;
    }

    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const zgltf = b.dependency("zgltf", .{ .target = target, .optimize = optimize });
    const wasm = b.addExecutable(.{
        .name = "racer",
        .root_source_file = b.path("src/main_wasm.zig"),
        .target = target,
        .optimize = optimize,
    });
    wasm.root_module.addImport("zgltf", zgltf.module("zgltf"));
    wasm.rdynamic = true;
    wasm.entry = .disabled;
    b.installArtifact(wasm);

    const blender_exe = "/Applications/Blender.app/Contents/MacOS/Blender";
    const source_blend = "data/cars/acrux.blend";

    const blender_export = b.addExecutable(.{
        .name = "blender-export",
        .root_source_file = b.path("src/build/blender_export.zig"),
        .target = b.host,
        .optimize = .Debug,
    });
    const run_blender_export = b.addRunArtifact(blender_export);
    run_blender_export.addArg(blender_exe);
    run_blender_export.addFileArg(b.path(source_blend));
    const output_glb = run_blender_export.addOutputFileArg("acrux.glb");

    const model_converter = b.addExecutable(.{
        .name = "model-converter",
        .root_source_file = b.path("src/build/model_converter.zig"),
        .target = b.host,
        .optimize = .Debug,
    });
    const run_model_converter = b.addRunArtifact(model_converter);
    const models_zig = run_model_converter.addOutputFileArg("models.zig");
    run_model_converter.addFileArg(output_glb);

    const models_mod = b.addModule("models", .{
        .root_source_file = models_zig,
        .target = target,
        .optimize = optimize,
    });
    wasm.root_module.addImport("models", models_mod);
}
