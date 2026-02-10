const std = @import("std");
const eno = @import("eno");
const ecs = eno.ecs;
const common = eno.common;
const scheds = common.schedules;

const World = ecs.World;
const Query = ecs.query.Query;
const Transform = common.Transform;

/// This component should be spawned as a separate
/// entity with the owner.
///
/// See `HealthBarTarget` for details about attaching
/// to the owner.
///
/// # Usage example:
/// ```zig
/// const Player = struct {};
///
/// world.spawnEntity(&.{
///     Player {},
///     HealthBarTarget,
/// });
/// ```
pub const HealthBar = struct {
    max_value: i32,
    curr_value: i32,

    pub fn init(max_value: i32) HealthBar {
        return .{
            .max_value = max_value,
            .curr_value = max_value,
        };
    }
};

/// The entity which uses `HealthBar` component must be
/// spawned with this component to determine who owns the
/// health bar.
pub const HealthBarTarget = struct {
    hb_id: ecs.Entity.ID,
};

pub const Offset = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Offset {
        return .{ .x = x, .y = y };
    }
};

pub const HealthBarBundle = struct {
    health_bar: HealthBar,
    offset: Offset,
    text_bundle: common.TextBundle,

    pub fn init(
        alloc: std.mem.Allocator,
        max_value: i32,
        /// offset from the attached entity
        offset: Offset,
    ) !HealthBarBundle {
        return .{
            .health_bar = .init(max_value),
            .offset = offset,
            .text_bundle = .{
                .text = try .initWithDefaultFont(
                    .{ .allocated = try alloc.allocSentinel(u8, 10, 0) },
                    .black,
                    10,
                ),
                .transform = .{},
            },
        };
    }
};

pub fn build(w: *World) void {
    _ = w.addSystems(.system, scheds.update, .{ updateDisplay, updatePos });
}

fn updateDisplay(hb_q: Query(&.{ HealthBar, *common.Text })) !void {
    for (hb_q.many()) |query| {
        const hb, var text = query;
        var buf: [10]u8 = undefined;
        const fmt = try std.fmt.bufPrintZ(
            &buf,
            "{d}/{d}",
            .{ hb.curr_value, hb.max_value },
        );

        std.debug.assert(fmt.len < text.content.allocated.len);
        @memset(@constCast(text.content.allocated), 0);
        @memcpy(@constCast(text.content.allocated[0..fmt.len]), fmt);
    }
}

fn updatePos(
    w: *World,
    /// all entites who are holding `HealthBarTarget`
    target_q: Query(&.{ Transform, HealthBarTarget }),
) !void {
    for (target_q.many()) |target| {
        const target_transform, const hb_target: HealthBarTarget = target;
        const transform: *Transform, const offset =
            try w
                .entity(hb_target.hb_id)
                .getComponents(&.{ *Transform, Offset });

        transform.* = .fromXYZ(
            target_transform.x - offset.x,
            target_transform.y - offset.y,
            target_transform.z,
        );
    }
}
