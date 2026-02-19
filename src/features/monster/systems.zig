const std = @import("std");
const eno = @import("eno");
const mod = @import("mod.zig");
const common = eno.common;
const rl = common.raylib;
const grid_collision = @import("extra_modules").grid_collision;
const health_bar = @import("extra_modules").health_bar;
const map = @import("../map/mod.zig");

const With = eno.ecs.query.With;
const Query = eno.ecs.query.Query;
const World = eno.ecs.World;
const Transform = common.Transform;
const Health = @import("../general_components.zig").Health;

const Player = @import("../player/mod.zig").Player;
const Map = map.Map;
const Monster = mod.Monster;
const VELOCITY = mod.VELOCITY;
const FOLLOW_RANGE = mod.FOLLOW_RANGE;

// TODO: add .follow_player
pub fn movement(
    w: *World,
    monster_q: Query(&.{ *Transform, rl.Texture2D, *Monster }),
    map_q: Query(&.{ common.InGrid, With(&.{Map}) }),
) !void {
    for (monster_q.many()) |query| {
        const monster_transform: *Transform = query[0];
        const monster_tex: rl.Texture2D = query[1];
        const monster: *Monster = query[2];
        if (monster.is_following_player) continue;

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

pub fn onDespawn(
    w: *World,
    monster_q: Query(&.{
        health_bar.HealthBarTarget,
        eno.ecs.Entity.ID,
        With(&.{Monster}),
    }),
) !void {
    for (monster_q.many()) |query| {
        const target, const entity_id = query;
        const health: health_bar.HealthBar =
            (try w
                .entity(target.hb_id)
                .getComponents(&.{health_bar.HealthBar}))[0];

        if (health.curr_value <= 0) try w.entity(entity_id).despawnRecursive();
    }
}

pub fn onAttack(
    monster_q: Query(&.{ Transform, With(&.{Monster}) }),
    player_q: Query(&.{ Transform, *Health, With(&.{Player}) }),
) !void {
    const p_transform, const p_health = player_q.single();

    for (monster_q.many()) |query| {
        const m_transform = query[0];

        if (rl.Vector2.distance(
            .init(@floatFromInt(p_transform.x), @floatFromInt(p_transform.y)),
            .init(@floatFromInt(m_transform.x), @floatFromInt(m_transform.y)),
        ) < 20) {
            p_health.current -= 5;
        }
    }
}

pub fn onFollowPlayer(
    monster_q: Query(&.{ *Transform, *Monster }),
    player_q: Query(&.{ Transform, With(&.{Player}) }),
) !void {
    const p_transform = player_q.single()[0];
    for (monster_q.many()) |query| {
        const m_transform, const monster_info = query;
        monster_info.is_following_player = shouldFollow(p_transform, m_transform.*);

        if (monster_info.is_following_player) {
            const norm_vec =
                rl.Vector2
                    .init(
                        @floatFromInt(p_transform.x - m_transform.x),
                        @floatFromInt(p_transform.y - m_transform.y),
                    ).normalize();

            m_transform.x += @intFromFloat(norm_vec.x * 2);
            m_transform.y += @intFromFloat(norm_vec.y * 2);
        }
    }
}

fn shouldFollow(player_transform: Transform, monster_transform: Transform) bool {
    return rl.Vector2.distance(
        .init(@floatFromInt(player_transform.x), @floatFromInt(player_transform.y)),
        .init(@floatFromInt(monster_transform.x), @floatFromInt(monster_transform.y)),
    ) < FOLLOW_RANGE;
}
