//! A namepsace that contains all thing related to `system`.
//!
//! Systems define how controlling elements (entity, component,
//! resource, ...) in application.
//!
//! * Registry: where all systems are registered (stored).
//! * Scheduler: decides which system is executed.
//! * Executor: decides how system is executed.
const std = @import("std");

const System = @import("../system.zig").System;

const Phases = enum {
    pre_startup,
    startup,
    update,
};

/// The graph represents systems and their dependencies
/// which are children.
pub const ScheduleGraph = struct {
    // all root nodes without any incoming edges
    nodes: std.ArrayList(*Node) = .empty,

    pub const Node = struct {
        pub const ID = usize;

        system_id: ID,
        children: std.ArrayList(*Node),

        pub fn init(id: ID) Node {
            return .{
                .system_id = id,
                .children = .empty,
            };
        }

        /// Deinit children and itself.
        pub fn recursiveDeinit(self: *Node, alloc: std.mem.Allocator) void {
            const children = self.children.items;
            for (children) |child| {
                std.log.debug("deinit {d} from {d}", .{ child.system_id, self.system_id });
                child.recursiveDeinit(alloc);
            }
            self.children.deinit(alloc);
            alloc.destroy(self);
        }
    };

    test "detect memory leaks in schedule info deinit" {
        const alloc = std.testing.allocator;

        const if1 = try alloc.create(Node);
        if1.* = .init(1);
        defer if1.recursiveDeinit(alloc);

        const if2 = try alloc.create(Node);
        if2.* = .init(2); // will be deinit in if1
        const if3 = try alloc.create(Node);
        if3.* = .init(3); // will be deinit in if2

        try if1.children.append(alloc, if2);
        try if2.children.append(alloc, if3);
    }

    pub fn init() ScheduleGraph {
        return .{ .nodes = .empty };
    }

    pub fn deinit(self: *ScheduleGraph, alloc: std.mem.Allocator) void {
        for (self.nodes.items) |n| {
            n.recursiveDeinit(alloc);
        }
        self.nodes.deinit(alloc);
    }
};

pub const Scheduler = struct {
    /// The container that contains all systems in the schedule.
    systems: std.ArrayList(System) = .empty,
    graph: ScheduleGraph,
    _labels: [][]const u8,

    pub fn init(comptime Labels: type) Scheduler {
        if (@typeInfo(Labels) != .@"enum")
            @compileError("Expected a enum, found {s}" ++ @typeName(Labels));

        const labels_str = comptime extract_fields: {
            const fields = std.meta.fields(Labels);
            var labels_str: [][]const u8 = &[0][]const u8{};
            for (fields) |f| {
                labels_str = labels_str ++ [_][]const u8{f.name};
            }
            break :extract_fields labels_str;
        };

        return .{ ._labels = labels_str };
    }

    pub fn deinit(self: *Scheduler, alloc: std.mem.Allocator) void {
        self.systems.deinit(alloc);
        self.graph.deinit(alloc);
    }
};

test "init scheduler" {
    const TestScheduleLabels = enum {
        start,
        init,
        update,
        deinit,
    };

    const scheduler = Scheduler.init(TestScheduleLabels);
    const expected = &[4][]const u8{ "start", "init", "update", "deinit" };

    try std.testing.expectEqualSlices(expected, scheduler._labels);
}
