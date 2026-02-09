const eno = @import("eno");
const common = eno.common;
const scheds = common.schedules;

const World = eno.ecs.World;
const Transform = common.Transform;

pub fn build(w: *World) void {
    _ = w.addSystem(.system, scheds.startup, spawn);
}

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/map.png");
    _ = w.spawnEntity(&.{
        try common.Texture2D.fromImage(map_img),
        Transform.fromXYZ(0, 0, 0),
    });
}
