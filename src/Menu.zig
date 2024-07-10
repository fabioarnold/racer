const rl = @import("raylib");

const screen_width = 1200;
const screen_height = 720;

var selected_item: i32 = 0;
var selected_item_anim: f32 = 0;

var sfx_move_up: rl.Sound = undefined;
var sfx_move_down: rl.Sound = undefined;

pub fn load() void {
    sfx_move_up = rl.loadSound("data/sfx/mouseclick1.wav");
    sfx_move_down = rl.loadSound("data/sfx/mouserelease1.wav");
}

pub fn handleInput() void {
    if (rl.isKeyPressed(.key_up) and selected_item > 0) {
        selected_item -= 1;
        rl.playSound(sfx_move_up);
    }
    if (rl.isKeyPressed(.key_down) and selected_item < 3) {
        selected_item += 1;
        rl.playSound(sfx_move_down);
    }

    const selected_item_target: f32 = @floatFromInt(selected_item);
    if (selected_item_anim < selected_item_target) selected_item_anim += 1.0 / 8.0;
    if (selected_item_anim > selected_item_target) selected_item_anim -= 1.0 / 8.0;
}

pub fn draw(alpha: f32) void {
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

fn mix(a: f32, b: f32, alpha: f32) f32 {
    return a * (1 - alpha) + b * alpha;
}

fn easeInQuad(x: f32) f32 {
    return x * x;
}

fn easeOutQuad(x: f32) f32 {
    return 1 - easeInQuad(1 - x);
}
