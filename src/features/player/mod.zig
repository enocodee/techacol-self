const eno = @import("eno");
const common = eno.common;
const rl = common.raylib;
const scheds = common.schedules;

const World = eno.ecs.World;
const Query = eno.ecs.query.Query;
const With = eno.ecs.query.With;
const Transform = common.Transform;

const Player = struct {};

const VELOCITY = 5;

pub fn build(w: *World) void {
    _ = w
        .addSystem(.system, scheds.startup, spawn)
        .addSystems(.system, scheds.update, &.{ movement, updateCam, onWindowResize });
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
}

fn movement(
    player_q: Query(&.{
        *Transform,
        With(&.{Player}),
    }),
) !void {
    const transform = player_q.single()[0];

    if (rl.isKeyDown(.j)) transform.y += VELOCITY;
    if (rl.isKeyDown(.k)) transform.y -= VELOCITY;
    if (rl.isKeyDown(.h)) transform.x -= VELOCITY;
    if (rl.isKeyDown(.l)) transform.x += VELOCITY;
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
