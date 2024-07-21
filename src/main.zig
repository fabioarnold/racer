const std = @import("std");
const rl = @import("raylib");
const gl = rl.gl;
const rlm = rl.math;
const Vec3 = rl.Vector3;
const Car = @import("Car.zig");
const Menu = @import("Menu.zig");

const RL_LINES = 0x0001;
const RL_TRIANGLES = 0x0004;
const RL_QUADS = 0x0007;

const max_forward_speed = mazda_rx7_top_speed_kmph * kmph_to_mps;
const max_reverse_speed = 5;

const kmph_to_mps = 1.0 / 3.6;
const mazda_rx7_top_speed_kmph = 250;

var car: Car = undefined;
var model: rl.Model = undefined;
var background_texture: rl.Texture2D = undefined;

var track_points: std.ArrayList(Vec3) = undefined;

fn drawScene(camera: rl.Camera) void {
    rl.beginMode3D(camera);
    defer rl.endMode3D();

    const draw_floor = false;
    if (draw_floor) {
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

    // mirror
    gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_front)));
    rl.drawModelEx(model, car.center(), Vec3.init(0, 1, 0), car.angle(), Vec3.init(1, -1, 1), rl.Color.white);
    gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_back)));

    rl.drawModelEx(model, car.center(), Vec3.init(0, 1, 0), car.angle(), Vec3.init(1, 1, 1), rl.Color.white);
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    const screen_width = 1280;
    const screen_height = 720;

    rl.setTraceLogLevel(.log_error);

    rl.setConfigFlags(.{ .msaa_4x_hint = true, .vsync_hint = true });
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
    var camera_td = rl.Camera{
        .position = rl.Vector3.init(0, 20, 0),
        .target = Vec3.zero(),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = .camera_perspective,
    };
    var use_camera_td = true;

    track_points = std.ArrayList(Vec3).init(allocator);
    model = rl.loadModel("data/mazda_rx7.glb");
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
    background_texture = rl.loadTextureFromImage(background_image);
    rl.unloadImage(background_image);


    var steer: f32 = 0;
    car = Car.init(Vec3.zero());

    var menu_time: f32 = 1000; // @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());
        camera.position.x = 10 * @sin(0 * time);
        camera.position.z = 10 * @cos(0 * time);

        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            const mouse_pos = rl.getMousePosition();
            const ray = rl.getScreenToWorldRay(mouse_pos, camera_td);
            const t = -ray.position.y / ray.direction.y;
            const point = ray.position.add(ray.direction.scale(t));
            try track_points.append(Vec3.init(point.x, point.z, 0));
        }
        if (rl.isKeyPressed(.key_tab)) {
            use_camera_td = !use_camera_td;
        }

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

        // update car animation
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

        camera.target = car.center();
        camera.position = camera.target.add(Vec3.init(0, 2, 5));
        camera_td.target = car.center();
        camera_td.position = camera_td.target.add(Vec3.init(0, 100, 10));

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangleGradientV(0, 0, screen_width, screen_height, rl.Color.black, rl.Color.dark_gray);

        drawScene(if (use_camera_td) camera_td else camera);

        const visualize_axles = false;
        if (visualize_axles) {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            gl.rlDisableDepthTest();
            rl.drawSphere(car.front.add(Vec3.init(0, 0, 0)), 0.1, rl.Color.red);
            rl.drawSphere(car.back.add(Vec3.init(0, 0, 0)), 0.1, rl.Color.blue);
        }
        // draw track
        {
            rl.beginMode3D(if (use_camera_td) camera_td else camera);
            defer rl.endMode3D();

            gl.rlRotatef(90, 1, 0, 0);
            defer gl.rlLoadIdentity();

            for (track_points.items, 0..) |point, i| {
                rl.drawSphere(point, 0.5, rl.Color.red);
                if (i >= 3 and i % 3 == 0) {
                    drawSplineSegmentBezierCubic(
                        track_points.items[i - 3],
                        track_points.items[i - 2],
                        track_points.items[i - 1],
                        point,
                        2,
                        rl.Color.red,
                    );
                    // rl.drawLine3D(track_points.items[i - 1], point, rl.Color.red);
                }
            }
        }

        // gauges
        rl.drawRectangleLines(40, screen_height / 2 - 300, 40, 600, rl.Color.white);
        rl.drawRectangle(40, @intFromFloat(screen_height / 2 - 15 * @max(0, car.speed)), 40, @intFromFloat(15 * @abs(car.speed)), rl.Color.white);
        rl.drawRectangleLines(100, 40, 200, 40, rl.Color.white);
        rl.drawRectangle(@intFromFloat(200 - 100 * @max(0, -steer)), 40, @intFromFloat(100 * @abs(steer)), 40, rl.Color.white);

        const alpha: f32 = @max(0, @min(1, 1 * (time - menu_time)));
        Menu.draw(alpha);
    }
}

const SPLINE_SEGMENT_DIVISIONS = 24;

// Draw spline segment: Cubic Bezier, 2 points, 2 control points
fn drawSplineSegmentBezierCubic(p1: Vec3, c2: Vec3, c3: Vec3, p4: Vec3, thick: f32, color: rl.Color) void {
    const step = 1.0 / @as(comptime_float, SPLINE_SEGMENT_DIVISIONS);

    var previous = p1;
    var current: Vec3 = undefined;
    var t: f32 = 0;

    var points: [2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3 = undefined;

    var i: usize = 1;
    while (i <= SPLINE_SEGMENT_DIVISIONS) : (i += 1) {
        t = step * @as(f32, @floatFromInt(i));

        const a = std.math.pow(f32, 1.0 - t, 3);
        const b = 3.0 * std.math.pow(f32, 1.0 - t, 2) * t;
        const c = 3.0 * (1.0 - t) * std.math.pow(f32, t, 2);
        const d = std.math.pow(f32, t, 3);

        current.y = a * p1.y + b * c2.y + c * c3.y + d * p4.y;
        current.x = a * p1.x + b * c2.x + c * c3.x + d * p4.x;

        const dy = current.y - previous.y;
        const dx = current.x - previous.x;
        const size = 0.5 * thick / @sqrt(dx * dx + dy * dy);

        if (i == 1) {
            points[0].x = previous.x + dy * size;
            points[0].y = previous.y - dx * size;
            points[0].z = 0.0;
            points[1].x = previous.x - dy * size;
            points[1].y = previous.y + dx * size;
            points[1].z = 0.0;
        }

        points[2 * i + 1].x = current.x - dy * size;
        points[2 * i + 1].y = current.y + dx * size;
        points[2 * i + 1].z = 0.0;
        points[2 * i].x = current.x + dy * size;
        points[2 * i].y = current.y - dx * size;
        points[2 * i].z = 0.0;

        previous = current;
    }

    rl.drawTriangleStrip3D(&points, color);
    // DrawTriangleStrip(points, 2*SPLINE_SEGMENT_DIVISIONS + 2, color);
}
