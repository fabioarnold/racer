const std = @import("std");
const rl = @import("raylib");
const Vec3 = rl.Vector3;

const Car = @This();

const dist_front = 1.49603;
const dist_back = 0.961294;
const wheel_radius = 0.352841;

front: Vec3,
back: Vec3,
speed: f32 = 0,
steering_angle: f32 = 0, // relative
wheel_angle: f32 = 0,

pub fn init(pos: Vec3) Car {
    return .{
        .front = pos.add(Vec3.init(0, 0, dist_front)),
        .back = pos.add(Vec3.init(0, 0, -dist_back)),
    };
}

pub fn integrate(self: *Car, dt: f32) void {
    const up = Vec3.init(0, 1, 0);
    var dir = self.direction();
    const move_forward = dir.scale(self.speed).scale(dt);
    const steer = move_forward.rotateByAxisAngle(up, self.steering_angle);
    self.front = self.front.add(steer);
    self.back = self.back.add(move_forward);
    // normalize distance
    dir = self.direction();
    self.front = self.back.add(dir.scale(dist_front + dist_back));

    // calculate wheel angle
    self.wheel_angle += self.speed / wheel_radius * dt;
}

pub fn center(self: Car) Vec3 {
    return self.front.lerp(self.back, dist_front / (dist_front + dist_back));
}

pub fn direction(self: Car) Vec3 {
    return self.front.subtract(self.back).normalize();
}

pub fn angle(self: Car) f32 {
    const dir = self.direction();
    return std.math.radiansToDegrees(std.math.atan2(dir.x, dir.z));
}
