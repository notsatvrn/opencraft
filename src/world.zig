const std = @import("std");

pub const dimensions = @import("world/dimensions.zig");

pub usingnamespace dimensions;

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
