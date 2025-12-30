//! The graph represents **systems** and **their dependencies**
//! which are **their children**.
const std = @import("std");

const ScheduleGraph = @This();

/// all root nodes without any incoming edges
nodes: std.ArrayList(*Node) = .empty,
count: usize = 0,

pub const Node = struct {
    id: usize,
    children: std.ArrayList(*Node) = .empty,

    pub fn init(id: usize) Node {
        return .{
            .id = id,
            .children = .empty,
        };
    }

    /// Deinit children and itself.
    pub fn recursiveDeinit(self: *Node, alloc: std.mem.Allocator) void {
        const children = self.children.items;
        for (children) |child| {
            std.log.debug("deinit ChildrenNode({d}) from ParentNode({d})", .{ child.id, self.id });
            child.recursiveDeinit(alloc);
        }
        self.children.deinit(alloc);
        alloc.destroy(self);
    }

    test "detect memory leaks of nodes in the schedule graph deinit" {
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
};

pub fn add(
    self: *ScheduleGraph,
    alloc: std.mem.Allocator,
    node: Node,
) !void {
    // NOTE: persist the node in the heap
    const node_ptr = try alloc.create(Node);
    node_ptr.* = node;
    errdefer alloc.destroy(node_ptr);

    try self.nodes.append(alloc, node_ptr);
    self.count += 1;
}

pub fn deinit(self: *ScheduleGraph, alloc: std.mem.Allocator) void {
    for (self.nodes.items) |n| {
        n.recursiveDeinit(alloc);
    }
    self.nodes.deinit(alloc);
}

/// return an immutable node slice
pub fn getTopoSort(self: ScheduleGraph) []*const Node {
    // TODO: sort
    return @ptrCast(self.nodes.items[0..self.count]);
}
