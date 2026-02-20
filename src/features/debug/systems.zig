const std = @import("std");
const ecs = @import("eno").ecs;
const components = @import("components.zig");

const Query = ecs.query.Query;
const DebugBox = components.DebugBox;
const DebugInfo = components.DebugInfo;

pub fn updateInfo(
    queries: Query(&.{*DebugInfo}),
) !void {
    const info = queries.single()[0];

    const rusage = std.posix.getrusage(0);
    info.* = .{
        .memory_usage = @as(i32, @intCast(rusage.maxrss)),
    };
}

pub fn render(queries: Query(&.{ DebugBox, DebugInfo })) !void {
    for (queries.many()) |q| {
        const box, const info = q;

        box.draw(&.{
            "Memory usage",
        }, .{
            info.memory_usage,
        });
    }
}
