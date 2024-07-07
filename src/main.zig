const rl = @import("raylib");

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
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = .camera_perspective,
    };

    const model = rl.loadModel("data/mazda_rx7.glb");
    const sfx_move_up = rl.loadSound("data/sfx/mouseclick1.wav");
    const sfx_move_down = rl.loadSound("data/sfx/mouserelease1.wav");
    const sfx_click = rl.loadSound("data/sfx/click.wav");

    rl.setTargetFPS(60);

    var selected_item: i32 = 0;
    var selected_item_anim: f32 = 0;

    var menu_time: f32 = 1000;// @floatCast(rl.getTime());

    while (!rl.windowShouldClose()) {
        const time: f32 = @floatCast(rl.getTime());
        camera.position.x = 10 * @sin(time);
        camera.position.z = 10 * @cos(time);

        if (rl.isKeyPressed(.key_up) and selected_item > 0) {
            selected_item -= 1;
            rl.playSound(sfx_move_up);
        }
        if (rl.isKeyPressed(.key_down) and selected_item < 3) {
            selected_item += 1;
            rl.playSound(sfx_move_down);
        }
        if (rl.isKeyPressed(.key_enter)) {
            menu_time = time;
            rl.playSound(sfx_click);
        }

        const selected_item_target: f32 = @floatFromInt(selected_item);
        if (selected_item_anim < selected_item_target) selected_item_anim += 1.0 / 8.0;
        if (selected_item_anim > selected_item_target) selected_item_anim -= 1.0 / 8.0;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);
        rl.drawRectangleGradientV(0, 0, screen_width, screen_height, rl.Color.black, rl.Color.dark_gray);

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();

            rl.drawGrid(10, 1);

            rl.drawModel(model, rl.Vector3.init(0, 0, 0), 0.01, rl.Color.white);
        }

        const alpha: f32 = @max(0, @min(1, 1 * (time - menu_time)));
        {
            // draw frame
            const s = 60;
            const lw = 2;
            const alpha_frame = easeOutQuad(@min(1, 2 * alpha));
            const cross_x: i32 = @intFromFloat(mix(screen_width, s, alpha_frame));
            const cross_y: i32 = @intFromFloat(mix(0, screen_height - 2 * s, alpha_frame));
            var color = rl.Color.gray;
            rl.drawRectangle(0, cross_y, screen_width, lw, color);
            rl.drawRectangle(cross_x, 0, lw, screen_height, color);
            const corner_x = screen_width - s;
            const corner_y = s;
            if (cross_x < corner_x and cross_y > corner_y) {
                rl.drawRectangle(cross_x, corner_y, corner_x - cross_x, lw, color);
                rl.drawRectangle(corner_x, corner_y, lw, cross_y - corner_y, color);
                const bar: i32 = @intFromFloat(mix(0.25 * s, s, alpha_frame));
                rl.drawRectangle(cross_x + bar, corner_y, lw, cross_y - corner_y, color);
                color = rl.Color.light_gray;
                color.a = 40;
                rl.drawRectangle(cross_x + lw, corner_y + lw, bar - lw, cross_y - corner_y - lw, color);
            }

            // menu text
            const alpha_text: f32 = easeInQuad(@max(0, @min(1, 2 * (alpha - 0.3))));
            const a_active = alpha_text * 255;
            const a_inactive = alpha_text * 160;

            color = rl.Color.light_gray;
            color.a = @intFromFloat(a_active);
            rl.drawRectangle(s + 30, s + 40 + 12 + @as(i32, @intFromFloat(selected_item_anim * 40)), 30, 20, color);
            color.a = @intFromFloat(mix(a_active, a_inactive, @min(1, @abs(selected_item_anim - 0))));
            rl.drawText("new game", 2 * s + 20, s + 40, 40, color);
            color.a = @intFromFloat(mix(a_active, a_inactive, @min(1, @abs(selected_item_anim - 1))));
            rl.drawText("load game", 2 * s + 20, s + 80, 40, color);
            color.a = @intFromFloat(mix(a_active, a_inactive, @min(1, @abs(selected_item_anim - 2))));
            rl.drawText("options", 2 * s + 20, s + 120, 40, color);
            color.a = @intFromFloat(mix(a_active, a_inactive, @min(1, @abs(selected_item_anim - 3))));
            rl.drawText("quit", 2 * s + 20, s + 160, 40, color);
        }
    }
}

fn mix(a: f32, b: f32, alpha: f32) f32 {
    return a * (1 - alpha) + b * alpha;
}

fn easeInQuad(x: f32) f32 {
    return x * x;
}

fn easeOutQuad(x: f32) f32 {
    return 1 - easeInQuad(1 - x);
}
