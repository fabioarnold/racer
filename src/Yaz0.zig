// Nintendo Yaz0 format.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const readInt = std.mem.readInt;

pub fn decompress(allocator: Allocator, src: []const u8) ![]const u8 {
    const magic = src[0..4];
    if (!std.mem.eql(u8, magic, "Yaz0"[0..4])) {
        return error.BadHeader;
    }
    var uncompressed_size = readInt(u32, src[4..8], .big);
    const dst = try allocator.alloc(u8, uncompressed_size);

    var src_offs: usize = 0x10;
    var dst_offs: usize = 0x00;

    while (true) {
        const command_byte = src[src_offs];
        src_offs += 1;

        for (0..8) |i| {
            const rev_i: u3 = @intCast(7 - i);
            const bit: u8 = @as(u8, 1) << rev_i;
            if ((command_byte & bit) != 0) {
                dst[dst_offs] = src[src_offs];
                src_offs += 1;
                dst_offs += 1;
                uncompressed_size -= 1;
            } else {
                const tmp = readInt(u16, src[src_offs..][0..2], .big);
                src_offs += 2;
                const window_offset = (tmp & 0x0FFF) + 1;
                var window_length = (tmp >> 12) + 2;
                if (window_length == 2) {
                    window_length += @as(u16, src[src_offs]) + 0x10;
                    src_offs += 1;
                }

                assert(window_length >= 3 and window_length <= 0x111);

                var copy_offs = dst_offs - window_offset;
                for (0..window_length) |_| {
                    dst[dst_offs] = dst[copy_offs];
                    dst_offs += 1;
                    copy_offs += 1;
                    uncompressed_size -= 1;
                }
            }

            if (uncompressed_size == 0) {
                return dst;
            }
        }
    }

    return dst;
}
