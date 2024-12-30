const std = @import("std");

pub const vec2 = @Vector(2, f32);
pub const vec3 = @Vector(3, f32);
pub const vec4 = @Vector(4, f32);
pub const mat4 = [4]vec4;

pub fn identity() mat4 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn perspective(fovy_degrees: f32, aspect_ratio: f32, z_near: f32) mat4 {
    const f = 1.0 / @tan(std.math.degreesToRadians(fovy_degrees) * 0.5);
    return .{
        .{ f / aspect_ratio, 0, 0, 0 },
        .{ 0, f, 0, 0 },
        .{ 0, 0, 0, -1 },
        .{ 0, 0, z_near, 0 },
    };
}

pub fn translation(x: f32, y: f32, z: f32) mat4 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ x, y, z, 1 },
    };
}

pub fn scale(x: f32, y: f32, z: f32) mat4 {
    return .{
        .{ x, 0, 0, 0 },
        .{ 0, y, 0, 0 },
        .{ 0, 0, z, 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn rotation(angle_degrees: f32, axis: vec3) mat4 {
    var result = identity();

    const sin_theta = @sin(std.math.degreesToRadians(angle_degrees));
    const cos_theta = @cos(std.math.degreesToRadians(angle_degrees));
    const cos_value = 1 - cos_theta;

    const x = axis[0];
    const y = axis[1];
    const z = axis[2];

    result[0][0] = (x * x * cos_value) + cos_theta;
    result[0][1] = (x * y * cos_value) + (z * sin_theta);
    result[0][2] = (x * z * cos_value) - (y * sin_theta);

    result[1][0] = (y * x * cos_value) - (z * sin_theta);
    result[1][1] = (y * y * cos_value) + cos_theta;
    result[1][2] = (y * z * cos_value) + (x * sin_theta);

    result[2][0] = (z * x * cos_value) + (y * sin_theta);
    result[2][1] = (z * y * cos_value) - (x * sin_theta);
    result[2][2] = (z * z * cos_value) + cos_theta;

    return result;
}

pub fn mul(m0: mat4, m1: mat4) mat4 {
    var result: mat4 = undefined;
    inline for (m1, 0..) |row, i| {
        const x = @shuffle(f32, row, undefined, [4]i32{ 0, 0, 0, 0 });
        const y = @shuffle(f32, row, undefined, [4]i32{ 1, 1, 1, 1 });
        const z = @shuffle(f32, row, undefined, [4]i32{ 2, 2, 2, 2 });
        const w = @shuffle(f32, row, undefined, [4]i32{ 3, 3, 3, 3 });
        result[i] = m0[0] * x + m0[1] * y + m0[2] * z + m0[3] * w;
    }
    return result;
}
