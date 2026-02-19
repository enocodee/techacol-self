const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
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

/// 1 is wall, 0 is ground
// TODO: remove
pub const collision_block_arr =
    &[_]u2{1} ** 120 ** 2 ++
    (&[_]u2{1} ++ &[_]u2{0} ** 118 ++ &[_]u2{1}) ** 56 ++
    &[_]u2{1} ** 120;

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/map.png");

    try w.spawnEntity(&.{
        Map{},
        try rl.Texture2D.fromImage(map_img),
        Transform.fromXYZ(0, 0, 0),
    }).withChildren(struct {
        pub fn cb(parent: eno.ecs.Entity) !void {
            const parent_transform, const parent_texture = try parent.getComponents(&.{ Transform, rl.Texture2D });
            var grid = common.Grid{
                .num_of_cols = 120,
                .num_of_rows = 59,
                .cell_gap = 0,
                .cell_height = 16,
                .cell_width = 16,
                .color = .red,
                .render_mode = .none,
            };
            grid.initCells(
                parent.world.alloc,
                parent_transform.x - @divTrunc(parent_texture.width, 2),
                parent_transform.y - @divTrunc(parent_texture.height, 2),
            );

            const entity = parent.spawn(&.{
                common.GridBundle{
                    .grid = grid,
                    .transform = Transform.fromXYZ(
                        parent_transform.x,
                        parent_transform.y,
                        1,
                    ),
                },
            });

            _ = parent.setComponent(common.InGrid, .{ .grid_entity = entity.id });
        }
    }.cb);
}
