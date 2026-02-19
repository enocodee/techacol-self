const eno = @import("eno");
const ecs = eno.ecs;

const World = ecs.World;

const player_health_bar = @import("player_health_bar/mod.zig");

const hit = @import("hit/mod.zig");
pub const Hit = hit.Hit;

pub fn build(w: *World) void {
    _ = w.addModules(&.{
        player_health_bar,
        hit,
    });
}
