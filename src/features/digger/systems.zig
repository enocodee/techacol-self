const std = @import("std");
const rl = @import("raylib");
const ecs_common = @import("ecs").common;

const World = @import("ecs").World;
const Position = ecs_common.Position;
const Grid = ecs_common.Grid;
const InGrid = ecs_common.InGrid;

const Digger = @import("mod.zig").Digger;

/// Draw all diggers
pub fn updatePos(w: *World) !void {
    const queries = try w.query(&.{ *Position, InGrid, Digger });

    for (queries) |query| {
        const pos, const in_grid, const digger = query;
        const idx_in_grid = digger.idx_in_grid;
        const grid = try w.getComponent(in_grid.grid_entity, Grid);

        const pos_in_px = grid.matrix[@intCast(try grid.getActualIndex(idx_in_grid.r, idx_in_grid.c))];
        pos.x = pos_in_px.x + @divTrunc(grid.cell_width, 2);
        pos.y = pos_in_px.y + @divTrunc(grid.cell_width, 2);
    }
}
