const std = @import("std");

const blocks = @import("world/blocks.zig");

pub const Registry = struct {
    // value -> variant -> block/item
    legacy: std.ArrayList(std.ArrayList(type)),
    // namespace -> name -> block/item
    string: std.StringHashMap(std.StringHashMap(type)),
    // blockstate ID -> block + properties
    // modern: std.ArrayList(struct { type, std.StringHashMap([]const u8) }),
};

// Legacy numerical identifiers. (example: "1:1")
pub const LegacyID = packed struct {
    value: u16 = 0,
    variant: u16 = 0,

    // "1:1" to { 1, 1 }
    pub fn fromString(string: []const u8) !LegacyID {
        var i: usize = 0;
        while (i < string.len and string[i] != ':') : (i += 1) {}
        return .{
            .value = try std.fmt.parseUnsigned(u16, string[0..i], 10),
            .variant = if (i < string.len) try std.fmt.parseUnsigned(u16, string[i + 1 .. string.len], 10) else 0,
        };
    }
};

// String identifiers. (example: "minecraft:air")
pub const StringID = struct {
    namespace: []const u8 = "minecraft",
    name: []const u8 = "",
    _combined_cached: []const u8 = "",

    // "minecraft:air" to { "minecraft", "air" }
    pub fn fromString(string: []const u8) StringID {
        var i: usize = 0;
        while (i < string.len and string[i] != ':') : (i += 1) {}
        return .{
            .namespace = if (i < string.len) string[0..i] else "minecraft",
            .name = if (i < string.len) string[i + 1 .. string.len] else string[0..string.len],
            ._combined_cached = string,
        };
    }
};

test LegacyID {
    const no_variant = try LegacyID.fromString("0");

    try std.testing.expect(no_variant.value == 0);
    try std.testing.expect(no_variant.variant == 0);

    const variant = try LegacyID.fromString("1:1");

    try std.testing.expect(variant.value == 1);
    try std.testing.expect(variant.variant == 1);
}

test StringID {
    const no_namespace = StringID.fromString("air");

    try std.testing.expect(std.mem.eql(u8, no_namespace.namespace, "minecraft"));
    try std.testing.expect(std.mem.eql(u8, no_namespace.name, "air"));

    const namespace = StringID.fromString("namespace:name");

    try std.testing.expect(std.mem.eql(u8, namespace.namespace, "namespace"));
    try std.testing.expect(std.mem.eql(u8, namespace.name, "name"));
}

pub const Difficulty = enum {
    peaceful,
    easy,
    normal,
    hard,

    pub fn fromString(string: []const u8) ?Difficulty {
        if (std.mem.eql(u8, string, "peaceful")) {
            return Difficulty.peaceful;
        } else if (std.mem.eql(u8, string, "easy")) {
            return Difficulty.easy;
        } else if (std.mem.eql(u8, string, "normal")) {
            return Difficulty.normal;
        } else if (std.mem.eql(u8, string, "hard")) {
            return Difficulty.hard;
        } else {
            return null;
        }
    }
};
