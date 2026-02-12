const eno = @import("eno");
const common = eno.common;
const rl = eno.common.raylib;

const Transform = common.Transform;
const Grid = common.Grid;

/// Currently, this generated arr is created based on
/// what is drawn in the map image (.png);
/// 1 is wall, 0 is ground
// TODO: create a tilemap module with collision masks
//       and remove this harded-code
pub const collision_block_arr =
    &[_]u2{1} ** 120 ** 2 ++
    (&[_]u2{1} ++ &[_]u2{0} ** 118 ++ &[_]u2{1}) ** 56 ++
    &[_]u2{1} ** 120;

pub fn getDirectedBlock(
    origin_texture: rl.Texture2D,
    origin_transform: Transform,
    grid: Grid,
    direction: enum { up, down, left, right },
) !bool {
    const x = origin_transform.x;
    const y = origin_transform.y;
    const z = origin_transform.z;

    const block: Transform = switch (direction) {
        .up => .fromXYZ(x, y - grid.cell_height, z),
        .down => .fromXYZ(x, y + grid.cell_height, z),
        .left => .fromXYZ(x - grid.cell_width, y, z),
        .right => .fromXYZ(x + grid.cell_width, y, z),
    };

    return isCollided(origin_texture, block, grid);
}

pub fn isCollided(
    texture: rl.Texture2D,
    transform: Transform,
    map_grid: common.Grid,
) !bool {
    const idx_from_pixels = map_grid.getVirtualPositionFromPixels(
        transform.x + @divTrunc(texture.width, 2), // center x
        transform.y + @divTrunc(texture.width, 2), // center y
    );
    const idx = map_grid.getActualIndex(
        idx_from_pixels.y,
        idx_from_pixels.x,
    ) catch return false;

    return collision_block_arr[idx] == 1;
}
