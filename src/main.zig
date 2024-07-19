const std = @import("std");
const rl = @import("raylib");
const gl = rl.gl;
const rlm = rl.math;
const Menu = @import("Menu.zig");

const Vec3 = rl.Vector3;

const RL_LINES = 0x0001;
const RL_TRIANGLES = 0x0004;
const RL_QUADS = 0x0007;

const max_forward_speed = 15;
const max_reverse_speed = 5;

const kmph_to_mps = 1.0 / 3.6;
const mazda_rx7_top_speed_kmph = 250;

const Car = struct {
    const dist_front = 1.49603;
    const dist_back = 0.961294;
    const wheel_radius = 0.352841;

    front: Vec3,
    back: Vec3,
    speed: f32 = 0,
    steering_angle: f32 = 0, // relative
    wheel_angle: f32 = 0,

    fn init(pos: Vec3) Car {
        return .{
            .front = pos.add(Vec3.init(0, 0, dist_front)),
            .back = pos.add(Vec3.init(0, 0, -dist_back)),
        };
    }

    fn integrate(self: *Car, dt: f32) void {
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

    fn center(self: Car) Vec3 {
        return self.front.lerp(self.back, dist_front / (dist_front + dist_back));
    }

    fn direction(self: Car) Vec3 {
        return self.front.subtract(self.back).normalize();
    }

    fn angle(self: Car) f32 {
        const dir = self.direction();
        return std.math.radiansToDegrees(std.math.atan2(dir.x, dir.z));
    }
};

pub fn main() !void {
    const screen_width = 1200;
    const screen_height = 720;

    rl.setTraceLogLevel(.log_error);

    rl.initWindow(screen_width, screen_height, "Racer");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var camera = rl.Camera{
        .position = rl.Vector3.init(0, 5, 10),
        .target = Vec3.zero(),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = .camera_perspective,
    };

    const model = rl.loadModel("data/mazda_rx7.glb");
    var model_animations = try rl.loadModelAnimations("data/mazda_rx7.glb");
    for (model_animations[0].bones[0..@intCast(model_animations[0].boneCount)], 0..) |b, i| {
        std.debug.print("b {} {s}\n", .{ i, b.name });
    }
    // b 0 body
    // b 1 steer_fr
    // b 2 wheel_fr
    // b 3 steer_fl
    // b 4 wheel_fl
    // b 5 wheel_br
    // b 6 wheel_bl
    const sfx_click = rl.loadSound("data/sfx/click.wav");
    Menu.load();

    const background_image = rl.genImageChecked(64, 64, 32, 32, rl.Color.black.alpha(0.5), rl.Color.gray);
    const background_texture = rl.loadTextureFromImage(background_image);
    rl.unloadImage(background_image);


    var steer: f32 = 0;
    var car = Car.init(Vec3.zero());

    var menu_time: f32 = 1000; // @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());
        camera.position.x = 10 * @sin(0 * time);
        camera.position.z = 10 * @cos(0 * time);

        Menu.handleInput();
        if (rl.isKeyPressed(.key_enter)) {
            menu_time = time;
            rl.playSound(sfx_click);
        }
        if (rl.isKeyDown(.key_left)) steer -= 0.1;
        if (rl.isKeyDown(.key_right)) steer += 0.1;
        if (!rl.isKeyDown(.key_left) and !rl.isKeyDown(.key_right) and @abs(steer) > 0.01) steer -= 0.1 * std.math.sign(steer);
        steer = std.math.clamp(steer, -1, 1);

        if (rl.isKeyDown(.key_up)) car.speed += 0.2;
        if (rl.isKeyDown(.key_down)) car.speed -= 0.2;
        car.speed = std.math.clamp(car.speed, -max_reverse_speed, max_forward_speed);

        const max_steering_angle = 0.4;
        car.steering_angle = -max_steering_angle * steer;
        car.integrate(1.0 / 60.0);

        camera.target = car.center();
        camera.position = camera.target.add(Vec3.init(0, 2, 5));

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangleGradientV(0, 0, screen_width, screen_height, rl.Color.black, rl.Color.dark_gray);

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            // draw floor
            {
                gl.rlPushMatrix();
                defer gl.rlPopMatrix();

                gl.rlSetTexture(background_texture.id);
                gl.rlBegin(RL_QUADS);
                gl.rlColor4f(1, 1, 1, 0.2);
                gl.rlTexCoord2f(0, 0);
                gl.rlVertex3f(-100, 0, -100);
                gl.rlTexCoord2f(0, 64);
                gl.rlVertex3f(-100, 0, 100);
                gl.rlTexCoord2f(64, 64);
                gl.rlVertex3f(100, 0, 100);
                gl.rlTexCoord2f(64, 0);
                gl.rlVertex3f(100, 0, -100);
                gl.rlEnd();
                gl.rlSetTexture(0);
            }

            const anim = &model_animations[1];
            const wheel_rot = rlm.quaternionFromAxisAngle(Vec3.init(1, 0, 0), car.wheel_angle);
            const wheel_turn = rlm.quaternionFromAxisAngle(Vec3.init(0, 1, 0), car.steering_angle);
            anim.framePoses[0][1].rotation = wheel_turn;
            anim.framePoses[0][2].rotation = rlm.quaternionMultiply(wheel_turn, wheel_rot);
            anim.framePoses[0][3].rotation = wheel_turn;
            anim.framePoses[0][4].rotation = rlm.quaternionMultiply(wheel_turn, wheel_rot);
            anim.framePoses[0][5].rotation = wheel_rot;
            anim.framePoses[0][6].rotation = wheel_rot;
            rl.updateModelAnimation(model, model_animations[1], 0);

            // mirror
            gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_front)));
            rl.drawModelEx(model, car.center(), Vec3.init(0, 1, 0), car.angle(), Vec3.init(1, -1, 1), rl.Color.white);
            gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_back)));

            rl.drawModelEx(model, car.center(), Vec3.init(0, 1, 0), car.angle(), Vec3.init(1, 1, 1), rl.Color.white);
        }

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            gl.rlDisableDepthTest();
            rl.drawSphere(car.front.add(Vec3.init(0, 1, 0)), 0.1, rl.Color.red);
            rl.drawSphere(car.back.add(Vec3.init(0, 1, 0)), 0.1, rl.Color.blue);
        }

        rl.drawRectangleLines(40, screen_height / 2 - 300, 40, 600, rl.Color.white);
        rl.drawRectangle(40, @intFromFloat(screen_height / 2 - 15 * @max(0, car.speed)), 40, @intFromFloat(15 * @abs(car.speed)), rl.Color.white);
        rl.drawRectangleLines(100, 40, 200, 40, rl.Color.white);
        rl.drawRectangle(@intFromFloat(200 - 100 * @max(0, -steer)), 40, @intFromFloat(100 * @abs(steer)), 40, rl.Color.white);

        const alpha: f32 = @max(0, @min(1, 1 * (time - menu_time)));
        Menu.draw(alpha);
    }
}
