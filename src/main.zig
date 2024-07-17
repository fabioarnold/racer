const std = @import("std");
const rl = @import("raylib");
const rlgl = @import("rlgl");
const raymath = @import("raymath");
const Menu = @import("Menu.zig");
const v3_zero = rl.Vector3.init(0, 0, 0);

pub fn main() !void {
    const screen_width = 1200;
    const screen_height = 720;

    rl.setTraceLogLevel(.log_error);

    rl.initWindow(screen_width, screen_height, "Racer");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var camera = rl.Camera{
        .position = rl.Vector3.init(0, 5, 10),
        .target = v3_zero,
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

    rl.setTargetFPS(60);

    var menu_time: f32 = 1000; // @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());
        camera.position.x = 10 * @sin(time);
        camera.position.z = 10 * @cos(time);

        Menu.handleInput();
        if (rl.isKeyPressed(.key_enter)) {
            menu_time = time;
            rl.playSound(sfx_click);
        }
        var steer: f32 = 0;
        if (rl.isKeyDown(.key_left)) steer -= 1;
        if (rl.isKeyDown(.key_right)) steer += 1;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangleGradientV(0, 0, screen_width, screen_height, rl.Color.black, rl.Color.dark_gray);

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            rl.drawPlane(v3_zero, .{ .x = 100, .y = 100 }, rl.Color.dark_blue.alpha(0.1));
            // rlgl.rlDisableDepthTest();
            // rl.drawGrid(10, 1);
            // rlgl.rlEnableDepthTest();

            const anim = &model_animations[1];
            const wheel_angle = 20 * time;
            const wheel_rot = raymath.quaternionFromAxisAngle(.{ .x = 1, .y = 0, .z = 0 }, wheel_angle);
            const wheel_turn = raymath.quaternionFromAxisAngle(.{ .x = 0, .y = 1, .z = 0 }, -0.3 * steer);
            anim.framePoses[0][2].rotation = raymath.quaternionMultiply(wheel_turn, wheel_rot);
            anim.framePoses[0][4].rotation = raymath.quaternionMultiply(wheel_turn, wheel_rot);
            anim.framePoses[0][5].rotation = wheel_rot;
            anim.framePoses[0][6].rotation = wheel_rot;
            rl.updateModelAnimation(model, model_animations[1], 0);

            // mirror
            rlgl.rlSetCullFace(@intCast(@intFromEnum(rlgl.rlCullMode.rl_cull_face_front)));
            rl.drawModelEx(model, v3_zero, v3_zero, 0, .{ .x = 1, .y = -1, .z = 1 }, rl.Color.white);
            rlgl.rlSetCullFace(@intCast(@intFromEnum(rlgl.rlCullMode.rl_cull_face_back)));

            rl.drawModel(model, v3_zero, 1, rl.Color.white);
        }

        const alpha: f32 = @max(0, @min(1, 1 * (time - menu_time)));
        Menu.draw(alpha);
    }
}
