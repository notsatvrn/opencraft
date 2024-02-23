const std = @import("std");
const fmt = @import("../fmt.zig");

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

    pub fn writeAlloc(self: Vec3i, version: u16) ![]const u8 {
        return fmt.number.writeBigAlloc(i64, blk: {
            if (version < 477) break :blk ((self.x & 0x3FFFFFF) << 38) | ((self.y & 0xFFF) << 26) | (self.z & 0x3FFFFFF);
            break :blk ((self.x & 0x3FFFFFF) << 38) | ((self.z & 0x3FFFFFF) << 12) | (self.y & 0xFFF);
        });
    }

    pub fn read(version: u16, bytes: []const u8) Vec3i {
        const value = fmt.number.readBig(i64, bytes);
        return .{
            .x = value >> 38,
            .y = if (version < 477) (value >> 26) & 0xFFF else value << 52 >> 52,
            .z = if (version < 477) value << 38 >> 38 else value << 26 >> 38,
        };
    }
};
