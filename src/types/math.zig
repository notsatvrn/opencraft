const std = @import("std");

pub const Vec3d = packed struct {
    x: f64,
    y: f64,
    z: f64,

    pub inline fn init(x: f64, y: f64, z: f64) Vec3d {
        return .{ .x = x, .y = y, .z = z };
    }
};

pub const Vec3s = packed struct {
    x: i16,
    y: i16,
    z: i16,

    pub inline fn init(x: i16, y: i16, z: i16) Vec3s {
        return .{ .x = x, .y = y, .z = z };
    }
};

// Often used to store position in packets.
// Position serialization and deserialization changed in 477 (1.14).
// Because of this, the protocol version must be passed to use the correct implementation.
pub const Vec3i = packed struct {
    x: i32,
    y: i32,
    z: i32,

    pub inline fn init(x: i32, y: i32, z: i32) Vec3i {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn write(self: Vec3i, version: u16) i64 {
        if (version < 477) {
            return ((self.x & 0x3FFFFFF) << 38) | ((self.y & 0xFFF) << 26) | (self.z & 0x3FFFFFF);
        } else {
            return ((self.x & 0x3FFFFFF) << 38) | ((self.z & 0x3FFFFFF) << 12) | (self.y & 0xFFF);
        }
    }

    pub fn read(version: u16, value: i64) Vec3i {
        return .{
            .x = value >> 38,
            .y = if (version < 477) (value >> 26) & 0xFFF else value << 52 >> 52,
            .z = if (version < 477) value << 38 >> 38 else value << 26 >> 38,
        };
    }
};

pub const Direction = union(enum) {
    north,
    west,
    south,
    east,
    up,
    down,
    exact: struct { pitch: f64, yaw: f64 },
};
