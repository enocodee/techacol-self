const std = @import("std");
const rl = @import("raylib");

const digger = @import("../digger/mod.zig");
const utils = @import("utils.zig");

const World = @import("ecs").World;
const Grid = @import("ecs").common.Grid;
const Command = @import("../interpreter/command.zig").Command;
const State = @import("resources.zig").State;
const Style = @import("resources.zig").Style;

const QueryError = @import("ecs").World.QueryError;

pub const Terminal = struct {};

pub const Buffer = struct {
    // TODO: enhance the way to store `lines`
    // HACK: :)) this is very inefficent
    lines: Lines,
    cursor: struct {
        row: usize = 0,
        col: usize = 0,
    } = .{},
    total_line: usize = 1,

    const Lines = std.ArrayList(std.ArrayList(u8));

    pub fn init(alloc: std.mem.Allocator) !Buffer {
        var lines: Lines = .empty;
        // init the first line
        try lines.append(alloc, .empty);

        return .{
            .lines = lines,
        };
    }

    pub fn deinit(self: *Buffer, alloc: std.mem.Allocator) void {
        for (self.lines.items) |*line| {
            line.deinit(alloc);
        }
        self.lines.deinit(alloc);
    }

    pub fn draw(self: Buffer, grid: Grid, style: Style) !void {
        var col_in_grid: i32 = 0;
        var row_in_grid: i32 = 0;
        var count: i32 = 0;

        for (self.lines.items) |line| {
            count = 0;
            for (line.items) |c| {
                count += 1;
                if (count >= grid.num_of_cols) {
                    count = 1;
                    row_in_grid += 1;
                    col_in_grid = 0;
                }

                const pos = grid.matrix[try grid.getActualIndex(row_in_grid, col_in_grid)];

                rl.drawTextEx(
                    style.font,
                    rl.textFormat("%c", .{c}),
                    .init(
                        @floatFromInt(pos.x),
                        @floatFromInt(pos.y),
                    ),
                    @floatFromInt(style.font_size),
                    0,
                    .white,
                );

                col_in_grid += 1;
            }

            row_in_grid += 1;
            col_in_grid = 0;
        }
    }

    pub fn drawCursor(
        self: Buffer,
        grid: Grid,
        style: Style,
        /// take the pointer to increase or reset `frame_counter`
        state: *State,
    ) !void {
        if (state.is_focused) {
            state.*.frame_counter += 1;
        } else {
            state.*.frame_counter = 0;
        }

        // TODO: handling over-horizontal
        const real_pos = grid.matrix[
            try grid.getActualIndex(
                @intCast(self.cursor.row),
                @intCast(self.cursor.col),
            )
        ];

        if (state.is_focused) { // blink
            if (((state.*.frame_counter / 20) % 2) == 0) {
                rl.drawText("|", real_pos.x, real_pos.y, style.font_size, .white);
            }
        }
    }

    /// The caller owns the the returned value memory.
    pub fn toString(self: Buffer, alloc: std.mem.Allocator) ![]const u8 {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(alloc);

        for (self.lines.items) |line| {
            try list.appendSlice(alloc, line.items[0..line.items.len]);
            try list.append(alloc, ' ');
        }

        return list.toOwnedSlice(alloc);
    }

    /// Append a character to the cursor position and **right-shift** the cursor.
    ///
    /// Asserts that the current line equals or less than the total line.
    pub fn insert(self: *Buffer, alloc: std.mem.Allocator, char: u8) !void {
        std.debug.assert(self.cursor.row <= self.total_line);

        const curr_idx = self.cursor.col;
        const curr_line = &self.lines.items[self.cursor.row];

        if (curr_idx == curr_line.*.items.len) { // at the last col
            try curr_line.append(alloc, char);
        } else { // at a random index which is not the last col
            try utils.insertAndShiftMemory(alloc, u8, curr_line, curr_idx, char);
        }
        self.seek(.right);
    }

    /// Remove a character at the cursor position and **left-shift
    /// the cursor** if .
    ///
    /// If the cursor at the **first column**, it will move to the
    /// next character in the last character and move all characters
    /// after the cursor back to the previous line and remove the
    /// current line. Otherwise, the cursor will move left.
    ///
    /// Asserts that the current line equals or less than the total line
    pub fn remove(self: *Buffer, alloc: std.mem.Allocator) !void {
        std.debug.assert(self.cursor.row <= self.total_line);
        const curr_line = &self.lines.items[self.cursor.row];
        // nothing to remove
        if (self.cursor.row == 0 and curr_line.items.len == 0) return;
        // at the first column and first row
        if (self.cursor.row == 0 and self.cursor.col == 0) return;

        if (self.cursor.col <= 0) {
            const prev_line = self.lines.items[self.cursor.row - 1];

            if (prev_line.items.len > 0) {
                const num_char_of_prev = prev_line.items.len;
                self.cursor.col = num_char_of_prev;
            } else {
                self.cursor.col = 0;
            }

            var line = self.lines.orderedRemove(self.cursor.row);
            defer line.deinit(alloc);
            self.seek(.up);
            self.total_line -= 1;

            if (line.items.len > 0) {
                try self
                    .lines
                    .items[self.cursor.row]
                    .appendSlice(alloc, line.items);
            }
        } else {
            _ = curr_line.orderedRemove(self.cursor.col - 1);
            self.seek(.left);
        }
    }

    /// Add and move to the new line.
    ///
    /// * If there are any characters after the cursor position, all
    /// will be moved to the new line.
    /// * If the current line is not the last line, all lines after the
    /// current line will shift to the right in `lines`.
    pub fn newLine(self: *Buffer, alloc: std.mem.Allocator) !void {
        const curr_line = &self.lines.items[self.cursor.row];

        var chars: []u8 = "";
        if (curr_line.*.items.len > 0 and self.cursor.col <= curr_line.*.items.len - 1) {
            const after_i = try alloc.dupe(
                u8,
                curr_line.items[self.cursor.col..curr_line.items.len],
            );
            try curr_line.replaceRange(alloc, self.cursor.col, after_i.len, &.{});
            chars = after_i;
        }

        const new_line: std.ArrayList(u8) = create_new_line: {
            if (chars.len > 0) {
                break :create_new_line .fromOwnedSlice(chars);
            } else {
                break :create_new_line .empty;
            }
        };

        if (self.cursor.row != self.total_line - 1) {
            try utils.insertAndShiftMemory(
                alloc,
                std.ArrayList(u8),
                &self.lines,
                self.cursor.row + 1,
                new_line,
            );
        } else {
            try self.lines.append(alloc, new_line);
        }

        self.total_line += 1;
        self.cursor.row += 1;
        self.cursor.col = 0;
    }

    /// Move the cursor with a direction.
    ///
    /// * Up: not move if `cursor.row == 0` (the first line)
    /// * Down: not move if `cursor.row > total line` (the last line)
    /// * Left: not move if `cursor.col == 0` (the first column)
    /// * Right: not move if `cursor.col >= num of characters in the line` (the last column)
    pub fn seek(self: *Buffer, dir: enum {
        up,
        down,
        left,
        right,
    }) void {
        switch (dir) {
            .up, .down => |up_or_down| {
                switch (up_or_down) {
                    .up => {
                        if (self.cursor.row > 0)
                            self.cursor.row -= 1;
                    },
                    .down => {
                        if (self.cursor.row < self.total_line)
                            self.cursor.row += 1;
                    },
                    else => unreachable,
                }

                // move cursor.col if neccessary
                if (self.cursor.col < self.lines.items[self.cursor.row].items.len) {
                    // do nothing
                } else if (self.lines.items[self.cursor.row].items.len > 0) {
                    // move to the last one of the previous line
                    const num_char_of_prev = self.lines.items[self.cursor.row].items.len;
                    self.cursor.col = num_char_of_prev;
                } else {
                    self.cursor.col = 0;
                }
            },
            .left => {
                if (self.cursor.col > 0)
                    self.cursor.col -= 1;
            },
            .right => {
                const curr_line = self.lines.items[self.cursor.row];

                if (self.cursor.col + 1 <= curr_line.items.len)
                    self.cursor.col += 1;
            },
        }
    }
};
