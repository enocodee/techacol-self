const std = @import("std");
const eno_common = @import("eno").common;
const GameAssets = @This();

/// The font use for most displayed text.
main_font: ?eno_common.raylib.Font = null,
/// The font use for displayed text in terminal.
terminal_font: ?eno_common.raylib.Font = null,

pub fn getMainFont(self: *GameAssets) !eno_common.Font {
    if (self.main_font == null) {
        self.main_font = try eno_common.loadFont("assets/fonts/boldpixelsx1.ttf");
    }
    return self.main_font.?;
}

pub fn getTerminalFont(self: *GameAssets) !eno_common.raylib.Font {
    if (self.terminal_font == null) {
        self.terminal_font = try eno_common.raylib.loadFont("assets/fonts/jetbrains-mono-medium.ttf");
    }
    return self.terminal_font.?;
}

pub fn deinit(self: GameAssets, _: std.mem.Allocator) void {
    if (self.main_font) |f| {
        f.unload();
    }
    if (self.terminal_font) |f| {
        f.unload();
    }
}
