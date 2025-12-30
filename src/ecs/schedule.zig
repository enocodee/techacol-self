const Resource = @import("resource.zig").Resource;
const World = @import("World.zig");

pub const Label = @import("schedule/label.zig").Label;
pub const Graph = @import("schedule/Graph.zig");
pub const Scheduler = @import("schedule/Scheduler.zig");

pub const schedules = struct {
    /// Start the application
    pub const startup = Label.init("startup");

    /// The main loop of the application
    pub const update = Label.init("update");

    /// End the frame
    pub const last = Label.init("deinit");
};

const MainScheduleOrder = struct {
    /// Just run once
    startup_labels: []const Label = &[_]Label{
        schedules.startup,
    },
    /// Run multiple times
    labels: []const Label = &[_]Label{
        schedules.update,
        schedules.last,
    },
    is_run_once: bool = false,
};

fn run(w: *World, orders_res: Resource(*MainScheduleOrder)) !void {
    const orders = orders_res.result;
    if (!orders.is_run_once) {
        for (orders.startup_labels) |label| {
            try w.runSchedule(label);
        }
        orders.*.is_run_once = true;
    }

    for (orders.labels) |label| {
        try w.runSchedule(label);
    }
}

fn endFrame(w: *World) !void {
    // reset the short-lived allocator
    _ = w.arena.reset(.free_all);
}

/// The main schedule includes (startup, update, last)
pub const main_schedule_mod = struct {
    pub fn build(w: *@import("World.zig")) void {
        _ = w
            .addSchedule(schedules.startup)
            .addSchedule(schedules.update)
            .addSchedule(schedules.last)
            .addResource(MainScheduleOrder, .{})
            .addSystem(@import("common.zig").entry, run)
            .addSystem(schedules.last, endFrame);
    }
};
