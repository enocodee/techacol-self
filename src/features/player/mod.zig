const std = @import("std");
const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;

const World = eno.ecs.World;
const Transform = common.Transform;

const systems = @import("systems.zig");

pub const MOVEMENT_VELOCITY = 5;

pub const Player = struct {
    health: u32 = 100,
};

pub const SkillAnimationInfo = struct {
    texture: rl.Texture,
    total_frames: u8, // 0..255
    current_frame: u8 = 0,
    /// timestamp of the last rendering (ms)
    last: i64 = 0,
    /// duration rendering between frames (ms)
    duration: u32,

    pub fn init(
        filename: [:0]const u8,
        total_frames: u8,
        duration: u32,
    ) SkillAnimationInfo {
        return .{
            .texture = rl.Texture.init(filename) catch @panic("Loading slash texture failed"),
            .total_frames = total_frames,
            .current_frame = total_frames,
            .duration = duration,
        };
    }

    /// Start to record time of the frame rendering
    pub fn start(self: *SkillAnimationInfo) void {
        self.last = std.time.milliTimestamp();
    }

    /// return `true` if the elapsed time is greater than `duration`
    pub fn tick(self: SkillAnimationInfo) bool {
        return (std.time.milliTimestamp() - self.last) >= self.duration;
    }

    pub fn deinit(self: *const SkillAnimationInfo) void {
        self.texture.unload();
    }
};

pub fn build(w: *World) void {
    _ = w
        .addResource(SkillAnimationInfo, .init(
            "assets/animations/slash_sword/fire_slash.png",
            6,
            30,
        ))
        .addSystem(.system, scheds.startup, spawn)
        .addSystems(
            .system,
            scheds.update,
            &.{
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
        rl.Camera2D{
            .offset = .{
                .x = @floatFromInt(@divTrunc(rl.getScreenWidth(), 2)),
                .y = @floatFromInt(@divTrunc(rl.getScreenHeight(), 2)),
            },
            .target = .{ .x = 50, .y = 50 },
            .rotation = 0,
            .zoom = 2.0,
        },
        try common.Texture2D.fromImage(map_img),
        Transform.fromXYZ(50, 50, 1),
    });
}
