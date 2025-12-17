const std = @import("std");
const rl = @import("raylib");

const World = @import("World.zig");

const position = @import("common/position.zig");
const grid = @import("common/grid/mod.zig");
const button = @import("common/button.zig");

// Shape components
const rectangle = @import("common/rectangle.zig");
const circle = @import("common/circle.zig");

pub const Position = position.Position;
pub const Rectangle = rectangle.Rectangle;
pub const Grid = grid.Grid;
pub const InGrid = grid.InGrid;
pub const Button = button.Button;
pub const Circle = circle.Circle;

pub const ButtonBundle = button.Bundle;
pub const CircleBundle = circle.Bundle;

pub const CommonModule = struct {
    pub fn build(w: *World) void {
        _ = w.addSystems(.update, &.{
            rectangle.render,
            button.render,
            grid.render,
            circle.render,
        });
    }
};
