const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const extra_mods = @import("extra_modules");
const grid_collision = extra_mods.grid_collision;
const health_bar = extra_mods.health_bar;
const mod = @import("mod.zig");

const HitGui = @import("../../gui/mod.zig").Hit;

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const Resource = eno.ecs.query.Resource;
const With = eno.ecs.query.With;
const Transform = common.Transform;

const Health = @import("../general_components.zig").Health;
const Map = @import("../map/mod.zig").Map;
const Monster = @import("../monster/mod.zig").Monster;
const AnimationData = extra_mods.animator.Data;

const VELOCITY = mod.MOVEMENT_VELOCITY;
const Player = mod.Player;
const Skill = mod.Skill;

pub fn updateCam(
    player_q: Query(&.{
        *rl.Camera2D,
        Transform,
        With(&.{Player}),
    }),
) !void {
    const cam, const transform = player_q.single();
    cam.target = .init(@floatFromInt(transform.x), @floatFromInt(transform.y));

    if (rl.isKeyPressed(.equal) and rl.isKeyDown(.left_control))
        cam.zoom += 0.2;
    if (rl.isKeyPressed(.minus) and rl.isKeyDown(.left_control))
        cam.zoom -= 0.2;
}

pub fn movement(
    w: *World,
    player_q: Query(&.{ *Transform, rl.Texture2D, With(&.{Player}) }),
    map_q: Query(&.{ common.InGrid, With(&.{Map}) }),
) !void {
    const player_transform: *Transform = player_q.single()[0];
    const player_tex: rl.Texture2D = player_q.single()[1];

    const map_grid: common.Grid =
        (try w
            .entity(map_q.single()[0].grid_entity)
            .getComponents(&.{common.Grid}))[0];

    if (rl.isKeyDown(.s)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .down,
        )) return;

        player_transform.y += VELOCITY;
    }
    if (rl.isKeyDown(.w)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .up,
        )) return;

        player_transform.y -= VELOCITY;
    }
    if (rl.isKeyDown(.a)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .left,
        )) return;

        player_transform.x -= VELOCITY;
    }
    if (rl.isKeyDown(.d)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .right,
        )) return;

        player_transform.x += VELOCITY;
    }
}

pub fn onAttack(
    w: *World,
    monster_q: Query(&.{
        rl.Texture,
        Transform,
        health_bar.HealthBarTarget,
        With(&.{Monster}),
    }),
    player_q: Query(&.{
        Transform,
        With(&.{Player}),
    }),
    skill_q: Query(&.{
        *Skill,
        *AnimationData,
    }),
) !void {
    if (rl.isKeyPressed(.j)) {
        const p_transform = player_q.single()[0];
        const skill, const animation = skill_q.single();
        if (!skill.doneCooldown()) return;
        skill.start(animation);

        // TODO: enhance by spatial queries
        for (monster_q.many()) |query| {
            _, const m_transform, const hb = query;
            const health: *health_bar.HealthBar =
                (try w
                    .entity(hb.hb_id)
                    .getComponents(&.{*health_bar.HealthBar}))[0];

            if (rl.Vector2.distance(
                .init(
                    @floatFromInt(m_transform.x),
                    @floatFromInt(m_transform.y),
                ),
                .init(
                    @floatFromInt(p_transform.x),
                    @floatFromInt(p_transform.y),
                ),
            ) <= 25) {
                _ = w.spawnEntity(.{
                    try HitGui.init(1000),
                    common.TextBundle{
                        .text = try .initWithDefaultFont(
                            .{ .allocated = try std.fmt.allocPrintSentinel(w.alloc, "{d}", .{10}, 0) },
                            .red,
                            10,
                        ),
                        .transform = .{
                            .x = m_transform.x - 5,
                            .y = m_transform.y - 5,
                            .z = m_transform.z,
                        },
                    },
                });
                health.curr_value -= 10;
            }
        }
    }
}

pub fn onWindowResize(
    player_q: Query(&.{
        *rl.Camera2D,
        With(&.{Player}),
    }),
) !void {
    if (rl.isWindowResized()) {
        const cam = player_q.single()[0];
        cam.offset = .init(
            @floatFromInt(@divTrunc(rl.getScreenWidth(), 2)),
            @floatFromInt(@divTrunc(rl.getScreenHeight(), 2)),
        );
    }
}

pub fn onDespawn(
    w: *World,
    player_q: Query(&.{
        Health,
        eno.ecs.Entity.ID,
        With(&.{Player}),
    }),
) !void {
    const health, const entity_id = player_q.single();
    if (health.current <= 0) try w.entity(entity_id).despawnRecursive();
}
