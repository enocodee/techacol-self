const eno = @import("eno");
const common = eno.common;
const scheds = common.schedules;

const World = eno.ecs.World;
const Transform = common.Transform;

pub const SpawnMap = eno.ecs.system.Set{ .name = "spawn_map" };
pub const Map = struct {};

pub fn build(w: *World) void {
    _ = w.addSystemWithConfig(
        .system,
        scheds.startup,
        spawn,
        .{ .in_sets = &.{SpawnMap} },
    );
}

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/map.png");
    _ = w.spawnEntity(&.{
        Map{},
        try common.Texture2D.fromImage(map_img),
        Transform.fromXYZ(0, 0, 0),
    });
}
