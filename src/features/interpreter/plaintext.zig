const std = @import("std");

const Interpreter = @import("Interpreter.zig");

const Error = Interpreter.Error;
const Command = Interpreter.Command;

pub fn parse(
    alloc: std.mem.Allocator,
    interpreter: *Interpreter,
    source: []const u8,
) ![]Command {
    const command_parser: Command.Parser = .init(alloc, interpreter);
    var commands: std.ArrayList(Command) = .empty;
    var line_iter = std.mem.splitSequence(u8, source, "\r\n");

    while (line_iter.next()) |line| {
        var tokenizer = std.mem.tokenizeAny(u8, line, " ");

        const fn_name: []const u8 = tokenizer.next() orelse break;
        const should_be_value = tokenizer.next() orelse {
            try interpreter.appendError(alloc, .{
                .tag = .expected_type_action,
                .extra = .{ .expected_token = "arguments" },
                .token = "empty",
            });
            break;
        };
        const cmd = try command_parser.parse(
            fn_name,
            should_be_value,
            .enum_literal,
        );
        try commands.append(alloc, cmd);
    }
    return commands.toOwnedSlice(alloc);
}

test "parse action (plaintext)" {
    // simulate the `World.arena`
    var base_alloc = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer base_alloc.deinit();
    const alloc = base_alloc.allocator();

    var interpreter: Interpreter = .{};
    const list_err = &interpreter.errors;

    const action_1 = "move up";
    const parsed_1 = try parse(alloc, &interpreter, action_1);
    const result_1: Command = .{
        .move = .up,
    };
    try std.testing.expectEqual(1, parsed_1.len);
    try std.testing.expectEqual(result_1, parsed_1[0]);

    const action_2 = "nothing arg";
    _ = try parse(alloc, &interpreter, action_2);

    try std.testing.expectEqualDeep(Error{
        .tag = .unknown_action,
        .token = "nothing",
    }, list_err.*.getLast());

    const action_3 = "move forward";
    _ = try parse(alloc, &interpreter, action_3);

    try std.testing.expectEqualDeep(Error{
        .tag = .expected_type_action,
        .extra = .{ .expected_token = "digger.MoveDirection" },
        .token = "forward",
    }, list_err.*.getLast());
}
