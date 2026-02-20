//! # Damge hit animation
//! This can be used with TextBundle to display the dmg
//! or sprite with TextureBundle
const std = @import("std");
const eno = @import("eno");
const ecs = eno.ecs;
const scheds = eno.common.schedules;

const World = ecs.World;
const Query = ecs.query.Query;

pub const Hit = struct {
    timer: std.time.Timer,
    duration: u32, // (ms)

    pub fn init(duration: u32) !Hit {
        return .{
            .timer = try .start(),
            .duration = duration,
        };
    }
};

pub fn build(w: *World) void {
    _ = w.addSystem(.system, scheds.update, onDespawn);
}

pub fn onDespawn(w: *World, hit_q: Query(&.{ *Hit, ecs.Entity.ID })) !void {
    for (hit_q.many()) |query| {
        const hit: *Hit, const entity_id = query;
        if (hit.timer.read() >= hit.duration * std.time.ns_per_ms)
            try w.entity(entity_id).despawn();
    }
}
