const rl = @import("eno").common.raylib;

pub const DebugInfo = struct {
    score: i32 = 0,
    memory_usage: i32 = 0,
};

pub const DebugBox = struct {
    x: i32,
    y: i32,
    font_size: i32,
    item_height: i32,
    width: i32,

    pub fn draw(
        self: DebugBox,
        comptime names: []const []const u8,
        values: anytype,
    ) void {
        rl.drawRectangle(
            self.x,
            self.y,
            self.width,
            self.item_height * @as(i32, @intCast(names.len)),
            .black,
        );

        self.renderInfo(names, values);
    }

    pub fn renderInfo(
        self: DebugBox,
        comptime names: []const []const u8,
        values: anytype,
    ) void {
        var buf = [_:0]u8{0} ** 50;

        inline for (names, values, 0..) |name, value, i| {
            buf = [_:0]u8{0} ** 50;
            var count: i32 = 0;

            for (name, 0..) |c, j| {
                count += 1;
                buf[j] = c;
            }
            // render the field name
            rl.drawText(
                rl.textFormat("%s: ", .{&buf}),
                self.x + 10,
                self.calcY(i),
                self.font_size,
                .sky_blue,
            );

            // render the value
            rl.drawText(
                rl.textFormat("%d", .{value}),
                self.x + count * 10 + 50,
                self.calcY(i),
                self.font_size,
                .sky_blue,
            );
        }
    }

    fn calcY(self: DebugBox, ith: usize) i32 {
        return (self.y + self.item_height * @as(i32, @intCast(ith))) + 10;
    }
};
