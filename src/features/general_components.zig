pub const Health = struct {
    max: f32,
    current: f32,

    pub fn init(max: f32) Health {
        return .{ .max = max, .current = max };
    }

    pub fn getCurrentPercetange(self: Health) f32 {
        return self.current / self.max;
    }
};
