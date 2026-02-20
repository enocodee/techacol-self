//! This module handle animation processes.
//!
//! # Features
//! * Load a animation from an image.
const std = @import("std");
const eno = @import("eno");
const ecs = eno.ecs;
const common = eno.common;
const rl = eno.common.raylib;
const render_scheds = eno.render.schedules;

const World = ecs.World;
const Query = ecs.query.Query;
const Transform = common.Transform;

pub const Bundle = struct {
    data: Data,
    transform: Transform,
};

/// A component is attached to an entity that
/// need animations.
pub const Data = struct {
    texture: rl.Texture,
    scale: f32, // range from 0..1
    /// timestamp of the last rendering (ms)
    last: i64 = 0,
    /// duration rendering between frames (ms)
    duration_per_frame: u32,
    /// cooldown after the last frame is executed (ms)
    total_frames: u8, // 0..255
    // Number of animations in the texture
    num_of_animations: u8,
    current_frame: u8,

    /// This function can cause to panic due to invalid texture
    pub fn init(
        filename: [:0]const u8,
        scale: f32,
        total_frames: u8,
        num_of_animations: u8,
        duration: u32,
    ) Data {
        return .{
            .texture = rl.Texture.init(filename) catch @panic("Loading the animation texture failed"),
            .scale = scale,
            .total_frames = total_frames,
            .num_of_animations = num_of_animations,
            .current_frame = total_frames,
            .duration_per_frame = duration,
        };
    }

    /// Start to process the animation
    pub fn start(self: *Data) void {
        self.last = std.time.milliTimestamp();
        self.current_frame = 0;
    }

    /// The current frame index will be increased for 1 if `current_ts - last_ts`
    /// greater than `duration` and must be used when the animation is activated,
    /// otherwise, it will do nothing.
    pub fn tickAnimation(self: *Data) void {
        if (self.current_frame == self.total_frames) return;
        if (std.time.milliTimestamp() - self.last >= self.duration_per_frame) {
            self.last = std.time.milliTimestamp();
            self.current_frame += 1;
        }
    }

    pub fn isActive(self: Data) bool {
        return self.current_frame < self.total_frames;
    }

    pub fn deinit(self: *const Data, _: std.mem.Allocator) void {
        self.texture.unload();
    }
};

pub fn build(w: *World) void {
    _ = w.addSystem(.render, render_scheds.process_render, draw);
}

pub fn draw(anim_data: Query(&.{ *Data, Transform })) !void {
    for (anim_data.many()) |query| {
        const data: *Data, const transform: Transform = query;
        if (!data.isActive()) continue;

        const frame_width: f32 = @floatFromInt(@divTrunc(data.texture.width, data.total_frames));
        const frame_height: f32 = @floatFromInt(@divTrunc(data.texture.height, data.num_of_animations));

        const origin_frame_rec: rl.Rectangle = .{
            // x in img
            .x = @as(f32, @floatFromInt(data.current_frame)) * frame_width,
            // y in img
            .y = frame_height * 1,
            .width = frame_width,
            .height = frame_height,
        };

        const scaled_frame_rec: rl.Rectangle = .{
            // x in the game world
            .x = @as(f32, @floatFromInt(transform.x)) - (frame_width * data.scale) / 2,
            // y in the game world
            .y = @as(f32, @floatFromInt(transform.y)) - (frame_height * data.scale) / 2,
            .width = frame_width * data.scale,
            .height = frame_height * data.scale,
        };

        data.texture.drawPro(
            origin_frame_rec,
            scaled_frame_rec,
            .init(0, 0),
            0,
            .white,
        );

        data.tickAnimation();
    }
}
