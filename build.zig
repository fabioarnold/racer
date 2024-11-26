const std = @import("std");
// const emcc = @import("emcc.zig");

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
    } else {
        const wasm = b.addExecutable(.{
            .name = "racer",
            .root_source_file = b.path("src/main_wasm.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize,
        });
        wasm.rdynamic = true;
        wasm.entry = .disabled;
        b.installArtifact(wasm);
    }
}
