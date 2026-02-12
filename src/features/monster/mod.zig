const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;
const grid_collision = @import("extra_modules").grid_collision;

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

const Monster = struct {
    direction: Direction = .up,

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
const NUM_OF_MONSTERS = 10;
const VELOCITY = 5;

pub fn build(w: *World) void {
    _ = w
        .configureSet(
            .system,
            scheds.startup,
            SpawnMonster,
            .{ .after = &.{SpawnMap} },
        )
        .addSystemWithConfig(.system, scheds.startup, spawn, .{ .in_sets = &.{SpawnMonster} })
        .addSystem(.system, scheds.update, movement);
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
        const pos = try randomPos(map_tex.width, map_tex.height);

        try w.spawnEntity(&.{
            try common.Texture2D.fromImage(crab_img),
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

// TODO:
fn movement(
    w: *World,
    monster_q: Query(&.{ *Transform, rl.Texture2D, *Monster }),
    map_q: Query(&.{ common.InGrid, With(&.{Map}) }),
) !void {
    for (monster_q.many()) |query| {
        const monster_transform: *Transform = query[0];
        const monster_tex: rl.Texture2D = query[1];
        const monster: *Monster = query[2];

        const map_grid: common.Grid =
            (try w
                .entity(map_q.single()[0].grid_entity)
                .getComponents(&.{common.Grid}))[0];

        switch (monster.direction) {
            .up => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .up,
                )) {
                    monster.direction = try randomToggleDirection(.up);
                    continue;
                }
                monster_transform.y -= VELOCITY;
            },
            .up_left => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .up,
                ) or try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .left,
                )) {
                    monster.direction = try randomToggleDirection(.up_left);
                    continue;
                }
                monster_transform.x -= VELOCITY;
                monster_transform.y -= VELOCITY;
            },
            .up_right => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .up,
                ) or try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .right,
                )) {
                    monster.direction = try randomToggleDirection(.up_left);
                    continue;
                }
                monster_transform.x += VELOCITY;
                monster_transform.y -= VELOCITY;
            },
            .down => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .down,
                )) {
                    monster.direction = try randomToggleDirection(.down);
                    continue;
                }
                monster_transform.y += VELOCITY;
            },
            .down_left => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .down,
                ) or try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .left,
                )) {
                    monster.direction = try randomToggleDirection(.down_left);
                    continue;
                }
                monster_transform.x -= VELOCITY;
                monster_transform.y += VELOCITY;
            },
            .down_right => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .down,
                ) or try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .right,
                )) {
                    monster.direction = try randomToggleDirection(.down_right);
                    continue;
                }
                monster_transform.x -= VELOCITY;
                monster_transform.y -= VELOCITY;
            },
            .left => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .left,
                )) {
                    monster.direction = try randomToggleDirection(.left);
                    continue;
                }
                monster_transform.x -= VELOCITY;
            },
            .right => {
                if (try grid_collision.getDirectedBlock(
                    monster_tex,
                    monster_transform.*,
                    map_grid,
                    .right,
                )) {
                    monster.direction = try randomToggleDirection(.right);
                    continue;
                }
                monster_transform.x += VELOCITY;
            },
        }
    }
}

fn randomToggleDirection(curr_direction: Monster.Direction) !Monster.Direction {
    var buffer_seed: u8 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&buffer_seed));
    var rand = std.Random.DefaultPrng.init(buffer_seed);

    while (true) {
        const idx = rand.random().intRangeAtMost(usize, 0, 7);
        if (idx != @intFromEnum(curr_direction)) return @enumFromInt(idx);
    }
}
