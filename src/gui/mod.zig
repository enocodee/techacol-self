const eno = @import("eno");
const ecs = eno.ecs;

const World = ecs.World;

const player_health_bar = @import("player_health_bar/mod.zig");

pub fn build(w: *World) void {
    _ = w.addModules(&.{player_health_bar});
}
