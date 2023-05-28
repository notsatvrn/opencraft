const std = @import("std");

// Numerical identifiers. (example: "1:1")
pub const NumericalID = struct {
    value: u16 = 0,
    variant: u16 = 0,

    // "1:1" to { 1, 1 }
    pub fn fromBytes(bytes: []const u8) !NumericalID {
        var i: usize = 0;

        while (i < bytes.len) : (i += 1) {
            if (bytes[i] == ':' and i < bytes.len - 1) break;
        }

        return .{
            .value = try std.fmt.parseUnsigned(u16, bytes[0..i], 10),
            .variant = if (i < bytes.len) try std.fmt.parseUnsigned(u16, bytes[i + 1 .. bytes.len], 10) else 0,
        };
    }
};

// String identifiers. (example: "minecraft:air")
pub const ID = struct {
    namespace: []const u8 = "minecraft",
    name: []const u8 = "",

    // "minecraft:air" to { "minecraft", "air" }
    pub fn fromBytes(bytes: []const u8) ID {
        var i: usize = 0;

        while (i < bytes.len) : (i += 1) {
            if (bytes[i] == ':' and i < bytes.len - 1) break;
        }

        return .{
            .namespace = if (i < bytes.len) bytes[0..i] else "minecraft",
            .name = if (i < bytes.len) bytes[i + 1 .. bytes.len] else bytes[0..bytes.len],
        };
    }
};

pub const Difficulty = enum {
    peaceful,
    easy,
    normal,
    hard,

    pub fn fromBytes(bytes: []const u8) ?Difficulty {
        if (std.mem.eql(u8, bytes, "peaceful")) {
            return Difficulty.peaceful;
        } else if (std.mem.eql(u8, bytes, "easy")) {
            return Difficulty.easy;
        } else if (std.mem.eql(u8, bytes, "normal")) {
            return Difficulty.normal;
        } else if (std.mem.eql(u8, bytes, "hard")) {
            return Difficulty.hard;
        } else {
            return null;
        }
    }
};

test "NumericalID" {
    var no_variant = try NumericalID.fromBytes("0");

    try std.testing.expect(no_variant.value == 0);
    try std.testing.expect(no_variant.variant == 0);

    var variant = try NumericalID.fromBytes("1:1");

    try std.testing.expect(variant.value == 1);
    try std.testing.expect(variant.variant == 1);
}

test "ID" {
    var no_namespace = ID.fromBytes("air");

    try std.testing.expect(std.mem.eql(u8, no_namespace.namespace, "minecraft"));
    try std.testing.expect(std.mem.eql(u8, no_namespace.name, "air"));

    var namespace = ID.fromBytes("namespace:name");

    try std.testing.expect(std.mem.eql(u8, namespace.namespace, "namespace"));
    try std.testing.expect(std.mem.eql(u8, namespace.name, "name"));
}
