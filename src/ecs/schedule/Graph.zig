//! The graph (directed acyclic) represents **systems** and **their dependencies**
//! which are **their children**.
const std = @import("std");

const ScheduleGraph = @This();

/// all nodes in the graph.
/// Indexed by `node id`
_nodes: std.ArrayList(Node) = .empty,
count: usize = 0,

pub const Node = struct {
    id: ID,
    is_visited: bool = false,
    children: std.ArrayList(ID) = .empty,

    pub const ID = union(enum) {
        system: usize,
        set: usize,

        /// Ignore the tag and get value
        pub fn value(self: ID) usize {
            switch (self) {
                .system, .set => |id| return id,
            }
        }
    };

    pub fn init(id: usize) Node {
        return .{
            .id = id,
            .children = .empty,
        };
    }

    /// Deinit children and itself.
    pub fn deinit(self: *Node, alloc: std.mem.Allocator) void {
        self.children.deinit(alloc);
    }
};

pub fn deinit(self: *ScheduleGraph, alloc: std.mem.Allocator) void {
    for (self._nodes.items) |*node| {
        node.deinit(alloc);
    }

    self._nodes.deinit(alloc);
}

pub inline fn nodes(self: ScheduleGraph) []Node {
    return self._nodes.items;
}

/// Adding a new node and return `id`
pub fn add(
    self: *ScheduleGraph,
    alloc: std.mem.Allocator,
    kind: enum { system, set },
) !Node.ID {
    const node: Node = .{
        .id = get_id: switch (kind) {
            inline else => |tag| {
                break :get_id @unionInit(Node.ID, @tagName(tag), self.count);
            },
        },
    };

    try self._nodes.append(alloc, node);
    self.count += 1;
    return node.id;
}

/// Add a dependency that should be run **after**
/// a node with `id = parent_id`.
pub fn addDep(
    self: *ScheduleGraph,
    alloc: std.mem.Allocator,
    parent_id: Node.ID,
    child_id: Node.ID,
) !void {
    try self
        ._nodes
        .items[parent_id.value()]
        .children
        .append(alloc, child_id);
}

test "adding children" {
    const alloc = std.testing.allocator;
    var graph: ScheduleGraph = .{};
    defer graph.deinit(alloc);

    const n1 = try graph.add(alloc, .system);
    const n2 = try graph.add(alloc, .set);
    _ = try graph.addDep(alloc, n2, n1);

    const first_child_in_n2 =
        graph
            ._nodes
            .items[n2.set]
            .children
            .items[0];

    try std.testing.expectEqual(n1, first_child_in_n2);
}

/// Return an immutable node slice after sorting using
/// `Topological` algorithm.
///
/// The caller owns the returned vamemory.
pub fn toposort(self: ScheduleGraph, alloc: std.mem.Allocator) ![]const Node.ID {
    var final: std.ArrayList(Node.ID) = .empty;

    for (self.nodes()) |*node| {
        try self.traversal(alloc, &final, node);
    }

    return @ptrCast(try final.toOwnedSlice(alloc));
}

pub fn traversal(
    self: ScheduleGraph,
    alloc: std.mem.Allocator,
    list: *std.ArrayList(Node.ID),
    node: *Node,
) !void {
    if (!node.is_visited) {
        for (node.children.items) |child_id| {
            try self.traversal(
                alloc,
                list,
                &self._nodes.items[child_id.value()],
            );
        }

        node.is_visited = true;
        switch (node.id) {
            .set => {},
            .system => {
                try list.append(alloc, node.id);
            },
        }
    }
}

test "toposort" {
    const alloc = std.testing.allocator;
    var graph: ScheduleGraph = .{};
    defer graph.deinit(alloc);

    const n0 = try graph.add(alloc, .set); // SetA
    const n1 = try graph.add(alloc, .set); // SetB

    const n2 = try graph.add(alloc, .system); // system1
    const n3 = try graph.add(alloc, .system); // system2
    const n4 = try graph.add(alloc, .system); // system3

    try graph.addDep(alloc, n0, n3); // SetA contains system3
    try graph.addDep(alloc, n0, n1); // SetA run before SetB

    try graph.addDep(alloc, n1, n2); // SetB contains n2
    try graph.addDep(alloc, n1, n4); // SetB contains n4

    const sorted = try graph.toposort(alloc);
    defer alloc.free(sorted);

    const expected = [_]Node.ID{
        .{ .system = 3 },
        .{ .system = 2 },
        .{ .system = 4 },
    };

    try std.testing.expectEqualSlices(Node.ID, &expected, sorted);

    // TODO: solve if the set is added after children systems
}
