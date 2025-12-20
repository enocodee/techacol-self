const std = @import("std");

/// Increase the list item length by 1 and right-shift all
/// items after from index `i`, then insert an `item` at
/// index `i` in list.
pub fn insertAndShiftMemory(
    alloc: std.mem.Allocator,
    comptime T: type,
    list: *std.ArrayList(T),
    i: usize,
    item: T,
) !void {
    try list.ensureTotalCapacity(alloc, list.items.len + 1);
    list.items.len += 1;
    @memmove(
        list.items[i + 1 .. list.items.len],
        list.items[i .. list.items.len - 1],
    );
    list.items[i] = item;
}
