const std = @import("std");

pub const performance = struct {
    pub fn now() f64 {
        return performance_now();
    }
};

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);

fn writeLog(_: void, msg: []const u8) WriteError!usize {
    wasm_log_write(msg.ptr, msg.len);
    return msg.len;
}

/// Overwrite default log handler
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ @tagName(level) ++ "] " ++ "(" ++ @tagName(scope) ++ "): ";

    (LogWriter{ .context = {} }).print(prefix ++ format ++ "\n", args) catch return;

    wasm_log_flush();
}

extern fn performance_now() f64;
extern fn wasm_log_write(ptr: [*]const u8, len: usize) void;
extern fn wasm_log_flush() void;
