const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;
const systems = @import("systems.zig");
const animator = @import("extra_modules").animator;

const Health = @import("../general_components.zig").Health;
const AnimationBundle = animator.Bundle;
const AnimationaData = animator.Data;

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const ChildOf = eno.ecs.hierarchy.ChildOf;
const Transform = common.Transform;

pub const MOVEMENT_VELOCITY = 2;

pub const Player = struct {};

// TODO: trigger skills via events?
// refer to (https://bevy-cheatbook.github.io/programming/events.html)
pub const Skill = struct {
    last: i64 = 0,
    /// cooldown after the last frame is executed (ms)
    cooldown: u32,
    is_active: bool = false,
    attachable: union(enum) {
        no,
        yes: struct {
            offset_x: i32,
            offset_y: i32,
        },
    },

    /// Start to record time of the frame rendering
    pub fn start(self: *Skill, animation: *AnimationaData) void {
        self.last = std.time.milliTimestamp();
        self.is_active = true;
        animation.start();
    }

    pub fn doneCooldown(self: Skill) bool {
        if (!self.is_active) return true;
        return (std.time.milliTimestamp() - self.last) >= self.cooldown;
    }

    /// The skill animation will be follow the target (parent)
    pub fn onFollowTarget(
        w: *World,
        skill_q: Query(&.{ Skill, *Transform, ChildOf }),
    ) !void {
        for (skill_q.many()) |query| {
            const skill: Skill, const transform: *Transform, const child_of: ChildOf = query;
            if (skill.attachable == .no) return;
            const parent_transform =
                (try w
                    .entity(child_of.parent_id)
                    .getComponents(&.{Transform}))[0];

            transform.* = parent_transform;
        }
    }
};

pub fn build(w: *World) void {
    _ = w
        .addSystem(.system, scheds.startup, spawn)
        .addSystems(
        .system,
        scheds.update,
        &.{
            systems.onDespawn,
            systems.movement,
            systems.updateCam,
            systems.onWindowResize,
            systems.onAttack,
            Skill.onFollowTarget,
        },
    );
}

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/main_char.png");

    try w.spawnEntity(&.{
        Player{},
        Health.init(100),
        rl.Camera2D{
            .offset = .{
                .x = @floatFromInt(@divTrunc(rl.getScreenWidth(), 2)),
                .y = @floatFromInt(@divTrunc(rl.getScreenHeight(), 2)),
            },
            .target = .{ .x = 50, .y = 50 },
            .rotation = 0,
            .zoom = 2.0,
        },
        try rl.Texture2D.fromImage(map_img),
        Transform.fromXYZ(50, 50, 1),
    }).withChildren(struct {
        pub fn cb(parent: eno.ecs.Entity) !void {
            const transform = (try parent.getComponents(&.{Transform}))[0];

            _ = parent.spawn(&.{
                Skill{
                    .cooldown = 500,
                    .attachable = .{
                        .yes = .{
                            .offset_x = 0,
                            .offset_y = 0,
                        },
                    },
                },
                AnimationBundle{
                    .data = .init("assets/animations/slash_sword/fire_slash.png", 0.7, 6, 5, 40),
                    .transform = transform,
                },
            });
        }
    }.cb);
}
