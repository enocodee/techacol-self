const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;

const With = eno.ecs.query.With;
const Query = eno.ecs.query.Query;
const World = eno.ecs.World;
const Transform = common.Transform;

const map = @import("../map/mod.zig");

const Map = map.Map;
const SpawnMap = map.SpawnMap;
const SpawnMonster = eno.ecs.system.Set{ .name = "spawn_monster" };

const NUM_OF_MONSTERS = 10;

pub fn build(w: *World) void {
    _ = w
        .configureSet(
            .system,
            scheds.startup,
            SpawnMonster,
            .{ .after = &.{SpawnMap} },
        )
        .addSystemWithConfig(
        .system,
        scheds.startup,
        spawn,
        .{ .in_sets = &.{SpawnMonster} },
    );
}

fn randomPos(
    x_max: i32,
    y_max: i32,
) !struct { x: i32, y: i32 } {
    var buffer_seed: u8 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&buffer_seed));
    var rand = std.Random.DefaultPrng.init(buffer_seed);

    return .{
        .x = rand.random().intRangeAtMost(i32, 0, x_max),
        .y = rand.random().intRangeAtMost(i32, 0, y_max),
    };
}

fn spawn(
    w: *World,
    map_q: Query(&.{ rl.Texture2D, With(&.{Map}) }),
) !void {
    const map_tex: rl.Texture2D = map_q.single()[0];
    const crab_img = try common.raylib.loadImage("assets/crab.png");

    for (0..NUM_OF_MONSTERS) |_| {
        const pos = try randomPos(map_tex.width, map_tex.height);
        _ = w.spawnEntity(&.{
            try common.Texture2D.fromImage(crab_img),
            Transform.fromXYZ(pos.x, pos.y, 1),
        });
    }
}
