const std = @import("std");
const rl = @import("raylib");
const gl = rl.gl;
const rlm = rl.math;
const gui = @import("raygui");
const Vec3 = rl.Vector3;
const Car = @import("Car.zig");
const Menu = @import("Menu.zig");
const ResourceSystem = @import("ResourceSystem.zig");

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

const TrackNode = struct {
    pos: Vec3,
    dir: Vec3, // TODO: left handle + right handle
    tilt: f32 = 0,
};
var track: std.ArrayList(TrackNode) = undefined;

const track_data = [_]TrackNode{
    .{ .pos = Vec3.init(-44.40104675292969, 1.721134901046753, -1.3928852081298828), .dir = Vec3.init(-0.08200836181640625, 0.0, 11.109437942504883), .tilt = 0.4923742711544037 },
    .{ .pos = Vec3.init(-22.16115951538086, 0.0, 25.05327796936035), .dir = Vec3.init(11.108991622924805, 0.0, 0.1291065216064453) },
    .{ .pos = Vec3.init(-0.13704636693000793, 0.0, 18.279998779296875), .dir = Vec3.init(10.364692687988281, 0.0, -0.01633453369140625) },
    .{ .pos = Vec3.init(25.252986907958984, 0.0, 25.312191009521484), .dir = Vec3.init(10.576545715332031, 0.0, 0.17934799194335938) },
    .{ .pos = Vec3.init(39.60963821411133, 1.8524237871170044, -1.0046038627624512), .dir = Vec3.init(-0.21197891235351562, 0.0, -10.298568725585938), .tilt = 0.7031676769256592 },
    .{ .pos = Vec3.init(21.150728225708008, 0.0, -22.470476150512695), .dir = Vec3.init(-10.55300235748291, 0.0, -0.06367683410644531) },
    .{ .pos = Vec3.init(-0.24440056085586548, 4.444904804229736, -22.27613067626953), .dir = Vec3.init(-8.729326248168945, 0.0, 0.1701068878173828) },
    .{ .pos = Vec3.init(-24.074430465698242, 0.0, -21.877046585083008), .dir = Vec3.init(-14.097784042358398, 0.0, 0.08992767333984375) },
};

fn addTrackPoint(point: Vec3) !void {
    if (track.items.len > 0) {
        const node = &track.items[track.items.len - 1];
        if (node.dir.equals(Vec3.zero()) != 0) {
            node.dir = point.subtract(node.pos);
            return;
        }
    }
    try track.append(.{ .pos = point, .dir = Vec3.zero() });
}

const node_inspector_bounds = rl.Rectangle{ .x = 10, .y = 10, .width = 200, .height = 400 };
const TrackNodeInspector = struct {
    var node_x: [20:0]u8 = undefined;
    var node_y: [20:0]u8 = undefined;
    var node_z: [20:0]u8 = undefined;
    var node_x_edit: bool = false;
    var node_y_edit: bool = false;
    var node_z_edit: bool = false;

    fn select(node: TrackNode) void {
        _ = try std.fmt.bufPrintZ(&node_x, "{d:.2}", .{node.pos.x});
        _ = try std.fmt.bufPrintZ(&node_y, "{d:.2}", .{node.pos.y});
        _ = try std.fmt.bufPrintZ(&node_z, "{d:.2}", .{node.pos.z});
    }

    fn update() void {
        if (track.items.len > 0) {
            const node = &track.items[0];
            _ = gui.guiWindowBox(node_inspector_bounds, "Node");
            if (gui.guiValueBoxFloat(.{ .x = 50, .y = 44, .width = 150, .height = 20 }, "Pos X", &node_x, &node.pos.x, node_x_edit) != 0) node_x_edit = !node_x_edit;
            if (gui.guiValueBoxFloat(.{ .x = 50, .y = 74, .width = 150, .height = 20 }, "Pos Y", &node_y, &node.pos.y, node_y_edit) != 0) node_y_edit = !node_y_edit;
            if (gui.guiValueBoxFloat(.{ .x = 50, .y = 104, .width = 150, .height = 20 }, "Pos Z", &node_z, &node.pos.z, node_z_edit) != 0) node_z_edit = !node_z_edit;
        }
    }
};

