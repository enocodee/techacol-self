const std = @import("std");
const schedules = @import("eno").common.schedules;
const eno = @import("eno");
const ecs = eno.ecs;
const rl = eno.common.raylib;
const extra_mods = @import("extra_modules");

const debug_mod = @import("features/debug/mod.zig");
const map_mod = @import("features/map/mod.zig");
const player_mod = @import("features/player/mod.zig");
const monster_mod = @import("features/monster/mod.zig");
const gui_mod = @import("gui/mod.zig");

const World = ecs.World;
const GameAssets = @import("GameAssets.zig");

fn closeWindow(w: *World) !void {
    if (eno.window.shouldClose()) {
        w.should_exit = true;
    }
}

fn loop(alloc: std.mem.Allocator) !void {
    var world: World = .init(alloc);
    defer world.deinit();

    rl.setTargetFPS(60);

    try world
        .addModules(&.{
            eno.common.CommonModule,
            extra_mods.health_bar,
        })
        .addResource(GameAssets, .{})
        .addSystems(.system, schedules.update, &.{closeWindow})
        .addModules(&.{
            monster_mod,
            map_mod,
            player_mod,
            debug_mod,
            gui_mod,
        })
        .run();
}

pub fn main() !void {
    var base_alloc = std.heap.DebugAllocator(.{}).init;
    defer {
        if (base_alloc.deinit() == .leak) @panic("Leak memory have been detected!");
    }
    const alloc = base_alloc.allocator();

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Digger Replace");
    defer rl.closeWindow();

    try loop(alloc);
}

test {
    std.testing.refAllDecls(@This());
}
