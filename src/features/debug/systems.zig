const std = @import("std");
const rl = @import("raylib");
const components = @import("components.zig");

const World = @import("ecs").World;
const Position = @import("ecs").common.Position;
const Score = @import("../score/mod.zig").Score;
const DebugBox = components.DebugBox;
const DebugInfo = components.DebugInfo;

pub fn updateInfo(w: *World) !void {
    const query = (try w.query(&.{*DebugInfo}))[0];
    const score = try w.getResource(Score);
    const info = query[0];

    const rusage = std.posix.getrusage(0);
    info.* = .{
        .memory_usage = @as(i32, @intCast(rusage.maxrss)),
        .score = score.amount,
    };
}

pub fn render(w: *World) !void {
    const queries = try w.query(&.{ DebugBox, DebugInfo });

    for (queries) |q| {
        const box, const info = q;

        box.draw(&.{
            "Memory usage",
            "Score",
        }, .{
            info.memory_usage,
            info.score,
        });
    }
}
