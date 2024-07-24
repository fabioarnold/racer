// Nintendo "U8" filesystem archives.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const readInt = std.mem.readInt;

pub const NodeType = enum(u8) {
    file = 0x00,
    dir = 0x01,
};

pub const File = struct {
    name: []const u8,
    buffer: []const u8,
};

pub const Dir = struct {
    name: []const u8,
    child_nodes: []const Node,
    // subdirs: []const Dir,
    // files: []const File,
    next_node_index: usize,
};

pub const Node = union(NodeType) {
    file: File,
    dir: Dir,
};

pub const Archive = struct {
    root: Dir,

    const ParseContext = struct {
        allocator: Allocator,
        buffer: []const u8,
        toc_offs: u32,
        string_table_offs: u32,

        fn readString(ctx: ParseContext, offs: u32) []const u8 {
            const string = ctx.buffer[ctx.string_table_offs + offs ..];
            var len: usize = 0;
            while (string[len] != 0) : (len += 1) {}
            return string[0..len];
        }

        fn readU32(ctx: ParseContext, offs: u32) u32 {
            return readInt(u32, ctx.buffer[offs..][0..4], .big);
        }
    };

    pub fn parse(allocator: Allocator, buffer: []const u8) !Archive {
        const magic = buffer[0..4];
        if (!std.mem.eql(u8, magic, &.{ 0x55, 0xAA, 0x38, 0x2D })) {
            return error.BadHeader;
        }

        var ctx: ParseContext = .{
            .allocator = allocator,
            .buffer = buffer,
            .toc_offs = undefined,
            .string_table_offs = undefined,
        };
        ctx.toc_offs = ctx.readU32(0x04);
        // const header_size = ctx.readU32(0x08);
        // const data_offs = ctx.readU32(0x0C);

        const root_node_type: NodeType = @enumFromInt(buffer[ctx.toc_offs]);
        assert(root_node_type == .dir);
        const root_node_child_count = ctx.readU32(ctx.toc_offs + 0x08);
        ctx.string_table_offs = ctx.toc_offs + root_node_child_count * 0x0C;

        const root_node = try readNode(ctx, 0);

        return .{ .root = root_node.dir };
    }

    fn readNode(ctx: ParseContext, node_index: u32) !Node {
        const node_offs = ctx.toc_offs + node_index * 0x0C;
        const node_type: NodeType = @enumFromInt(ctx.buffer[node_offs + 0x00]);
        const node_name_offs = ctx.readU32(node_offs + 0x00) & 0x00FFFFFF;
        const node_name = ctx.readString(node_name_offs);

        switch (node_type) {
            .file => {
                const node_data_offs = ctx.readU32(node_offs + 0x04);
                const node_data_size = ctx.readU32(node_offs + 0x08);
                return Node{ .file = .{
                    .name = node_name,
                    .buffer = ctx.buffer[node_data_offs..][0..node_data_size],
                } };
            },
            .dir => {
                const next_node_index = ctx.readU32(node_offs + 0x08);

                var child_nodes = ArrayList(Node).init(ctx.allocator);

                var i = node_index + 1;
                while (i < next_node_index) : (i += 1) {
                    const sub_node = try readNode(ctx, i);
                    try child_nodes.append(sub_node);
                }

                return Node{ .dir = .{
                    .name = node_name,
                    .child_nodes = try child_nodes.toOwnedSlice(),
                    .next_node_index = next_node_index,
                } };
            },
        }
    }
};
