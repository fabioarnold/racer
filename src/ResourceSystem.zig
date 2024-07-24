const std = @import("std");
const Allocator = std.mem.Allocator;
const Yaz0 = @import("Yaz0.zig");
const U8 = @import("U8.zig");

fn readFile(allocator: Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    _ = try file.readAll(contents);
    return contents;
}

pub fn loadCarc(allocator: Allocator, path: []const u8) !void {
    const d = try readFile(allocator, path);
    defer allocator.free(d);
    const g = try Yaz0.decompress(allocator, d);
    const dir = try U8.Archive.parse(allocator, g);
    _ = dir;
}