fn drawScene(camera: rl.Camera) void {
    rl.beginMode3D(camera);
    defer rl.endMode3D();

    const draw_floor = false;
    if (draw_floor) {
        gl.rlPushMatrix();
        defer gl.rlPopMatrix();

        gl.rlTranslatef(0, -0.1, 0);

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

    track = std.ArrayList(TrackNode).init(allocator);
    try track.appendSlice(&track_data);
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

    try ResourceSystem.loadCarc(allocator, "data/WiiSportsResort/Stage/Static/StageArc.carc");

    var steer: f32 = 0;
    car = Car.init(Vec3.zero());

    var menu_time: f32 = 1000; // @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());

        const mouse_pos = rl.getMousePosition();

        // const gui_focused = gui.guiGetState() == @intFromEnum(gui.GuiState.state_focused);
        const gui_hover = rl.checkCollisionPointRec(mouse_pos, node_inspector_bounds) and false;

        if (rl.isMouseButtonPressed(.mouse_button_left) and !gui_hover) {
            const ray = rl.getScreenToWorldRay(mouse_pos, camera_td);
            const t = -ray.position.y / ray.direction.y;
            const point = ray.position.add(ray.direction.scale(t));
            try addTrackPoint(point);
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

        const max_steering_angle = 0.4 * (1 - @abs(car.speed) / 80.0);
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

        camera.target = car.center().add(Vec3.init(0, 1, 0));
        const camera_position = camera.target.add(Vec3.init(0, 2, -6).rotateByAxisAngle(Vec3.init(0, 1, 0), std.math.degreesToRadians(car.angle())));
        camera.position = camera.position.lerp(camera_position, 0.1);
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

            // gl.rlRotatef(90, 1, 0, 0);
            // defer gl.rlLoadIdentity();

            var prev_node: TrackNode = undefined;
            for (track.items, 0..) |node, i| {
                defer prev_node = node;
                rl.drawSphere(node.pos, 0.5, rl.Color.red);
                if (node.dir.equals(Vec3.zero()) != 0) {
                    break;
                }
                rl.drawSphere(node.pos.add(node.dir), 0.5, rl.Color.blue);
                rl.drawSphere(node.pos.subtract(node.dir), 0.5, rl.Color.blue);
                if (i > 0) {
                    drawTrackSegment(prev_node, node, 10, rl.Color.red.alpha(0.5));
                }
            }
            if (track.items.len > 1 and prev_node.dir.equals(Vec3.zero()) == 0) {
                drawTrackSegment(prev_node, track.items[0], 10, rl.Color.red.alpha(0.5));
            }
        }

        const show_gauges = false;
        if (show_gauges) {
            // gauges
            rl.drawRectangleLines(40, screen_height / 2 - 300, 40, 600, rl.Color.white);
            rl.drawRectangle(40, @intFromFloat(screen_height / 2 - 15 * @max(0, car.speed)), 40, @intFromFloat(15 * @abs(car.speed)), rl.Color.white);
            rl.drawRectangleLines(100, 40, 200, 40, rl.Color.white);
            rl.drawRectangle(@intFromFloat(200 - 100 * @max(0, -steer)), 40, @intFromFloat(100 * @abs(steer)), 40, rl.Color.white);
        }

        var buf: [20]u8 = undefined;
        const kmh_str = try std.fmt.bufPrintZ(&buf, "{d:.0} km/h", .{car.speed / kmph_to_mps});
        const text_width = rl.measureText(kmh_str, 40);
        rl.drawText(kmh_str, screen_width - 20 - text_width, screen_height - 40, 40, rl.Color.white);

        const alpha: f32 = @max(0, @min(1, 1 * (time - menu_time)));
        Menu.draw(alpha);
    }
}

const SPLINE_SEGMENT_DIVISIONS = 24;

fn interpolateCubic(p1: Vec3, c2: Vec3, c3: Vec3, p4: Vec3, t: f32) Vec3 {
    const a = std.math.pow(f32, 1.0 - t, 3);
    const b = 3.0 * std.math.pow(f32, 1.0 - t, 2) * t;
    const c = 3.0 * (1.0 - t) * std.math.pow(f32, t, 2);
    const d = std.math.pow(f32, t, 3);
    return p1.scale(a).add(c2.scale(b)).add(c3.scale(c)).add(p4.scale(d));
}

fn drawTrackSegment(node1: TrackNode, node2: TrackNode, thick: f32, color: rl.Color) void {
    var points: [2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3 = undefined;

    const y_up = Vec3.init(0, 1, 0);

    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.dir);
    const c3 = node2.pos.subtract(node2.dir);
    const p4 = node2.pos;

    var prev_pos: Vec3 = undefined;
    for (0..SPLINE_SEGMENT_DIVISIONS + 1) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / SPLINE_SEGMENT_DIVISIONS;
        const pos = interpolateCubic(p1, c2, c3, p4, t);
        defer prev_pos = pos;
        var dir: Vec3 = undefined;
        if (i == 0) {
            dir = node1.dir.normalize();
        } else if (i == SPLINE_SEGMENT_DIVISIONS) {
            dir = node2.dir.normalize();
        } else {
            dir = pos.subtract(prev_pos).normalize();
        }

        const ease_t = easeInOutQuad(t);
        const tilt = std.math.lerp(node1.tilt, node2.tilt, ease_t);
        const side = y_up.rotateByAxisAngle(dir, 0.5 * std.math.pi - tilt);
        points[2 * i + 0] = pos.add(side.scale(-0.5 * thick));
        points[2 * i + 1] = pos.add(side.scale(0.5 * thick));
    }

    rl.drawTriangleStrip3D(&points, color);
}

fn calcTrackSegmentLength(node1: TrackNode, node2: TrackNode) f32 {
    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.dir);
    const c3 = node2.pos.subtract(node2.dir);
    const p4 = node2.pos;

    // TODO: recursively subdivide and average between coords and control net until convergence

    var length: f32 = 0;
    var prev_pos: Vec3 = undefined;
    for (0..SPLINE_SEGMENT_DIVISIONS + 1) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / SPLINE_SEGMENT_DIVISIONS;
        const pos = interpolateCubic(p1, c2, c3, p4, t);
        defer prev_pos = pos;
        length += pos.subtract(prev_pos).length();
    }

    return length;
}

fn easeInOutQuad(t: f32) f32 {
    return if (t < 0.5) 2 * t * t else 1 - 2 * (1 - t) * (1 - t);
}
