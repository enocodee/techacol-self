const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const With = eno.ecs.query.With;
const Transform = common.Transform;

const Map = @import("../map/mod.zig").Map;
const collision_block_arr = @import("../map/mod.zig").collision_block_arr;

const Player = struct {};

const VELOCITY = 5;

pub fn build(w: *World) void {
    _ = w
        .addSystem(.system, scheds.startup, spawn)
        .addSystems(
        .system,
        scheds.update,
        &.{
            movement,
            updateCam,
            onWindowResize,
        },
    );
}

fn spawn(w: *World) !void {
    const map_img = try common.raylib.loadImage("assets/main_char.png");
    _ = w.spawnEntity(&.{
        Player{},
        rl.Camera2D{
            .offset = .{
                .x = @floatFromInt(@divTrunc(rl.getScreenWidth(), 2)),
                .y = @floatFromInt(@divTrunc(rl.getScreenHeight(), 2)),
            },
            .target = .{ .x = 50, .y = 50 },
            .rotation = 0,
            .zoom = 2.0,
        },
        try common.Texture2D.fromImage(map_img),
        Transform.fromXYZ(50, 50, 1),
    });
}

fn updateCam(
    player_q: Query(&.{
        *rl.Camera2D,
        Transform,
        With(&.{Player}),
    }),
) !void {
    const cam, const transform = player_q.single();
    cam.target = .init(@floatFromInt(transform.x), @floatFromInt(transform.y));

    if (rl.isKeyPressed(.equal) and rl.isKeyDown(.left_control))
        cam.zoom += 0.2;
    if (rl.isKeyPressed(.minus) and rl.isKeyDown(.left_control))
        cam.zoom -= 0.2;
}

fn movement(
    w: *World,
    player_q: Query(&.{ *Transform, rl.Texture2D, With(&.{Player}) }),
    map_q: Query(&.{ common.InGrid, With(&.{Map}) }),
) !void {
    const player_transform: *Transform = player_q.single()[0];
    const player_tex: rl.Texture2D = player_q.single()[1];

    const map_grid: common.Grid =
        (try w
            .entity(map_q.single()[0].grid_entity)
            .getComponents(&.{common.Grid}))[0];

    if (rl.isKeyDown(.j)) {
        if (try getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid.cell_width,
            map_grid.cell_height,
            map_grid,
            .down,
        )) return;

        player_transform.y += VELOCITY;
    }
    if (rl.isKeyDown(.k)) {
        if (try getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid.cell_width,
            map_grid.cell_height,
            map_grid,
            .up,
        ))
            return;

        player_transform.y -= VELOCITY;
    }
    if (rl.isKeyDown(.h)) {
        if (try getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid.cell_width,
            map_grid.cell_height,
            map_grid,
            .left,
        )) return;

        player_transform.x -= VELOCITY;
    }
    if (rl.isKeyDown(.l)) {
        if (try getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid.cell_width,
            map_grid.cell_height,
            map_grid,
            .right,
        )) return;

        player_transform.x += VELOCITY;
    }
}

fn getDirectedBlock(
    origin_texture: rl.Texture2D,
    origin_transform: Transform,
    block_width: i32,
    block_height: i32,
    map_grid: common.Grid,
    direction: enum { up, down, left, right },
) !bool {
    const x = origin_transform.x;
    const y = origin_transform.y;
    const z = origin_transform.z;

    const block: Transform = switch (direction) {
        .up => .fromXYZ(x, y - block_height, z),
        .down => .fromXYZ(x, y + block_height, z),
        .left => .fromXYZ(x - block_width, y, z),
        .right => .fromXYZ(x + block_width, y, z),
    };

    return isCollided(origin_texture, block, map_grid);
}

fn isCollided(
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

fn onWindowResize(
    player_q: Query(&.{
        *rl.Camera2D,
        With(&.{Player}),
    }),
) !void {
    if (rl.isWindowResized()) {
        const cam = player_q.single()[0];
        cam.offset = .init(
            @floatFromInt(@divTrunc(rl.getScreenWidth(), 2)),
            @floatFromInt(@divTrunc(rl.getScreenHeight(), 2)),
        );
    }
}
