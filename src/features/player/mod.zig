const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;
const Health = @import("../general_components.zig").Health;

const World = eno.ecs.World;
const Transform = common.Transform;

const systems = @import("systems.zig");

pub const MOVEMENT_VELOCITY = 2;

pub const Player = struct {};

pub const Skill = struct {
    texture: rl.Texture,
    /// timestamp of the last rendering (ms)
    last: i64 = 0,
    /// duration rendering between frames (ms)
    duration: u32,
    /// cooldown after the last frame is executed (ms)
    cooldown: u32,
    total_frames: u8, // 0..255
    current_frame: u8 = 0,
    is_active: bool = false,

    pub fn init(
        filename: [:0]const u8,
        total_frames: u8,
        duration: u32,
        cooldown: u32,
    ) Skill {
        return .{
            .texture = rl.Texture.init(filename) catch @panic("Loading slash texture failed"),
            .total_frames = total_frames,
            .current_frame = total_frames,
            .duration = duration,
            .cooldown = cooldown,
        };
    }

    /// Start to record time of the frame rendering
    pub fn start(self: *Skill) void {
        self.last = std.time.milliTimestamp();
    }

    /// This function is used to calculate the frame display time.
    ///
    /// return `true` if the elapsed time is greater than `duration`,
    /// which means the next animation frame can be processed.
    ///
    /// Always `true` if the current frame == 0.
    pub fn tickAnimation(self: Skill) bool {
        return (std.time.milliTimestamp() - self.last) >= self.duration;
    }

    pub fn doneCooldown(self: Skill) bool {
        if (!self.is_active) return true;
        return (std.time.milliTimestamp() - self.last) >= self.cooldown;
    }

    pub fn deinit(self: *const Skill) void {
        self.texture.unload();
    }
};

pub fn build(w: *World) void {
    _ = w
        .addResource(Skill, Skill.init(
            "assets/animations/slash_sword/fire_slash.png",
            6,
            30,
            500,
        ))
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
            },
        ).addSystem(.render, eno.render.schedules.process_render, systems.drawSlashAnimation);
}

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/main_char.png");
    _ = w.spawnEntity(&.{
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
    });
}
