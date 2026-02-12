const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;
const grid_collision = @import("extra_modules").grid_collision;

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const With = eno.ecs.query.With;
const Transform = common.Transform;

const Map = @import("../map/mod.zig").Map;

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
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .down,
        )) return;

        player_transform.y += VELOCITY;
    }
    if (rl.isKeyDown(.k)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .up,
        ))
            return;

        player_transform.y -= VELOCITY;
    }
    if (rl.isKeyDown(.h)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .left,
        )) return;

        player_transform.x -= VELOCITY;
    }
    if (rl.isKeyDown(.l)) {
        if (try grid_collision.getDirectedBlock(
            player_tex,
            player_transform.*,
            map_grid,
            .right,
        )) return;

        player_transform.x += VELOCITY;
    }
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
