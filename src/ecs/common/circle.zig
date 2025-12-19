const std = @import("std");
const rl = @import("raylib");

const World = @import("../World.zig");
const Position = @import("position.zig").Position;

const queryToRender = @import("utils.zig").queryToRender;

pub const Bundle = struct {
    circle: Circle,
    pos: Position,
};

pub const Circle = struct {
    radius: i32,
    color: rl.Color,
};

pub fn render(w: *World, _: std.mem.Allocator) !void {
    const queries = (try queryToRender(w, &.{
        Position,
        Circle,
    })) orelse return;

    for (queries) |query| {
        const pos, const cir = query;
        rl.drawCircle(
            pos.x,
            pos.y,
            @floatFromInt(cir.radius),
            cir.color,
        );
    }
}
