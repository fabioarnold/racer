const std = @import("std");
const rl = @import("raylib");
const gl = rl.gl;
const rlm = rl.math;
const gui = @import("raygui");
const Vec2 = rl.Vector2;
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

const track_data = [_]Track.Node{
    .{ .pos = Vec3.init(-44.401, -1.393, 1.721), .left_handle = Vec3.init(0.095, -12.898, 0.000), .right_handle = Vec3.init(-0.082, 11.109, 0.000), .tilt = 0.49 },
    .{ .pos = Vec3.init(-22.161, 25.053, 0.000), .left_handle = Vec3.init(-10.460, -0.122, 0.000), .right_handle = Vec3.init(11.109, 0.129, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-0.137, 18.280, 0.000), .left_handle = Vec3.init(-9.759, 0.015, 0.000), .right_handle = Vec3.init(10.365, -0.016, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(25.253, 25.312, 0.000), .left_handle = Vec3.init(-10.451, -0.177, 0.000), .right_handle = Vec3.init(10.577, 0.179, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(39.610, -1.005, 1.852), .left_handle = Vec3.init(0.181, 8.812, 0.000), .right_handle = Vec3.init(-0.212, -10.299, 0.000), .tilt = 0.70 },
    .{ .pos = Vec3.init(21.151, -22.470, 0.000), .left_handle = Vec3.init(9.569, 0.058, 0.000), .right_handle = Vec3.init(-10.553, -0.064, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-0.244, -22.276, 4.445), .left_handle = Vec3.init(7.496, -0.146, 0.000), .right_handle = Vec3.init(-8.729, 0.170, 0.000), .tilt = 0.00 },
    .{ .pos = Vec3.init(-24.074, -21.877, 0.000), .left_handle = Vec3.init(11.415, -0.073, 0.000), .right_handle = Vec3.init(-14.098, 0.090, 0.000), .tilt = 0.00 },
};

const Quad = struct {
    positions: [4]Vec3,
    normals: [4]Vec3,

    fn samplePosition(quad: Quad, u: f32, v: f32) Vec3 {
        const v01 = Vec3.lerp(quad.positions[0], quad.positions[1], u);
        const v23 = Vec3.lerp(quad.positions[3], quad.positions[2], u);
        return Vec3.lerp(v01, v23, v);
    }

    fn sampleNormal(quad: Quad, u: f32, v: f32) Vec3 {
        const v01 = Vec3.lerp(quad.normals[0], quad.normals[1], u);
        const v23 = Vec3.lerp(quad.normals[3], quad.normals[2], u);
        return Vec3.lerp(v01, v23, v);
    }
};

const Track = struct {
    const Node = struct {
        pos: Vec3,
        left_handle: Vec3,
        right_handle: Vec3,
        tilt: f32 = 0,
    };

    const Segment = struct {
        const divisions = 4; //24;
        quads: [divisions]Quad, // CCW order
    };

    const Position = struct {
        segment: usize,
        quad: usize,
    };

    segments: std.ArrayList(Segment),

    fn initFromData(self: *Track, allocator: std.mem.Allocator) !void {
        self.segments = std.ArrayList(Segment).init(allocator);
        for (track_data, 0..) |node1, n| {
            const node2 = track_data[(n + 1) % track_data.len];
            var points: [2 * Segment.divisions + 2]Vec3 = undefined;
            var normals: [Segment.divisions + 1]Vec3 = undefined;
            evaluateTrackSegment(node1, node2, 10, &points, &normals);
            var segment: Segment = undefined;
            for (&segment.quads, 0..) |*q, i| {
                q.positions[0] = points[2 * i + 0];
                q.positions[1] = points[2 * i + 1];
                q.positions[2] = points[2 * i + 3];
                q.positions[3] = points[2 * i + 2];
                q.normals[0] = normals[i + 0];
                q.normals[1] = normals[i + 0];
                q.normals[2] = normals[i + 1];
                q.normals[3] = normals[i + 1];
            }
            try self.segments.append(segment);
        }
    }
};
var track: Track = undefined;

const Player = struct {
    position: Vec3,
    normal: Vec3,
    track_pos: Track.Position,
    angle: f32,
    speed: f32,
};
var player: Player = undefined;

const node_inspector_bounds = rl.Rectangle{ .x = 10, .y = 10, .width = 200, .height = 400 };
const TrackNodeInspector = struct {
    var node_x: [20:0]u8 = undefined;
    var node_y: [20:0]u8 = undefined;
    var node_z: [20:0]u8 = undefined;
    var node_x_edit: bool = false;
    var node_y_edit: bool = false;
    var node_z_edit: bool = false;

    fn select(node: Track.Node) void {
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
        .fovy = 80,
        .projection = .camera_orthographic,
    };
    var use_camera_td = true;

    try track.initFromData(allocator);
    player.position = track.segments.items[0].quads[0].samplePosition(0.5, 0.5);
    player.track_pos = .{ .segment = 0, .quad = 0 };
    player.angle = 0.5 * std.math.pi;
    player.speed = 10;

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
        player.speed = car.speed;

        const max_steering_angle = 0.4 * (1 - @abs(car.speed) / 80.0);
        car.steering_angle = -max_steering_angle * steer;
        // car.integrate(1.0 / 60.0);

        player.angle += -0.04 * steer;
        const player_dir = Vec3.init(@cos(player.angle), @sin(player.angle), 0);
        const player_move = player_dir.scale(player.speed);
        playerSlideMove(player_move.scale(1.0 / 60.0));

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
        {
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
        }

        const camera_target = if (true) player.position else car.center();
        const camera_angle = if (true) player.angle + 0.5 * std.math.pi else std.math.degreesToRadians(car.angle());
        camera.target = camera_target.add(Vec3.init(0, 0, 1));
        const camera_position = camera.target.add(Vec3.init(0, 6, 2).rotateByAxisAngle(Vec3.init(0, 0, 1), camera_angle));
        camera.position = camera.position.lerp(camera_position, 0.1);
        camera_td.target = camera_target;
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
        }

        // debug player visualization
        {
            rl.beginMode3D(if (use_camera_td) camera_td else camera);
            defer rl.endMode3D();

            if (point_on_track) |point| {
                rl.drawSphere(point, 0.5, rl.Color.green);
            }

            {
                const quad = track.segments.items[player.track_pos.segment].quads[player.track_pos.quad];
                rl.drawTriangle3D(quad.positions[0], quad.positions[1], quad.positions[2], rl.Color.blue.alpha(0.5));
                rl.drawTriangle3D(quad.positions[0], quad.positions[2], quad.positions[3], rl.Color.blue.alpha(0.5));
            }

            gl.rlPushMatrix();
            defer gl.rlPopMatrix();
            gl.rlTranslatef(player.position.x, player.position.y, player.position.z);

            rl.drawSphere(Vec3.zero(), 0.2, rl.Color.yellow);
            rl.drawLine3D(Vec3.zero(), player_dir, rl.Color.yellow);
            rl.drawLine3D(Vec3.zero(), player.normal, rl.Color.yellow);

            const z_axis = player.normal;
            const x_axis = Vec3.crossProduct(player_dir, z_axis);
            const y_axis = Vec3.crossProduct(z_axis, x_axis);

            const orientation = rl.Matrix{
                .m0 = x_axis.x,
                .m4 = x_axis.y,
                .m8 = x_axis.z,
                .m12 = 0,
                .m1 = y_axis.x,
                .m5 = y_axis.y,
                .m9 = y_axis.z,
                .m13 = 0,
                .m2 = z_axis.x,
                .m6 = z_axis.y,
                .m10 = z_axis.z,
                .m14 = 0,
                .m3 = player.position.x,
                .m7 = player.position.y,
                .m11 = player.position.z,
                .m15 = 1,
            };
            gl.rlLoadIdentity();
            gl.rlMultMatrixf(@as([*]const f32, @ptrCast(&orientation.m0))[0..16]);
            rl.drawModelEx(model, car.center(), Vec3.init(0, 0, 1), 180, Vec3.init(1, 1, 1), rl.Color.white);

            rl.drawLine3D(Vec3.zero(), x_axis, rl.Color.red);
            rl.drawLine3D(Vec3.zero(), y_axis, rl.Color.green);
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

fn playerSnapToQuad(quad: Quad) void {
    for (0..4) |i| {
        const q0 = quad.positions[i];
        const q1 = quad.positions[(i + 1) % 4];
        const normal = Vec3.init(q0.y - q1.y, q1.x - q0.x, 0).normalize();
        const d = player.position.subtract(q0);
        const dot = d.x * normal.x + d.y * normal.y;
        if (dot < 0.01) {
            player.position = player.position.add(normal.scale(-dot + 0.01));
        }
    }
}

fn playerSlideMove(_move: Vec3) void {
    var move = _move;
    const segment = track.segments.items[player.track_pos.segment];
    const quad = segment.quads[player.track_pos.quad];
    const qp = quad.positions;

    playerSnapToQuad(quad);
    const uv = reverseBilinearInterpolate(player.position.x, player.position.y, qp) catch .{ 0.5, 0.5 };
    player.position = quad.samplePosition(uv[0], uv[1]);
    player.normal = quad.sampleNormal(uv[0], uv[1]);

    var move_forward = false; // are we moving to the next or previous quad
    var t: f32 = 1e6;
    if (intersectRayLineXY(player.position, move, qp[2], qp[3])) |t_forward| {
        move_forward = true;
        t = t_forward;
    } else if (intersectRayLineXY(player.position, move, qp[0], qp[1])) |t_back| {
        move_forward = false;
        t = t_back;
    }

    if (intersectRayLineXY(player.position, move, qp[3], qp[0])) |t_left| {
        if (t_left < t) {
            t = t_left;
            const step = move.scale(@min(1, t));
            player.position = player.position.add(step);
            if (t < 1) {
                move = move.subtract(step);

                // clip move by normal
                var normal = qp[0].subtract(qp[3]);
                normal = Vec3.init(normal.y, -normal.x, 0).normalize();
                const dot = normal.x * move.x + normal.y * move.y;
                move = move.subtract(normal.scale(dot));
                playerSlideMove(move);
            }
            return;
        }
    }

    if (intersectRayLineXY(player.position, move, qp[1], qp[2])) |t_right| {
        if (t_right < t) {
            t = t_right;
            const step = move.scale(@min(1, t));
            player.position = player.position.add(step);
            if (t < 1) {
                move = move.subtract(step);

                // clip move by normal
                var normal = qp[2].subtract(qp[1]);
                normal = Vec3.init(normal.y, -normal.x, 0).normalize();
                const dot = normal.x * move.x + normal.y * move.y;
                move = move.subtract(normal.scale(dot));
                playerSlideMove(move);
            }
            return;
        }
    }

    const step = move.scale(@min(1, t));
    player.position = player.position.add(step);

    if (t < 1) {
        // go to next/previous quad
        if (move_forward) {
            player.track_pos.quad += 1;
            if (player.track_pos.quad == segment.quads.len) {
                player.track_pos.quad = 0;
                player.track_pos.segment += 1;
                if (player.track_pos.segment == track.segments.items.len) {
                    player.track_pos.segment = 0;
                }
            }
        } else {
            if (player.track_pos.quad == 0) {
                player.track_pos.quad = segment.quads.len - 1;
                if (player.track_pos.segment == 0) {
                    player.track_pos.segment = track.segments.items.len - 1;
                } else {
                    player.track_pos.segment -= 1;
                }
            } else {
                player.track_pos.quad -= 1;
            }
        }

        move = move.subtract(step);
        playerSlideMove(move);
    }
}

fn intersectRayLineXY(ro: Vec3, rd: Vec3, l1: Vec3, l2: Vec3) ?f32 {
    const v1 = l1.subtract(ro);
    const v2 = l2.subtract(l1);

    const denom = rd.x * v2.y - rd.y * v2.x;

    if (@abs(denom) < 0.0001) {
        return null; // parallel
    }

    const t = (v1.x * v2.y - v1.y * v2.x) / denom;
    if (t < 0.0001) {
        return null; // behind
    }

    return t;
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

fn getRayCollisionTrackSegment(ray: rl.Ray, node1: Track.Node, node2: Track.Node) rl.RayCollision {
    var points: [2 * Track.Segment.divisions + 2]Vec3 = undefined;
    var normals: [Track.Segment.divisions + 1]Vec3 = undefined;
    evaluateTrackSegment(node1, node2, 10, &points, &normals);

    for (0..Track.Segment.divisions) |i| {
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

fn evaluateTrackSegment(
    node1: Track.Node,
    node2: Track.Node,
    thick: f32,
    points: *[2 * Track.Segment.divisions + 2]Vec3,
    normals: *[Track.Segment.divisions + 1]Vec3,
) void {
    const z_up = Vec3.init(0, 0, 1);

    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.right_handle);
    const c3 = node2.pos.add(node2.left_handle);
    const p4 = node2.pos;

    for (0..Track.Segment.divisions + 1) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / Track.Segment.divisions;
        const pos = interpolateCubic(p1, c2, c3, p4, t);
        var dir: Vec3 = undefined;
        if (i == 0) {
            dir = node1.right_handle.normalize();
        } else if (i == Track.Segment.divisions) {
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
        normals[i] = Vec3.crossProduct(side, dir);
    }
}

fn drawTrackSegment(node1: Track.Node, node2: Track.Node, thick: f32, color: rl.Color) void {
    var points: [2 * Track.Segment.divisions + 2]Vec3 = undefined;
    var normals: [Track.Segment.divisions + 1]Vec3 = undefined;
    evaluateTrackSegment(node1, node2, thick, &points, &normals);
    rl.drawTriangleStrip3D(&points, color);
    const draw_normals = true;
    if (draw_normals) {
        for (normals, 0..) |normal, i| {
            rl.drawLine3D(points[2 * i + 0], points[2 * i + 0].add(normal), rl.Color.yellow);
            rl.drawLine3D(points[2 * i + 1], points[2 * i + 1].add(normal), rl.Color.yellow);
        }
    }
}

fn calcTrackSegmentLength(node1: Track.Node, node2: Track.Node) f32 {
    const p1 = node1.pos;
    const c2 = node1.pos.add(node1.right_handle);
    const c3 = node2.pos.add(node2.left_handle);
    const p4 = node2.pos;

    // TODO: recursively subdivide and average between coords and control net until convergence

    var length: f32 = 0;
    var prev_pos: Vec3 = undefined;
    for (0..Track.Segment.divisions + 1) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / Track.Segment.divisions;
        const pos = interpolateCubic(p1, c2, c3, p4, t);
        defer prev_pos = pos;
        length += pos.subtract(prev_pos).length();
    }

    return length;
}

fn easeInOutQuad(t: f32) f32 {
    return if (t < 0.5) 2 * t * t else 1 - 2 * (1 - t) * (1 - t);
}

fn reverseBilinearInterpolate(x: f32, y: f32, q: [4]Vec3) ![2]f32 {
    const tolerance = 1e-3;
    // Vertices of the quadrilateral
    const x1 = q[0].x;
    const y1 = q[0].y;
    const x2 = q[1].x;
    const y2 = q[1].y;
    const x3 = q[2].x;
    const y3 = q[2].y;
    const x4 = q[3].x;
    const y4 = q[3].y;

    // Initial guess for (u, v)
    var u: f32 = 0.5;
    var v: f32 = 0.5;

    // Iterative method
    const max_iter = 100;
    var iter: usize = 0;
    while (iter < max_iter) : (iter += 1) {
        // Calculate x(u, v) and y(u, v)
        const xu = (1 - u) * (1 - v) * x1 + u * (1 - v) * x2 + u * v * x3 + (1 - u) * v * x4;
        const yv = (1 - u) * (1 - v) * y1 + u * (1 - v) * y2 + u * v * y3 + (1 - u) * v * y4;

        // Calculate the difference
        const dx = xu - x;
        const dy = yv - y;

        // Check if the difference is within the tolerance
        if (@abs(dx) < tolerance and @abs(dy) < tolerance) {
            return .{ u, v };
        }

        // Calculate partial derivatives
        const dxdu = (1 - v) * (x2 - x1) + v * (x3 - x4);
        const dxdv = (1 - u) * (x4 - x1) + u * (x3 - x2);
        const dydu = (1 - v) * (y2 - y1) + v * (y3 - y4);
        const dydv = (1 - u) * (y4 - y1) + u * (y3 - y2);

        // Jacobian matrix determinant
        const detJ = dxdu * dydv - dxdv * dydu;

        if (@abs(detJ) < tolerance) {
            // Jacobian determinant is too small, the method may not converge.
            return error.JacobianDeterminantTooSmall;
        }

        // Newton-Raphson step
        const du = (dydv * dx - dxdv * dy) / detJ;
        const dv = (dxdu * dy - dydu * dx) / detJ;

        u -= du;
        v -= dv;

        // Clamp u and v to [0, 1] to stay within bounds
        u = @min(@max(u, 0), 1);
        v = @min(@max(v, 0), 1);
    }

    // Maximum iterations exceeded, the method did not converge.
    return error.MaximumIterationsExceeded;
}
