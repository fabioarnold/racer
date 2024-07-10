const rl = @import("raylib");
const Menu = @import("Menu.zig");

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
        Menu.draw(alpha);
    }
}
