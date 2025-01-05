const std = @import("std");
const zgltf = @import("zgltf");

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_allocator.allocator();

    var args = std.process.args();
    _ = args.skip();
    const models_zig = args.next().?;
    const target_dir = std.fs.path.dirname(models_zig).?;

    var buffer = std.ArrayList(u8).init(arena);
    const writer = buffer.writer();

    while (args.next()) |source| {
        const basename = std.fs.path.basename(source);
        const target = try std.fs.path.join(arena, &.{ target_dir, basename });
        try std.fs.copyFileAbsolute(source, target, .{});
        try writer.print("pub const {s} = @embedFile(\"{s}\");\n", .{ std.fs.path.stem(basename), basename });
    }

    try std.fs.cwd().writeFile(.{ .sub_path = models_zig, .data = buffer.items });
    std.debug.print("models_zig={s}\n", .{models_zig});
}
