const std = @import("std");

pub fn main() !u8 {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_allocator.allocator();

    var args = std.process.args();
    _ = args.skip();
    const blender_exe = args.next().?;
    const source_blend = args.next().?;
    const target_glb = args.next().?;

    const python_expr = try std.fmt.allocPrint(
        arena,
        "import bpy; bpy.ops.export_scene.gltf(filepath='{s}', export_yup=False)",
        .{target_glb},
    );
    var child = std.process.Child.init(&.{ blender_exe, "-b", source_blend, "--python-expr", python_expr }, arena);
    return switch (try child.spawnAndWait()) {
        .Exited => |exit_code| exit_code,
        else => 1,
    };
}
