const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const grid_collision = @import("extra_modules").grid_collision;
const health_bar = @import("extra_modules").health_bar;
const mod = @import("mod.zig");

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const Resource = eno.ecs.query.Resource;
const With = eno.ecs.query.With;
const Transform = common.Transform;

const Health = @import("../general_components.zig").Health;
const Map = @import("../map/mod.zig").Map;
const Monster = @import("../monster/mod.zig").Monster;

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
    skill_res: Resource(*Skill),
    monster_q: Query(&.{
        rl.Texture,
        Transform,
        health_bar.HealthBarTarget,
        With(&.{Monster}),
    }),
    player_q: Query(&.{
        rl.Texture,
        Transform,
        With(&.{Player}),
    }),
) !void {
    if (rl.isKeyPressed(.j)) {
        const p_tex, const p_transform = player_q.single();
        const skill = skill_res.result;
        if (!skill.doneCooldown()) return;

        skill.current_frame = 0;

        const p_center_x: f32 = @floatFromInt(p_transform.x + @divTrunc(p_tex.width, 2));
        const p_center_y: f32 = @floatFromInt(p_transform.y + @divTrunc(p_tex.height, 2));

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
                .init(p_center_x, p_center_y),
            ) <= 25) {
                health.curr_value -= 10;
            }
        }
    }
}

pub fn drawSlashAnimation(
    skill_res: Resource(*Skill),
    player_q: Query(&.{ Transform, With(&.{Player}) }),
) !void {
    const skill = skill_res.result;
    if (skill.current_frame == skill.total_frames) {
        skill.is_active = false;
        return;
    } else if (skill.current_frame == 0)
        skill.is_active = true;

    const player_transform = player_q.single()[0];
    const frame_width: f32 = @floatFromInt(@divTrunc(skill.texture.width, 6));
    const frame_height: f32 = @floatFromInt(@divTrunc(skill.texture.height, 5));
    const scale_factor = 0.7;

    var origin_frame_rec: rl.Rectangle = .{
        .x = 0,
        .y = frame_height * 1,
        .width = frame_width,
        .height = frame_height,
    };
    const scaled_frame_rec: rl.Rectangle = .{
        .x = 0,
        .y = 0,
        .width = frame_width * scale_factor,
        .height = frame_height * scale_factor,
    };
    origin_frame_rec.x = @as(f32, @floatFromInt(skill.current_frame)) * frame_width;

    skill.texture.drawPro(
        origin_frame_rec,
        scaled_frame_rec,
        .init(
            @floatFromInt(-player_transform.x + 25),
            @floatFromInt(-player_transform.y + 35),
        ),
        0,
        .white,
    );

    if (skill.tickAnimation()) {
        skill.start();
        skill.current_frame += 1;
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

