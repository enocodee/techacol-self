const std = @import("std");
const rl = @import("raylib");

const GameAssets = @import("../../GameAssets.zig");
const World = @import("ecs").World;
const Grid = @import("ecs").common.Grid;
const Area = @import("components.zig").Area;

pub fn render(w: *World) !void {
    const assets = try w.getMutResource(GameAssets);
    const queries = try w.query(&.{ Grid, Area });
    const font = try assets.getMainFont();

    for (queries) |query| {
        const grid = query[0]; // get "grid" field

        for (grid.matrix, 0..) |cell, i| {
            rl.drawTextEx(
                font,
                rl.textFormat("%d", .{i}),
                .{
                    .x = @floatFromInt(cell.x + @divTrunc(grid.cell_width, 2) - 5),
                    .y = @floatFromInt(cell.y + @divTrunc(grid.cell_width, 2) - 5),
                },
                @floatFromInt(font.baseSize - 9),
                0,
                .white,
            );
        }
    }
}
