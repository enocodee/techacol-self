const eno = @import("eno");
const ecs = eno.ecs;
const ui = eno.ui;
const scheds = eno.common.schedules;

const UiStyle = ui.components.Style;
const World = ecs.World;
const Entity = ecs.Entity;
const Query = ecs.query.Query;
const With = ecs.query.With;

const Player = @import("../../features/player/mod.zig").Player;
const Health = @import("../../features/general_components.zig").Health;

const PlayerHealthBar = struct {
    max_width: u32,
};

pub fn build(w: *World) void {
    _ = w
        .addSystem(.system, scheds.startup, spawn)
        .addSystem(.system, scheds.update, update);
}

fn spawn(w: *World) !void {
    try w.spawnEntity(&.{ // background
        UiStyle{
            .width = 200,
            .height = 50,
            .bg_color = .black,
            .pos = .{ .x = 10, .y = 10 },
        },
    }).withChildren(struct {
        pub fn cb(p1: Entity) !void {
            const s1 = (try p1.getComponents(&.{UiStyle}))[0];

            try p1.spawn(&.{ // foreground 1
                UiStyle{
                    .width = s1.width - 10,
                    .height = s1.height - 10,
                    .bg_color = .red,
                    .pos = .{ .x = s1.pos.x + 5, .y = s1.pos.y + 5 },
                    .z_index = 1,
                },
            }).withChildren(struct {
                pub fn cb(p2: Entity) !void { // foreground 2
                    const s2 = (try p2.getComponents(&.{UiStyle}))[0];
                    _ = p2.spawn(&.{
                        PlayerHealthBar{ .max_width = s2.width },
                        UiStyle{
                            .width = s2.width,
                            .height = s2.height,
                            .bg_color = .green,
                            .pos = .{ .x = s2.pos.x, .y = s2.pos.y },
                            .z_index = 2,
                        },
                    });
                }
            }.cb);
        }
    }.cb);
}

fn update(
    player_q: Query(&.{ Health, With(&.{Player}) }),
    health_bar_q: Query(&.{ PlayerHealthBar, *UiStyle }),
) !void {
    const health = player_q.single()[0];
    const health_bar, const style = health_bar_q.single();
    const curr_percetange = health.getCurrentPercetange();
    style.width = @intFromFloat(@as(f32, @floatFromInt(health_bar.max_width)) * curr_percetange);
}
