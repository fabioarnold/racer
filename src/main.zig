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
    left_handle: Vec3,
    right_handle: Vec3,
    tilt: f32 = 0,
};

const track_data = [_]TrackNode{
    .{ .pos = Vec3.init(-44.401, -1.393, 1.721), .left_handle = Vec3.init(0.095, -12.898, 0.000), .right_handle = Vec3.init(-0.082, 11.109, 0.000), .tilt = 0.49 },
    .{ .pos = Vec3.init(-22.161, 25.053, 0.000), .left_handle = Vec3.init(-10.460, -0.122, 0.000), .right_handle = Vec3.init(11.109, 0.129, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-0.137, 18.280, 0.000), .left_handle = Vec3.init(-9.759, 0.015, 0.000), .right_handle = Vec3.init(10.365, -0.016, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(25.253, 25.312, 0.000), .left_handle = Vec3.init(-10.451, -0.177, 0.000), .right_handle = Vec3.init(10.577, 0.179, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(39.610, -1.005, 1.852), .left_handle = Vec3.init(0.181, 8.812, 0.000), .right_handle = Vec3.init(-0.212, -10.299, 0.000), .tilt = 0.70 },
    .{ .pos = Vec3.init(21.151, -22.470, 0.000), .left_handle = Vec3.init(9.569, 0.058, 0.000), .right_handle = Vec3.init(-10.553, -0.064, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-0.244, -22.276, 4.445), .left_handle = Vec3.init(7.496, -0.146, 0.000), .right_handle = Vec3.init(-8.729, 0.170, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-24.074, -21.877, 0.000), .left_handle = Vec3.init(11.415, -0.073, 0.000), .right_handle = Vec3.init(-14.098, 0.090, 0.000), .tilt = 0.00 },
};

const SPLINE_SEGMENT_DIVISIONS = 4; //24;

const TrackSegment = struct {
    quads: [SPLINE_SEGMENT_DIVISIONS][4]Vec3,
};

const Track = struct {
    segments: std.ArrayList(TrackSegment),
};

var track: Track = undefined;
fn initTrack(allocator: std.mem.Allocator) !void {
    track.segments = std.ArrayList(TrackSegment).init(allocator);
    for (track_data, 0..) |node1, n| {
        const node2 = track_data[(n + 1) % track_data.len];
        var points: [2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3 = undefined;
        evaluateTrackSegment(node1, node2, 10, &points);
        var segment: TrackSegment = undefined;
        for (&segment.quads, 0..) |*q, i| {
            q[0] = points[2 * i + 0];
            q[1] = points[2 * i + 1];
            q[2] = points[2 * i + 3];
            q[3] = points[2 * i + 2];
        }
        try track.segments.append(segment);
    }
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

        gl.rlTranslatef(0, 0, -0.1);

        gl.rlSetTexture(background_texture.id);
        gl.rlBegin(RL_QUADS);
        gl.rlColor4f(1, 1, 1, 0.2);
        gl.rlTexCoord2f(0, 0);
        gl.rlVertex2f(-100, -100);
        gl.rlTexCoord2f(0, 64);
        gl.rlVertex2f(-100, 100);
        gl.rlTexCoord2f(64, 64);
        gl.rlVertex2f(100, 100);
        gl.rlTexCoord2f(64, 0);
        gl.rlVertex2f(100, -100);
        gl.rlEnd();
        gl.rlSetTexture(0);
    }

    // mirror
    gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_front)));
    rl.drawModelEx(model, car.center(), Vec3.init(0, 0, 1), car.angle(), Vec3.init(1, 1, -1), rl.Color.white);
    gl.rlSetCullFace(@intCast(@intFromEnum(gl.rlCullMode.rl_cull_face_back)));

    rl.drawModelEx(model, car.center(), Vec3.init(0, 0, 1), car.angle(), Vec3.init(1, 1, 1), rl.Color.white);
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
        .position = rl.Vector3.init(0, -10, 5),
        .target = Vec3.zero(),
        .up = rl.Vector3.init(0, 0, 1),
        .fovy = 45,
        .projection = .camera_perspective,
    };
    var camera_td = rl.Camera{
        .position = rl.Vector3.init(0, 0, 20),
        .target = Vec3.zero(),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = .camera_perspective,
    };
    var use_camera_td = true;

    try initTrack(allocator);
    model = rl.loadModel("data/mazda_rx7.glb");
    var model_animations = try rl.loadModelAnimations("data/mazda_rx7.glb");
    // for (model_animations[0].bones[0..@intCast(model_animations[0].boneCount)], 0..) |b, i| {
    //     std.debug.print("b {} {s}\n", .{ i, b.name });
    // }
    const sfx_click = rl.loadSound("data/sfx/click.wav");
    Menu.load();

    const background_image = rl.genImageChecked(64, 64, 32, 32, rl.Color.black.alpha(0.5), rl.Color.gray);
    background_texture = rl.loadTextureFromImage(background_image);
    rl.unloadImage(background_image);

    //try ResourceSystem.loadCarc(allocator, "data/WiiSportsResort/Stage/Static/StageArc.carc");

    var steer: f32 = 0;
    car = Car.init(Vec3.zero());

    var menu_time: f32 = 1000; // @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());

        const mouse_pos = rl.getMousePosition();

        // const gui_focused = gui.guiGetState() == @intFromEnum(gui.GuiState.state_focused);
        // const gui_hover = rl.checkCollisionPointRec(mouse_pos, node_inspector_bounds) and false;

        const ray = rl.getScreenToWorldRay(mouse_pos, if (use_camera_td) camera_td else camera);
        var point_on_track: ?Vec3 = null;
        const result = getRayCollisionTrack(ray);
        if (result.hit) {
            point_on_track = result.point;
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

        // project car onto track
        // TODO: need the surface normals for the orientation
        if (false) {
            const ray_front = rl.Ray{ .position = car.front.add(Vec3.init(0, 0, 100)), .direction = Vec3.init(0, 0, -1) };
            const result_front = getRayCollisionTrack(ray_front);
            if (result_front.hit) {
                const ray_back = rl.Ray{ .position = car.back.add(Vec3.init(0, 0, 100)), .direction = Vec3.init(0, 0, -1) };
                const result_back = getRayCollisionTrack(ray_back);
                if (result_back.hit) {
                    car.front = result_front.point;
                    car.back = result_back.point;
                }
            }
        }

        // update car animation
        const anim = &model_animations[1];
        const wheel_rot = rlm.quaternionFromAxisAngle(Vec3.init(1, 0, 0), car.wheel_angle);
        const wheel_turn = rlm.quaternionFromAxisAngle(Vec3.init(0, 0, 1), car.steering_angle);
        anim.framePoses[0][1].rotation = wheel_turn;
        anim.framePoses[0][2].rotation = rlm.quaternionMultiply(wheel_turn, wheel_rot);
        anim.framePoses[0][3].rotation = wheel_turn;
        anim.framePoses[0][4].rotation = rlm.quaternionMultiply(wheel_turn, wheel_rot);
        anim.framePoses[0][5].rotation = wheel_rot;
        anim.framePoses[0][6].rotation = wheel_rot;
        rl.updateModelAnimation(model, model_animations[1], 0);

        camera.target = car.center().add(Vec3.init(0, 0, 1));
        const camera_position = camera.target.add(Vec3.init(0, 6, 2).rotateByAxisAngle(Vec3.init(0, 0, 1), std.math.degreesToRadians(car.angle())));
        camera.position = camera.position.lerp(camera_position, 0.1);
        camera_td.target = car.center();
        camera_td.position = camera_td.target.add(Vec3.init(0, 0, 100));

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangleGradientV(0, 0, screen_width, screen_height, rl.Color.black, rl.Color.dark_gray);

        drawScene(if (use_camera_td) camera_td else camera);

        const visualize_axles = true;
        if (visualize_axles) {
            rl.beginMode3D(if (use_camera_td) camera_td else camera);
            defer rl.endMode3D();

            gl.rlDisableDepthTest();
            rl.drawSphere(car.front.add(Vec3.init(0, 0, 0)), 0.1, rl.Color.red);
            rl.drawSphere(car.back.add(Vec3.init(0, 0, 0)), 0.1, rl.Color.blue);
        }
        // draw track
        {
            gl.rlEnableWireMode();
            defer gl.rlDisableWireMode();

            rl.beginMode3D(if (use_camera_td) camera_td else camera);
            defer rl.endMode3D();

            for (track_data, 0..) |node, i| {
                rl.drawSphere(node.pos, 0.5, rl.Color.red);
                rl.drawSphere(node.pos.add(node.left_handle), 0.5, rl.Color.blue);
                rl.drawSphere(node.pos.add(node.right_handle), 0.5, rl.Color.blue);
                const next_node = track_data[(i + 1) % track_data.len];
                drawTrackSegment(node, next_node, 10, rl.Color.red.alpha(0.5));
            }

            if (point_on_track) |point| {
                rl.drawSphere(point, 0.5, rl.Color.green);
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

fn getRayCollisionTrack(ray: rl.Ray) rl.RayCollision {
    for (track_data, 0..) |node, i| {
        const next_node = track_data[(i + 1) % track_data.len];
        const result = getRayCollisionTrackSegment(ray, node, next_node);
        if (result.hit) {
            return result;
        }
    }
    var neg_result: rl.RayCollision = undefined;
    neg_result.hit = false;
    return neg_result;
}

fn getRayCollisionTrackSegment(ray: rl.Ray, node1: TrackNode, node2: TrackNode) rl.RayCollision {
    var points: [2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3 = undefined;
    evaluateTrackSegment(node1, node2, 10, &points);

    for (0..SPLINE_SEGMENT_DIVISIONS) |i| {
        const p1 = points[2 * i + 0];
        const p2 = points[2 * i + 1];
        const p3 = points[2 * i + 2];
        const p4 = points[2 * i + 3];
        const result = rl.getRayCollisionQuad(ray, p1, p2, p4, p3); // p3 and p4 swapped because of triangle strips
        if (result.hit) {
            // calculate correct Z height (not based on triangles)
            // const c1 = p1.add(p2).scale(0.5);
            // const c2 = p3.add(p4).scale(0.5);
            // result.point.z = 100;
            return result;
        }
    }
    var neg_result: rl.RayCollision = undefined;
    neg_result.hit = false;
    return neg_result;
}

fn interpolateCubic(p1: Vec3, c2: Vec3, c3: Vec3, p4: Vec3, t: f32) Vec3 {
    const a = std.math.pow(f32, 1.0 - t, 3);
    const b = 3.0 * std.math.pow(f32, 1.0 - t, 2) * t;
    const c = 3.0 * (1.0 - t) * std.math.pow(f32, t, 2);
    const d = std.math.pow(f32, t, 3);
    return p1.scale(a).add(c2.scale(b)).add(c3.scale(c)).add(p4.scale(d));
}

fn evaluateTrackSegment(node1: TrackNode, node2: TrackNode, thick: f32, points: *[2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3) void {
    const z_up = Vec3.init(0, 0, 1);

    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.right_handle);
    const c3 = node2.pos.add(node2.left_handle);
    const p4 = node2.pos;

    for (0..SPLINE_SEGMENT_DIVISIONS + 1) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / SPLINE_SEGMENT_DIVISIONS;
        const pos = interpolateCubic(p1, c2, c3, p4, t);
        var dir: Vec3 = undefined;
        if (i == 0) {
            dir = node1.right_handle.normalize();
        } else if (i == SPLINE_SEGMENT_DIVISIONS) {
            dir = node2.right_handle.normalize();
        } else {
            const next_pos = interpolateCubic(p1, c2, c3, p4, t + 0.01);
            dir = next_pos.subtract(pos).normalize();
        }

        const ease_t = easeInOutQuad(t);
        const tilt = std.math.lerp(node1.tilt, node2.tilt, ease_t);
        const side = z_up.rotateByAxisAngle(dir, 0.5 * std.math.pi + tilt);
        points[2 * i + 0] = pos.add(side.scale(-0.5 * thick));
        points[2 * i + 1] = pos.add(side.scale(0.5 * thick));
    }
}

fn drawTrackSegment(node1: TrackNode, node2: TrackNode, thick: f32, color: rl.Color) void {
    var points: [2 * SPLINE_SEGMENT_DIVISIONS + 2]Vec3 = undefined;
    evaluateTrackSegment(node1, node2, thick, &points);
    rl.drawTriangleStrip3D(&points, color);
}

fn calcTrackSegmentLength(node1: TrackNode, node2: TrackNode) f32 {
    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.right_handle);
    const c3 = node2.pos.add(node2.left_handle);
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
