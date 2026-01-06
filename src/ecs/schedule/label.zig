const std = @import("std");
const system = @import("../system.zig");

const World = @import("../World.zig");
const SystemSet = system.Set;
const System = system.System;

const Graph = @import("Graph.zig");

/// A schedule label (or simply called the **schedule**) mark
/// a stage in the schedule and contains all systems need
/// to be run **(belong to)** that label.
pub const Label = struct {
    const LabeledSchedule = @This();

    /// The container that contains all systems in the schedule.
    /// Indexed by system node id in the graph.
    systems: std.ArrayList(System) = .empty,
    system_sets: std.ArrayList(SystemSet) = .empty,
    graph: Graph = .{},
    _label: []const u8,

    pub fn init(comptime _label: []const u8) Label {
        return .{ ._label = _label };
    }

    pub fn deinit(self: *LabeledSchedule, alloc: std.mem.Allocator) void {
        self.systems.deinit(alloc);
        self.graph.deinit(alloc);
    }

    pub fn addSystem(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime sys: System,
    ) !void {
        _ = try self.putOneSystem(alloc, sys);
    }

    pub fn addSystemWithConfig(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime sys: System,
        comptime config: System.Config,
    ) !void {
        var in_set_ids: []Graph.Node.ID = &[_]Graph.Node.ID{};
        if (config.in_sets) |sets| {
            inline for (sets) |set| {
                const id = try self.getOrPutSystemSet(alloc, set);
                in_set_ids = in_set_ids ++ id;
            }
        }

        const system_id = try self.putOneSystem(alloc, sys);
        for (in_set_ids) |set_id| {
            try self.graph.addDep(alloc, set_id, system_id);
        }
    }

    /// Append a **system** to the list and add a **system** node to the graph.
    ///
    /// Return a node id
    fn putOneSystem(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime sys: System,
    ) !Graph.Node.ID {
        try self.systems.append(alloc, sys);
        return try self.graph.add(alloc, .system);
    }

    pub fn addSetWithConfig(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime set: SystemSet,
        comptime config: SystemSet.Config,
    ) !void {
        const set_id = try self.putOneSystemSet(alloc, set);

        inline for (config.after) |s| {
            const parent_set_id = try self.getOrPutSystemSet(alloc, s);
            try self.graph.addDep(alloc, parent_set_id, set_id);
        }

        // TODO: config.before
    }

    /// Get a **system set** node that is the same with `set`,
    /// the new one will be put if not found.
    ///
    /// Return a node id.
    fn getOrPutSystemSet(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime set: SystemSet,
    ) !Graph.Node.ID {
        for (self.graph.nodes()) |node| {
            if (node.id == .system) continue;
            const set_node = self.system_sets.items[node.id.set];
            if (set_node.eql(set)) return node.id;
        }

        return self.putOneSystemSet(alloc, set);
    }

    /// Append a **system set** to the list and add a
    /// **system set** node to the graph.
    ///
    /// Return a node id
    fn putOneSystemSet(
        self: *LabeledSchedule,
        alloc: std.mem.Allocator,
        comptime set: SystemSet,
    ) !Graph.Node.ID {
        try self.system_sets.append(alloc, set);
        return try self.graph.add(alloc, .set);
    }

    /// Get all node in the graph after sorting for scheduling.
    /// The caller owns the returned vamemory.
    ///
    /// See `Label.run()` to run a system by node id.
    pub fn schedule(
        self: LabeledSchedule,
        alloc: std.mem.Allocator,
    ) ![]const Graph.Node.ID {
        return self.graph.toposort(alloc);
    }

    /// Run a system by `node` in the graph
    ///
    /// This function asserts that `node` contains `id` of **a system**
    /// and `id` value is lesss than total number of systems in the
    /// schedule.
    pub fn run(
        self: LabeledSchedule,
        w: *World,
        node_id: Graph.Node.ID,
    ) !void {
        std.debug.assert(std.meta.activeTag(node_id) == .system);
        const system_node_id = node_id.system;
        std.debug.assert(system_node_id < self.systems.items.len);

        try self
            .systems
            .items[system_node_id]
            .handler(w);
    }
};

test "add systems" {
    const H = struct {
        pub fn system1() !void {
            std.log.debug("System 1 is running!", .{});
        }
        pub fn system2() !void {
            std.log.debug("System 2 is running!", .{});
        }
        pub fn system3() !void {
            std.log.debug("System 3 is running!", .{});
        }
    };

    const alloc = std.testing.allocator;
    var world: World = .init(alloc);
    defer world.deinit();

    var test_label: Label = .init("test");
    defer test_label.deinit(alloc);

    // No chidren were added
    try test_label.addSystem(alloc, .fromFn(H.system1));
    try test_label.addSystem(alloc, .fromFn(H.system2));
    try test_label.addSystem(alloc, .fromFn(H.system3));

    const system_node_ids = try test_label.schedule(alloc);
    defer alloc.free(system_node_ids);

    for (system_node_ids, 0..) |id, i| {
        try std.testing.expectEqual(i, id.system);
        try test_label.run(&world, id);
    }

    // TODO: Added children
}
