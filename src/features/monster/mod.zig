const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;

const With = eno.ecs.query.With;
const Query = eno.ecs.query.Query;
const World = eno.ecs.World;
const Transform = common.Transform;

const health_bar = @import("extra_modules").health_bar;
const HealthBarBundle = health_bar.HealthBarBundle;
const HealthBarTarget = health_bar.HealthBarTarget;

const map = @import("../map/mod.zig");

const Map = map.Map;
const SpawnMap = map.SpawnMap;
const SpawnMonster = eno.ecs.system.Set{ .name = "spawn_monster" };

const systems = @import("systems.zig");

pub const Monster = struct {
    direction: Direction = .up,
    is_following_player: bool = false,

    pub const Direction = enum {
        up,
        up_left,
        up_right,
        down,
        down_left,
        down_right,
        left,
        right,
    };
};
pub const VELOCITY = 1;
pub const FOLLOW_RANGE = 100;

const NUM_OF_MONSTERS = 10;

pub fn build(w: *World) void {
    _ = w
        .configureSet(
            .system,
            scheds.startup,
            SpawnMonster,
            .{ .after = &.{SpawnMap} },
        )
        .addSystemWithConfig(.system, scheds.startup, spawn, .{ .in_sets = &.{SpawnMonster} })
        .addSystems(
        .system,
        scheds.update,
        .{
            systems.onDespawn,
            systems.movement,
            systems.onAttack,
            systems.onFollowPlayer,
        },
    );
}

fn randomPos(
    x_max: i32,
    y_max: i32,
) !struct { x: i32, y: i32 } {
    // SAFETY: assigned in getrandom()
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
        const pos = try randomPos(
            map_tex.width - @divTrunc(map_tex.width, 2),
            map_tex.height - @divTrunc(map_tex.height, 2),
        );

        try w.spawnEntity(&.{
            try rl.Texture2D.fromImage(crab_img),
            Transform.fromXYZ(pos.x, pos.y, 1),
            Monster{},
        }).withChildren(struct {
            pub fn cb(parent: eno.ecs.Entity) !void {
                const entity = parent.spawn(&.{
                    try HealthBarBundle.init(parent.world.alloc, 100, .init(10, 10)),
                });

                _ = parent.setComponent(HealthBarTarget, .{ .hb_id = entity.id });
            }
        }.cb);
    }
}
