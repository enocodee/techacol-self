const std = @import("std");
const rl = @import("raylib");
const digger = @import("../../digger/mod.zig");
const utils = @import("../utils.zig");

const Terminal = @import("../mod.zig").Terminal;
const Buffer = @import("../mod.zig").Buffer;
const Executor = @import("../../command_executor/mod.zig").CommandExecutor;
const Interpreter = @import("../../interpreter/Interpreter.zig");
const World = @import("ecs").World;
const Grid = @import("ecs").common.Grid;

/// Running all available cmds in queue
pub fn execCmds(w: *World, _: std.mem.Allocator) !void {
    const executor = (try w.query(&.{ *Executor, Terminal }))[0][0];
    try executor.execNext(w, 1000);
}

pub fn handleKeys(
    alloc: std.mem.Allocator,
    buf: *Buffer,
    ts_backspace: *i64,
) !void {
    _ = ts_backspace;
    if (try handleTyping(alloc, buf)) return;

    // TODO: handle key combination and key holding
    const pressed = rl.getKeyPressed();
    if (pressed != .null) {
        switch (pressed) {
            .backspace => try buf.remove(alloc),
            .enter => try buf.newLine(alloc),
            .left => buf.seek(.left),
            .right => buf.seek(.right),
            .up => buf.seek(.up),
            .down => buf.seek(.down),
            else => {},
        }
    }
}

/// Return `true` if typing
pub fn handleTyping(alloc: std.mem.Allocator, buf: *Buffer) !bool {
    var key_int = rl.getCharPressed();

    while (key_int != 0) : (key_int = rl.getCharPressed()) {
        // allow range 32..127 chars in unicode
        if (key_int >= 32 and key_int < 127) {
            try buf.insert(alloc, @as(u8, @intCast(key_int)));
        }
    }

    return key_int != 0;
}

pub fn process(
    w: *World,
    alloc: std.mem.Allocator,
    content: []const u8,
    lang: Interpreter.Language,
) !void {
    var executor = (try w.query(&.{ *Executor, Terminal }))[0][0];
    var interpreter: Interpreter = .{};

    const cmds = try interpreter.parse(alloc, content, lang);
    defer alloc.free(cmds);

    for (cmds) |cmd| {
        try executor.enqueue(cmd);
    }
}
