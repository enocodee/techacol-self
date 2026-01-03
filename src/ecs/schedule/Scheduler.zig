//! A scheduler who collects and run all schedules by order
//! in the application.
const std = @import("std");
const ScheduleLabel = @import("label.zig").Label;

const Scheduler = @This();

labels: std.StringHashMapUnmanaged(ScheduleLabel) = .{},

pub fn deinit(
    self: *Scheduler,
    alloc: std.mem.Allocator,
) void {
    var value_iter = self.labels.valueIterator();
    while (value_iter.next()) |label| {
        label.deinit(alloc);
    }
    self.labels.deinit(alloc);
}

/// This function can cause to `panic` due to out of memory.
pub fn addSchedule(
    self: *Scheduler,
    alloc: std.mem.Allocator,
    schedule: ScheduleLabel,
) void {
    self
        .labels
        .put(alloc, schedule._label, schedule) catch @panic("OOM");
}

/// Run a schedule
pub fn runSchedule(
    self: Scheduler,
    w: *@import("../World.zig"),
    label: ScheduleLabel,
) !void {
    const sched = self
        .labels
        .get(label._label) orelse
        return error.ScheduleNotFound;

    const system_nodes = sched.schedule();
    for (system_nodes) |node| {
        try sched.run(w, node.*);
    }
}

pub fn addSystem(
    self: *Scheduler,
    schedule_label: @TypeOf(.enum_literal),
    comptime system_fn: anytype,
) void {
    const label = self
        .labels
        .getPtr(@tagName(schedule_label)) orelse @panic("invalid shedule"); // NOTE: this is intended :)

    label.addSystem(self.alloc, system_fn) catch @panic("OOM");
}
